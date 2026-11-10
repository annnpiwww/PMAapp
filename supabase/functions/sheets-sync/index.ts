// Supabase Edge Function: sheets-sync (SEC-08)
// Proxies Google Sheets webhook requests behind session verification
// and sanitizes formula injection vectors ([=+\-@\t\r]).

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { verifySession } from '../_shared/session.ts';
import { resolveTasksTableForCabang } from '../_shared/branch.ts';

const MAX_BODY_BYTES = 200 * 1024; // 200 KB body cap

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-app-session',
  'Access-Control-Max-Age': '86400',
};

function json(body: unknown, status: number) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      'Content-Type': 'application/json',
      'Cache-Control': 'no-store',
    },
  });
}

/**
 * SEC-08: Formula injection prevention.
 * Any string starting with =, +, -, @, tab, or carriage return is prefixed with '
 */
export function sanitizeForSheetValue(val: unknown): unknown {
  if (typeof val === 'string') {
    if (/^[=+\-@\t\r]/.test(val)) {
      return "'" + val;
    }
    return val;
  }
  if (Array.isArray(val)) {
    return val.map(sanitizeForSheetValue);
  }
  if (val !== null && typeof val === 'object') {
    const res: Record<string, unknown> = {};
    for (const [k, v] of Object.entries(val as Record<string, unknown>)) {
      res[k] = sanitizeForSheetValue(v);
    }
    return res;
  }
  return val;
}

export async function handleSheetsSync(
  req: Request,
  fetchImpl: typeof fetch = fetch,
): Promise<Response> {
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return json({ error: 'method_not_allowed' }, 405);
  }

  // 1. Session verification against ../_shared/session.ts
  let session;
  try {
    session = await verifySession(req);
    if (!session) {
      return json({ error: 'unauthorized' }, 401);
    }
  } catch (_e) {
    return json({ error: 'unauthorized' }, 401);
  }

  // 2. Body size check (max 200 KB)
  const contentLength = req.headers.get('content-length');
  if (contentLength && parseInt(contentLength, 10) > MAX_BODY_BYTES) {
    return json({ error: 'payload_too_large', message: 'Body exceeds 200 KB limit' }, 413);
  }

  const rawBytes = await req.arrayBuffer();
  if (rawBytes.byteLength > MAX_BODY_BYTES) {
    return json({ error: 'payload_too_large', message: 'Body exceeds 200 KB limit' }, 413);
  }

  // 3. Parse JSON body
  let bodyJson: Record<string, unknown>;
  try {
    const text = new TextDecoder().decode(rawBytes);
    bodyJson = JSON.parse(text);
    if (typeof bodyJson !== 'object' || bodyJson === null || Array.isArray(bodyJson)) {
      return json({ error: 'bad_request', message: 'Body must be a JSON object' }, 400);
    }
  } catch (_e) {
    return json({ error: 'bad_request', message: 'Invalid JSON payload' }, 400);
  }

  // Tiket Error gate: Manado only
  if (bodyJson.kind === 'error') {
    if (resolveTasksTableForCabang(session.cabang) !== 'daily_tasks_manado') {
      return json({ error: 'forbidden' }, 403);
    }
  }

  // 4. Sanitize formula injection prefixes
  const sanitized = sanitizeForSheetValue(bodyJson) as Record<string, unknown>;

  // 5. Inject secretToken and verify target webhook URL
  const webhookUrl = Deno.env.get('GOOGLE_SHEETS_WEBHOOK_URL');
  if (!webhookUrl) {
    return json({ error: 'server_misconfigured', message: 'GOOGLE_SHEETS_WEBHOOK_URL not configured' }, 500);
  }

  const secretToken = Deno.env.get('GOOGLE_SHEETS_SECRET') || '';
  sanitized['secretToken'] = secretToken;

  // 6. Forward to Google Apps Script webhook (follow 302 redirects)
  try {
    const upstreamRes = await fetchImpl(webhookUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Auth-Token': secretToken,
      },
      body: JSON.stringify(sanitized),
      redirect: 'follow',
    });

    const upstreamText = await upstreamRes.text();
    let upstreamData: unknown;
    try {
      upstreamData = JSON.parse(upstreamText);
    } catch {
      upstreamData = { message: upstreamText };
    }

    const statusCode = upstreamRes.status >= 200 && upstreamRes.status < 400 ? 200 : upstreamRes.status;
    return json(upstreamData, statusCode);
  } catch (err: unknown) {
    const errorMsg = err instanceof Error ? err.message : String(err);
    return json({ error: 'upstream_error', message: errorMsg }, 502);
  }
}

if (!Deno.env.get('DENO_TESTING')) {
  serve((req: Request) => handleSheetsSync(req));
}
