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
