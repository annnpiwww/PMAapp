import {
  assertEquals,
  assertMatch,
  assertNotEquals,
  assertRejects,
  assertStringIncludes,
} from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import {
  type R2Config,
  presignR2Url,
  r2Delete,
  r2GetBytes,
  readR2Config,
} from './r2.ts';

const FAKE_CONFIG: R2Config = {
  accountId: 'acct1234567890abcdef',
  accessKeyId: 'AKIAFAKEACCESSKEY001',
  secretAccessKey: 'fake-secret-access-key-0123456789abcdef',
  bucket: 'pmapp',
};

const FIXED_NOW = new Date('2026-11-22T10:00:00.000Z');

Deno.test('presignR2Url produces deterministic SigV4 URL with expected query params and path', async () => {
  const url1 = await presignR2Url({
    method: 'PUT',
    config: FAKE_CONFIG,
    key: 'prod/3156-armeabi-v7a.apk',
    expiresSeconds: 900,
    now: FIXED_NOW,
  });
  const url2 = await presignR2Url({
    method: 'PUT',
    config: FAKE_CONFIG,
    key: 'prod/3156-armeabi-v7a.apk',
    expiresSeconds: 900,
    now: FIXED_NOW,
  });

  assertEquals(url1, url2);

  const parsed = new URL(url1);
  assertEquals(parsed.origin, 'https://acct1234567890abcdef.r2.cloudflarestorage.com');
  assertEquals(parsed.pathname, '/pmapp/prod/3156-armeabi-v7a.apk');
  assertStringIncludes(url1, 'X-Amz-Algorithm=AWS4-HMAC-SHA256');
  assertStringIncludes(url1, 'X-Amz-SignedHeaders=host');
  assertStringIncludes(url1, 'X-Amz-Expires=900');
  assertStringIncludes(url1, 'X-Amz-Date=20261122T100000Z');
  assertStringIncludes(
    url1,
    'X-Amz-Credential=AKIAFAKEACCESSKEY001%2F20261122%2Fauto%2Fs3%2Faws4_request',
  );
  assertMatch(parsed.searchParams.get('X-Amz-Signature') ?? '', /^[0-9a-f]{64}$/);

  const getUrl = await presignR2Url({
    method: 'GET',
    config: FAKE_CONFIG,
    key: 'prod/3156-armeabi-v7a.apk',
    expiresSeconds: 900,
    now: FIXED_NOW,
  });
  assertNotEquals(
    new URL(getUrl).searchParams.get('X-Amz-Signature'),
    parsed.searchParams.get('X-Amz-Signature'),
  );
});

Deno.test('presignR2Url RFC3986-encodes each path segment including plus signs', async () => {
  const url = await presignR2Url({
    method: 'GET',
    config: FAKE_CONFIG,
    key: 'v4156/arm64-v8a/pmapp-2.0.143+4156!(test).apk',
    expiresSeconds: 900,
    now: FIXED_NOW,
  });

  const parsed = new URL(url);
  assertEquals(
    parsed.pathname,
    '/pmapp/v4156/arm64-v8a/pmapp-2.0.143%2B4156%21%28test%29.apk',
  );
  assertStringIncludes(url, '%2B4156');
});

Deno.test('readR2Config trims values and returns null when any variable is missing or blank', () => {
  const validEnv: Record<string, string> = {
    R2_ACCOUNT_ID: '  acct123  ',
    R2_ACCESS_KEY_ID: ' key123 ',
    R2_SECRET_ACCESS_KEY: ' secret123 ',
    R2_BUCKET: ' pmapp ',
  };
  assertEquals(readR2Config((k) => validEnv[k]), {
    accountId: 'acct123',
    accessKeyId: 'key123',
    secretAccessKey: 'secret123',
    bucket: 'pmapp',
  });

  for (const missingKey of [
    'R2_ACCOUNT_ID',
    'R2_ACCESS_KEY_ID',
    'R2_SECRET_ACCESS_KEY',
    'R2_BUCKET',
  ]) {
    const omitted = { ...validEnv };
    delete omitted[missingKey];
    assertEquals(readR2Config((k) => omitted[k]), null);

    const blank = { ...validEnv, [missingKey]: '   ' };
    assertEquals(readR2Config((k) => blank[k]), null);
  }
});

Deno.test('r2GetBytes returns bytes on 200, null on 404, and throws sanitized error on 500', async () => {
  const origFetch = globalThis.fetch;
  try {
    globalThis.fetch = () => Promise.resolve(new Response(new Uint8Array([80, 75, 3, 4]), { status: 200 }));
    const okBytes = await r2GetBytes(FAKE_CONFIG, 'prod/3156-armeabi-v7a.apk');
    assertEquals(okBytes, new Uint8Array([80, 75, 3, 4]));

    globalThis.fetch = () => Promise.resolve(new Response('not found', { status: 404 }));
    const missing = await r2GetBytes(FAKE_CONFIG, 'prod/3156-armeabi-v7a.apk');
    assertEquals(missing, null);

    globalThis.fetch = () => Promise.resolve(new Response('forbidden', { status: 403 }));
    const err = await assertRejects(
      () => r2GetBytes(FAKE_CONFIG, 'prod/3156-armeabi-v7a.apk'),
      Error,
      'R2 GET failed with status 403',
    );
    assertEquals(err.message.includes(FAKE_CONFIG.secretAccessKey), false);
    assertEquals(err.message.includes(FAKE_CONFIG.accessKeyId), false);
  } finally {
    globalThis.fetch = origFetch;
  }
});

Deno.test('r2Delete succeeds on 204 and 404, and throws sanitized error on 500', async () => {
  const origFetch = globalThis.fetch;
  try {
    globalThis.fetch = () => Promise.resolve(new Response(null, { status: 204 }));
    await r2Delete(FAKE_CONFIG, 'prod/3156-armeabi-v7a.apk');

    globalThis.fetch = () => Promise.resolve(new Response(null, { status: 404 }));
    await r2Delete(FAKE_CONFIG, 'prod/3156-armeabi-v7a.apk');

    globalThis.fetch = () => Promise.resolve(new Response('error', { status: 500 }));
    const err = await assertRejects(
      () => r2Delete(FAKE_CONFIG, 'prod/3156-armeabi-v7a.apk'),
      Error,
      'R2 DELETE failed with status 500',
    );
    assertEquals(err.message.includes(FAKE_CONFIG.secretAccessKey), false);
    assertEquals(err.message.includes(FAKE_CONFIG.accessKeyId), false);
  } finally {
    globalThis.fetch = origFetch;
  }
});
