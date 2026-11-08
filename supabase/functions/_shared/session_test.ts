import { assertEquals, assertNotEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { isSpv, signSession, verifySession } from './session.ts';

Deno.env.set('DENO_TESTING', '1');
Deno.env.set('APP_SESSION_SECRET', 'test-session-secret-32-bytes-minimum-key!!');
Deno.env.set('AUTH_FAILURE_DELAY_MS', '1');

const { handleAiVision } = await import('../ai-vision/index.ts');
const { handlePosLocations } = await import('../pos-locations/index.ts');
const { handleDailyTasks } = await import('../daily-tasks/index.ts');
const { createPbkdf2Hash, handleAuthLogin, verifyPbkdf2Hash } = await import('../auth-login/index.ts');

Deno.test('session.ts: valid token signs and verifies accurately', async () => {
  const token = await signSession({
    uid: 'usr_bali_spv',
    role: 'spv',
    cabang: 'KC Bali',
    name: 'Indra Yohana',
  });

  assertEquals(token.startsWith('v1.'), true);
  const req = new Request('https://example.com/fn', {
    method: 'POST',
    headers: { 'x-app-session': token },
  });

  const verified = await verifySession(req);
  assertNotEquals(verified, null);
  assertEquals(verified?.uid, 'usr_bali_spv');
  assertEquals(verified?.role, 'spv');
  assertEquals(verified?.cabang, 'KC Bali');
  assertEquals(verified?.name, 'Indra Yohana');
  assertEquals(isSpv(verified!), true);
});

Deno.test('session.ts: tampered payload returns null', async () => {
  const token = await signSession({
    uid: 'usr_tek_1',
    role: 'technician',
    cabang: 'manado',
    name: 'Ryan',
  });
  const parts = token.split('.');
  // Replace payload with escalated role while keeping original signature
  const forgedPayload = btoa(
    JSON.stringify({
      uid: 'usr_tek_1',
      role: 'spv',
      cabang: 'manado',
      name: 'Ryan',
      iat: Math.floor(Date.now() / 1000),
      exp: Math.floor(Date.now() / 1000) + 86400,
    }),
  ).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');

  const forgedToken = `v1.${forgedPayload}.${parts[2]}`;
  const req = new Request('https://example.com/fn', {
    headers: { 'x-app-session': forgedToken },
  });
  assertEquals(await verifySession(req), null);
});

Deno.test('session.ts: tampered signature returns null', async () => {
  const token = await signSession({
    uid: 'usr_1',
    role: 'spv',
    cabang: 'manado',
    name: 'Test',
  });
  const parts = token.split('.');
  const lastChar = parts[2].endsWith('A') ? 'B' : 'A';
  const badSigToken = `${parts[0]}.${parts[1]}.${parts[2].slice(0, -1)}${lastChar}`;

  const req = new Request('https://example.com/fn', {
    headers: { 'x-app-session': badSigToken },
  });
  assertEquals(await verifySession(req), null);
});

Deno.test('session.ts: expired token returns null', async () => {
  const now = Math.floor(Date.now() / 1000);
  const expiredToken = await signSession({
    uid: 'usr_1',
    role: 'technician',
    cabang: 'bali',
    name: 'Expired User',
    iat: now - 7200,
    exp: now - 10,
  });

  const req = new Request('https://example.com/fn', {
    headers: { 'x-app-session': expiredToken },
  });
  assertEquals(await verifySession(req), null);
});

Deno.test('session.ts: missing header returns null', async () => {
  const req = new Request('https://example.com/fn');
  assertEquals(await verifySession(req), null);
});

Deno.test('ai-vision: ENFORCE_SESSION=true vs compat mode, size cap, allowlist, field strip & sanitising', async () => {
  Deno.env.set('GEMINI_API_KEY', 'fake-gemini-key');
  const validToken = await signSession({
    uid: 'usr_1',
    role: 'technician',
    cabang: 'manado',
    name: 'Ryan',
  });

  const validBody = JSON.stringify({
    model: 'gemini-3-flash-preview',
    messages: [{ role: 'user', content: 'check' }],
    max_tokens: 99999,
    temperature: 2.5,
    extra_injected_field: 'must_be_dropped',
    tools: [{ function: { name: 'evil' } }],
  });

  // 1. ENFORCE_SESSION=true rejects missing header with 401
  Deno.env.set('ENFORCE_SESSION', 'true');
  const noHeaderEnforced = new Request('https://example.com/functions/v1/ai-vision', {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      'content-length': String(validBody.length),
    },
    body: validBody,
  });
  assertEquals((await handleAiVision(noHeaderEnforced)).status, 401);

  // 2. Compat mode (ENFORCE_SESSION unset): present-but-invalid token STILL returns 401
  Deno.env.delete('ENFORCE_SESSION');
  const badTokenCompat = new Request('https://example.com/functions/v1/ai-vision', {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      'content-length': String(validBody.length),
      'x-app-session': 'v1.bad.sig',
    },
    body: validBody,
  });
  assertEquals((await handleAiVision(badTokenCompat)).status, 401);

  // 3. Compat mode: missing header passes auth, enforces caps, strips extra fields, caps max_tokens=1024 & temp=1
  let capturedUpstreamBody: Record<string, unknown> | null = null;
  const mockGeminiOk: typeof fetch = async (_input, init) => {
    capturedUpstreamBody = JSON.parse(String(init?.body ?? '{}'));
    return new Response(JSON.stringify({ choices: [{ message: { content: '{}' } }] }), {
      status: 200,
    });
  };
  const noHeaderCompat = new Request('https://example.com/functions/v1/ai-vision', {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      'content-length': String(validBody.length),
    },
    body: validBody,
  });
  const compatRes = await handleAiVision(noHeaderCompat, mockGeminiOk);
  assertEquals(compatRes.status, 200);
  assertNotEquals(capturedUpstreamBody, null);
  assertEquals(capturedUpstreamBody!['max_tokens'], 1024);
  assertEquals(capturedUpstreamBody!['temperature'], 1);
  assertEquals('extra_injected_field' in capturedUpstreamBody!, false);
  assertEquals('tools' in capturedUpstreamBody!, false);

  // 3a. response_format {type:'json_object'} + reasoning_effort 'none' with model 'gemini-3-flash-preview' -> upstream body has both
  const bodyA = JSON.stringify({
    model: 'gemini-3-flash-preview',
    messages: [{ role: 'user', content: 'check' }],
    response_format: { type: 'json_object' },
    reasoning_effort: 'none',
  });
  const reqA = new Request('https://example.com/functions/v1/ai-vision', {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      'content-length': String(bodyA.length),
    },
    body: bodyA,
  });
  await handleAiVision(reqA, mockGeminiOk);
  assertEquals(capturedUpstreamBody!['response_format'], { type: 'json_object' });
  assertEquals(capturedUpstreamBody!['reasoning_effort'], 'none');

  // 3b. response_format {type:'json_schema', json_schema:{...}} -> not forwarded
  const bodyB = JSON.stringify({
    model: 'gemini-3-flash-preview',
    messages: [{ role: 'user', content: 'check' }],
    response_format: { type: 'json_schema', json_schema: { strict: true } },
  });
  const reqB = new Request('https://example.com/functions/v1/ai-vision', {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      'content-length': String(bodyB.length),
    },
    body: bodyB,
  });
  await handleAiVision(reqB, mockGeminiOk);
  assertEquals('response_format' in capturedUpstreamBody!, false);

  // 3c. reasoning_effort 'none' with a model outside the family that is allowlisted (gemini-flash-lite) -> not forwarded
  const bodyC = JSON.stringify({
    model: 'gemini-flash-lite',
    messages: [{ role: 'user', content: 'check' }],
    reasoning_effort: 'none',
  });
  const reqC = new Request('https://example.com/functions/v1/ai-vision', {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      'content-length': String(bodyC.length),
    },
    body: bodyC,
  });
  await handleAiVision(reqC, mockGeminiOk);
  assertEquals('reasoning_effort' in capturedUpstreamBody!, false);

  // 3d. reasoning_effort 'turbo' -> not forwarded
  const bodyD = JSON.stringify({
    model: 'gemini-3-flash-preview',
    messages: [{ role: 'user', content: 'check' }],
    reasoning_effort: 'turbo',
  });
  const reqD = new Request('https://example.com/functions/v1/ai-vision', {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      'content-length': String(bodyD.length),
    },
    body: bodyD,
  });
  await handleAiVision(reqD, mockGeminiOk);
  assertEquals('reasoning_effort' in capturedUpstreamBody!, false);

  // 3e. extra unknown field still stripped
  const bodyE = JSON.stringify({
    model: 'gemini-3-flash-preview',
    messages: [{ role: 'user', content: 'check' }],
    unrecognized_arbitrary_field: 'strip_me',
  });
  const reqE = new Request('https://example.com/functions/v1/ai-vision', {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      'content-length': String(bodyE.length),
    },
    body: bodyE,
  });
  await handleAiVision(reqE, mockGeminiOk);
  assertEquals('unrecognized_arbitrary_field' in capturedUpstreamBody!, false);

  // 3f. fallback call drops reasoning_effort for fallbackModel outside the family but keeps response_format
  Deno.env.set('GEMINI_API_KEY_FALLBACK', 'fake-fallback-key');
  let fallbackCapturedBody: Record<string, unknown> | null = null;
  let callCount = 0;
  const mockGeminiFallback: typeof fetch = async (_input, init) => {
    callCount++;
    if (callCount === 1) {
      return new Response(JSON.stringify({ error: { code: 503 } }), { status: 503 });
    }
    fallbackCapturedBody = JSON.parse(String(init?.body ?? '{}'));
    return new Response(JSON.stringify({ choices: [{ message: { content: '{}' } }] }), {
      status: 200,
    });
  };
  const reqFallback = new Request('https://example.com/functions/v1/ai-vision', {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      'content-length': String(bodyA.length),
    },
    body: bodyA,
  });
  await handleAiVision(reqFallback, mockGeminiFallback);
  assertNotEquals(fallbackCapturedBody, null);
  assertEquals(fallbackCapturedBody!['model'], 'gemini-3.5-flash');
  assertEquals(fallbackCapturedBody!['response_format'], { type: 'json_object' });
  assertEquals('reasoning_effort' in fallbackCapturedBody!, false);
  Deno.env.delete('GEMINI_API_KEY_FALLBACK');

  // 4. Missing content-length rejected before reading
  Deno.env.set('ENFORCE_SESSION', 'true');
  const missingClReq = new Request('https://example.com/functions/v1/ai-vision', {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      'x-app-session': validToken,
    },
    body: validBody,
  });
  assertEquals((await handleAiVision(missingClReq, mockGeminiOk)).status, 411);

  // 5. Oversize content-length (> 8_000_000) rejected with 413
  const oversizeClReq = new Request('https://example.com/functions/v1/ai-vision', {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      'content-length': '8000001',
      'x-app-session': validToken,
    },
    body: validBody,
  });
  assertEquals((await handleAiVision(oversizeClReq, mockGeminiOk)).status, 413);

  // 6. Non-allowlisted model rejected with 400
  const badModelBody = JSON.stringify({
    model: 'gpt-4o-expensive',
    messages: [{ role: 'user', content: 'hi' }],
  });
  const badModelReq = new Request('https://example.com/functions/v1/ai-vision', {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      'content-length': String(badModelBody.length),
      'x-app-session': validToken,
    },
    body: badModelBody,
  });
  assertEquals((await handleAiVision(badModelReq, mockGeminiOk)).status, 400);

  // 7. Upstream error sanitised to 502 {"error":"ai unavailable"} (no internal key/url leak)
  const mockGeminiError: typeof fetch = async () =>
    new Response('{"error":{"message":"Secret internal stack trace API_KEY=xyz"}}', {
      status: 500,
    });
  const upstreamFailReq = new Request('https://example.com/functions/v1/ai-vision', {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      'content-length': String(validBody.length),
      'x-app-session': validToken,
    },
    body: validBody,
  });
  const errRes = await handleAiVision(upstreamFailReq, mockGeminiError);
  assertEquals(errRes.status, 502);
  const errJson = await errRes.json();
  assertEquals(errJson, { error: 'ai unavailable' });
  Deno.env.delete('ENFORCE_SESSION');
});

