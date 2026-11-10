# Security Audit Report: Tiket Error v2/v3 & FCM Push (Pre-Release 2.0.137)

- **Date**: 2026-11-11
- **Task ID**: `t20261111-004750-6ec6`
- **Auditor**: Tukang Security (`sec`)
- **Baseline Commit**: `c68923d` (plus uncommitted working tree changes for Tiket Error v2/v3 & FCM Push)
- **Verdict**: **RELEASE_OK** (0 Critical / 0 High / 1 Medium-Low TOCTOU hardening note / 2 Low defense-in-depth notes)

---

## 1. Executive Summary & Release Gate Verdict

All critical security invariants across **Tiket Error v2/v3** and **FCM Push Notifications** were audited against the 7-Point OWASP Mandatory Guards and project contracts (`docs/contracts/error-ticket.md`, `docs/contracts/app-session.md`):

- **Branch & Ownership Isolation (`daily-tasks`, `push-register`, `error-push`)**: Verified. All mutations derive `cabang`, `name`, and `role` strictly from the HMAC-SHA256 verified `x-app-session` token (`supabase/functions/_shared/session.ts`). Cross-branch IDOR and spoofing another user's name/branch are blocked.
- **Database RLS & Trigger Safety (`2026-11-11_device_push_tokens.sql`)**: Verified. `public.device_push_tokens` has Row Level Security enabled with zero `anon`/`authenticated` policies (default-deny). `trigger_error_push_notify()` returns `trigger` (cannot be invoked via PostgREST RPC, confirmed `404 PGRST202` live) and only fires `AFTER INSERT` when `NEW.kategori = 'error' AND NEW.status = 'pending'`.
- **Credential Hygiene (`google-services.json`, Git History, Working Tree, `Curabeauty/public`)**: Verified clean. No Firebase service account private keys (`private_key` / `firebase-adminsdk`) exist in the working tree, untracked files, git history of `BssparkingTimeMark`, or `/home/annnpii/Product development annpii/Curabeauty/public/`.
- **PostgREST Filter Injection (`DailyTaskService.getTasksForTeknisi`)**: Verified safe. `_assignedOrGroup` strips PostgREST structural delimiters (`[,()*.:%\\]`) before building `ilike` clauses.

**Gate Verdict**: **RELEASE_OK** for `2.0.137`. Non-blocking hardening recommendations are documented below.

---

## 2. Scope & Component Audit Matrix

| Component | File(s) | Security Controls Verified | Status |
|---|---|---|---|
| **Edge Function: `daily-tasks` (`claim`)** | `supabase/functions/daily-tasks/index.ts:98-103, 303-391` | `verifySession(req)` mandatory (`401` if missing/invalid). Table resolved strictly from `resolveTasksTableForCabang(session.cabang)` (no cross-branch IDOR). `TASK_ID_REGEX` (`^[A-Za-z0-9_-]{1,80}$`) enforced. Verifies row is not completed and last `serah_terima` line has empty `ke` (`parts[1].trim().length === 0`, open handover). Sets `teknisi_nama = session.name.trim()`, ignoring client payload fields. | **PASS** (see `SEC-20261111-01` for concurrent race hardening) |
| **Edge Function: `push-register`** | `supabase/functions/push-register/index.ts:46-145` | `verifySession(req)` mandatory (`401`). Payload capped at 16 KB. `token` validated (`20..4096` chars, `400` on malformed length). `POST` upserts `user_name: session.name`, `cabang: session.cabang`, `role: session.role` exclusively from verified session. `DELETE` filters by both `token=eq.<token>` AND `user_name=eq.<session.name>`, preventing cross-user token deletion. | **PASS** |
| **Edge Function: `error-push` & `_shared/fcm.ts`** | `supabase/functions/error-push/index.ts:38-255`, `supabase/functions/_shared/fcm.ts:1-185` | Authenticates `x-error-push-secret` against `ERROR_PUSH_SHARED_SECRET` via byte-level constant-time `timingSafeEqual` (`index.ts:38-50, 82-87`); fails closed if secret is empty/missing. Never echoes tokens or secrets in responses or logs. Filters target tokens by `resolveTasksTableForCabang(t.cabang) === tableName` and excludes creator (`extractCreator`). Uses RS256 OAuth2 JWT exchange with 60s expiry buffer and cleans up `UNREGISTERED` tokens. | **PASS** (see `SEC-20261111-02` for minor 500 error body detail) |
| **DB Migration & Trigger SQL** | `supabase/migrations/2026-11-11_device_push_tokens.sql:1-88` | `ALTER TABLE public.device_push_tokens ENABLE ROW LEVEL SECURITY;` with grant only to `service_role` (no `anon`/`authenticated` policies). Shared secret provisioned in `vault.secrets`. `trigger_error_push_notify()` reads `vault.decrypted_secrets` as `SECURITY DEFINER` and triggers only `AFTER INSERT` when `NEW.kategori = 'error' AND NEW.status = 'pending'`. | **PASS** (see `SEC-20261111-03` for rate-limit note) |
| **Client Services & PostgREST Filter** | `lib/data/services/push_service.dart`, `lib/data/services/error_alarm_service.dart`, `lib/data/services/daily_task_service.dart:280-355` | `PushService` authenticates with `x-app-session`, unregisters on logout via `ErrorAlarmService.tick()`, and handles background isolate messages safely without intent/URL execution. `_assignedOrGroup` strips `[,()*.:%\\]` before assembling `teknisi_nama.ilike.*$n*,peserta.ilike.*$n*`, preventing PostgREST operator injection. | **PASS** (see `SEC-20261111-04` for edge-case symbol-only name) |
| **Firebase Config & Secret Hygiene** | `android/app/google-services.json`, Repo History, `Curabeauty/public/` | `google-services.json` contains only public Android client configuration (`pmapp-8e840`). Zero `private_key` or `firebase-adminsdk` credentials in working tree, untracked files, git history, or `Curabeauty/public/`. | **PASS** |

