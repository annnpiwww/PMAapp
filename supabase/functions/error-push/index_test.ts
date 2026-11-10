import { assertEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { extractCreator, handleErrorPush } from './index.ts';

Deno.env.set('DENO_TESTING', '1');

Deno.test('error-push: extractCreator parses Pelapor header or fallbacks', () => {
  assertEquals(extractCreator('Pelapor: Farhan\nKendala: Rusak', 'Ryan'), 'farhan');
  assertEquals(extractCreator('Pelapor : Indra Yohana\nKendala: Rusak', 'Ryan'), 'indra yohana');
  assertEquals(extractCreator('No pelapor here', 'Ryan Lumasuge'), 'ryan lumasuge');
  assertEquals(extractCreator(undefined, 'Teknisi A'), 'teknisi a');
});

Deno.test('error-push: rejects invalid secret', async () => {
  const req = new Request('https://example.com/error-push', {
    method: 'POST',
    headers: { 'x-error-push-secret': 'wrong-secret' },
    body: JSON.stringify({ table: 'daily_tasks_manado', record: {} }),
  });

  const res = await handleErrorPush(req, { secret: 'correct-secret' });
  assertEquals(res.status, 401);
});

Deno.test('error-push: skips creator and sends to other branch tokens', async () => {
  const mockTokens = [
    { token: 'tok_creator_1234567890123456', user_name: 'Farhan', cabang: 'KC Manado' },
    { token: 'tok_other_12345678901234567', user_name: 'Ryan', cabang: 'KC Manado' },
    { token: 'tok_bali_123456789012345678', user_name: 'Indra', cabang: 'KC Bali' },
  ];

  let fcmSentCount = 0;
  const mockFetch = async (input: RequestInfo | URL, init?: RequestInit): Promise<Response> => {
    const url = String(input);
    if (url.includes('device_push_tokens')) {
      return new Response(JSON.stringify(mockTokens), { status: 200 });
    }
    if (url.includes('oauth2.googleapis.com')) {
      return new Response(JSON.stringify({ access_token: 'fake_jwt', expires_in: 3600 }), { status: 200 });
    }
    if (url.includes('fcm.googleapis.com')) {
      fcmSentCount++;
      return new Response(JSON.stringify({ name: 'projects/pmapp/messages/1' }), { status: 200 });
    }
    return new Response(null, { status: 400 });
  };

  const req = new Request('https://example.com/error-push', {
    method: 'POST',
    headers: {
      'x-error-push-secret': 'shared-secret-12345',
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      table: 'daily_tasks_manado',
      record: {
        id: 'err_task_1',
        pos_name: 'Pos 1 Manado',
        judul: 'Barrier motor patah',
        deskripsi: 'Pelapor: Farhan\nKendala: Patah',
        kategori: 'error',
        status: 'pending',
      },
    }),
  });

  // Dummy RSA key pair for testing
  const keyPair = await crypto.subtle.generateKey(
    {
      name: 'RSASSA-PKCS1-v1_5',
      modulusLength: 2048,
      publicExponent: new Uint8Array([1, 0, 1]),
      hash: 'SHA-256',
    },
    true,
    ['sign', 'verify'],
  );
  const exported = await crypto.subtle.exportKey('pkcs8', keyPair.privateKey);
  let binary = '';
  const bytes = new Uint8Array(exported);
  for (let i = 0; i < bytes.byteLength; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  const pem = `-----BEGIN PRIVATE KEY-----\n${btoa(binary)}\n-----END PRIVATE KEY-----`;

  const res = await handleErrorPush(req, {
    secret: 'shared-secret-12345',
    supabaseUrl: 'https://mock.supabase.co',
    serviceRoleKey: 'mock-key',
    serviceAccount: {
      project_id: 'pmapp-8e840',
      client_email: 'test@pmapp-8e840.iam.gserviceaccount.com',
      private_key: pem,
    },
    fetchImpl: mockFetch as typeof fetch,
  });

  assertEquals(res.status, 200);
  const data = await res.json();
  assertEquals(data.ok, true);
  assertEquals(data.sent, 1); // Only Ryan's token sent, Farhan (creator) skipped, Bali skipped
  assertEquals(data.skipped_creator, 1);
});

Deno.test('error-push: 500 response returns only {error: internal} when token fetch fails', async () => {
  const mockFetchFailed = async (input: RequestInfo | URL): Promise<Response> => {
    const url = String(input);
    if (url.includes('device_push_tokens')) {
      return new Response('Database timeout error details', { status: 502 });
    }
    return new Response(null, { status: 400 });
  };

  const req = new Request('https://example.com/error-push', {
    method: 'POST',
    headers: {
      'x-error-push-secret': 'shared-secret-12345',
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      table: 'daily_tasks_manado',
      record: {
        id: 'err_task_1',
        pos_name: 'Pos 1 Manado',
        judul: 'Barrier motor patah',
        deskripsi: 'Pelapor: Farhan\nKendala: Patah',
        kategori: 'error',
        status: 'pending',
      },
    }),
  });

  const res = await handleErrorPush(req, {
    secret: 'shared-secret-12345',
    supabaseUrl: 'https://mock.supabase.co',
    serviceRoleKey: 'mock-key',
    fetchImpl: mockFetchFailed as typeof fetch,
  });

  assertEquals(res.status, 500);
  const data = await res.json();
  assertEquals(data, { error: 'internal' });
});
