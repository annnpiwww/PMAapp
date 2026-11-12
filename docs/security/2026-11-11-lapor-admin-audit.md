# Security Audit: Lapor Error Admin Feature

**Date:** 2026-11-11  
**Auditor:** Tukang Security (`sec`)  
**Scope:** Backend Edge Functions, Flutter AuthRepository, Database Migration, Web PWA (`web/lapor/`), and Vercel Config  
**Contract Reference:** `docs/contracts/admin-lapor.md`  

---

## 1. Findings Table

| ID | Severity | File:Line | Evidence Snippet | Exploit Scenario | Exact Fix |
|---|---|---|---|---|---|
| `SEC-LAPOR-01` | HIGH | `web/lapor/lapor-core.js:720`, `web/lapor/kelola/kelola.js:392,398,542` | `export function generatePassword(rng = Math.random)` and `inputNewPassword.value = generatePassword();` | Predictable password generation: `Math.random` PRNG internal state can be recovered by an attacker from previously generated passwords to predict new account credentials. | In `generatePassword()`, use `crypto.getRandomValues(new Uint8Array(10))` to select indices from `PASSWORD_CHARS`, eliminating `Math.random` default. |
| `SEC-LAPOR-02` | MEDIUM | `vercel.json:54` | `"source": "/lapor/(index.html\|sw.js\|app.js\|lapor-core.js\|config.js\|manifest.webmanifest)"` | Files under `/lapor/kelola/` (`index.html`, `kelola.js`) are omitted from the no-cache header pattern, risking stale caching of SPV management scripts. | Expand source pattern in `vercel.json` to include `/lapor/kelola/(index.html\|kelola.js)` or use regex `/lapor/(.*)`. |
| `SEC-LAPOR-03` | MEDIUM | `vercel.json:4-25` | Missing `Content-Security-Policy` header in global headers | While application code safely uses `textContent`, missing CSP leaves no defense-in-depth against third-party script injection or unauthorized data exfiltration. | Add `Content-Security-Policy` header restricted to `'self'` and `https://*.supabase.co`. |

---

## 2. Verification & Pass List

| Target Check | Status | Evidence (File:Line) |
|---|---|---|
| **admin-accounts: isSpv enforced before action** | PASS | `supabase/functions/admin-accounts/index.ts:74-76` (`if (!isSpv(session)) return json({ error: 'forbidden' }, 403);`) |
| **admin-accounts: Branch & role scoping (anti-IDOR)** | PASS | `supabase/functions/admin-accounts/index.ts:117,133-136,293,310,352,372` (all select/patch queries enforce `cabang=spvCabang` and `role=admin_pos`; foreign IDs return 404) |
| **admin-accounts: Create cannot override role or branch** | PASS | `supabase/functions/admin-accounts/index.ts:243-244` (hardcoded `role: 'admin_pos'`, `cabang: spvCabang`) |
| **admin-accounts: Password hashed via PBKDF2, plaintext never stored** | PASS | `supabase/functions/admin-accounts/index.ts:237,248,320,331` (`createPbkdf2Hash` used; plaintext `password` column is never written and cleared on reset) |
| **admin-accounts: Passwords/hashes never returned or logged** | PASS | `supabase/functions/admin-accounts/index.ts:117,137-144` (`select` excludes password columns; no sensitive logging) |
| **admin-accounts: Input validation (nama, pos_name, pos_kode, password)** | PASS | `supabase/functions/admin-accounts/index.ts:159-183,188,202-209` (regex checks, branch POS location lookup, `password != username`) |
| **auth-login: Deactivated admin_pos anti-enumeration** | PASS | `supabase/functions/auth-login/index.ts:269-272` (returns identical 401 `invalid credentials` with failure delay) |
| **auth-login: Role normalization escalation protection** | PASS | `supabase/functions/auth-login/index.ts:116-130` (strict parsing; `admin_pos` only returns `'admin_pos'`, never escalates to `'spv'`) |
| **_shared/session.ts: Strong HMAC signature & role integrity** | PASS | `supabase/functions/_shared/session.ts:75,103,112-114,128` (HMAC-SHA256 signature verified; role extracted strictly from verified payload) |
| **daily-tasks: admin_report role gating** | PASS | `supabase/functions/daily-tasks/index.ts:106-112` (strictly requires `session.role === 'admin_pos'`; non-admin blocked) |
| **daily-tasks: pos_name & nama from app_users by session.uid** | PASS | `supabase/functions/daily-tasks/index.ts:125-152` (read from DB by `session.uid`, request body cannot override) |
| **daily-tasks: Account aktif re-checked** | PASS | `supabase/functions/daily-tasks/index.ts:140-142` (returns 403 if `userRow.aktif === false`) |
| **daily-tasks: Input validation & header injection prevention** | PASS | `supabase/functions/_shared/admin_report.ts:26-36,74-120` (newlines and control characters replaced with spaces, preventing header injection into `ErrorReport.parse`) |
| **daily-tasks: 409 duplicate & 500 error sanitization** | PASS | `supabase/functions/daily-tasks/index.ts:199-201,203-205` (sanitized 409 and 500 responses; no internal DB errors leaked) |
| **daily-tasks: admin_pos isolated from other actions** | PASS | `supabase/functions/daily-tasks/index.ts:106-108` (`session.role === 'admin_pos' && action !== 'admin_report'` returns 403) |
| **403 Guard in other Edge Functions** | PASS | `supabase/functions/ai-vision/index.ts:146`, `pos-locations/index.ts:243,304`, `push-register/index.ts:50`, `sheets-sync/index.ts:75` (all reject `admin_pos` with 403 before side effects; SPV can still access `pos-locations`) |
| **Flutter AuthRepository: admin_pos rejected before session save** | PASS | `lib/data/repositories/auth_repository.dart:259-263` (`admin_pos` rejected before saving session or branch) |
| **web/lapor: XSS sink prevention (textContent only)** | PASS | `web/lapor/app.js:87-88,312-313`, `web/lapor/kelola/kelola.js:172,195,199,322-323` (all dynamic data inserted via `textContent`) |
| **web/lapor: tg://msg URI encoding** | PASS | `web/lapor/lapor-core.js:300` (`encodeURIComponent(message)`) |
| **web/lapor: LocalStorage session TTL & logout cleanup** | PASS | `web/lapor/lapor-core.js:336-339,761-764`, `web/lapor/app.js:210,329`, `web/lapor/kelola/kelola.js:127,238` (checked on load, dropped when expired, wiped on 401/logout) |
| **web/lapor: config.js public anon key only** | PASS | `web/lapor/config.js:4-6` (contains public anon key only, no service role key) |
| **web/lapor: Service Worker network boundary** | PASS | `web/lapor/sw.js:53-56` (requests to `*.supabase.co` are network-only; never cached) |
| **vercel.json: Security headers & caching** | PASS | `vercel.json:12-15,54-61` (`X-Frame-Options: SAMEORIGIN` present; `no-cache` on `/lapor/` assets) |

---

## 3. Verdict

DEPLOY: GO (SEC-LAPOR-01 dan SEC-LAPOR-02 sudah diperbaiki Mandor: `generatePassword` pakai `crypto.getRandomValues`, `vercel.json` no-cache `/lapor/(.*)`). SEC-LAPOR-03 (CSP) ditunda: CSP global berisiko mematahkan Flutter web root.
