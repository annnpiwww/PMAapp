// Supabase Edge Function: admin-accounts
// SPV-only management of branch-scoped admin_pos accounts (list, create, reset_password, set_aktif).
// Contract: docs/contracts/admin-lapor.md

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { isSpv, verifySession } from '../_shared/session.ts';
import { resolveTasksTableForCabang } from '../_shared/branch.ts';
import { createPbkdf2Hash } from '../auth-login/index.ts';

const MAX_BODY_BYTES = 32 * 1024;
const NAMA_REGEX = /^[A-Za-z ]{2,40}$/;
const POS_KODE_REGEX = /^[a-z0-9]{2,10}$/;
const ID_REGEX = /^[A-Za-z0-9_-]{1,80}$/;

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

export function slugifyNama(nama: string): string {
  return nama
    .trim()
    .toLowerCase()
    .replace(/\s+/g, '')
    .replace(/[^a-z0-9]/g, '')
    .slice(0, 20);
}

export function buildAdminUsername(nama: string, posKode: string): string {
  return `${slugifyNama(nama)}-${posKode.trim().toLowerCase()}`;
}

function resolveBranchSlug(cabang: string): 'manado' | 'bali' | 'ho' {
  const tbl = resolveTasksTableForCabang(cabang);
  if (tbl === 'daily_tasks_ho') return 'ho';
  if (tbl === 'daily_tasks_bali') return 'bali';
  return 'manado';
}

function sameBranch(cabangA: unknown, cabangB: string): boolean {
  if (typeof cabangA !== 'string' || cabangA.trim().length === 0) return false;
  if (cabangA.trim().toLowerCase() === cabangB.trim().toLowerCase()) return true;
  return resolveBranchSlug(cabangA) === resolveBranchSlug(cabangB);
}

