// FCM HTTP v1 helper with RS256 Service Account OAuth2 token exchange
// and token caching for Deno runtime.

export interface ServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
}

export interface FcmPayload {
  token: string;
  data: Record<string, string>;
  priority?: 'HIGH' | 'NORMAL';
  ttlSeconds?: number;
}

export interface FcmSendResult {
  token: string;
  success: boolean;
  unregistered: boolean;
  error?: string;
}

let cachedAccessToken: string | null = null;
let tokenExpiryTimestamp = 0;

function base64urlEncode(bytes: Uint8Array): string {
  let bin = '';
  for (let i = 0; i < bytes.length; i++) {
    bin += String.fromCharCode(bytes[i]);
  }
  return btoa(bin).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function pemToDer(pem: string): Uint8Array {
  const b64 = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/-----BEGIN RSA PRIVATE KEY-----/, '')
    .replace(/-----END RSA PRIVATE KEY-----/, '')
    .replace(/\s+/g, '');
  const bin = atob(b64);
  const bytes = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) {
    bytes[i] = bin.charCodeAt(i);
  }
  return bytes;
}

export function parseServiceAccount(): ServiceAccount {
  const raw = Deno.env.get('FCM_SERVICE_ACCOUNT');
  if (!raw) {
    throw new Error('FCM_SERVICE_ACCOUNT env is missing');
  }
  try {
    const parsed = JSON.parse(raw);
    if (!parsed.project_id || !parsed.client_email || !parsed.private_key) {
      throw new Error('FCM_SERVICE_ACCOUNT missing required fields (project_id, client_email, private_key)');
    }
    return parsed as ServiceAccount;
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err);
    throw new Error(`Failed to parse FCM_SERVICE_ACCOUNT: ${msg}`);
  }
}

export async function getAccessToken(
  sa: ServiceAccount,
  fetchImpl: typeof fetch = fetch,
): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedAccessToken && tokenExpiryTimestamp > now + 60) {
    return cachedAccessToken;
  }

  const header = { alg: 'RS256', typ: 'JWT' };
  const payload = {
    iss: sa.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    exp: now + 3600,
    iat: now,
  };

  const enc = new TextEncoder();
  const headerB64 = base64urlEncode(enc.encode(JSON.stringify(header)));
  const payloadB64 = base64urlEncode(enc.encode(JSON.stringify(payload)));
  const unsignedToken = `${headerB64}.${payloadB64}`;

  const der = pemToDer(sa.private_key);
  const cryptoKey = await crypto.subtle.importKey(
    'pkcs8',
    der as BufferSource,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );

  const sigBuffer = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    cryptoKey,
    enc.encode(unsignedToken),
  );
  const sigB64 = base64urlEncode(new Uint8Array(sigBuffer));
  const jwt = `${unsignedToken}.${sigB64}`;

  const res = await fetchImpl('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  });

  if (!res.ok) {
    const errText = await res.text();
    throw new Error(`Google OAuth2 token exchange failed: HTTP ${res.status} ${errText}`);
  }

  const data = await res.json();
  cachedAccessToken = data.access_token as string;
  tokenExpiryTimestamp = now + (data.expires_in as number ?? 3600);
  return cachedAccessToken;
}

export async function sendFcmMessage(
  sa: ServiceAccount,
  accessToken: string,
  payload: FcmPayload,
  fetchImpl: typeof fetch = fetch,
): Promise<FcmSendResult> {
  const url = `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`;
  const body = {
    message: {
      token: payload.token,
      data: payload.data,
      android: {
        priority: payload.priority ?? 'HIGH',
        ttl: `${payload.ttlSeconds ?? 3600}s`,
      },
    },
  };

  try {
    const res = await fetchImpl(url, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(body),
    });

    if (res.ok) {
      return { token: payload.token, success: true, unregistered: false };
    }

    const errJson = await res.json().catch(() => ({}));
    const errorCode = errJson?.error?.details?.[0]?.errorCode || errJson?.error?.status || '';
    const errorMsg = errJson?.error?.message || `HTTP ${res.status}`;

    const isUnregistered =
      errorCode === 'UNREGISTERED' ||
      errorCode === 'INVALID_ARGUMENT' ||
      res.status === 404 ||
      errorMsg.includes('Requested entity was not found') ||
      errorMsg.includes('registration token is not valid');

    return {
      token: payload.token,
      success: false,
      unregistered: isUnregistered,
      error: errorMsg,
    };
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err);
    return {
      token: payload.token,
      success: false,
      unregistered: false,
      error: msg,
    };
  }
}
