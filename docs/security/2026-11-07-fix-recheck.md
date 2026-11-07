# Security Re-Check of 2026-11-07 Fixes (`ef61936` Working Tree Diff)

**Verdict: `RELEASE_OK`** (0 new security issues or regressions introduced in the `2026-11-07` uncommitted diff across `lib/` and `supabase/`).

---

## 1. New Issues Introduced in Diff

| ID | File:Line | Severity | Evidence |
|---|---|---|---|
| *None* | — | — | **0 new issues found** across the 26 modified files (`1581 insertions, 1142 deletions`) relative to `HEAD ef61936`. |

---

## 2. Verification of Fixed Security Items (`2026-11-07`)

| Check Item | Status | File:Line & Verification Evidence |
|---|---|---|
| **`SEC-01` — PostgREST Login Filter Hardening** | **PASS** | `lib/data/repositories/auth_repository.dart:22, 166-198`: `cleanIdentity` is trimmed, lowercased, bounded to `1..64` chars, and validated against `_validIdentityRegex = RegExp(r'^[a-zA-Z0-9 ._@-]+$')` before any HTTP call (rejecting `*`, `%`, `,`, `(`, `)`, `'`, `"`). `orFilters` uses exact `.eq.` clauses only (`username.eq`, `email.eq`, `nama.eq`, plus exact computed email-prefix `userPrefix`). |
| **`SEC-02` — `pos-locations` `import` SPV Guard (Code + Live Smoke)** | **PASS** | `supabase/functions/pos-locations/index.ts:273-279`: `action === 'import'` now invokes `await verifySpv(supabaseUrl, serviceRoleKey, identity, password)` before payload validation or database writes.<br>**Live Read-Only Smoke Probe**:<br>`curl -s -X POST "https://sxsjixnnlzhjinzcyhjb.supabase.co/functions/v1/pos-locations" -H "Content-Type: application/json" -d '{"action":"import","locations":[]}'`<br>Returned **`HTTP 401 {"error":"unauthorized"}`** (previously returned `HTTP 400`). |
| **`KNOWN-02` — Offline Credentials Storage (`bss_offline_credentials_v1`)** | **PASS** | `lib/data/repositories/auth_repository.dart:16, 40-160, 241-257`:<br>1. All 59 hardcoded offline accounts and passwords (`spvbali`, `spvho`, `teknisi123`) deleted from `lib/`.<br>2. `_saveOfflineCredential` (`lines 59-89`) is skipped on Web (`if (_isWeb) return;`), generates a 16-byte `Random.secure()` salt (Base64), computes 10,000x iterated `sha256` (`_hashPassword`, `lines 40-46`), and stores `{user, salt, hash}` under `bss_offline_credentials_v1` with **zero plaintext passwords** in `SharedPreferences`.<br>3. `_tryOfflineLogin` (`lines 91-160`) triggers only on network/server failure (never when the server returns `HTTP 200` with a password mismatch at `lines 249-256`), blocks Web (`line 95`), and verifies hashes with constant-time XOR (`_constantTimeEquals`, `lines 48-57`). |
| **`KNOWN-06` — Embedded Gemini API Key Removed from `lib/`** | **PASS** | `lib/data/models/ai_vision_config.dart:115-118`: `defaultApiKey` is now `String.fromEnvironment('BSS_AI_API_KEY', defaultValue: '')`. `lib/data/services/storage_service.dart:307-313, 325-327` purges any cached 53-char `AQ.*` key back to `''`. Literal scan across `lib/` for `AQ.Ab8`, `AIza`, and `sk-` returned 0 hits. |
| **`SEC-06` — Attendance GPS Block (Android `isMocked` & Web Permission Denial)** | **PASS** | 1. **No POS coordinate substitution**: `lib/data/services/location_service.dart:1595-1608` returns `lat: 0.0, lng: 0.0, isGpsEnabled: false, isFallback: true, isDefaultFallback: true` when GPS fails or is denied.<br>2. **Android mock location (`isMocked`)**: Both cold-start `getLastKnownPosition()` (`camera_capture_screen.dart:799`) and `getCurrentLocation()` (`location_service.dart:1577`) set `isMockLocation: position.isMocked`. In attendance mode (`_isAbsensiMode`), `_isAbsensiMockLocation` (`camera_capture_screen.dart:514-515`) sets `_isAbsensiShutterBlocked = true`, disabling the shutter button (`lines 3186-3198`) and hard-returning inside `_takePictureAndVerify` (`lines 1306-1314, 1340-1346`) without offering `_confirmMockLocationProceed()`.<br>3. **Web permission denial**: Denying browser geolocation causes `ensureLocationPermission()` (`location_service.dart:1460-1467`) to return `false`, producing the `0.0, 0.0` fallback where `_isAbsensiNoGpsFix` (`camera_capture_screen.dart:517-524`) is `true` and blocks capture. |
| **`SEC-10` — No Auto-Save to Public Gallery** | **PASS** | `lib/features/camera/screens/camera_capture_screen.dart:1679-1681`: Removed `ShareHelper.saveToGallery(capturedPath)` from `commitRecord()`. Watermarked photos remain in app-private directories pruned after 7 days by `PhotoCleanupService.cleanOldPhotos(maxDays: 7)` (`lib/data/services/photo_cleanup_service.dart:7-30`). |
| **AI Vision Changes — No Photo or Key Logging** | **PASS** | `lib/data/services/ai_vision_service.dart:691, 761, 770, 808, 818`: `debugPrint` statements log only model names, HTTP status codes, and truncated upstream error text (`<= 300` chars). Neither `imageBase64` nor `effectiveApiKey` is logged. |
| **Google Sheets Payload — No Extra PII Leaked** | **PASS** | `lib/data/services/google_sheets_service.dart:142-196`: Offline queue fallback reuses the existing maintenance `payload` map (submission ID, branch, POS name, technician name, checklist counts/notes, timestamp, and clock-tamper warning tag) without adding any extra PII, credentials, or tokens. |