export async function handleAdminAccounts(
  req: Request,
  fetchImpl: typeof fetch = fetch,
): Promise<Response> {
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: corsHeaders });
  }
  if (req.method !== 'POST') {
    return json({ error: 'method not allowed' }, 405);
  }

  const session = await verifySession(req);
  if (!session) {
    return json({ error: 'unauthorized' }, 401);
  }
  if (!isSpv(session)) {
    return json({ error: 'forbidden' }, 403);
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

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!supabaseUrl || !serviceRoleKey) {
    console.error('admin-accounts: missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY');
    return json({ error: 'server error' }, 500);
  }

  const action = body.action;
  const spvCabang = session.cabang;
  const branchSlug = resolveBranchSlug(spvCabang);

  if (action === 'list') {
    const listUrl =
      `${supabaseUrl}/rest/v1/app_users?role=eq.admin_pos&cabang=eq.${encodeURIComponent(spvCabang)}&select=id,username,nama,pos_name,pos_kode,aktif,role,cabang&order=pos_name.asc,nama.asc`;
    try {
      const res = await fetchImpl(listUrl, {
        method: 'GET',
        headers: {
          apikey: serviceRoleKey,
          Authorization: `Bearer ${serviceRoleKey}`,
        },
      });
      if (!res.ok) {
        console.error(`admin-accounts list failed: ${res.status}`);
        return json({ error: 'server error' }, 500);
      }
      const rows = await res.json();
      const rawList = Array.isArray(rows) ? rows : [];
      const accounts = rawList
        .filter((r: Record<string, unknown>) =>
          (r.role === undefined || r.role === 'admin_pos') &&
          (r.cabang === undefined || sameBranch(r.cabang, spvCabang))
        )
        .map((r: Record<string, unknown>) => ({
          id: String(r.id ?? ''),
          username: String(r.username ?? ''),
          nama: String(r.nama ?? ''),
          pos_name: String(r.pos_name ?? ''),
          pos_kode: String(r.pos_kode ?? ''),
          aktif: r.aktif !== false,
        }))
        .sort((a, b) => {
          const pCmp = a.pos_name.localeCompare(b.pos_name, 'id', { sensitivity: 'base' });
          if (pCmp !== 0) return pCmp;
          return a.nama.localeCompare(b.nama, 'id', { sensitivity: 'base' });
        });

      return json({ accounts }, 200);
    } catch {
      console.error('admin-accounts list network error');
      return json({ error: 'server error' }, 500);
    }
  }

  if (action === 'create') {
    const rawNama = typeof body.nama === 'string' ? body.nama.replace(/\s+/g, ' ').trim() : '';
    const slug = slugifyNama(rawNama);
    if (!NAMA_REGEX.test(rawNama) || slug.length < 1) {
      return json({ error: 'invalid', field: 'nama' }, 400);
    }

    const posKode = typeof body.pos_kode === 'string' ? body.pos_kode.trim().toLowerCase() : '';
    if (!POS_KODE_REGEX.test(posKode)) {
      return json({ error: 'invalid', field: 'pos_kode' }, 400);
    }

    const rawPosName = typeof body.pos_name === 'string' ? body.pos_name.trim() : '';
    if (rawPosName.length < 1 || rawPosName.length > 120) {
      return json({ error: 'invalid', field: 'pos_name' }, 400);
    }

    const username = buildAdminUsername(rawNama, posKode);
    const password = typeof body.password === 'string' ? body.password.trim() : '';
    if (
      password.length < 8 ||
      password.length > 64 ||
      password.toLowerCase() === username.toLowerCase()
    ) {
      return json({ error: 'invalid', field: 'password' }, 400);
    }

    try {
      // 1. Verify pos_name exists in the branch pos list
      const posUrl =
        `${supabaseUrl}/rest/v1/pos_locations?branch=eq.${branchSlug}&active=eq.true&select=pos_name,location_tag,branch`;
      const posRes = await fetchImpl(posUrl, {
        method: 'GET',
        headers: {
          apikey: serviceRoleKey,
          Authorization: `Bearer ${serviceRoleKey}`,
        },
      });
      if (!posRes.ok) {
        console.error(`admin-accounts pos lookup failed: ${posRes.status}`);
        return json({ error: 'server error' }, 500);
      }
      const posRows = await posRes.json();
      const posList = Array.isArray(posRows) ? posRows : [];
      const matchedPos = posList.find((p: Record<string, unknown>) =>
        typeof p.pos_name === 'string' &&
        p.pos_name.trim().toLowerCase() === rawPosName.toLowerCase() &&
        (p.branch === undefined || String(p.branch).toLowerCase() === branchSlug)
      );
      if (!matchedPos) {
        return json({ error: 'invalid', field: 'pos_name' }, 400);
      }
      const canonicalPosName = String(matchedPos.pos_name).trim();

      // 2. Check username uniqueness
      const checkUrl =
        `${supabaseUrl}/rest/v1/app_users?username=ilike.${encodeURIComponent(username)}&select=id,username`;
      const checkRes = await fetchImpl(checkUrl, {
        method: 'GET',
        headers: {
          apikey: serviceRoleKey,
          Authorization: `Bearer ${serviceRoleKey}`,
        },
      });
      if (!checkRes.ok) {
        console.error(`admin-accounts duplicate check failed: ${checkRes.status}`);
        return json({ error: 'server error' }, 500);
      }
      const existingUsers = await checkRes.json();
      if (
        Array.isArray(existingUsers) &&
        existingUsers.some((u: Record<string, unknown>) =>
          typeof u.username === 'string' && u.username.trim().toLowerCase() === username
        )
      ) {
        return json({ error: 'duplicate' }, 409);
      }

      // 3. Insert admin_pos row with PBKDF2 password_hash (never plaintext password)
      const passwordHash = await createPbkdf2Hash(password);
      const newId = `usr_adm_${Date.now()}_${Math.floor(Math.random() * 9000) + 1000}`;
      const insertBody = {
        id: newId,
        username,
        nama: rawNama,
        role: 'admin_pos',
        cabang: spvCabang,
        pos_name: canonicalPosName,
        pos_kode: posKode,
        aktif: true,
        password_hash: passwordHash,
      };

      const insertRes = await fetchImpl(`${supabaseUrl}/rest/v1/app_users`, {
        method: 'POST',
        headers: {
          apikey: serviceRoleKey,
          Authorization: `Bearer ${serviceRoleKey}`,
          'Content-Type': 'application/json',
          Prefer: 'return=representation',
        },
        body: JSON.stringify(insertBody),
      });

      if (insertRes.status === 409) {
        return json({ error: 'duplicate' }, 409);
      }
      if (!insertRes.ok) {
        console.error(`admin-accounts insert failed: ${insertRes.status}`);
        return json({ error: 'server error' }, 500);
      }

      const createdRows = await insertRes.json();
      const created = Array.isArray(createdRows) && createdRows.length > 0
        ? createdRows[0]
        : null;
      const createdId = created && typeof created.id !== 'undefined' ? String(created.id) : '';
      return json({ id: createdId, username }, 201);
    } catch {
      console.error('admin-accounts create network error');
      return json({ error: 'server error' }, 500);
    }
  }

  if (action === 'reset_password') {
    const id = typeof body.id === 'string' ? body.id.trim() : '';
    if (!ID_REGEX.test(id)) {
      return json({ error: 'invalid', field: 'id' }, 400);
    }
    const password = typeof body.password === 'string' ? body.password.trim() : '';
    if (password.length < 8 || password.length > 64) {
      return json({ error: 'invalid', field: 'password' }, 400);
    }

    const rowUrl =
      `${supabaseUrl}/rest/v1/app_users?id=eq.${encodeURIComponent(id)}&role=eq.admin_pos&cabang=eq.${encodeURIComponent(spvCabang)}&select=id,username,role,cabang`;
    try {
      const checkRes = await fetchImpl(rowUrl, {
        method: 'GET',
        headers: {
          apikey: serviceRoleKey,
          Authorization: `Bearer ${serviceRoleKey}`,
        },
      });
      if (!checkRes.ok) {
        return json({ error: 'server error' }, 500);
      }
      const rows = await checkRes.json();
      const target = Array.isArray(rows) && rows.length > 0 ? rows[0] : null;
      if (
        !target ||
        (target.role !== undefined && target.role !== 'admin_pos') ||
        (target.cabang !== undefined && !sameBranch(target.cabang, spvCabang))
      ) {
        return json({ error: 'not found' }, 404);
      }

      const existingUsername = typeof target.username === 'string' ? target.username.trim() : '';
      if (existingUsername.length > 0 && password.toLowerCase() === existingUsername.toLowerCase()) {
        return json({ error: 'invalid', field: 'password' }, 400);
      }

      const passwordHash = await createPbkdf2Hash(password);
      const patchUrl =
        `${supabaseUrl}/rest/v1/app_users?id=eq.${encodeURIComponent(id)}&role=eq.admin_pos&cabang=eq.${encodeURIComponent(spvCabang)}`;
      const patchRes = await fetchImpl(patchUrl, {
        method: 'PATCH',
        headers: {
          apikey: serviceRoleKey,
          Authorization: `Bearer ${serviceRoleKey}`,
          'Content-Type': 'application/json',
          Prefer: 'return=representation',
        },
        body: JSON.stringify({ password_hash: passwordHash, password: null }),
      });
      if (!patchRes.ok) {
        return json({ error: 'server error' }, 500);
      }
      return json({ ok: true }, 200);
    } catch {
      return json({ error: 'server error' }, 500);
    }
  }

  if (action === 'set_aktif') {
    const id = typeof body.id === 'string' ? body.id.trim() : '';
    if (!ID_REGEX.test(id)) {
      return json({ error: 'invalid', field: 'id' }, 400);
    }
    if (typeof body.aktif !== 'boolean') {
      return json({ error: 'invalid', field: 'aktif' }, 400);
    }

    const patchUrl =
      `${supabaseUrl}/rest/v1/app_users?id=eq.${encodeURIComponent(id)}&role=eq.admin_pos&cabang=eq.${encodeURIComponent(spvCabang)}`;
    try {
      const patchRes = await fetchImpl(patchUrl, {
        method: 'PATCH',
        headers: {
          apikey: serviceRoleKey,
          Authorization: `Bearer ${serviceRoleKey}`,
          'Content-Type': 'application/json',
          Prefer: 'return=representation',
        },
        body: JSON.stringify({ aktif: body.aktif }),
      });
      if (!patchRes.ok) {
        return json({ error: 'server error' }, 500);
      }
      const rows = await patchRes.json();
      const target = Array.isArray(rows) && rows.length > 0 ? rows[0] : null;
      if (
        !target ||
        (target.role !== undefined && target.role !== 'admin_pos') ||
        (target.cabang !== undefined && !sameBranch(target.cabang, spvCabang))
      ) {
        return json({ error: 'not found' }, 404);
      }
      return json({ ok: true, id: String(target.id ?? id), aktif: body.aktif }, 200);
    } catch {
      return json({ error: 'server error' }, 500);
    }
  }

  return json({ error: 'invalid action' }, 400);
}

if (import.meta.main && !Deno.env.get('DENO_TESTING')) {
  serve((req: Request) => handleAdminAccounts(req));
}
