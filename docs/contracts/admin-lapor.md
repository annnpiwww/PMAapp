# Contract: Lapor Error (admin pos PWA)

Owner: Mandor. Builds on `docs/contracts/error-ticket.md` (ticket = daily task row `kategori='error'`; alarm, FCM push trigger, map radar, sheet `Error`, SPV modes already live in 2.0.137).

## Decisions (Aan, 2026-11-11)
- Admin pos reports errors in a web page `https://bssparking-pma.vercel.app/lapor/`, installable as its own PWA ("Lapor Error"). No new APK, no Flutter route.
- One account per PERSON (Aan v2, 2026-11-11): a pos may have several admins on shifts (e.g. 3 at one pos), others have one. `app_users.role = 'admin_pos'`, `app_users.pos_name` fixed per account, `nama` = the person (e.g. `Irma`). Lokasi is never typed by the admin. Pelapor in the ticket = account `nama`.
- Accounts are managed on the web by the SPV of the same branch at `/lapor/kelola/` (no app update, no seed script). Username = `<nama slug>-<kode lokasi>`, e.g. `irma-mgnw`; password chosen by SPV (min 8 chars, not equal to username) or generated.
- Ticket goes to "Semua teknisi" mode: open list, first technician to claim wins (same representation `createErrorTicketForMode` uses for that mode).
- Optional damage photo: shared to Telegram only, NOT uploaded/stored.
- Technician paste flow (AdHocTaskDialog error mode) stays as fallback.
- KC Manado only for now (code is branch-agnostic via `session.cabang`; SPV manages only own-branch accounts).
- Order on "Kirim & bagikan": save ticket on server first (alarm + FCM fire on insert), then open the share sheet with the server-built message. The app cannot know whether the Telegram message was actually sent; a cancelled share still leaves the ticket open (the admin page says so after success).
- Copy (Aan 2026-11-11 20:55): every user-visible "pos" says "lokasi" (Admin lokasi, Pilih lokasi, Kode lokasi). Code identifiers and API fields (`admin_pos`, `pos_name`, `pos_kode`) unchanged.

## Data
- Migration `docs/sql/2026-11-11-admin-pos.sql`: `alter table public.app_users add column if not exists pos_name text; add column if not exists pos_kode text; add column if not exists aktif boolean not null default true;` (only admin_pos rows use them). No other schema change.
- `pos_name` MUST equal the map marker `posName` of that pos (same string the radar matches, trim + lowercase compare). `pos_kode` = short location code (`mgnw`): taken from the pos-locations source if it has a code field, else typed by the SPV once per account (lowercase `[a-z0-9]{2,10}`).
- No seed script, no credentials file: passwords exist only in the SPV's hands (shown once after create/reset).
- `auth-login`: `admin_pos` row with `aktif = false` => same 401 as wrong password.

## API: `POST functions/v1/admin-accounts` (new function, SPV only)
Headers like other functions (`apikey`, `x-app-session`). `isSpv(session)` required, else 403; every query scoped to `cabang = session.cabang` and `role = 'admin_pos'` (an id from another branch or role => 404).
- `{"action":"list"}` -> 200 `{"accounts":[{"id","username","nama","pos_name","pos_kode","aktif"}]}` sorted by pos_name, nama.
- `{"action":"create","nama","pos_name","pos_kode","password"}` -> server builds username `slug(nama)-pos_kode` (slug: lowercase, spaces to nothing, `[a-z0-9]` only, max 20), stores PBKDF2 `password_hash` (reuse `createPbkdf2Hash`), never the plaintext `password` column. 201 `{"id","username"}`; 409 `{"error":"duplicate"}` when username exists; 400 `{"error":"invalid","field":...}` (nama 2..40 letters/spaces, pos_name must exist in the branch pos list, password 8..64 and != username).
- `{"action":"reset_password","id","password"}` -> 200. Same password rules.
- `{"action":"set_aktif","id","aktif":bool}` -> 200. Deactivated accounts cannot log in; existing admin sessions of that account are rejected by `daily-tasks admin_report` (check `aktif` when loading the account row there).
- No delete (keeps Pelapor history readable). Passwords never returned, never logged.