Deno.test('pos-locations: compat mode vs ENFORCE_SESSION=true + role enforcement', async () => {
  Deno.env.set('SUPABASE_URL', 'https://fake.supabase.co');
  Deno.env.set('SUPABASE_SERVICE_ROLE_KEY', 'fake-service-role');

  const spvToken = await signSession({
    uid: 'usr_spv',
    role: 'spv',
    cabang: 'manado',
    name: 'SPV Manado',
  });
  const techToken = await signSession({
    uid: 'usr_tek',
    role: 'technician',
    cabang: 'manado',
    name: 'Teknisi',
  });

  const mockDb: typeof fetch = async (input) => {
    const url = String(input);
    if (url.includes('/rest/v1/app_users')) {
      return new Response(
        JSON.stringify([
          {
            username: 'spv1',
            email: 'spv1@pma.com',
            nama: 'SPV One',
            password: 'secret',
            role: 'spv',
          },
        ]),
        { status: 200 },
      );
    }
    return new Response(JSON.stringify([{ pos_id: 'POS-TEST-01' }]), { status: 200 });
  };

  // Compat mode: legacy body without header works for valid SPV, 401 for bad SPV
  Deno.env.delete('ENFORCE_SESSION');
  const legacyBadBody = JSON.stringify({
    action: 'delete',
    identity: 'spv1',
    password: 'wrong',
    pos_id: 'POS-TEST-01',
  });
  const legacyBadRes = await handlePosLocations(
    new Request('https://example.com/pos-locations', {
      method: 'POST',
      body: legacyBadBody,
    }),
    mockDb,
  );
  assertEquals(legacyBadRes.status, 401);

  const legacyGoodBody = JSON.stringify({
    action: 'delete',
    identity: 'spv1',
    password: 'secret',
    pos_id: 'POS-TEST-01',
  });
  const legacyGoodRes = await handlePosLocations(
    new Request('https://example.com/pos-locations', {
      method: 'POST',
      body: legacyGoodBody,
    }),
    mockDb,
  );
  assertEquals(legacyGoodRes.status, 200);

  // Compat mode: bad x-app-session header ALWAYS returns 401 even if legacy password in body is right
  const badHeaderRes = await handlePosLocations(
    new Request('https://example.com/pos-locations', {
      method: 'POST',
      headers: { 'x-app-session': 'v1.invalid.token' },
      body: legacyGoodBody,
    }),
    mockDb,
  );
  assertEquals(badHeaderRes.status, 401);

  // Technician token gets 403 forbidden
  const techRes = await handlePosLocations(
    new Request('https://example.com/pos-locations', {
      method: 'POST',
      headers: { 'x-app-session': techToken },
      body: JSON.stringify({ action: 'delete', pos_id: 'POS-TEST-01' }),
    }),
    mockDb,
  );
  assertEquals(techRes.status, 403);

  // Enforced mode: missing token rejected with 401, SPV token succeeds with 200
  Deno.env.set('ENFORCE_SESSION', 'true');
  const enforcedNoHeaderRes = await handlePosLocations(
    new Request('https://example.com/pos-locations', {
      method: 'POST',
      body: legacyGoodBody,
    }),
    mockDb,
  );
  assertEquals(enforcedNoHeaderRes.status, 401);

  const spvOkRes = await handlePosLocations(
    new Request('https://example.com/pos-locations', {
      method: 'POST',
      headers: { 'x-app-session': spvToken },
      body: JSON.stringify({ action: 'delete', pos_id: 'POS-TEST-01' }),
    }),
    mockDb,
  );
  assertEquals(spvOkRes.status, 200);
  Deno.env.delete('ENFORCE_SESSION');
});

