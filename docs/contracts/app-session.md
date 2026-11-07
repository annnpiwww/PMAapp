# Contract: App Session Token (2026-11-07)

Owner: coder (`supabase/functions/_shared/session.ts`, `supabase/functions/auth-login/`).
Consumers: `ai-vision`, `pos-locations`, `daily-tasks`, `sheets-sync` edge functions; Flutter client.

## Token
- Format: `v1.<base64url(payload JSON)>.<base64url(HMAC-SHA256(secret, "v1." + payloadB64))>`
- Secret: Supabase secret `APP_SESSION_SECRET` (32+ random bytes, set with `supabase secrets set`, never in repo or client).
- Payload: `{"uid": string, "role": "spv"|"technician", "cabang": string, "name": string, "iat": int, "exp": int}`; `exp = iat + 30 days`.
- Issued only by `auth-login` after server-side password check against `public.app_users` (service role).

## Shared module `supabase/functions/_shared/session.ts`
```ts
export type Session = { uid: string; role: 'spv' | 'technician'; cabang: string; name: string; exp: number };
export async function signSession(s: Omit<Session, 'exp'>): Promise<string>;
// Reads header `x-app-session`. Returns null when missing, malformed, bad signature, or expired.
export async function verifySession(req: Request): Promise<Session | null>;
export function isSpv(s: Session): boolean; // role === 'spv'
```
- Constant-time signature compare (`crypto.subtle.verify` with HMAC key).
- Failure response from every consumer: HTTP 401 `{"error":"unauthorized"}`; wrong role: 403 `{"error":"forbidden"}`. Never echo internals.

## Client
- Header name: `x-app-session: <token>` on every edge-function call (plus the existing `apikey`/`Authorization: Bearer <anonKey>`).
- Token stored by `AuthRepository` only (prefs key `bss_session_token_v1`); exposed as `AuthRepository.instance.sessionToken` (String?).
- 401 from any function: client clears the session and routes to login with message `Sesi habis, silakan login ulang.`