---

## 3. Detailed Findings & Hardening Recommendations

### [LOW / MEDIUM] `SEC-20261111-01` — TOCTOU Window in `daily-tasks` `claim` Action (`PATCH` Missing Open-State CAS Filter)
- **Risk Level**: LOW (race condition under simultaneous click within ~50–100 ms by two technicians in the same branch; no cross-branch IDOR or privilege escalation).
- **Evidence**: `supabase/functions/daily-tasks/index.ts:309-374`
  - Lines `309-348` perform a `GET` query and verify that the ticket is in the open handover list (`isOpen === true`) and not completed.
  - Line `359` executes the update with:
    ```ts
    const patchUrl = `${supabaseUrl}/rest/v1/${table}?id=eq.${encodeURIComponent(id)}&status=eq.pending`;
    ```
  - Because claiming a ticket keeps `status = 'pending'` (only updating `teknisi_nama`, `peserta`, and `serah_terima`), if Technician A and Technician B both pass the `GET` check concurrently before either `PATCH` commits, both `PATCH` requests match `id=eq.<id>&status=eq.pending` and succeed (`200 OK`), with Technician B overwriting Technician A's claim.
- **Fix Recommendation**: Add `&serah_terima=eq.${encodeURIComponent(serahTerima)}` (or `&teknisi_nama=eq.${encodeURIComponent(taskRow.teknisi_nama ?? '')}`) to `patchUrl` at `supabase/functions/daily-tasks/index.ts:359` so PostgreSQL enforces an atomic compare-and-swap on the row's pre-claim handover state and returns an empty array (`409 already claimed`) to the second concurrent request.

---

### [LOW] `SEC-20261111-02` — Upstream PostgREST Error Body Included in Authenticated `error-push` 500 Response
- **Risk Level**: LOW (only reachable by callers possessing the valid `ERROR_PUSH_SHARED_SECRET`, i.e., internal `pg_net` trigger).
- **Evidence**: `supabase/functions/error-push/index.ts:144-148`
  ```ts
  if (!tokenRes.ok) {
    const errBody = await tokenRes.text().catch(() => '');
    console.error(`error-push: failed to fetch tokens: HTTP ${tokenRes.status} ${errBody}`);
    return json({ error: 'failed to fetch tokens', status: tokenRes.status, detail: errBody }, 500);
  }
  ```
- **Fix Recommendation**: Keep `errBody` in `console.error` for server logs and omit `detail: errBody` from the JSON response body (`return json({ error: 'failed to fetch tokens' }, 500);`) per OWASP Guard #2 (Zero Trust Output).

---

### [LOW] `SEC-20261111-03` — Trigger & Error Ticket Creation Rate Limiting / Deduplication
- **Risk Level**: LOW (requires a valid authenticated session or pre-cutover direct DB write access).
- **Evidence**: `supabase/migrations/2026-11-11_device_push_tokens.sql:69-88` and `supabase/functions/daily-tasks/index.ts:105-197`
  - `trigger_error_push_notify()` cannot be called via PostgREST RPC (`404 PGRST202`) and only runs on `AFTER INSERT WHEN (NEW.kategori = 'error' AND NEW.status = 'pending')`.
  - Once `2026-11-07_cutover_lockdown.sql` is active in production (`REVOKE INSERT, DELETE, TRUNCATE ON TABLE public.daily_tasks_* FROM anon, authenticated`), unauthenticated/anon clients cannot insert rows directly to trigger FCM pushes.
  - However, an authenticated user calling `daily-tasks` (`action: 'create'`, `kategori: 'error'`) in a rapid script could trigger repeated FCM alarms to branch devices.
