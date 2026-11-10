// Supabase Edge Function: error-push
// Called by DB trigger on daily_tasks_manado, daily_tasks_bali, daily_tasks_ho
// when NEW.kategori = 'error' AND NEW.status = 'pending'.
// Dispatches FCM HTTP v1 push notifications to all devices in the matching branch,
// skipping the creator's device(s).
// Contract: docs/contracts/error-ticket.md

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { resolveTasksTableForCabang } from '../_shared/branch.ts';
import {
  FcmPayload,
  getAccessToken,
  parseServiceAccount,
  sendFcmMessage,
  ServiceAccount,
} from '../_shared/fcm.ts';

const MAX_BODY_BYTES = 64 * 1024;

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-error-push-secret',
  'Access-Control-Max-Age': '86400',
};

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      'Content-Type': 'application/json',
      'Cache-Control': 'no-store',
    },
  });
}

export function timingSafeEqual(a: string, b: string): boolean {
  const enc = new TextEncoder();
  const aBuf = enc.encode(a);
  const bBuf = enc.encode(b);
  if (aBuf.byteLength !== bBuf.byteLength) {
    return false;
  }
  let c = 0;
  for (let i = 0; i < aBuf.byteLength; i++) {
    c |= aBuf[i] ^ bBuf[i];
  }
  return c === 0;
}

export function extractCreator(deskripsi: string | undefined, teknisiNama: string | undefined): string {
  if (deskripsi) {
    const match = deskripsi.match(/^Pelapor\s*:\s*(.+)$/im) ?? deskripsi.match(/^Pelapor\s+(.+)$/im);
    if (match && match[1] && match[1].trim().length > 0) {
      return match[1].trim().toLowerCase();
    }
  }
  return (teknisiNama ?? '').trim().toLowerCase();
}

export interface ErrorPushDeps {
  secret?: string;
  supabaseUrl?: string;
  serviceRoleKey?: string;
  serviceAccount?: ServiceAccount;
  fetchImpl?: typeof fetch;
}

