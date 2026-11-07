// Supabase Edge Function: daily-tasks (SEC-05)
// Server-side SPV mutations (create, transfer, delete) scoped to session branch table.
// Contract: docs/contracts/app-session.md

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { isSpv, verifySession } from '../_shared/session.ts';

const MAX_BODY_BYTES = 64 * 1024;
const TASK_ID_REGEX = /^[A-Za-z0-9_-]{1,80}$/;
const DATE_REGEX = /^\d{4}-\d{2}-\d{2}$/;

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

// Mirrors BranchService.parseBranchFromName + DailyTaskService.tasksTable
export function resolveTasksTableForCabang(cabang: string): string {
  const lower = cabang.trim().toLowerCase();
  if (
    lower === 'ho' ||
    lower === 'hom' ||
    lower.includes('ho makassar') ||
    lower.includes('head office') ||
    lower.includes('makassar')
  ) {
    return 'daily_tasks_ho';
  }
  if (lower.includes('bali') || lower.includes('dps')) {
    return 'daily_tasks_bali';
  }
  return 'daily_tasks_manado';
}

function isCompletedStatus(status: unknown): boolean {
  const s = String(status ?? '').trim().toLowerCase();
  return (
    s === 'completed' ||
    s === 'selesai' ||
    s === 'done' ||
    s === 'finish' ||
    s === 'finished' ||
    s === 'sukses' ||
    s === 'closed'
  );
}