- **Fix Recommendation**: Ensure `2026-11-07_cutover_lockdown.sql` (`REVOKE INSERT ... FROM anon, authenticated`) is applied alongside `2026-11-11_device_push_tokens.sql`, and optionally add a short cooldown/rate-limit check in `daily-tasks` or `error-push` (e.g., skip or throttle if the same creator dispatches >5 pending `error` tickets within 60 seconds).

---

### [INFO] `SEC-20261111-04` — `_assignedOrGroup` Edge Case on Symbol-Only Technician Name
- **Risk Level**: INFORMATIONAL (not exploitable; self-mitigates via offline cache fallback).
- **Evidence**: `lib/data/services/daily_task_service.dart:280-291, 308`
  - `_assignedOrGroup` strips `[,()*.:%\\]`. If `teknisiNama` contains only stripped symbols (e.g., `"..."`), `_assignedOrGroup` returns `""`, producing `or(and(kategori.eq.error,status.eq.pending),)` with a trailing comma (HTTP 400 from PostgREST, falling back to local cache).
- **Fix Recommendation**: Include `"` in the strip regex (`RegExp(r'[,()*.:%\\"]')`) and in `getTasksForTeknisi` (`line 308`), omit the trailing `,${assignedGroup}` when `_assignedOrGroup(teknisiNama)` is empty.

---

## 4. Verification & Evidence Log

### 4.1 Secret & Git History Audit
- **Working tree & untracked files (`BssparkingTimeMark`)**:
  - Command: `grep -rn -l -E "BEGIN (RSA )?PRIVATE KEY|firebase-adminsdk|\"private_key\"\s*:" .`
  - Result: Only `supabase/functions/_shared/fcm.ts` (PEM parser & interface definition) and `supabase/functions/error-push/index_test.ts` (ephemeral `crypto.subtle.generateKey` test keypair). Zero real keys.
- **Git commit history (`BssparkingTimeMark`)**:
  - Command: `git --no-pager log --all --full-history -S "firebase-adminsdk" --oneline` -> `0` matches.
  - Command: `git --no-pager log --all --full-history -S "BEGIN PRIVATE KEY" --oneline` -> `0` matches.
  - Command: `git --no-pager log --all --full-history -S "private_key" --oneline` -> `0` matches.
- **External directory check (`/home/annnpii/Product development annpii/Curabeauty/public/`)**:
  - Command: `grep -rn -l -E "private_key|firebase-adminsdk" "/home/annnpii/Product development annpii/Curabeauty/public/"`
  - Result: Clean (`css`, `icons`, `img`, `index.html`, `js`, `manifest.json`, `sw.js` only).

### 4.2 Live Read-Only Endpoint & RLS Probes
1. **`POST /functions/v1/error-push` without `x-error-push-secret`**:
   - Response: `HTTP 401` — `{"error":"unauthorized"}`
2. **`POST /functions/v1/error-push` with invalid `x-error-push-secret`**:
   - Response: `HTTP 401` — `{"error":"unauthorized"}`
3. **`POST /functions/v1/push-register` without `x-app-session`**:
   - Response: `HTTP 401` — `{"error":"unauthorized"}`
4. **`GET /rest/v1/device_push_tokens?select=token&limit=1` with `anon` key**:
   - Response: `HTTP 200` — `[]` (RLS default-deny confirmed; 0 rows exposed to `anon`).
5. **`POST /rest/v1/rpc/trigger_error_push_notify` with `anon` key**:
   - Response: `HTTP 404` — `{"code":"PGRST202","message":"Could not find the function public.trigger_error_push_notify without parameters in the schema cache"}`

### 4.3 Automated Test Suite & Static Analysis
- **Deno Edge Function Tests** (`DENO_TESTING=1 deno test --allow-env supabase/functions/push-register/index_test.ts supabase/functions/error-push/index_test.ts supabase/functions/daily-tasks/index_test.ts`):
  - `8 passed / 0 failed` (includes `push-register` rejecting missing session with `401` and malformed short token `{"token":"short"}` with `400`, `daily-tasks` `claim` returning `200` on open ticket and `409` when already claimed, `error-push` rejecting invalid secret with `401` and skipping creator/other-branch tokens).
- **Flutter Static Analysis** (`flutter analyze lib/data/services/push_service.dart lib/data/services/error_alarm_service.dart lib/data/services/daily_task_service.dart lib/data/services/error_ticket_service.dart`):
  - `No issues found!`
- **Flutter Unit Tests** (`flutter test test/daily_task_teknisi_scope_test.dart test/error_report_test.dart test/error_ticket_service_test.dart test/push_service_test.dart test/error_alarm_service_test.dart`):
  - `46 passed / 0 failed`
