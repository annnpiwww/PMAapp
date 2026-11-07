// Supabase Edge Function: pos-locations
// Contract references: docs/contracts/pos-locations.md, docs/contracts/app-session.md
// Manages POS locations in public.pos_locations (upsert, delete, import)

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { isSpv, verifySession } from '../_shared/session.ts';

const MAX_BODY_BYTES = 64 * 1024; // 64 KB
const POS_ID_REGEX = /^[A-Za-z0-9_-]{3,60}$/;
const BRANCH_VALUES = new Set(['manado', 'bali', 'ho']);
const SPECIAL_CHARS = /[,()*%]/;

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
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

function timingSafeEqualBytes(a: Uint8Array, b: Uint8Array): boolean {
  const len = Math.max(a.length, b.length, 1);
  let diff = a.length ^ b.length;
  for (let i = 0; i < len; i++) {
    const av = i < a.length ? a[i] : 0;
    const bv = i < b.length ? b[i] : 0;
    diff |= av ^ bv;
  }
  return diff === 0;
}

function base64ToBytes(b64: string): Uint8Array | null {
  try {
    const normalized = b64.replace(/-/g, '+').replace(/_/g, '/');
    const rem = normalized.length % 4;
    if (rem === 1) return null;
    const padded = rem === 0 ? normalized : normalized + '='.repeat(4 - rem);
    const bin = atob(padded);
    const out = new Uint8Array(bin.length);
    for (let i = 0; i < bin.length; i++) {
      out[i] = bin.charCodeAt(i);
    }
    return out;
  } catch {
    return null;
  }
}

async function verifyPbkdf2Compat(password: string, stored: string): Promise<boolean> {
  const parts = stored.split('$');
  if (parts.length !== 4 || parts[0] !== 'pbkdf2') return false;
  const iterations = Number(parts[1]);
  if (!Number.isInteger(iterations) || iterations < 10_000 || iterations > 1_000_000) return false;
  const salt = base64ToBytes(parts[2]);
  const expected = base64ToBytes(parts[3]);
  if (!salt || salt.length !== 16 || !expected || expected.length !== 32) return false;
  const keyMaterial = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(password),
    'PBKDF2',
    false,
    ['deriveBits'],
  );
  const bits = await crypto.subtle.deriveBits(
    { name: 'PBKDF2', hash: 'SHA-256', salt: salt as BufferSource, iterations },
    keyMaterial,
    256,
  );
  return timingSafeEqualBytes(new Uint8Array(bits), expected);
}

export function validateLocation(loc: Record<string, unknown>): {
  valid: boolean;
  cleaned?: Record<string, unknown>;
  error?: string;
} {
  if (!loc || typeof loc !== 'object') {
    return { valid: false, error: 'location must be an object' };
  }
  const { pos_id, pos_name, cabang_name, full_address, location_tag, tag_color, branch, lat, lng } =
    loc;

  if (typeof pos_id !== 'string' || !POS_ID_REGEX.test(pos_id)) {
    return { valid: false, error: 'invalid pos_id' };
  }
  if (typeof pos_name !== 'string' || pos_name.length < 1 || pos_name.length > 120) {
    return { valid: false, error: 'invalid pos_name' };
  }
  if (typeof cabang_name !== 'string' || cabang_name.length < 1 || cabang_name.length > 120) {
    return { valid: false, error: 'invalid cabang_name' };
  }
  const address = typeof full_address === 'string' ? full_address : '';
  if (address.length > 300) {
    return { valid: false, error: 'invalid full_address' };
  }
  if (
    typeof location_tag !== 'string' ||
    location_tag.trim().length < 1 ||
    location_tag.trim().length > 16
  ) {
    return { valid: false, error: 'invalid location_tag' };
  }
  const cleanTag = location_tag.trim().toUpperCase();

  const color = typeof tag_color === 'number' ? Math.floor(tag_color) : 4294286859;

  if (typeof branch !== 'string' || !BRANCH_VALUES.has(branch)) {
    return { valid: false, error: 'invalid branch' };
  }
  if (typeof lat !== 'number' || isNaN(lat) || lat < -90 || lat > 90) {
    return { valid: false, error: 'invalid lat' };
  }
  if (typeof lng !== 'number' || isNaN(lng) || lng < -180 || lng > 180) {
    return { valid: false, error: 'invalid lng' };
  }

  return {
    valid: true,
    cleaned: {
      pos_id,
      pos_name,
      cabang_name,
      full_address: address,
      location_tag: cleanTag,
      tag_color: color,
      branch,
      lat,
      lng,
    },
  };
}