---

## 3. Still-Open Audit Items (`needs architecture decision`)

The following items from `docs/security/2026-11-07-security-audit.md` remain open by design pending backend architecture migration (Supabase Auth / RLS lockdown):

- **`SEC-03` (`ai-vision` Edge Function open proxy — `needs architecture decision`)**: `supabase/functions/ai-vision/index.ts:50-118` is deployed with `--no-verify-jwt` and forwards caller JSON bodies to Gemini (`GEMINI_API_KEY`) so web/mobile clients without a local API key can run AI photo verification. Locking it down requires an authenticated session token or server-enforced prompt schema.
- **`SEC-04` & `SEC-05` (Client-side session trust & SPV vs. technician REST authorization — `needs architecture decision`)**: `AuthRepository` stores session state in `SharedPreferences` (`bss_current_user`) and `DailyTaskService` authenticates PostgREST calls (`createTask`, `transferTask`, `deleteTask`) with the public `anonKey` (`lib/data/services/daily_task_service.dart:165-177`). Enforcing SPV role server-side on task mutations requires migrating to Supabase Auth JWTs or routing task mutations through a verified Edge Function / RPC.
- **`KNOWN-01`, `KNOWN-03`, `KNOWN-04`, `KNOWN-05` (Supabase RLS `anon` policies on `app_users`, `daily_tasks_*`, `maintenance_logs_manado`, and `task-proofs` — `needs architecture decision`)**: Direct PostgREST table access is still used by the client app with `anonKey`; enabling restrictive RLS policies (`supabase/migrations/2026-10-22_security_rls_lockdown.sql`) requires switching login to a `SECURITY DEFINER` RPC (`verify_login`) and issuing authenticated JWTs first so existing clients do not break.
