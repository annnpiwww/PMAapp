// Supabase Edge Function: auth-login
// Contract: docs/contracts/app-session.md

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { signSession } from '../_shared/session.ts';

const MAX_BODY_BYTES = 16 * 1024;
const IDENTITY_REGEX = /^[a-zA-Z0-9 ._@-]{1,64}$/;
const PBKDF2_ITERATIONS = 100_000;
const SALT_BYTES = 16;
const HASH_BYTES = 32;

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

function bytesToBase64(bytes: Uint8Array): string {
  let bin = '';
  for (let i = 0; i < bytes.length; i++) {
    bin += String.fromCharCode(bytes[i]);
  }
  return btoa(bin);
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

export function timingSafeEqualBytes(a: Uint8Array, b: Uint8Array): boolean {
  const len = Math.max(a.length, b.length, 1);
  let diff = a.length ^ b.length;
  for (let i = 0; i < len; i++) {
    const av = i < a.length ? a[i] : 0;
    const bv = i < b.length ? b[i] : 0;
    diff |= av ^ bv;
  }
  return diff === 0;
}

async function derivePbkdf2(password: string, salt: Uint8Array, iterations: number): Promise<Uint8Array> {
  const keyMaterial = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(password),
    'PBKDF2',
    false,
    ['deriveBits'],
  );
  const bits = await crypto.subtle.deriveBits(
    {
      name: 'PBKDF2',
      hash: 'SHA-256',
      salt: salt as BufferSource,
      iterations,
    },
    keyMaterial,
    HASH_BYTES * 8,
  );
  return new Uint8Array(bits);
}

export async function createPbkdf2Hash(password: string): Promise<string> {
  const salt = crypto.getRandomValues(new Uint8Array(SALT_BYTES));
  const hash = await derivePbkdf2(password, salt, PBKDF2_ITERATIONS);
  return `pbkdf2$${PBKDF2_ITERATIONS}$${bytesToBase64(salt)}$${bytesToBase64(hash)}`;
}

export async function verifyPbkdf2Hash(password: string, stored: string): Promise<boolean> {
  const parts = stored.split('$');
  if (parts.length !== 4 || parts[0] !== 'pbkdf2') return false;
  const iterations = Number(parts[1]);
  if (!Number.isInteger(iterations) || iterations < 10_000 || iterations > 1_000_000) return false;
  const salt = base64ToBytes(parts[2]);
  const expected = base64ToBytes(parts[3]);
  if (!salt || salt.length !== SALT_BYTES || !expected || expected.length !== HASH_BYTES) {
    return false;
  }
  const actual = await derivePbkdf2(password, salt, iterations);
  return timingSafeEqualBytes(actual, expected);
}

async function failureDelay(): Promise<void> {
  const raw = Deno.env.get('AUTH_FAILURE_DELAY_MS');
  const ms = raw !== undefined && /^\d+$/.test(raw) ? Number(raw) : 300;
  if (ms > 0) {
    await new Promise((resolve) => setTimeout(resolve, ms));
  }
}

function normalizeRole(rawRole: unknown): 'spv' | 'technician' | 'admin_pos' {
  const roleStr = String(rawRole ?? '').trim().toLowerCase();
  if (roleStr === 'admin_pos') {
    return 'admin_pos';
  }
  if (
    roleStr === 'spv' ||
    roleStr === 'supervisor' ||
    roleStr === 'ho' ||
    roleStr === 'headoffice'
  ) {
    return 'spv';
  }
  return 'technician';
}