## Auth
- `auth-login`: `normalizeRole` returns `'admin_pos'` for raw role `admin_pos`; response `user` adds `pos_name` (string, '' when null). Session payload unchanged except `role`.
- Session TTL for `admin_pos`: 30 days (pos device stays logged in). Other roles unchanged.
- Flutter `AuthRepository` online login: role `admin_pos` => refuse login, no session saved, message `Akun ini khusus halaman Lapor Error.`.
- Every edge function except `daily-tasks` action `admin_report` and `auth-login` rejects an `admin_pos` session with 403 (`ai-vision`, `pos-locations`, `sheets-sync`, `push-register`, `daily-tasks` other actions).

## API: `POST functions/v1/daily-tasks` action `admin_report`
Headers as today (`apikey`, `x-app-session`). Only `role === 'admin_pos'`; any other role => 403.
Request:
```json
{"action":"admin_report","report":{"tanggal":"11-11-2026","waktu":"10.00","kendala":"...","penyebab":"...","solusi_sementara":"...","durasi_error":"...","ada_foto":true}}
```
- `tanggal` `dd-MM-yyyy`, `waktu` `HH.mm` (both required, Asia/Makassar; page pre-fills now). `kendala` required 1..300. `penyebab`, `solusi_sementara`, `durasi_error` optional 0..300 (empty => `-`). `ada_foto` bool. Strip control chars; reject `\r` only lines. Unknown keys ignored.
- Server reads `pos_name` + `nama` from `app_users` by `session.uid` (never from the request). Missing `pos_name` => 403.
- Server builds:
  - `message` (admin Telegram format, exact):
    ```
    <Salam>, izin melaporkan, telah terjadi kendala dengan kronologi sebagai berikut:

    Tanggal : <tanggal>
    Waktu : <waktu>

    Lokasi : <pos_name>

    Kendala : <kendala>

    Penyebab : <penyebab>

    Solusi sementara : <solusi_sementara>

    Durasi Error : <durasi_error>

    Berikut kami lampirkan dokumentasi kerusakan.   <- only when ada_foto

    Terima kasih.
    ```
    `<Salam>` from `waktu`: `Selamat pagi` < 11:00, `Selamat siang` < 15:00, `Selamat sore` < 18:00, else `Selamat malam`.
  - Row: `kategori='error'`, `status='pending'`, `tanggal` = report date `yyyy-MM-dd`, `pos_name` = account pos, `pos_tag` as the Flutter error-ticket create sets it, `judul` = kendala (max 120), `deskripsi` = byte-identical port of Dart `ErrorReport.toDeskripsi(message, pelapor: <app_users.nama>)` (`lib/data/models/error_report.dart`) so `ErrorReport.parse` on any device reads it back, open-list fields (`teknisi_nama`, `peserta`, `serah_terima`) exactly as `createErrorTicketForMode` "Semua teknisi" writes them.
  - Sheet `Error` stage `open`: fire-and-forget server-side, same payload as the Flutter create hook, only when the table is `daily_tasks_manado`. Never fails the request.
- Response 201: `{"id":"...","message":"..."}`. Errors: 400 `{"error":"invalid","field":"kendala"}`, 401, 403, 409 `{"error":"duplicate"}` (same kendala same day), 500 `{"error":"server error"}` (no internals).
- FCM `error-push` trigger fires on the insert as for app-created tickets (verify in smoke).
- 2026-11-12 (Aan): admin deskripsi has NO `Pelapor :` line (diverges from Dart `toDeskripsi`). error-push falls back to `teknisi_nama` (= admin) for creator exclusion. `admin_list` status reads last `serah_terima` line: empty `ke` = menunggu (teknisi_nama is still the pelapor then).

