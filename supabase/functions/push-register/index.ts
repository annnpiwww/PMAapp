// Supabase Edge Function: push-register
// Registers or unregisters FCM device push tokens scoped to verified session.
// Contract: docs/contracts/error-ticket.md

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { verifySession } from '../_shared/session.ts';

const MAX_BODY_BYTES = 16 * 1024;
const MIN_TOKEN_LEN = 20;
const MAX_TOKEN_LEN = 4096;

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-app-session',
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

export async function handlePushRegister(
  req: Request,
  deps?: {
    supabaseUrl?: string;
    serviceRoleKey?: string;
    fetchImpl?: typeof fetch;
  },
): Promise<Response> {
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  if (req.method !== 'POST' && req.method !== 'DELETE') {
    return json({ error: 'method not allowed' }, 405);
  }

  const session = await verifySession(req);
  if (!session) {
    return json({ error: 'unauthorized' }, 401);
  }
  if (session.role === 'admin_pos') return json({ error: 'forbidden' }, 403);

  const clHeader = Number(req.headers.get('content-length') ?? '0');
  if (clHeader > MAX_BODY_BYTES) {
    return json({ error: 'payload too large' }, 413);
  }

  let body: Record<string, unknown> = {};
  try {
    const rawBody = await req.text();
    if (rawBody.trim().length > 0) {
      if (new TextEncoder().encode(rawBody).length > MAX_BODY_BYTES) {
        return json({ error: 'payload too large' }, 413);
      }
      const parsed = JSON.parse(rawBody);
      if (parsed && typeof parsed === 'object' && !Array.isArray(parsed)) {
        body = parsed as Record<string, unknown>;
      }
    }
  } catch {
    return json({ error: 'invalid json' }, 400);
  }

  const tokenRaw = typeof body.token === 'string' ? body.token.trim() : '';
  if (tokenRaw.length < MIN_TOKEN_LEN || tokenRaw.length > MAX_TOKEN_LEN) {
    return json({ error: 'invalid token length' }, 400);
  }

  const supabaseUrl = deps?.supabaseUrl ?? Deno.env.get('SUPABASE_URL');
  const serviceRoleKey = deps?.serviceRoleKey ?? Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  const fetchImpl = deps?.fetchImpl ?? fetch;

  if (!supabaseUrl || !serviceRoleKey) {
    console.error('push-register: missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY');
    return json({ error: 'server error' }, 500);
  }

  if (req.method === 'POST') {
    const platform = typeof body.platform === 'string' && body.platform.trim().length > 0
      ? body.platform.trim().toLowerCase().slice(0, 32)
      : 'android';

    const row = {
      token: tokenRaw,
      user_name: session.name,
      cabang: session.cabang,
      role: session.role,
      platform,
      updated_at: new Date().toISOString(),
    };

    try {
      const res = await fetchImpl(`${supabaseUrl}/rest/v1/device_push_tokens`, {
        method: 'POST',
        headers: {
          apikey: serviceRoleKey,
          Authorization: `Bearer ${serviceRoleKey}`,
          'Content-Type': 'application/json',
          Prefer: 'resolution=merge-duplicates',
        },
        body: JSON.stringify([row]),
      });

      if (!res.ok) {
        console.error(`push-register upsert failed: ${res.status}`);
        return json({ error: 'failed to register token' }, 500);
      }

      return json({ ok: true, registered: true }, 200);
    } catch (e) {
      console.error('push-register network error', e);
      return json({ error: 'server error' }, 500);
    }
  }

  // DELETE
  try {
    const url = `${supabaseUrl}/rest/v1/device_push_tokens?token=eq.${encodeURIComponent(tokenRaw)}&user_name=eq.${encodeURIComponent(session.name)}`;
    const res = await fetchImpl(url, {
      method: 'DELETE',
      headers: {
        apikey: serviceRoleKey,
        Authorization: `Bearer ${serviceRoleKey}`,
      },
    });

    if (!res.ok) {
      console.error(`push-register delete failed: ${res.status}`);
      return json({ error: 'failed to unregister token' }, 500);
    }

    return json({ ok: true, unregistered: true }, 200);
  } catch (e) {
    console.error('push-register delete network error', e);
    return json({ error: 'server error' }, 500);
  }
}

if (!Deno.env.get('DENO_TESTING')) {
  serve((req: Request) => handlePushRegister(req));
}