// Legacy 2.0.132 compatibility fallback (only reachable when ENFORCE_SESSION !== 'true' and no x-app-session header)
async function verifySpvLegacy(
  supabaseUrl: string,
  serviceKey: string,
  identity: unknown,
  password: unknown,
  fetchImpl: typeof fetch,
): Promise<{ ok: boolean; status: number; error: string; actor: string }> {
  if (typeof identity !== 'string' || typeof password !== 'string') {
    return { ok: false, status: 401, error: 'unauthorized', actor: '' };
  }
  const idStr = identity.trim();
  const passStr = password.trim();
  if (idStr.length === 0 || idStr.length > 100 || SPECIAL_CHARS.test(idStr)) {
    return { ok: false, status: 401, error: 'unauthorized', actor: '' };
  }
  if (passStr.length === 0 || passStr.length > 128) {
    return { ok: false, status: 401, error: 'unauthorized', actor: '' };
  }

  const encId = encodeURIComponent(idStr);
  const url =
    `${supabaseUrl}/rest/v1/app_users?or=(username.ilike.${encId},email.ilike.${encId},nama.ilike.${encId})&select=username,email,nama,password,password_hash,role`;

  try {
    const res = await fetchImpl(url, {
      method: 'GET',
      headers: {
        apikey: serviceKey,
        Authorization: `Bearer ${serviceKey}`,
      },
    });

    if (!res.ok) {
      console.error(`app_users query failed with status ${res.status}`);
      return { ok: false, status: 500, error: 'server error', actor: '' };
    }

    const users = await res.json();
    if (!Array.isArray(users) || users.length === 0) {
      return { ok: false, status: 401, error: 'unauthorized', actor: '' };
    }

    const lowerId = idStr.toLowerCase();
    const matched = users.find((u: Record<string, unknown>) =>
      (typeof u.username === 'string' && u.username.trim().toLowerCase() === lowerId) ||
      (typeof u.email === 'string' && u.email.trim().toLowerCase() === lowerId) ||
      (typeof u.nama === 'string' && u.nama.trim().toLowerCase() === lowerId)
    );

    if (!matched) {
      return { ok: false, status: 401, error: 'unauthorized', actor: '' };
    }

    let passOk = false;
    const storedHash = typeof matched.password_hash === 'string' ? matched.password_hash.trim() : '';
    if (storedHash.length > 0) {
      passOk = await verifyPbkdf2Compat(passStr, storedHash);
      if (!passOk) {
        passOk = await verifyPbkdf2Compat(passStr.toLowerCase(), storedHash);
      }
    } else {
      const userPass = String(matched.password ?? '').trim().toLowerCase();
      passOk = userPass.length > 0 && timingSafeEqualBytes(
        new TextEncoder().encode(passStr.toLowerCase()),
        new TextEncoder().encode(userPass),
      );
    }

    if (!passOk) {
      return { ok: false, status: 401, error: 'unauthorized', actor: '' };
    }

    const userRole = String(matched.role ?? '').trim().toLowerCase();
    if (userRole !== 'spv' && userRole !== 'supervisor' && userRole !== 'ho' && userRole !== 'headoffice') {
      return { ok: false, status: 403, error: 'forbidden', actor: '' };
    }

    return { ok: true, status: 200, error: '', actor: idStr };
  } catch {
    console.error('SPV check error');
    return { ok: false, status: 500, error: 'server error', actor: '' };
  }
}

async function authorizeSpvRequest(
  req: Request,
  body: Record<string, unknown>,
  supabaseUrl: string,
  serviceRoleKey: string,
  fetchImpl: typeof fetch,
): Promise<{ ok: boolean; status: number; error: string; actor: string }> {
  const enforceSession = Deno.env.get('ENFORCE_SESSION') === 'true';
  const rawSessionHeader = req.headers.get('x-app-session');

  if (rawSessionHeader !== null && rawSessionHeader.trim().length > 0) {
    const session = await verifySession(req);
    if (!session) {
      return { ok: false, status: 401, error: 'unauthorized', actor: '' };
    }
    if (!isSpv(session)) {
      return { ok: false, status: 403, error: 'forbidden', actor: '' };
    }
    return {
      ok: true,
      status: 200,
      error: '',
      actor: session.name || session.uid,
    };
  }

  if (enforceSession) {
    return { ok: false, status: 401, error: 'unauthorized', actor: '' };
  }

  return verifySpvLegacy(supabaseUrl, serviceRoleKey, body.identity, body.password, fetchImpl);
}

