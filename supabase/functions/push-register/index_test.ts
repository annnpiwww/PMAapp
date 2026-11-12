import { assertEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { handlePushRegister } from './index.ts';
import { signSession } from '../_shared/session.ts';

Deno.env.set('DENO_TESTING', '1');
Deno.env.set('APP_SESSION_SECRET', 'test-session-secret-32-bytes-minimum-key!!');

Deno.test('push-register: rejects request without session', async () => {
  const req = new Request('https://example.com/push-register', {
    method: 'POST',
    body: JSON.stringify({ token: 'test_token_12345678901234567890' }),
  });

  const res = await handlePushRegister(req);
  assertEquals(res.status, 401);
});

Deno.test('push-register: rejects invalid token length', async () => {
  const sessionToken = await signSession({
    uid: 'u_1',
    role: 'technician',
    cabang: 'KC Manado',
    name: 'Ryan Lumasuge',
  });

  const req = new Request('https://example.com/push-register', {
    method: 'POST',
    headers: {
      'x-app-session': sessionToken,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ token: 'short' }),
  });

  const res = await handlePushRegister(req);
  assertEquals(res.status, 400);
});

Deno.test('push-register: successfully registers token via POST', async () => {
  const sessionToken = await signSession({
    uid: 'u_1',
    role: 'technician',
    cabang: 'KC Manado',
    name: 'Ryan Lumasuge',
  });

  let upsertCalled = false;
  let capturedBody = '';

  const mockFetch = async (_input: RequestInfo | URL, init?: RequestInit): Promise<Response> => {
    upsertCalled = true;
    capturedBody = String(init?.body ?? '');
    return new Response(JSON.stringify([{ ok: true }]), { status: 201 });
  };

  const req = new Request('https://example.com/push-register', {
    method: 'POST',
    headers: {
      'x-app-session': sessionToken,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      token: 'fcm_token_valid_length_1234567890',
      platform: 'android',
    }),
  });

  const res = await handlePushRegister(req, {
    supabaseUrl: 'https://mock.supabase.co',
    serviceRoleKey: 'mock-key',
    fetchImpl: mockFetch as typeof fetch,
  });

  assertEquals(res.status, 200);
  assertEquals(upsertCalled, true);
  const rows = JSON.parse(capturedBody);
  assertEquals(rows[0].token, 'fcm_token_valid_length_1234567890');
  assertEquals(rows[0].user_name, 'Ryan Lumasuge');
  assertEquals(rows[0].cabang, 'KC Manado');
  assertEquals(rows[0].role, 'technician');
});

Deno.test('push-register: successfully unregisters token via DELETE', async () => {
  const sessionToken = await signSession({
    uid: 'u_1',
    role: 'technician',
    cabang: 'KC Manado',
    name: 'Ryan Lumasuge',
  });

  let deleteCalled = false;

  const mockFetch = async (_input: RequestInfo | URL, init?: RequestInit): Promise<Response> => {
    if (init?.method === 'DELETE') {
      deleteCalled = true;
      return new Response(null, { status: 204 });
    }
    return new Response(null, { status: 400 });
  };

  const req = new Request('https://example.com/push-register', {
    method: 'DELETE',
    headers: {
      'x-app-session': sessionToken,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      token: 'fcm_token_valid_length_1234567890',
    }),
  });

  const res = await handlePushRegister(req, {
    supabaseUrl: 'https://mock.supabase.co',
    serviceRoleKey: 'mock-key',
    fetchImpl: mockFetch as typeof fetch,
  });

  assertEquals(res.status, 200);
  assertEquals(deleteCalled, true);
});

Deno.test('push-register: rejects admin_pos session with 403', async () => {
  const sessionToken = await signSession({
    uid: 'u_admin_1',
    role: 'admin_pos',
    cabang: 'KC Manado',
    name: 'Irma',
  });

  const req = new Request('https://example.com/push-register', {
    method: 'POST',
    headers: {
      'x-app-session': sessionToken,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      token: 'fcm_token_valid_length_1234567890',
      platform: 'android',
    }),
  });

  const res = await handlePushRegister(req);
  assertEquals(res.status, 403);
  assertEquals(await res.json(), { error: 'forbidden' });
});
