import { assertEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { signSession } from '../_shared/session.ts';

Deno.env.set('DENO_TESTING', '1');
Deno.env.set('APP_SESSION_SECRET', 'test-session-secret-32-bytes-minimum-key!!');
Deno.env.set('GOOGLE_SHEETS_WEBHOOK_URL', 'https://script.google.com/macros/s/test/exec');
Deno.env.set('GOOGLE_SHEETS_SECRET', 'test-sheets-secret');

const { handleSheetsSync } = await import('./index.ts');

async function createReq(cabang: string, body: Record<string, unknown>): Promise<Request> {
  const token = await signSession({
    uid: 'usr_test',
    role: 'technician',
    cabang,
    name: 'Test User',
  });
  return new Request('https://example.com/sheets-sync', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-app-session': token,
    },
    body: JSON.stringify(body),
  });
}

Deno.test('sheets-sync: error + manado -> forwarded', async () => {
  let forwarded = false;
  // deno-lint-ignore no-explicit-any
  let forwardedBody: any = null;

  const fakeFetch: typeof fetch = async (_input, init) => {
    forwarded = true;
    forwardedBody = JSON.parse(init?.body as string);
    return new Response(JSON.stringify({ status: 'success' }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    });
  };

  const req = await createReq('manado', { kind: 'error', stage: 'open', id: 'task-1' });
  const res = await handleSheetsSync(req, fakeFetch);

  assertEquals(res.status, 200);
  assertEquals(forwarded, true);
  assertEquals(forwardedBody?.kind, 'error');
  assertEquals(forwardedBody?.secretToken, 'test-sheets-secret');
});

Deno.test('sheets-sync: error + bali -> 403', async () => {
  let called = false;
  const fakeFetch: typeof fetch = async () => {
    called = true;
    return new Response('{}', { status: 200 });
  };

  const req = await createReq('bali', { kind: 'error', stage: 'open', id: 'task-1' });
  const res = await handleSheetsSync(req, fakeFetch);

  assertEquals(res.status, 403);
  assertEquals(called, false);
  const json = await res.json();
  assertEquals(json.error, 'forbidden');
});

Deno.test('sheets-sync: error + HO -> 403', async () => {
  let called = false;
  const fakeFetch: typeof fetch = async () => {
    called = true;
    return new Response('{}', { status: 200 });
  };

  const req = await createReq('ho', { kind: 'error', stage: 'open', id: 'task-1' });
  const res = await handleSheetsSync(req, fakeFetch);

  assertEquals(res.status, 403);
  assertEquals(called, false);
  const json = await res.json();
  assertEquals(json.error, 'forbidden');
});

Deno.test('sheets-sync: non-error + bali -> forwarded', async () => {
  let forwarded = false;
  // deno-lint-ignore no-explicit-any
  let forwardedBody: any = null;

  const fakeFetch: typeof fetch = async (_input, init) => {
    forwarded = true;
    forwardedBody = JSON.parse(init?.body as string);
    return new Response(JSON.stringify({ status: 'success' }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    });
  };

  const req = await createReq('bali', { sheetName: 'Maintenance', rows: [['1', '2']] });
  const res = await handleSheetsSync(req, fakeFetch);

  assertEquals(res.status, 200);
  assertEquals(forwarded, true);
  assertEquals(forwardedBody?.sheetName, 'Maintenance');
});

Deno.test('sheets-sync: admin_pos role rejected with 403', async () => {
  const token = await signSession({
    uid: 'usr_admin_pos',
    role: 'admin_pos',
    cabang: 'KC Manado',
    name: 'Irma',
  });
  const req = new Request('https://example.com/sheets-sync', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-app-session': token,
    },
    body: JSON.stringify({ kind: 'error', stage: 'open', id: 'task-1' }),
  });
  const res = await handleSheetsSync(req);
  assertEquals(res.status, 403);
  assertEquals(await res.json(), { error: 'forbidden' });
});