export async function handlePosLocations(
  req: Request,
  fetchImpl: typeof fetch = fetch,
): Promise<Response> {
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: corsHeaders });
  }
  if (req.method !== 'POST') {
    return json({ error: 'method not allowed' }, 405);
  }

  const contentLength = Number(req.headers.get('content-length') ?? '0');
  if (contentLength > MAX_BODY_BYTES) {
    return json({ error: 'payload too large' }, 413);
  }

  const rawBody = await req.text();
  if (new TextEncoder().encode(rawBody).length > MAX_BODY_BYTES) {
    return json({ error: 'payload too large' }, 413);
  }

  let body: Record<string, unknown>;
  try {
    const parsed = JSON.parse(rawBody);
    if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) {
      return json({ error: 'invalid' }, 400);
    }
    body = parsed as Record<string, unknown>;
  } catch {
    return json({ error: 'invalid' }, 400);
  }

  const action = body.action;
  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

  if (!supabaseUrl || !serviceRoleKey) {
    console.error('Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY');
    return json({ error: 'server error' }, 500);
  }

  if (action === 'upsert') {
    const auth = await authorizeSpvRequest(req, body, supabaseUrl, serviceRoleKey, fetchImpl);
    if (!auth.ok) {
      return json({ error: auth.error }, auth.status);
    }

    const val = validateLocation(body.location as Record<string, unknown>);
    if (!val.valid || !val.cleaned) {
      return json({ error: 'invalid' }, 400);
    }

    const row = {
      ...val.cleaned,
      active: true,
      source: 'spv',
      updated_by: auth.actor,
    };

    const url = `${supabaseUrl}/rest/v1/pos_locations?on_conflict=pos_id`;
    try {
      const res = await fetchImpl(url, {
        method: 'POST',
        headers: {
          apikey: serviceRoleKey,
          Authorization: `Bearer ${serviceRoleKey}`,
          'Content-Type': 'application/json',
          Prefer: 'resolution=merge-duplicates,return=representation',
        },
        body: JSON.stringify(row),
      });

      if (!res.ok) {
        console.error(`upsert failed with status ${res.status}`);
        return json({ error: 'server error' }, 500);
      }

      return json({ ok: true, count: 1 }, 200);
    } catch {
      console.error('upsert error');
      return json({ error: 'server error' }, 500);
    }
  }

  if (action === 'delete') {
    const auth = await authorizeSpvRequest(req, body, supabaseUrl, serviceRoleKey, fetchImpl);
    if (!auth.ok) {
      return json({ error: auth.error }, auth.status);
    }

    const posId = body.pos_id;
    if (typeof posId !== 'string' || !POS_ID_REGEX.test(posId)) {
      return json({ error: 'invalid' }, 400);
    }

    const url = `${supabaseUrl}/rest/v1/pos_locations?pos_id=eq.${encodeURIComponent(posId)}`;
    try {
      const res = await fetchImpl(url, {
        method: 'PATCH',
        headers: {
          apikey: serviceRoleKey,
          Authorization: `Bearer ${serviceRoleKey}`,
          'Content-Type': 'application/json',
          Prefer: 'return=representation',
        },
        body: JSON.stringify({
          active: false,
          updated_by: auth.actor,
        }),
      });

      if (!res.ok) {
        console.error(`delete failed with status ${res.status}`);
        return json({ error: 'server error' }, 500);
      }

      const rows = await res.json();
      const count = Array.isArray(rows) ? rows.length : 1;
      return json({ ok: true, count }, 200);
    } catch {
      console.error('delete error');
      return json({ error: 'server error' }, 500);
    }
  }

  if (action === 'import') {
    const auth = await authorizeSpvRequest(req, body, supabaseUrl, serviceRoleKey, fetchImpl);
    if (!auth.ok) {
      return json({ error: auth.error }, auth.status);
    }

    const locations = body.locations;
    if (!Array.isArray(locations) || locations.length === 0 || locations.length > 50) {
      return json({ error: 'invalid' }, 400);
    }

    const rows: Record<string, unknown>[] = [];
    for (const item of locations) {
      const val = validateLocation(item as Record<string, unknown>);
      if (!val.valid || !val.cleaned) {
        return json({ error: 'invalid' }, 400);
      }
      rows.push({
        ...val.cleaned,
        active: true,
        source: 'device_import',
      });
    }

    const url = `${supabaseUrl}/rest/v1/pos_locations?on_conflict=pos_id`;
    try {
      const res = await fetchImpl(url, {
        method: 'POST',
        headers: {
          apikey: serviceRoleKey,
          Authorization: `Bearer ${serviceRoleKey}`,
          'Content-Type': 'application/json',
          Prefer: 'resolution=ignore-duplicates,return=representation',
        },
        body: JSON.stringify(rows),
      });

      if (!res.ok) {
        console.error(`import failed with status ${res.status}`);
        return json({ error: 'server error' }, 500);
      }

      const inserted = await res.json();
      const count = Array.isArray(inserted) ? inserted.length : rows.length;
      return json({ ok: true, count }, 200);
    } catch {
      console.error('import error');
      return json({ error: 'server error' }, 500);
    }
  }

  return json({ error: 'invalid' }, 400);
}

if (!Deno.env.get('DENO_TESTING')) {
  serve((req: Request) => handlePosLocations(req));
}