## API: `POST functions/v1/daily-tasks` action `admin_list`
Headers as `admin_report` (`apikey`, `x-app-session`). Only `role === 'admin_pos'`; any other role => 403.
Request: `{"action":"admin_list"}`. No parameters.
- Server reads `pos_name` from `app_users` by `session.uid` (same lookup as `admin_report`). Missing/inactive => 403.
- Query `daily_tasks_<cabang>` where `kategori='error'` AND `pos_name = user.pos_name`, order by `created_at DESC`, limit 20.
- Response 200: `{"reports":[{"id","tanggal","kendala","status","teknisi","diambil","selesai","waktu_lapor"}]}` where:
  - `kendala` = `judul` (max 120)
  - `status` = `"selesai"` when row `status='done'` or `'completed'`, `"ditangani"` when `teknisi_nama` is non-empty and claimed, else `"menunggu"`
  - `teknisi` = `teknisi_nama` or `null`
  - `diambil` = waktu field (4th '|' part) of the LAST `serah_terima` line whose `ke` is non-empty, or `null` when open
  - `selesai` = `jam_selesai` string or `null`
  - `waktu_lapor` = `created_at` ISO string
- No pagination (error reports are rare; 20 cap is enough).
- Gate: line 106 in daily-tasks/index.ts must also allow `admin_list` (currently only allows `admin_report`).
- UI Tabs: screen L2 is split into 2 tabs 'Laporan' (the existing form) and 'Riwayat' (report history) via segmented control in Tiket style. The sticky submit bar shows ONLY on tab 'Laporan'.

## Web page `web/lapor/` (copied to `build/web/lapor/` by `flutter build web`)
Files (owner in brackets):
- `lapor-core.js` [coder2]: ES module, no DOM. `export function nowParts(date)` -> `{tanggal:'dd-MM-yyyy', waktu:'HH.mm'}` in Asia/Makassar; `export function validate(form)` -> `{ok, field, message}` (Indonesian messages); `export async function login(identity, password, fetchImpl)` -> `{token, user}` (rejects non-`admin_pos` with message `Akun ini bukan akun admin pos.`); `export async function sendReport(token, form, fetchImpl)` -> `{id, message}` mapping HTTP errors to Indonesian messages; `export async function shareReport(message, file, nav)` -> `'shared'|'copied'|'cancelled'` (Web Share Level 2 with file when `nav.canShare({files})`, text-only share otherwise, fallback copy to clipboard + open `tg://msg?text=<encoded>`); session storage helpers `saveSession/loadSession/clearSession` (localStorage key `lapor_session_v1`, drop when expired).
- `config.js` [coder2]: Supabase URL + anon key (same public values the Flutter web build uses).
- `manifest.webmanifest` [coder2]: `name` "Lapor Error PMApp", `short_name` "Lapor Error", `start_url` and `scope` `/lapor/`, `display` standalone, icons `/icons/Icon-192.png`, `/icons/Icon-512.png` (+ maskable variants already in `web/icons/`).
- `sw.js` [coder2]: scope `/lapor/`, cache-first app shell (`/lapor/`, css, js, manifest, icons), network-only for `*.supabase.co`, versioned cache name, old caches deleted on activate.
- `index.html`, `lapor.css`, `app.js` [ui, after Aan approves mockup]: DOM + wiring to `lapor-core.js`. All asset URLs absolute (`/lapor/...`): `cleanUrls` serves `/lapor` without trailing slash.
- `vercel.json` [coder2]: no-cache header for `/lapor/(index.html|sw.js|app.js|lapor-core.js|config.js)`; static files win over the SPA rewrite (verify on preview deploy).
- Tests: `test/web_lapor/*.test.mjs` (`node --test`), never inside `web/` (would ship).

## Kelola akun page `web/lapor/kelola/` (Aan v2)
- `lapor-core.js` [coder2] adds: `loginSpv(identity, password, fetchImpl)` (accepts only role `spv`, else `Akun ini bukan akun SPV.`), `listAccounts(token, fetchImpl)`, `createAccount(token, {nama,pos_name,pos_kode,password}, fetchImpl)`, `resetPassword(token, id, password, fetchImpl)`, `setAktif(token, id, aktif, fetchImpl)`, `fetchPosList(token, fetchImpl)` (branch pos names (+ code if the source has one) via the existing `pos-locations` function, read its index.ts for the list action), `usernamePreview(nama, kode)` (same slug rule as server), `generatePassword(rng)` (10 chars, no look-alikes 0/O/1/l/I). SPV session stored under a separate key `lapor_spv_session_v1`.
- `index.html`, `kelola.js`, styles reuse `/lapor/lapor.css` [ui, after mockup approval].
