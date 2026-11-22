// Cloudflare R2 SigV4 presigning and minimal object helpers for app-releases.

const R2_REGION = 'auto';
const R2_SERVICE = 's3';
const INTERNAL_GET_EXPIRES_SECONDS = 300;
const INTERNAL_DELETE_EXPIRES_SECONDS = 60;

const encoder = new TextEncoder();

export type R2Config = {
  accountId: string;
  accessKeyId: string;
  secretAccessKey: string;
  bucket: string;
};

export function readR2Config(
  get: (key: string) => string | undefined = (key) => Deno.env.get(key),
): R2Config | null {
  const accountId = (get('R2_ACCOUNT_ID') ?? '').trim();
  const accessKeyId = (get('R2_ACCESS_KEY_ID') ?? '').trim();
  const secretAccessKey = (get('R2_SECRET_ACCESS_KEY') ?? '').trim();
  const bucket = (get('R2_BUCKET') ?? '').trim();
  if (!accountId || !accessKeyId || !secretAccessKey || !bucket) {
    return null;
  }
  return { accountId, accessKeyId, secretAccessKey, bucket };
}

function toHex(bytes: Uint8Array): string {
  let out = '';
  for (let i = 0; i < bytes.length; i++) {
    out += bytes[i].toString(16).padStart(2, '0');
  }
  return out;
}

async function sha256Hex(input: string): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-256', encoder.encode(input));
  return toHex(new Uint8Array(digest));
}

async function hmacSha256(
  keyBytes: Uint8Array,
  message: string,
): Promise<Uint8Array> {
  const rawKey = keyBytes.buffer.slice(
    keyBytes.byteOffset,
    keyBytes.byteOffset + keyBytes.byteLength,
  ) as ArrayBuffer;
  const key = await crypto.subtle.importKey(
    'raw',
    rawKey,
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const sig = await crypto.subtle.sign('HMAC', key, encoder.encode(message));
  return new Uint8Array(sig);
}

function rfc3986Encode(value: string): string {
  return encodeURIComponent(value).replace(
    /[!'()*]/g,
    (ch) => `%${ch.charCodeAt(0).toString(16).toUpperCase()}`,
  );
}

function formatAmzDate(date: Date): { amzDate: string; dateStamp: string } {
  const iso = date.toISOString().replace(/[:-]|\.\d{3}/g, '');
  return { amzDate: iso, dateStamp: iso.slice(0, 8) };
}

export async function presignR2Url(params: {
  method: 'GET' | 'PUT' | 'DELETE';
  config: R2Config;
  key: string;
  expiresSeconds: number;
  now?: Date;
}): Promise<string> {
  const { method, config, key, expiresSeconds } = params;
  const host = `${config.accountId}.r2.cloudflarestorage.com`;
  const { amzDate, dateStamp } = formatAmzDate(params.now ?? new Date());
  const credentialScope = `${dateStamp}/${R2_REGION}/${R2_SERVICE}/aws4_request`;
  const canonicalUri =
    '/' + [config.bucket, ...key.split('/')].map(rfc3986Encode).join('/');

  const queryEntries: [string, string][] = [
    ['X-Amz-Algorithm', 'AWS4-HMAC-SHA256'],
    ['X-Amz-Credential', `${config.accessKeyId}/${credentialScope}`],
    ['X-Amz-Date', amzDate],
    ['X-Amz-Expires', String(expiresSeconds)],
    ['X-Amz-SignedHeaders', 'host'],
  ];
  queryEntries.sort((a, b) => (a[0] < b[0] ? -1 : a[0] > b[0] ? 1 : 0));
  const canonicalQuery = queryEntries
    .map(([k, v]) => `${rfc3986Encode(k)}=${rfc3986Encode(v)}`)
    .join('&');

  const canonicalRequest = [
    method,
    canonicalUri,
    canonicalQuery,
    `host:${host}\n`,
    'host',
    'UNSIGNED-PAYLOAD',
  ].join('\n');

  const stringToSign = [
    'AWS4-HMAC-SHA256',
    amzDate,
    credentialScope,
    await sha256Hex(canonicalRequest),
  ].join('\n');

  const kDate = await hmacSha256(
    encoder.encode(`AWS4${config.secretAccessKey}`),
    dateStamp,
  );
  const kRegion = await hmacSha256(kDate, R2_REGION);
  const kService = await hmacSha256(kRegion, R2_SERVICE);
  const kSigning = await hmacSha256(kService, 'aws4_request');
  const signature = toHex(await hmacSha256(kSigning, stringToSign));

  return `https://${host}${canonicalUri}?${canonicalQuery}&X-Amz-Signature=${signature}`;
}

export async function r2GetBytes(
  config: R2Config,
  key: string,
): Promise<Uint8Array | null> {
  const url = await presignR2Url({
    method: 'GET',
    config,
    key,
    expiresSeconds: INTERNAL_GET_EXPIRES_SECONDS,
  });
  const resp = await fetch(url, { method: 'GET' });
  if (resp.status === 404) {
    await resp.body?.cancel();
    return null;
  }
  if (!resp.ok) {
    await resp.body?.cancel();
    throw new Error(`R2 GET failed with status ${resp.status}`);
  }
  return new Uint8Array(await resp.arrayBuffer());
}

export async function r2Delete(
  config: R2Config,
  key: string,
): Promise<void> {
  const url = await presignR2Url({
    method: 'DELETE',
    config,
    key,
    expiresSeconds: INTERNAL_DELETE_EXPIRES_SECONDS,
  });
  const resp = await fetch(url, { method: 'DELETE' });
  await resp.body?.cancel();
  if (resp.ok || resp.status === 404) {
    return;
  }
  throw new Error(`R2 DELETE failed with status ${resp.status}`);
}
