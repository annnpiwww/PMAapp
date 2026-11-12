import { assertEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { signSession } from '../_shared/session.ts';

Deno.env.set('DENO_TESTING', '1');
Deno.env.set('APP_SESSION_SECRET', 'test-session-secret-32-bytes-minimum-key!!');
Deno.env.set('SUPABASE_URL', 'https://fake.supabase.co');
Deno.env.set('SUPABASE_SERVICE_ROLE_KEY', 'fake-service-role');

const { verifyPbkdf2Hash } = await import('../auth-login/index.ts');
const { buildAdminUsername, handleAdminAccounts, slugifyNama } = await import('./index.ts');

Deno.test('admin-accounts: slugifyNama and buildAdminUsername follow contract rules', () => {
  assertEquals(slugifyNama('Irma'), 'irma');
  assertEquals(slugifyNama('  Putri Ayu  '), 'putriayu');
  assertEquals(buildAdminUsername('Irma', 'mgnw'), 'irma-mgnw');
});

Deno.test('admin-accounts: non-SPV roles (technician, admin_pos) rejected with 403', async () => {
  const techToken = await signSession({
    uid: 'usr_tek_1',
    role: 'technician',
    cabang: 'KC Manado',
    name: 'Ryan',
  });
  const adminToken = await signSession({
    uid: 'usr_adm_1',
    role: 'admin_pos',
    cabang: 'KC Manado',
    name: 'Irma',
  });

  for (const token of [techToken, adminToken]) {
    const res = await handleAdminAccounts(
      new Request('https://example.com/admin-accounts', {
        method: 'POST',
        headers: { 'x-app-session': token, 'content-type': 'application/json' },
        body: JSON.stringify({ action: 'list' }),
      }),
    );
    assertEquals(res.status, 403);
  }
});

Deno.test('admin-accounts: list, create, duplicate 409, validation 400, reset_password, set_aktif & cross-branch 404', async () => {
  const spvToken = await signSession({
    uid: 'usr_spv_mdo',
    role: 'spv',
    cabang: 'KC Manado',
    name: 'Farhan Lakoro',
  });

  // In-memory store for mock DB
  const usersDb: Array<Record<string, unknown>> = [
    {
      id: 'adm_2',
      username: 'sari-pbm',
      nama: 'Sari',
      role: 'admin_pos',
      cabang: 'KC Manado',
      pos_name: 'Pasar Bersehati Manado',
      pos_kode: 'pbm',
      aktif: true,
    },
    {
      id: 'adm_1',
      username: 'budi-mgnw',
      nama: 'Budi',
      role: 'admin_pos',
      cabang: 'KC Manado',
      pos_name: 'Mie Gacoan Nani Wartabone',
      pos_kode: 'mgnw',
      aktif: true,
    },
    {
      id: 'adm_bali_1',
      username: 'ketut-bali',
      nama: 'Ketut',
      role: 'admin_pos',
      cabang: 'KC Bali',
      pos_name: 'Pos Bali',
      pos_kode: 'bali',
      aktif: true,
    },
  ];

  let lastInsertedRow: Record<string, unknown> | null = null;
  let lastPatchedBody: Record<string, unknown> | null = null;

  const mockFetch: typeof fetch = async (input, init) => {
    const url = String(input);
    const method = init?.method ?? 'GET';

    if (url.includes('/rest/v1/pos_locations')) {
      return new Response(
        JSON.stringify([
          {
            pos_name: 'Mie Gacoan Nani Wartabone',
            location_tag: 'MGNW',
            branch: 'manado',
          },
          {
            pos_name: 'Pasar Bersehati Manado',
            location_tag: 'PBM',
            branch: 'manado',
          },
        ]),
        { status: 200 },
      );
    }

    if (url.includes('/rest/v1/app_users')) {
      if (method === 'GET') {
        if (url.includes('username=ilike.')) {
          const uname = decodeURIComponent(url.split('username=ilike.')[1].split('&')[0]).toLowerCase();
          const matches = usersDb.filter((u) => String(u.username).toLowerCase() === uname);
          return new Response(JSON.stringify(matches), { status: 200 });
        }
        if (url.includes('id=eq.')) {
          const id = decodeURIComponent(url.split('id=eq.')[1].split('&')[0]);
          const matches = usersDb.filter((u) => u.id === id);
          return new Response(JSON.stringify(matches), { status: 200 });
        }
        return new Response(JSON.stringify(usersDb), { status: 200 });
      }

      if (method === 'POST') {
        const body = JSON.parse(String(init?.body ?? '{}'));
        lastInsertedRow = body;
        const created = { ...body, id: 'adm_new_1' };
        usersDb.push(created);
        return new Response(JSON.stringify([created]), { status: 201 });
      }

      if (method === 'PATCH') {
        const body = JSON.parse(String(init?.body ?? '{}'));
        lastPatchedBody = body;
        const id = decodeURIComponent(url.split('id=eq.')[1].split('&')[0]);
        const target = usersDb.find((u) => u.id === id && u.cabang === 'KC Manado' && u.role === 'admin_pos');
        if (!target) {
          return new Response('[]', { status: 200 });
        }
        Object.assign(target, body);
        return new Response(JSON.stringify([target]), { status: 200 });
      }
    }

    return new Response('[]', { status: 200 });
  };

  // 1. list: sorted by pos_name, nama and excludes KC Bali account
  const listRes = await handleAdminAccounts(
    new Request('https://example.com/admin-accounts', {
      method: 'POST',
      headers: { 'x-app-session': spvToken, 'content-type': 'application/json' },
      body: JSON.stringify({ action: 'list' }),
    }),
    mockFetch,
  );
  assertEquals(listRes.status, 200);
  const listData = await listRes.json();
  assertEquals(listData.accounts.length, 2);
  assertEquals(listData.accounts[0].username, 'budi-mgnw');
  assertEquals(listData.accounts[1].username, 'sari-pbm');

  // 2. create: success 201 with PBKDF2 hash and no plaintext password
  const createRes = await handleAdminAccounts(
    new Request('https://example.com/admin-accounts', {
      method: 'POST',
      headers: { 'x-app-session': spvToken, 'content-type': 'application/json' },
      body: JSON.stringify({
        action: 'create',
        nama: 'Irma',
        pos_name: 'Mie Gacoan Nani Wartabone',
        pos_kode: 'mgnw',
        password: ' test_pw_8chars ',
      }),
    }),
    mockFetch,
  );
  assertEquals(createRes.status, 201);
  const createData = await createRes.json();
  assertEquals(createData, { id: 'adm_new_1', username: 'irma-mgnw' });
  assertEquals('password' in lastInsertedRow!, false);
  assertEquals(await verifyPbkdf2Hash('test_pw_8chars', String(lastInsertedRow!.password_hash)), true);

  // 3. create duplicate -> 409
  const dupRes = await handleAdminAccounts(
    new Request('https://example.com/admin-accounts', {
      method: 'POST',
      headers: { 'x-app-session': spvToken, 'content-type': 'application/json' },
      body: JSON.stringify({
        action: 'create',
        nama: 'Irma',
        pos_name: 'Mie Gacoan Nani Wartabone',
        pos_kode: 'mgnw',
        password: 'another_valid_pw',
      }),
    }),
    mockFetch,
  );
  assertEquals(dupRes.status, 409);
  assertEquals(await dupRes.json(), { error: 'duplicate' });

  // 4. create validation failures -> 400 with field
  const badPosRes = await handleAdminAccounts(
    new Request('https://example.com/admin-accounts', {
      method: 'POST',
      headers: { 'x-app-session': spvToken, 'content-type': 'application/json' },
      body: JSON.stringify({
        action: 'create',
        nama: 'Rina',
        pos_name: 'Pos Tidak Ada',
        pos_kode: 'mgnw',
        password: 'valid_password_1',
      }),
    }),
    mockFetch,
  );
  assertEquals(badPosRes.status, 400);
  assertEquals(await badPosRes.json(), { error: 'invalid', field: 'pos_name' });

  const samePassAsUsernameRes = await handleAdminAccounts(
    new Request('https://example.com/admin-accounts', {
      method: 'POST',
      headers: { 'x-app-session': spvToken, 'content-type': 'application/json' },
      body: JSON.stringify({
        action: 'create',
        nama: 'Rina',
        pos_name: 'Mie Gacoan Nani Wartabone',
        pos_kode: 'mgnw',
        password: 'rina-mgnw',
      }),
    }),
    mockFetch,
  );
  assertEquals(samePassAsUsernameRes.status, 400);
  assertEquals(await samePassAsUsernameRes.json(), { error: 'invalid', field: 'password' });

  // 5. reset_password -> 200 on own branch, 404 on other branch
  const resetOk = await handleAdminAccounts(
    new Request('https://example.com/admin-accounts', {
      method: 'POST',
      headers: { 'x-app-session': spvToken, 'content-type': 'application/json' },
      body: JSON.stringify({
        action: 'reset_password',
        id: 'adm_new_1',
        password: 'new_valid_pw_99',
      }),
    }),
    mockFetch,
  );
  assertEquals(resetOk.status, 200);
  assertEquals(await verifyPbkdf2Hash('new_valid_pw_99', String(lastPatchedBody!.password_hash)), true);

  const resetOtherBranch = await handleAdminAccounts(
    new Request('https://example.com/admin-accounts', {
      method: 'POST',
      headers: { 'x-app-session': spvToken, 'content-type': 'application/json' },
      body: JSON.stringify({
        action: 'reset_password',
        id: 'adm_bali_1',
        password: 'new_valid_pw_99',
      }),
    }),
    mockFetch,
  );
  assertEquals(resetOtherBranch.status, 404);

  // 6. set_aktif -> 200 on own branch, 404 on other branch
  const setAktifRes = await handleAdminAccounts(
    new Request('https://example.com/admin-accounts', {
      method: 'POST',
      headers: { 'x-app-session': spvToken, 'content-type': 'application/json' },
      body: JSON.stringify({
        action: 'set_aktif',
        id: 'adm_new_1',
        aktif: false,
      }),
    }),
    mockFetch,
  );
  assertEquals(setAktifRes.status, 200);
  assertEquals(lastPatchedBody, { aktif: false });

  const setAktifOtherBranch = await handleAdminAccounts(
    new Request('https://example.com/admin-accounts', {
      method: 'POST',
      headers: { 'x-app-session': spvToken, 'content-type': 'application/json' },
      body: JSON.stringify({
        action: 'set_aktif',
        id: 'adm_bali_1',
        aktif: false,
      }),
    }),
    mockFetch,
  );
  assertEquals(setAktifOtherBranch.status, 404);
});