export async function handleErrorPush(
  req: Request,
  deps?: ErrorPushDeps,
): Promise<Response> {
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return json({ error: 'method not allowed' }, 405);
  }

  const expectedSecret = deps?.secret ?? Deno.env.get('ERROR_PUSH_SHARED_SECRET') ?? '';
  const incomingSecret = req.headers.get('x-error-push-secret') ?? '';

  if (!expectedSecret || !incomingSecret || !timingSafeEqual(incomingSecret, expectedSecret)) {
    return json({ error: 'unauthorized' }, 401);
  }

  const clHeader = Number(req.headers.get('content-length') ?? '0');
  if (clHeader > MAX_BODY_BYTES) {
    return json({ error: 'payload too large' }, 413);
  }

  let body: Record<string, unknown> = {};
  try {
    const rawBody = await req.text();
    if (new TextEncoder().encode(rawBody).length > MAX_BODY_BYTES) {
      return json({ error: 'payload too large' }, 413);
    }
    const parsed = JSON.parse(rawBody);
    if (parsed && typeof parsed === 'object' && !Array.isArray(parsed)) {
      body = parsed as Record<string, unknown>;
    }
  } catch {
    return json({ error: 'invalid json' }, 400);
  }

  const tableName = typeof body.table === 'string' ? body.table.trim() : '';
  const record = (body.record && typeof body.record === 'object' && !Array.isArray(body.record))
    ? (body.record as Record<string, unknown>)
    : null;

  if (!tableName || !record) {
    return json({ error: 'missing table or record' }, 400);
  }

  const kategori = String(record.kategori ?? '').trim().toLowerCase();
  const status = String(record.status ?? '').trim().toLowerCase();
  if (kategori !== 'error' || status !== 'pending') {
    return json({ ok: true, skipped: 'not pending error ticket' }, 200);
  }

  const supabaseUrl = deps?.supabaseUrl ?? Deno.env.get('SUPABASE_URL');
  const serviceRoleKey = deps?.serviceRoleKey ?? Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  const fetchImpl = deps?.fetchImpl ?? fetch;

  if (!supabaseUrl || !serviceRoleKey) {
    console.error('error-push: missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY');
    return json({ error: 'server error' }, 500);
  }

  // 1. Fetch all registered device push tokens
  let allTokens: Array<{ token: string; user_name: string; cabang: string }> = [];
  try {
    const tokenRes = await fetchImpl(
      `${supabaseUrl}/rest/v1/device_push_tokens?select=token,user_name,cabang`,
      {
        headers: {
          apikey: serviceRoleKey,
          Authorization: `Bearer ${serviceRoleKey}`,
        },
      },
    );
    if (!tokenRes.ok) {
      const errBody = await tokenRes.text().catch(() => '');
      console.error(`error-push: failed to fetch tokens: HTTP ${tokenRes.status} ${errBody}`);
      return json({ error: 'internal' }, 500);
    }
    allTokens = await tokenRes.json();
  } catch (err) {
    console.error('error-push: error fetching tokens', err);
    return json({ error: 'server error' }, 500);
  }

  // 2. Filter tokens by matching branch via resolveTasksTableForCabang reverse mapping
  const branchTokens = allTokens.filter((t) => resolveTasksTableForCabang(t.cabang) === tableName);

  // 3. Skip creator's tokens
  const creator = extractCreator(
    typeof record.deskripsi === 'string' ? record.deskripsi : undefined,
    typeof record.teknisi_nama === 'string' ? record.teknisi_nama : undefined,
  );

  const targetTokens = branchTokens.filter(
    (t) => (t.user_name ?? '').trim().toLowerCase() !== creator,
  );
  const skippedCreator = branchTokens.length - targetTokens.length;

  if (targetTokens.length === 0) {
    return json({
      ok: true,
      sent: 0,
      skipped_creator: skippedCreator,
      total_branch_tokens: branchTokens.length,
    }, 200);
  }

  // 4. Authenticate FCM Service Account & obtain access token
  let sa: ServiceAccount;
  let accessToken: string;
  try {
    sa = deps?.serviceAccount ?? parseServiceAccount();
    accessToken = await getAccessToken(sa, fetchImpl);
  } catch (err) {
    console.error('error-push: failed to get FCM access token', err);
    return json({ error: 'FCM auth error' }, 500);
  }

  // 5. Dispatch FCM messages to all target tokens
  let sentCount = 0;
  let failedCount = 0;
  const invalidTokens: string[] = [];

  const taskId = String(record.id ?? '');
  const posName = String(record.pos_name ?? '');
  const judul = String(record.judul ?? '');

  const promises = targetTokens.map(async (t) => {
    const payload: FcmPayload = {
      token: t.token,
      data: {
        type: 'error_alarm',
        task_id: taskId,
        pos_name: posName,
        judul: judul,
      },
      priority: 'HIGH',
      ttlSeconds: 3600,
    };

    const res = await sendFcmMessage(sa, accessToken, payload, fetchImpl);
    if (res.success) {
      sentCount++;
    } else {
      failedCount++;
      if (res.unregistered) {
        invalidTokens.push(t.token);
      }
    }
  });

  await Promise.all(promises);

  // 6. Delete invalid/unregistered tokens from DB
  if (invalidTokens.length > 0) {
    for (const invToken of invalidTokens) {
      try {
        await fetchImpl(
          `${supabaseUrl}/rest/v1/device_push_tokens?token=eq.${encodeURIComponent(invToken)}`,
          {
            method: 'DELETE',
            headers: {
              apikey: serviceRoleKey,
              Authorization: `Bearer ${serviceRoleKey}`,
            },
          },
        );
      } catch (err) {
        console.error('error-push: failed to delete unregistered token', err);
      }
    }
  }

  return json(
    {
      ok: true,
      sent: sentCount,
      failed: failedCount,
      unregistered_deleted: invalidTokens.length,
      skipped_creator: skippedCreator,
      total_target_tokens: targetTokens.length,
    },
    200,
  );
}

if (!Deno.env.get('DENO_TESTING')) {
  serve((req: Request) => handleErrorPush(req));
}
