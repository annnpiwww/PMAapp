// Shared App Session HMAC-SHA256 module
// Contract: docs/contracts/app-session.md

export type Session = {
  uid: string;
  role: 'spv' | 'technician' | 'admin_pos';
  cabang: string;
  name: string;
  iat?: number;
  exp: number;
};

const SESSION_TTL_SECONDS = 30 * 24 * 60 * 60; // 30 days
const B64URL_REGEX = /^[A-Za-z0-9_-]+$/;

function base64urlEncode(bytes: Uint8Array): string {
  let bin = '';
  for (let i = 0; i < bytes.length; i++) {
    bin += String.fromCharCode(bytes[i]);
  }
  return btoa(bin).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function base64urlDecode(input: string): Uint8Array | null {
  if (!input || !B64URL_REGEX.test(input)) return null;
  const rem = input.length % 4;
  if (rem === 1) return null;
  const padded = rem === 0 ? input : input + '='.repeat(4 - rem);
  const b64 = padded.replace(/-/g, '+').replace(/_/g, '/');
  try {
    const bin = atob(b64);
    const out = new Uint8Array(bin.length);
    for (let i = 0; i < bin.length; i++) {
      out[i] = bin.charCodeAt(i);
    }
    return out;
  } catch {
    return null;
  }
}

async function importHmacKey(secret: string, usage: KeyUsage[]): Promise<CryptoKey> {
  return crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    usage,
  );
}

export async function signSession(
  s: Omit<Session, 'exp' | 'iat'> & { iat?: number; exp?: number },
): Promise<string> {
  const secret = Deno.env.get('APP_SESSION_SECRET');
  if (!secret || secret.length < 16) {
    throw new Error('APP_SESSION_SECRET is missing or too short');
  }

  const iat = typeof s.iat === 'number' ? Math.floor(s.iat) : Math.floor(Date.now() / 1000);
  const exp = typeof s.exp === 'number' ? Math.floor(s.exp) : iat + SESSION_TTL_SECONDS;

  const payload = {
    uid: s.uid,
    role: s.role,
    cabang: s.cabang,
    name: s.name,
    iat,
    exp,
  };

  const payloadB64 = base64urlEncode(new TextEncoder().encode(JSON.stringify(payload)));
  const signingInput = new TextEncoder().encode(`v1.${payloadB64}`);
  const key = await importHmacKey(secret, ['sign']);
  const sigBuf = await crypto.subtle.sign('HMAC', key, signingInput);
  const sigB64 = base64urlEncode(new Uint8Array(sigBuf));

  return `v1.${payloadB64}.${sigB64}`;
}

// Reads header `x-app-session`. Returns null when missing, malformed, bad signature, or expired.
export async function verifySession(req: Request): Promise<Session | null> {
  const rawHeader = req.headers.get('x-app-session');
  if (!rawHeader) return null;

  const token = rawHeader.trim();
  const parts = token.split('.');
  if (parts.length !== 3 || parts[0] !== 'v1') return null;

  const payloadB64 = parts[1];
  const sigB64 = parts[2];
  if (!payloadB64 || !sigB64) return null;

  const sigBytes = base64urlDecode(sigB64);
  if (!sigBytes || sigBytes.length !== 32) return null;

  const secret = Deno.env.get('APP_SESSION_SECRET');
  if (!secret || secret.length < 16) return null;

  try {
    const key = await importHmacKey(secret, ['verify']);
    const signingInput = new TextEncoder().encode(`v1.${payloadB64}`);
    const validSig = await crypto.subtle.verify('HMAC', key, sigBytes as BufferSource, signingInput);
    if (!validSig) return null;

    const payloadBytes = base64urlDecode(payloadB64);
    if (!payloadBytes) return null;

    const parsed = JSON.parse(new TextDecoder().decode(payloadBytes));
    if (!parsed || typeof parsed !== 'object') return null;

    const { uid, role, cabang, name, iat, exp } = parsed as Record<string, unknown>;
    if (typeof uid !== 'string' || uid.length === 0) return null;
    if (role !== 'spv' && role !== 'technician' && role !== 'admin_pos') return null;
    if (typeof cabang !== 'string') return null;
    if (typeof name !== 'string') return null;
    if (typeof exp !== 'number' || !Number.isFinite(exp)) return null;

    const now = Math.floor(Date.now() / 1000);
    if (exp <= now) return null;

    const session: Session = { uid, role, cabang, name, exp };
    if (typeof iat === 'number' && Number.isFinite(iat)) {
      session.iat = iat;
    }
    return session;
  } catch {
    return null;
  }
}

export function isSpv(s: Session): boolean {
  return s.role === 'spv';
}
