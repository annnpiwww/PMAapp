import { assertEquals, assertNotEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { signSession } from '../_shared/session.ts';
import { handleDailyTasks } from './index.ts';

Deno.env.set('DENO_TESTING', '1');
Deno.env.set('APP_SESSION_SECRET', 'test-session-secret-32-bytes-minimum-key!!');
Deno.env.set('SUPABASE_URL', 'https://fake.supabase.co');
Deno.env.set('SUPABASE_SERVICE_ROLE_KEY', 'fake-service-role');

Deno.test('daily-tasks: technician can claim open-list ticket and gets 409 when already claimed', async () => {
  const techToken = await signSession({
    uid: 'usr_tek_1',
    role: 'technician',
    cabang: 'manado',
    name: 'Ryan Lumasuge',
  });

  // 1. Claim open ticket -> 200
  let patchedBody: Record<string, unknown> | null = null;
  let patchedUrl: string | null = null;
  const mockDbOpen: typeof fetch = async (input, init) => {
    const url = String(input);
    if (init?.method === 'GET' && url.includes('/rest/v1/daily_tasks_manado')) {
      return new Response(
        JSON.stringify([
          {
            id: 'task_open_1',
            status: 'pending',
            teknisi_nama: 'Farhan Lakoro',
            serah_terima: 'Farhan Lakoro||Daftar terbuka|10 Nov 08:30',
            kategori: 'error',
            peserta: '',
          },
        ]),
        { status: 200 },
      );
    }
    if (init?.method === 'PATCH' && url.includes('/rest/v1/daily_tasks_manado')) {
      patchedUrl = url;
      patchedBody = JSON.parse(String(init.body));
      return new Response(
        JSON.stringify([
          {
            id: 'task_open_1',
            status: 'pending',
            teknisi_nama: patchedBody?.teknisi_nama,
            serah_terima: patchedBody?.serah_terima,
          },
        ]),
        { status: 200 },
      );
    }
    return new Response('[]', { status: 200 });
  };

  const reqClaimOpen = new Request('https://example.com/daily-tasks', {
    method: 'POST',
    headers: {
      'x-app-session': techToken,
      'content-type': 'application/json',
    },
    body: JSON.stringify({ action: 'claim', id: 'task_open_1' }),
  });

  const resClaimOpen = await handleDailyTasks(reqClaimOpen, mockDbOpen);
  assertEquals(resClaimOpen.status, 200);
  assertEquals(patchedBody !== null, true);
  assertEquals(patchedBody!['teknisi_nama'], 'Ryan Lumasuge');
  assertEquals(String(patchedBody!['serah_terima']).includes('Ambil tugas terbuka'), true);
  assertEquals(patchedUrl !== null, true);
  assertEquals(patchedUrl!.includes(`&serah_terima=eq.${encodeURIComponent('Farhan Lakoro||Daftar terbuka|10 Nov 08:30')}`), true);

  // 1b. CAS filter race: PATCH returns 0 rows due to changed serah_terima -> 409 already claimed
  let casPatchUrl: string | null = null;
  const mockDbCasRace: typeof fetch = async (input, init) => {
    const url = String(input);
    if (init?.method === 'GET' && url.includes('/rest/v1/daily_tasks_manado')) {
      return new Response(
        JSON.stringify([
          {
            id: 'task_open_1',
            status: 'pending',
            teknisi_nama: 'Farhan Lakoro',
            serah_terima: 'Farhan Lakoro||Daftar terbuka|10 Nov 08:30',
            kategori: 'error',
            peserta: '',
          },
        ]),
        { status: 200 },
      );
    }
    if (init?.method === 'PATCH' && url.includes('/rest/v1/daily_tasks_manado')) {
      casPatchUrl = url;
      return new Response('[]', { status: 200 }); // CAS failed to match row
    }
    return new Response('[]', { status: 200 });
  };

  const reqClaimCasRace = new Request('https://example.com/daily-tasks', {
    method: 'POST',
    headers: {
      'x-app-session': techToken,
      'content-type': 'application/json',
    },
    body: JSON.stringify({ action: 'claim', id: 'task_open_1' }),
  });

  const resClaimCasRace = await handleDailyTasks(reqClaimCasRace, mockDbCasRace);
  assertEquals(resClaimCasRace.status, 409);
  const jsonCasRace = await resClaimCasRace.json();
  assertEquals(jsonCasRace.error, 'already claimed');
  assertEquals(casPatchUrl !== null, true);
  assertEquals(casPatchUrl!.includes(`&serah_terima=eq.${encodeURIComponent('Farhan Lakoro||Daftar terbuka|10 Nov 08:30')}`), true);

  // 2. Claim already claimed ticket -> 409
  const mockDbClaimed: typeof fetch = async (input, init) => {
    const url = String(input);
    if (init?.method === 'GET' && url.includes('/rest/v1/daily_tasks_manado')) {
      return new Response(
        JSON.stringify([
          {
            id: 'task_open_1',
            status: 'pending',
            teknisi_nama: 'Budi Santoso',
            serah_terima: 'Farhan Lakoro|Budi Santoso|Ambil tugas terbuka|10 Nov 08:35',
            kategori: 'error',
            peserta: '',
          },
        ]),
        { status: 200 },
      );
    }
    return new Response('[]', { status: 200 });
  };

  const reqClaimTaken = new Request('https://example.com/daily-tasks', {
    method: 'POST',
    headers: {
      'x-app-session': techToken,
      'content-type': 'application/json',
    },
    body: JSON.stringify({ action: 'claim', id: 'task_open_1' }),
  });

  const resClaimTaken = await handleDailyTasks(reqClaimTaken, mockDbClaimed);
  assertEquals(resClaimTaken.status, 409);
  const jsonTaken = await resClaimTaken.json();
  assertEquals(jsonTaken.error, 'already claimed');
  assertEquals(jsonTaken.claimed_by, 'Budi Santoso');

  // 3. Technician calling delete gets 403
  const reqDelete = new Request('https://example.com/daily-tasks', {
    method: 'POST',
    headers: {
      'x-app-session': techToken,
      'content-type': 'application/json',
    },
    body: JSON.stringify({ action: 'delete', id: 'task_open_1' }),
  });

  const resDelete = await handleDailyTasks(reqDelete, mockDbClaimed);
  assertEquals(resDelete.status, 403);
});

Deno.test('daily-tasks: admin_report role guards, open-list row creation, aktif=false 403, duplicate 409, and Manado sheet sync', async () => {
  Deno.env.set('GOOGLE_SHEETS_WEBHOOK_URL', 'https://script.google.com/macros/s/test/exec');
  Deno.env.set('GOOGLE_SHEETS_SECRET', 'sheet-secret-123');

  const adminToken = await signSession({
    uid: 'usr_admin_mgnw',
    role: 'admin_pos',
    cabang: 'KC Manado',
    name: 'Irma',
  });
  const techToken = await signSession({
    uid: 'usr_tek_1',
    role: 'technician',
    cabang: 'KC Manado',
    name: 'Ryan Lumasuge',
  });

  // 1. admin_pos calling create or claim -> 403
  for (const act of ['create', 'claim', 'delete', 'transfer']) {
    const res = await handleDailyTasks(
      new Request('https://example.com/daily-tasks', {
        method: 'POST',
        headers: { 'x-app-session': adminToken, 'content-type': 'application/json' },
        body: JSON.stringify({ action: act }),
      }),
    );
    assertEquals(res.status, 403);
  }

  // 2. technician calling admin_report -> 403
  const techReportRes = await handleDailyTasks(
    new Request('https://example.com/daily-tasks', {
      method: 'POST',
      headers: { 'x-app-session': techToken, 'content-type': 'application/json' },
      body: JSON.stringify({
        action: 'admin_report',
        report: {
          tanggal: '11-11-2026',
          waktu: '10.00',
          kendala: 'Gate macet',
          ada_foto: false,
        },
      }),
    }),
  );
  assertEquals(techReportRes.status, 403);

  // 3. admin_pos valid report -> 201 + open-list row + sheet open payload
  let insertedRow: Record<string, unknown> | null = null;
  let sheetPayloadSent: Record<string, unknown> | null = null;
  let userAktif = true;
  let userPosName: string | null = 'Mie Gacoan Nani Wartabone';
  let nextInsertStatus = 201;

  const mockFetch: typeof fetch = async (input, init) => {
    const url = String(input);
    if (url.includes('/rest/v1/app_users')) {
      return new Response(
        JSON.stringify([
          {
            nama: 'Irma',
            pos_name: userPosName,
            pos_kode: 'mgnw',
            aktif: userAktif,
          },
        ]),
        { status: 200 },
      );
    }
    if (url.includes('/rest/v1/daily_tasks_manado')) {
      if (nextInsertStatus === 409) {
        return new Response(JSON.stringify({ message: 'duplicate key' }), { status: 409 });
      }
      insertedRow = JSON.parse(String(init?.body ?? '{}'));
      return new Response(JSON.stringify([insertedRow]), { status: 201 });
    }
    if (url.includes('script.google.com')) {
      sheetPayloadSent = JSON.parse(String(init?.body ?? '{}'));
      return new Response(JSON.stringify({ status: 'success' }), { status: 200 });
    }
    return new Response('[]', { status: 200 });
  };

  const validReportBody = {
    action: 'admin_report',
    report: {
      tanggal: '11-11-2026',
      waktu: '10.00',
      kendala: 'Gate in 1 tidak keluar karcis',
      penyebab: '',
      solusi_sementara: 'Buka manual',
      durasi_error: '',
      ada_foto: true,
    },
  };

  const okRes = await handleDailyTasks(
    new Request('https://example.com/daily-tasks', {
      method: 'POST',
      headers: { 'x-app-session': adminToken, 'content-type': 'application/json' },
      body: JSON.stringify(validReportBody),
    }),
    mockFetch,
  );
  assertEquals(okRes.status, 201);
  const okJson = await okRes.json();
  assertEquals(typeof okJson.id, 'string');
  assertEquals(okJson.message.includes('Lokasi : Mie Gacoan Nani Wartabone'), true);
  assertNotEquals(insertedRow, null);
  assertEquals(insertedRow!['kategori'], 'error');
  assertEquals(insertedRow!['status'], 'pending');
  assertEquals(insertedRow!['tanggal'], '2026-11-11');
  assertEquals(insertedRow!['teknisi_nama'], 'Irma');
  assertEquals(insertedRow!['pos_name'], 'Mie Gacoan Nani Wartabone');
  assertEquals(insertedRow!['pos_tag'], 'MGNW');
  assertEquals(insertedRow!['peserta'], '');
  assertEquals(insertedRow!['serah_terima'], 'Irma||Daftar terbuka|11 Nov 10:00');
  assertNotEquals(sheetPayloadSent, null);
  assertEquals(sheetPayloadSent!['kind'], 'error');
  assertEquals(sheetPayloadSent!['stage'], 'open');
  assertEquals(sheetPayloadSent!['pelapor'], 'Irma');

  // 4. duplicate -> 409
  nextInsertStatus = 409;
  const dupRes = await handleDailyTasks(
    new Request('https://example.com/daily-tasks', {
      method: 'POST',
      headers: { 'x-app-session': adminToken, 'content-type': 'application/json' },
      body: JSON.stringify(validReportBody),
    }),
    mockFetch,
  );
  assertEquals(dupRes.status, 409);
  assertEquals(await dupRes.json(), { error: 'duplicate' });
  nextInsertStatus = 201;

  // 5. aktif = false -> 403
  userAktif = false;
  const inactiveRes = await handleDailyTasks(
    new Request('https://example.com/daily-tasks', {
      method: 'POST',
      headers: { 'x-app-session': adminToken, 'content-type': 'application/json' },
      body: JSON.stringify(validReportBody),
    }),
    mockFetch,
  );
  assertEquals(inactiveRes.status, 403);

  // 6. missing pos_name -> 403
  userAktif = true;
  userPosName = '';
  const noPosRes = await handleDailyTasks(
    new Request('https://example.com/daily-tasks', {
      method: 'POST',
      headers: { 'x-app-session': adminToken, 'content-type': 'application/json' },
      body: JSON.stringify(validReportBody),
    }),
    mockFetch,
  );
  assertEquals(noPosRes.status, 403);
});

Deno.test('daily-tasks: admin_list maps open, claimed, and completed reports with diambil and selesai', async () => {
  const adminToken = await signSession({
    uid: 'usr_admin_mgnw',
    role: 'admin_pos',
    cabang: 'KC Manado',
    name: 'Irma',
  });

  const mockRows = [
    // 1. Open row -> menunggu / teknisi null / diambil null
    {
      id: 'task_open',
      tanggal: '2026-11-12',
      judul: 'Gate in 1 macet',
      status: 'pending',
      teknisi_nama: 'Irma',
      serah_terima: 'Irma||Daftar terbuka|12 Nov 09:30',
      jam_selesai: null,
      created_at: '2026-11-12T01:30:00Z',
    },
    // 2. Claimed row -> ditangani / Ryan / diambil '12 Nov 10:05'
    {
      id: 'task_claimed',
      tanggal: '2026-11-12',
      judul: 'Printer karcis mati',
      status: 'pending',
      teknisi_nama: 'Ryan',
      serah_terima: 'Irma||Daftar terbuka|12 Nov 09:30\nIrma|Ryan|Ambil tugas terbuka|12 Nov 10:05',
      jam_selesai: null,
      created_at: '2026-11-12T01:35:00Z',
    },
    // 3. Completed row -> selesai with selesai '10:15'
    {
      id: 'task_done',
      tanggal: '2026-11-12',
      judul: 'Kamera LPR buram',
      status: 'done',
      teknisi_nama: 'Ryan',
      serah_terima: 'Irma||Daftar terbuka|12 Nov 09:30\nIrma|Ryan|Ambil tugas terbuka|12 Nov 10:05',
      jam_selesai: '10:15',
      created_at: '2026-11-12T01:40:00Z',
    },
  ];

  const mockFetch: typeof fetch = async (input) => {
    const url = String(input);
    if (url.includes('/rest/v1/app_users')) {
      return new Response(
        JSON.stringify([
          {
            nama: 'Irma',
            pos_name: 'Mie Gacoan Nani Wartabone',
            pos_kode: 'mgnw',
            aktif: true,
          },
        ]),
        { status: 200 },
      );
    }
    if (url.includes('/rest/v1/daily_tasks_manado')) {
      return new Response(JSON.stringify(mockRows), { status: 200 });
    }
    return new Response('[]', { status: 200 });
  };

  const res = await handleDailyTasks(
    new Request('https://example.com/daily-tasks', {
      method: 'POST',
      headers: { 'x-app-session': adminToken, 'content-type': 'application/json' },
      body: JSON.stringify({ action: 'admin_list' }),
    }),
    mockFetch,
  );

  assertEquals(res.status, 200);
  const data = await res.json();
  assertEquals(Array.isArray(data.reports), true);
  assertEquals(data.reports.length, 3);

  // open row -> menunggu/teknisi null/diambil null
  const rOpen = data.reports[0];
  assertEquals(rOpen.status, 'menunggu');
  assertEquals(rOpen.teknisi, null);
  assertEquals(rOpen.diambil, null);
  assertEquals(rOpen.selesai, null);

  // claimed row -> ditangani/Ryan/diambil '12 Nov 10:05'
  const rClaimed = data.reports[1];
  assertEquals(rClaimed.status, 'ditangani');
  assertEquals(rClaimed.teknisi, 'Ryan');
  assertEquals(rClaimed.diambil, '12 Nov 10:05');
  assertEquals(rClaimed.selesai, null);

  // completed -> selesai with selesai '10:15'
  const rDone = data.reports[2];
  assertEquals(rDone.status, 'selesai');
  assertEquals(rDone.teknisi, 'Ryan');
  assertEquals(rDone.diambil, '12 Nov 10:05');
  assertEquals(rDone.selesai, '10:15');
});