Deno.test('daily-tasks & auth-login: SPV enforcement, completed delete 409, PBKDF2 upgrade', async () => {
  Deno.env.set('SUPABASE_URL', 'https://fake.supabase.co');
  Deno.env.set('SUPABASE_SERVICE_ROLE_KEY', 'fake-service-role');

  const hash = await createPbkdf2Hash('mypassword123');
  assertEquals(await verifyPbkdf2Hash('mypassword123', hash), true);
  assertEquals(await verifyPbkdf2Hash('wrongpassword', hash), false);

  let upgradedHashWritten = '';
  const loginMockFetch: typeof fetch = async (input, init) => {
    const url = String(input);
    if (init?.method === 'PATCH' && url.includes('/rest/v1/app_users')) {
      const parsed = JSON.parse(String(init.body));
      upgradedHashWritten = parsed.password_hash;
      return new Response('[]', { status: 200 });
    }
    return new Response(
      JSON.stringify([
        {
          id: 'usr_ho_spv',
          username: 'adi',
          nama: 'ADI SUPRIADI',
          email: 'adi@pma.com',
          role: 'spv',
          cabang: 'HO Makassar',
          password: 'spvho',
          password_hash: null,
        },
      ]),
      { status: 200 },
    );
  };

  const loginRes = await handleAuthLogin(
    new Request('https://example.com/auth-login', {
      method: 'POST',
      body: JSON.stringify({ identity: 'adi', password: 'spvho' }),
    }),
    loginMockFetch,
  );
  assertEquals(loginRes.status, 200);
  const loginData = await loginRes.json();
  assertEquals(loginData.user.role, 'spv');
  assertEquals('password' in loginData.user, false);
  assertEquals('password_hash' in loginData.user, false);
  assertEquals(upgradedHashWritten.startsWith('pbkdf2$100000$'), true);

  // Completed task delete returns 409 {error:'completed'} on daily_tasks_ho
  let queriedTableUrl = '';
  const tasksMockFetch: typeof fetch = async (input) => {
    queriedTableUrl = String(input);
    return new Response(JSON.stringify([{ id: 'task_done_1', status: 'completed' }]), {
      status: 200,
    });
  };

  const delCompletedRes = await handleDailyTasks(
    new Request('https://example.com/daily-tasks', {
      method: 'POST',
      headers: { 'x-app-session': loginData.token },
      body: JSON.stringify({ action: 'delete', id: 'task_done_1' }),
    }),
    tasksMockFetch,
  );
  assertEquals(delCompletedRes.status, 409);
  assertEquals(await delCompletedRes.json(), { error: 'completed' });
  assertEquals(queriedTableUrl.includes('/rest/v1/daily_tasks_ho'), true);
});