export async function handleAuthLogin(
  req: Request,
  fetchImpl: typeof fetch = fetch,
): Promise<Response> {
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: corsHeaders });
  }
  if (req.method !== 'POST') {
    return json({ error: 'method not allowed' }, 405);
  }

  const clHeader = Number(req.headers.get('content-length') ?? '0');
  if (clHeader > MAX_BODY_BYTES) {
    return json({ error: 'payload too large' }, 413);
  }

  let rawBody: string;
  try {
    rawBody = await req.text();
  } catch {
    return json({ error: 'invalid' }, 400);
  }
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

  if (typeof body.identity !== 'string' || typeof body.password !== 'string') {
    await failureDelay();
    return json({ error: 'invalid credentials' }, 401);
  }

  const cleanIdentity = body.identity.trim();
  const cleanPassword = body.password.trim();
  if (
    !IDENTITY_REGEX.test(cleanIdentity) ||
    cleanPassword.length < 1 ||
    cleanPassword.length > 128
  ) {
    await failureDelay();
    return json({ error: 'invalid credentials' }, 401);
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!supabaseUrl || !serviceRoleKey) {
    console.error('auth-login: missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY');
    return json({ error: 'server error' }, 500);
  }

  const encId = encodeURIComponent(cleanIdentity);
  const orClauses = [
    `username.ilike.${encId}`,
    `email.ilike.${encId}`,
    `nama.ilike.${encId}`,
  ];
  const atIdx = cleanIdentity.indexOf('@');
  const prefix = atIdx > 0 ? cleanIdentity.slice(0, atIdx) : '';
  if (prefix && IDENTITY_REGEX.test(prefix)) {
    const encPrefix = encodeURIComponent(prefix);
    orClauses.push(`username.ilike.${encPrefix}`, `email.ilike.${encPrefix}`);
  }

  const queryUrl =
    `${supabaseUrl}/rest/v1/app_users?or=(${orClauses.join(',')})&select=id,username,nama,email,role,cabang,pos_name,aktif,password,password_hash`;

  try {
    const res = await fetchImpl(queryUrl, {
      method: 'GET',
      headers: {
        apikey: serviceRoleKey,
        Authorization: `Bearer ${serviceRoleKey}`,
      },
    });

    if (!res.ok) {
      console.error(`auth-login query status: ${res.status}`);
      return json({ error: 'server error' }, 500);
    }

    const rows = await res.json();
    const list = Array.isArray(rows) ? rows : [];
    const lowerId = cleanIdentity.toLowerCase();
    const lowerPrefix = prefix.toLowerCase();

    // Prefer exact match on full identity first, then prefix match on username/email
    let matched = list.find((u: Record<string, unknown>) =>
      (typeof u.username === 'string' && u.username.trim().toLowerCase() === lowerId) ||
      (typeof u.email === 'string' && u.email.trim().toLowerCase() === lowerId) ||
      (typeof u.nama === 'string' && u.nama.trim().toLowerCase() === lowerId)
    );
    if (!matched && lowerPrefix) {
      matched = list.find((u: Record<string, unknown>) =>
        (typeof u.username === 'string' && u.username.trim().toLowerCase() === lowerPrefix) ||
        (typeof u.email === 'string' && u.email.trim().toLowerCase() === lowerPrefix)
      );
    }

    if (!matched) {
      // Equalize CPU work against PBKDF2 before fixed failure delay
      await derivePbkdf2(cleanPassword, new Uint8Array(SALT_BYTES), PBKDF2_ITERATIONS);
      await failureDelay();
      return json({ error: 'invalid credentials' }, 401);
    }

    const storedHash = typeof matched.password_hash === 'string' ? matched.password_hash.trim() : '';
    let passwordValid = false;
    let shouldUpgradeHash = false;

    if (storedHash.length > 0) {
      passwordValid = await verifyPbkdf2Hash(cleanPassword, storedHash);
    } else {
      const dbPlain = typeof matched.password === 'string' ? matched.password.trim() : '';
      if (dbPlain.length > 0) {
        const inputBytes = new TextEncoder().encode(cleanPassword);
        const expectedBytes = new TextEncoder().encode(dbPlain);
        passwordValid = timingSafeEqualBytes(inputBytes, expectedBytes);
        if (!passwordValid && dbPlain === dbPlain.toLowerCase()) {
          // Preserve case-insensitive compatibility for legacy lowercase-only plaintext passwords
          const lowerBytes = new TextEncoder().encode(cleanPassword.toLowerCase());
          passwordValid = timingSafeEqualBytes(lowerBytes, expectedBytes);
        }
        shouldUpgradeHash = passwordValid;
      }
    }

    const role = normalizeRole(matched.role);
    if (!passwordValid || (role === 'admin_pos' && matched.aktif === false)) {
      await failureDelay();
      return json({ error: 'invalid credentials' }, 401);
    }

    const uid = String(matched.id ?? '');
    if (shouldUpgradeHash && uid.length > 0) {
      try {
        const canonicalPass =
          typeof matched.password === 'string' &&
            matched.password.trim() === matched.password.trim().toLowerCase() &&
            cleanPassword !== matched.password.trim()
            ? cleanPassword.toLowerCase()
            : cleanPassword;
        const upgradedHash = await createPbkdf2Hash(canonicalPass);
        const patchUrl = `${supabaseUrl}/rest/v1/app_users?id=eq.${encodeURIComponent(uid)}`;
        const patchRes = await fetchImpl(patchUrl, {
          method: 'PATCH',
          headers: {
            apikey: serviceRoleKey,
            Authorization: `Bearer ${serviceRoleKey}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({ password_hash: upgradedHash }),
        });
        if (!patchRes.ok) {
          console.error(`auth-login password_hash upgrade status: ${patchRes.status}`);
        }
      } catch {
        console.error('auth-login password_hash upgrade network error');
      }
    }

    const username = typeof matched.username === 'string' ? matched.username : '';
    const nama = typeof matched.nama === 'string' && matched.nama.trim().length > 0
      ? matched.nama
      : username;
    const email = typeof matched.email === 'string' ? matched.email : '';
    const cabang = typeof matched.cabang === 'string' ? matched.cabang : '';
    const posName = typeof matched.pos_name === 'string' ? matched.pos_name : '';

    const token = await signSession({
      uid,
      role,
      cabang,
      name: nama,
    });

    return json(
      {
        token,
        user: {
          id: uid,
          username,
          nama,
          email,
          role,
          cabang,
          pos_name: posName,
        },
      },
      200,
    );
  } catch {
    console.error('auth-login unexpected error');
    return json({ error: 'server error' }, 500);
  }
}

if (import.meta.main && !Deno.env.get('DENO_TESTING')) {
  serve((req: Request) => handleAuthLogin(req));
}
