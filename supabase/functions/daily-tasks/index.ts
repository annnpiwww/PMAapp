// Supabase Edge Function: daily-tasks (SEC-05)
// Server-side SPV mutations (create, transfer, delete) scoped to session branch table.
// Contract: docs/contracts/app-session.md

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { isSpv, verifySession } from '../_shared/session.ts';
import {
  buildAdminMessage,
  buildDeskripsi,
  validateReport,
} from '../_shared/admin_report.ts';

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

import { resolveTasksTableForCabang } from '../_shared/branch.ts';
export { resolveTasksTableForCabang };

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
  // Teknisi boleh create tugas untuk dirinya sendiri (cek nama di blok create);
  // transfer & delete tetap khusus SPV.
  const spv = isSpv(session);

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

  if (session.role === 'admin_pos' && action !== 'admin_report' && action !== 'admin_list') {
    return json({ error: 'forbidden' }, 403);
  }
  if (action === 'admin_report' && session.role !== 'admin_pos') {
    return json({ error: 'forbidden' }, 403);
  }
  if (action === 'admin_list' && session.role !== 'admin_pos') {
    return json({ error: 'forbidden' }, 403);
  }
  if (!spv && action !== 'create' && action !== 'claim' && action !== 'admin_report' && action !== 'admin_list') {
    return json({ error: 'forbidden' }, 403);
  }

  if (action === 'admin_report') {
    const validated = validateReport(body.report);
    if (!validated.ok) {
      return json({ error: 'invalid', field: validated.field }, 400);
    }
    const report = validated.report;

    let pelapor = '';
    let posName = '';
    let posTag = '';
    try {
      const userUrl =
        `${supabaseUrl}/rest/v1/app_users?id=eq.${encodeURIComponent(session.uid)}&select=nama,pos_name,pos_kode,aktif`;
      const userRes = await fetchImpl(userUrl, {
        method: 'GET',
        headers: {
          apikey: serviceRoleKey,
          Authorization: `Bearer ${serviceRoleKey}`,
        },
      });
      if (!userRes.ok) {
        console.error(`daily-tasks admin_report user lookup failed: ${userRes.status}`);
        return json({ error: 'server error' }, 500);
      }
      const users = await userRes.json();
      const userRow = Array.isArray(users) && users.length > 0 ? users[0] : null;
      if (!userRow || userRow.aktif === false) {
        return json({ error: 'forbidden' }, 403);
      }
      posName = typeof userRow.pos_name === 'string' ? userRow.pos_name.trim() : '';
      if (posName.length === 0) {
        return json({ error: 'forbidden' }, 403);
      }
      pelapor = typeof userRow.nama === 'string' && userRow.nama.trim().length > 0
        ? userRow.nama.trim()
        : session.name.trim();
      posTag = typeof userRow.pos_kode === 'string' && userRow.pos_kode.trim().length > 0
        ? userRow.pos_kode.trim().toUpperCase().slice(0, 64)
        : '';
    } catch {
      console.error('daily-tasks admin_report user lookup network error');
      return json({ error: 'server error' }, 500);
    }

    const message = buildAdminMessage(report, posName);
    const deskripsi = buildDeskripsi(message, posName, report);
    const judul = report.kendala.slice(0, 120);
    const id = `task_${Date.now()}_${Math.floor(Math.random() * 9000) + 1000}`;

    const bulanIndo = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    const [dd, mm] = report.tanggal.split('-');
    const waktuColon = report.waktu.replace('.', ':');
    const stamp = `${dd} ${bulanIndo[Number(mm) - 1] ?? 'Jan'} ${waktuColon}`;
    const safeDari = pelapor.replace(/\|/g, '/').replace(/\n/g, ' ');
    const serahTerima = `${safeDari}||Daftar terbuka|${stamp}`;

    const insertRow: Record<string, unknown> = {
      id,
      tanggal: report.tanggalIso,
      teknisi_nama: pelapor,
      pos_name: posName,
      pos_tag: posTag,
      judul,
      deskripsi,
      kategori: 'error',
      template_id: null,
      status: 'pending',
      peserta: '',
      serah_terima: serahTerima,
    };

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
        console.error(`daily-tasks admin_report insert failed status: ${res.status}`);
        return json({ error: 'server error' }, 500);
      }

      const rows = await res.json();
      const created = Array.isArray(rows) && rows.length > 0 ? rows[0] : insertRow;
      const createdId = typeof created?.id === 'string' && created.id.length > 0 ? created.id : id;

      const webhookUrl = Deno.env.get('GOOGLE_SHEETS_WEBHOOK_URL');
      if (table === 'daily_tasks_manado' && webhookUrl) {
        const secretToken = Deno.env.get('GOOGLE_SHEETS_SECRET') || '';
        const sanitizeCell = (v: string) => (/^[=+\-@\t\r]/.test(v) ? `'${v}` : v);
        const rawPenyebab = report.penyebab === '-' ? '' : report.penyebab;
        const rawSolusi = report.solusi_sementara === '-' ? '' : report.solusi_sementara;
        const sheetPayload = {
          kind: 'error',
          stage: 'open',
          id: createdId,
          tanggalLapor: sanitizeCell(report.tanggal),
          waktuLapor: sanitizeCell(report.waktu),
          lokasi: sanitizeCell(posName),
          kendala: sanitizeCell(report.kendala),
          penyebab: sanitizeCell(rawPenyebab),
          solusiSementara: sanitizeCell(rawSolusi),
          pelapor: sanitizeCell(pelapor),
          teknisi: sanitizeCell(pelapor),
          solusiPerbaikan: '',
          selesai: '',
          durasiPerbaikan: '',
          catatan: '',
          secretToken,
        };
        fetchImpl(webhookUrl, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'X-Auth-Token': secretToken,
          },
          body: JSON.stringify(sheetPayload),
          redirect: 'follow',
        }).catch(() => {});
      }

      return json({ id: createdId, message }, 201);
    } catch {
      console.error('daily-tasks admin_report insert network error');
      return json({ error: 'server error' }, 500);
    }
  }

  if (action === 'admin_list') {
    let posName = '';
    try {
      const userUrl =
        `${supabaseUrl}/rest/v1/app_users?id=eq.${encodeURIComponent(session.uid)}&select=nama,pos_name,pos_kode,aktif`;
      const userRes = await fetchImpl(userUrl, {
        method: 'GET',
        headers: {
          apikey: serviceRoleKey,
          Authorization: `Bearer ${serviceRoleKey}`,
        },
      });
      if (!userRes.ok) {
        console.error(`daily-tasks admin_list user lookup failed: ${userRes.status}`);
        return json({ error: 'server error' }, 500);
      }
      const users = await userRes.json();
      const userRow = Array.isArray(users) && users.length > 0 ? users[0] : null;
      if (!userRow || userRow.aktif === false) {
        return json({ error: 'forbidden' }, 403);
      }
      posName = typeof userRow.pos_name === 'string' ? userRow.pos_name.trim() : '';
      if (posName.length === 0) {
        return json({ error: 'forbidden' }, 403);
      }
    } catch {
      console.error('daily-tasks admin_list user lookup network error');
      return json({ error: 'server error' }, 500);
    }

    try {
      const queryUrl =
        `${supabaseUrl}/rest/v1/${table}?select=id,tanggal,judul,status,teknisi_nama,serah_terima,jam_selesai,created_at&kategori=eq.error&pos_name=eq.${encodeURIComponent(posName)}&order=created_at.desc&limit=20`;
      const tasksRes = await fetchImpl(queryUrl, {
        method: 'GET',
        headers: {
          apikey: serviceRoleKey,
          Authorization: `Bearer ${serviceRoleKey}`,
        },
      });
      if (!tasksRes.ok) {
        console.error(`daily-tasks admin_list tasks query status: ${tasksRes.status}`);
        return json({ error: 'server error' }, 500);
      }
      const rows = await tasksRes.json();
      const list = Array.isArray(rows) ? rows : [];
      const reports = list.map((row: Record<string, unknown>) => {
        const rawStatus = typeof row.status === 'string' ? row.status.trim() : '';
        // Open list ("Semua teknisi"): teknisi_nama = pelapor until claimed; last serah_terima line has empty `ke`.
        const lines = (typeof row.serah_terima === 'string' ? row.serah_terima : '')
          .split('\n').filter((l) => l.trim().length > 0);
        const isOpen = lines.length > 0 && (lines[lines.length - 1].split('|')[1] ?? '').trim().length === 0;
        const nama = typeof row.teknisi_nama === 'string' ? row.teknisi_nama.trim() : '';
        const teknisi = isOpen || nama.length === 0 ? null : nama;
        const status = (rawStatus === 'done' || rawStatus === 'completed')
          ? 'selesai'
          : (teknisi ? 'ditangani' : 'menunggu');

        let diambil: string | null = null;
        for (let i = lines.length - 1; i >= 0; i--) {
          const parts = lines[i].split('|');
          const ke = (parts[1] ?? '').trim();
          if (ke.length > 0) {
            const w = (parts[3] ?? '').trim();
            diambil = w.length > 0 ? w : null;
            break;
          }
        }

        const rawSelesai = typeof row.jam_selesai === 'string' ? row.jam_selesai.trim() : '';
        const selesai = rawSelesai.length > 0 ? rawSelesai : null;

        return {
          id: row.id,
          tanggal: row.tanggal,
          kendala: typeof row.judul === 'string' ? row.judul : '',
          status,
          teknisi,
          diambil,
          selesai,
          waktu_lapor: row.created_at,
        };
      });

      return json({ reports }, 200);
    } catch {
      console.error('daily-tasks admin_list tasks query network error');
      return json({ error: 'server error' }, 500);
    }
  }

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
    if (!spv && teknisiNama.toLowerCase() !== session.name.trim().toLowerCase()) {
      return json({ error: 'forbidden' }, 403);
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
    if (spv && typeof rawTask.status === 'string' && rawTask.status === 'completed') {
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

  if (action === 'claim') {
    const id = typeof body.id === 'string' ? body.id.trim() : '';
    if (!TASK_ID_REGEX.test(id)) {
      return json({ error: 'invalid id' }, 400);
    }

    const rowUrl = `${supabaseUrl}/rest/v1/${table}?id=eq.${encodeURIComponent(id)}&select=id,status,teknisi_nama,serah_terima,kategori,peserta`;
    try {
      const checkRes = await fetchImpl(rowUrl, {
        method: 'GET',
        headers: {
          apikey: serviceRoleKey,
          Authorization: `Bearer ${serviceRoleKey}`,
        },
      });

      if (!checkRes.ok) {
        console.error(`daily-tasks claim check failed status: ${checkRes.status}`);
        return json({ error: 'server error' }, 500);
      }

      const existing = await checkRes.json();
      if (!Array.isArray(existing) || existing.length === 0) {
        return json({ error: 'not found' }, 404);
      }

      const taskRow = existing[0];
      if (isCompletedStatus(taskRow.status)) {
        return json({ error: 'completed' }, 409);
      }

      // Pastikan tiket berada di daftar terbuka (open handover)
      const serahTerima = typeof taskRow.serah_terima === 'string' ? taskRow.serah_terima : '';
      const lines = serahTerima.split('\n').filter((l: string) => l.trim().length > 0);
      let isOpen = false;
      if (lines.length > 0) {
        const lastLine = lines[lines.length - 1];
        const parts = lastLine.split('|');
        if (parts.length >= 3 && parts[1].trim().length === 0) {
          isOpen = true;
        }
      }

      if (!isOpen) {
        return json({ error: 'already claimed', claimed_by: taskRow.teknisi_nama || 'teknisi lain' }, 409);
      }

      const claimant = session.name.trim();
      const prevDari = (typeof taskRow.teknisi_nama === 'string' && taskRow.teknisi_nama.trim().length > 0)
        ? taskRow.teknisi_nama.trim()
        : 'SPV';
      const n = new Date();
      const stamp = `${n.getDate().toString().padStart(2, '0')} ${n.toLocaleString('id-ID', { month: 'short' })} ${n.getHours().toString().padStart(2, '0')}:${n.getMinutes().toString().padStart(2, '0')}`;
      const newEntry = `${prevDari}|${claimant}|Ambil tugas terbuka|${stamp}`;
      const logBaru = lines.length > 0 ? `${lines.join('\n')}\n${newEntry}` : newEntry;

      const patchUrl = `${supabaseUrl}/rest/v1/${table}?id=eq.${encodeURIComponent(id)}&status=eq.pending&serah_terima=eq.${encodeURIComponent(serahTerima)}`;
      const patchRes = await fetchImpl(patchUrl, {
        method: 'PATCH',
        headers: {
          apikey: serviceRoleKey,
          Authorization: `Bearer ${serviceRoleKey}`,
          'Content-Type': 'application/json',
          Prefer: 'return=representation',
        },
        body: JSON.stringify({
          teknisi_nama: claimant,
          peserta: '',
          serah_terima: logBaru,
          updated_at: new Date().toISOString(),
        }),
      });

      if (!patchRes.ok) {
        console.error(`daily-tasks claim patch failed status: ${patchRes.status}`);
        return json({ error: 'server error' }, 500);
      }

      const rows = await patchRes.json();
      if (Array.isArray(rows) && rows.length === 0) {
        return json({ error: 'already claimed' }, 409);
      }

      return json({ ok: true, task: Array.isArray(rows) ? rows[0] : null }, 200);
    } catch {
      console.error('daily-tasks claim network error');
      return json({ error: 'server error' }, 500);
    }
  }

  return json({ error: 'invalid action' }, 400);
}

if (!Deno.env.get('DENO_TESTING')) {
  serve((req: Request) => handleDailyTasks(req));
}
