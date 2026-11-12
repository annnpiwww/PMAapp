# QA Deployment & Verification Report: Lapor Error Admin PWA

**Date:** 2026-11-11  
**Task ID:** `t20261111-221153-0065`  
**Deploy Target:** Vercel Production (`build/web`)  
**Production URL:** https://bssparking-pma.vercel.app  
**Deployment Inspect:** https://vercel.com/hermessd/bssparking-pma/9Bk7Xn2gNYrNiP8tMZqksSCbSpah  
**Deployment Deployment ID:** `bssparking-lmjxss64v-hermessd.vercel.app`  

---

## 1. Build & Artifact Verification

Per Mandor directive (`CORRECTION t20261111-221153-0065`), test suite and flutter web build were pre-completed and verified before deployment.

### Pre-Deploy Build Integrity Checks
- `build/web/lapor/index.html`: PRESENT (11.1 KB)
- `build/web/lapor/kelola/index.html`: PRESENT (12.2 KB)
- `build/web/lapor/sw.js`: PRESENT (2.3 KB)
- `build/web/lapor/manifest.webmanifest`: PRESENT (790 B)
- `build/web/version.json`: PRESENT (version 2.0.137, build 2150)

---

## 2. Live HTTP Endpoint & Header Verification (curl)

All requests executed against production alias `https://bssparking-pma.vercel.app` with `--max-time 20`.

| Endpoint | HTTP Status | Headers / Payload Evidence | Result |
|---|---|---|---|
| `/lapor/` | **200 OK** | HTML loaded successfully | PASS |
| `/lapor/kelola/` | **200 OK** | HTML loaded successfully | PASS |
| `/lapor/sw.js` | **200 OK** | `service-worker-allowed: /lapor/`<br>`cache-control: no-cache, no-store, must-revalidate` | PASS |
| `/lapor/manifest.webmanifest` | **200 OK** | Valid JSON: `start_url: "/lapor/"`, `scope: "/lapor/"` | PASS |
| `/lapor/kelola/kelola.js` | **200 OK** | `cache-control: no-cache, no-store, must-revalidate` | PASS |
| `/version.json` | **200 OK** | `{"app_name":"bssparking_timemark","version":"2.0.137","build_number":"2150","package_name":"bssparking_timemark"}` | PASS |
| `/` (Flutter Web Root) | **200 OK** | Flutter canvaskit app rendered successfully | PASS |

---

## 3. Live Browser Inspection & Verification

Tested in live browser session on `https://bssparking-pma.vercel.app`:

1. **Console Health:**
   - Command: `orca-bridge browser errors`
   - Result: `No console errors/warnings recorded.`
2. **Service Worker Registration:**
   - Registration query: `navigator.serviceWorker.getRegistrations()`
   - Registered scope: `https://bssparking-pma.vercel.app/lapor/`
3. **Data Integrity:**
   - Strictly read-only navigation. No test data, test accounts, or error tickets were created in production.
4. **Visual Screenshots:**
   - `docs/screenshots/lapor-live/lapor-login.png` (Lapor Error Admin Login)
   - `docs/screenshots/lapor-live/kelola-login.png` (SPV Kelola Akun Login)
   - `docs/screenshots/lapor-live/root-login.png` (PMApp Flutter Web Root Login)

---

## 4. Notifications Delivery

All 3 visual evidence screenshots delivered to Telegram via `anpidhs-notify`:
- `docs/screenshots/lapor-live/lapor-login.png` -> OK
- `docs/screenshots/lapor-live/kelola-login.png` -> OK
- `docs/screenshots/lapor-live/root-login.png` -> OK

---

## 5. Verification Verdict

**DEPLOY: PASS & LIVE**  
Both `/lapor/` and `/lapor/kelola/` are fully accessible live on Vercel prod without disturbing Flutter web root `/`.