export async function handleDailyTasks(
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
    console.error('daily-tasks: missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY');
    return json({ error: 'server error' }, 500);
  }

  const table = resolveTasksTableForCabang(session.cabang);
  const action = body.action;

  if (action === 'create') {
    const rawTask = (body.task && typeof body.task === 'object' && !Array.isArray(body.task))
      ? (body.task as Record<string, unknown>)
      : body;

    const id = typeof rawTask.id === 'string' && rawTask.id.trim().length > 0
      ? rawTask.id.trim()
      : `task_${Date.now()}_${Math.floor(Math.random() * 9000) + 1000}`;

    if (!TASK_ID_REGEX.test(id)) {
      return json({ error: 'invalid id' }, 400);
    }

    const tanggal = typeof rawTask.tanggal === 'string' ? rawTask.tanggal.trim() : '';
    const teknisiNama = typeof rawTask.teknisi_nama === 'string' ? rawTask.teknisi_nama.trim() : '';
    const posName = typeof rawTask.pos_name === 'string' ? rawTask.pos_name.trim() : '';
    const posTag = typeof rawTask.pos_tag === 'string' ? rawTask.pos_tag.trim() : '';
    const judul = typeof rawTask.judul === 'string' ? rawTask.judul.trim() : '';
    const deskripsi = typeof rawTask.deskripsi === 'string' ? rawTask.deskripsi : '';
    const kategori = typeof rawTask.kategori === 'string' && rawTask.kategori.trim().length > 0
      ? rawTask.kategori.trim()
      : 'khusus';
    const templateId = typeof rawTask.template_id === 'string' && rawTask.template_id.trim().length > 0
      ? rawTask.template_id.trim()
      : null;
    const peserta = typeof rawTask.peserta === 'string' ? rawTask.peserta.trim() : '';

    if (
      !DATE_REGEX.test(tanggal) ||
      teknisiNama.length === 0 ||
      teknisiNama.length > 160 ||
      judul.length === 0 ||
      judul.length > 500 ||
      posName.length > 160 ||
      posTag.length > 64 ||
      deskripsi.length > 2000 ||
      peserta.length > 500
    ) {
      return json({ error: 'invalid' }, 400);
    }

    const insertRow: Record<string, unknown> = {
      id,
      tanggal,
      teknisi_nama: teknisiNama,
      pos_name: posName,
      pos_tag: posTag,
      judul,
      deskripsi,
      kategori,
      template_id: templateId,
      status: 'pending',
    };
    if (peserta.length > 0) {
      insertRow.peserta = peserta;
    }
    if (typeof rawTask.status === 'string' && rawTask.status === 'completed') {
      insertRow.status = 'completed';
      if (typeof rawTask.jam_selesai === 'string') insertRow.jam_selesai = rawTask.jam_selesai;
      if (typeof rawTask.catatan_teknisi === 'string') insertRow.catatan_teknisi = rawTask.catatan_teknisi;
    }

    try {
      const res = await fetchImpl(`${supabaseUrl}/rest/v1/${table}`, {
        method: 'POST',
        headers: {
          apikey: serviceRoleKey,
          Authorization: `Bearer ${serviceRoleKey}`,
          'Content-Type': 'application/json',
          Prefer: 'return=representation',
        },
        body: JSON.stringify(insertRow),
      });

      if (res.status === 409) {
        return json({ error: 'duplicate' }, 409);
      }
      if (!res.ok) {
        console.error(`daily-tasks create failed status: ${res.status}`);
        return json({ error: 'server error' }, 500);
      }

      const rows = await res.json();
      const created = Array.isArray(rows) && rows.length > 0 ? rows[0] : insertRow;
      return json(created, 201);
    } catch {
      console.error('daily-tasks create network error');
      return json({ error: 'server error' }, 500);
    }
  }

  if (action === 'transfer') {
    const id = typeof body.id === 'string' ? body.id.trim() : '';
    if (!TASK_ID_REGEX.test(id)) {
      return json({ error: 'invalid id' }, 400);
    }

    const teknisiNama = typeof body.teknisi_nama === 'string' ? body.teknisi_nama.trim() : '';
    const peserta = typeof body.peserta === 'string' ? body.peserta : '';
    const serahTerima = typeof body.serah_terima === 'string' ? body.serah_terima : '';

    if (
      teknisiNama.length === 0 ||
      teknisiNama.length > 160 ||
      peserta.length > 500 ||
      serahTerima.length > 4000
    ) {
      return json({ error: 'invalid' }, 400);
    }

    const patchPayload = {
      teknisi_nama: teknisiNama,
      peserta,
      serah_terima: serahTerima,
      updated_at: new Date().toISOString(),
    };

    try {
      const url = `${supabaseUrl}/rest/v1/${table}?id=eq.${encodeURIComponent(id)}`;
      const res = await fetchImpl(url, {
        method: 'PATCH',
        headers: {
          apikey: serviceRoleKey,
          Authorization: `Bearer ${serviceRoleKey}`,
          'Content-Type': 'application/json',
          Prefer: 'return=representation',
        },
        body: JSON.stringify(patchPayload),
      });

      if (!res.ok) {
        console.error(`daily-tasks transfer failed status: ${res.status}`);
        return json({ error: 'server error' }, 500);
      }

      const rows = await res.json();
      if (Array.isArray(rows) && rows.length === 0) {
        return json({ error: 'not found' }, 404);
      }
      return json({ ok: true, task: Array.isArray(rows) ? rows[0] : null }, 200);
    } catch {
      console.error('daily-tasks transfer network error');
      return json({ error: 'server error' }, 500);
    }
  }

  if (action === 'delete') {
    const id = typeof body.id === 'string' ? body.id.trim() : '';
    if (!TASK_ID_REGEX.test(id)) {
      return json({ error: 'invalid id' }, 400);
    }

    const rowUrl = `${supabaseUrl}/rest/v1/${table}?id=eq.${encodeURIComponent(id)}&select=id,status`;
    try {
      const checkRes = await fetchImpl(rowUrl, {
        method: 'GET',
        headers: {
          apikey: serviceRoleKey,
          Authorization: `Bearer ${serviceRoleKey}`,
        },
      });

      if (!checkRes.ok) {
        console.error(`daily-tasks delete check failed status: ${checkRes.status}`);
        return json({ error: 'server error' }, 500);
      }

      const existing = await checkRes.json();
      if (Array.isArray(existing) && existing.length > 0) {
        if (isCompletedStatus(existing[0]?.status)) {
          return json({ error: 'completed' }, 409);
        }
      }

      const delUrl = `${supabaseUrl}/rest/v1/${table}?id=eq.${encodeURIComponent(id)}`;
      const delRes = await fetchImpl(delUrl, {
        method: 'DELETE',
        headers: {
          apikey: serviceRoleKey,
          Authorization: `Bearer ${serviceRoleKey}`,
        },
      });

      if (!delRes.ok) {
        console.error(`daily-tasks delete failed status: ${delRes.status}`);
        return json({ error: 'server error' }, 500);
      }

      return json({ ok: true }, 200);
    } catch {
      console.error('daily-tasks delete network error');
      return json({ error: 'server error' }, 500);
    }
  }

  return json({ error: 'invalid action' }, 400);
}

if (!Deno.env.get('DENO_TESTING')) {
  serve((req: Request) => handleDailyTasks(req));
}
