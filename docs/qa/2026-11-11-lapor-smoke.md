# QA Smoke Test: Lapor Error Admin PWA (Production)

- **Date / Time**: 2026-11-11 22:45 WITA / 14:45 UTC
- **Target URL**: `https://bssparking-pma.vercel.app/lapor/` and `/lapor/kelola/`
- **Supabase Project**: `sxsjixnnlzhjinzcyhjb` (PmaManado)
- **Tester / Execution**: Tukang Coder via automated Playwright headless runner (Viewport 390x844) & Supabase Management API
- **Overall Status**: **PASS (All steps verified & cleaned)**

---

## 1. Test Admin Account Setup

- **Action**: Created branch-scoped `admin_pos` account in KC Manado via Supabase Management API database/query.
- **Account Details**:
  - `user_id`: `usr_26e45c180e7e`
  - `username`: `smoketes-pkm`
  - `nama`: `Smoke Tes`
  - `role`: `admin_pos`
  - `cabang`: `manado`
  - `pos_name`: `Pelabuhan Kalimas Manado`
  - `pos_kode`: `pkm`
  - `aktif`: `true`
  - `password_hash`: PBKDF2 with SHA-256, 100,000 iterations (byte-compatible with `createPbkdf2Hash`)
  - Plaintext password / hash was kept exclusively in volatile execution memory and never printed/logged.
- **Verdict**: **PASS**

---

## 2. Live Web UI Smoke Test (Playwright Mobile Viewport 390x844)

- **Screen L1 (Login)**:
  - Navigated to `https://bssparking-pma.vercel.app/lapor/`.
  - Filled username `smoketes-pkm` and test password.
  - Captured screenshot: `docs/screenshots/lapor-smoke/01-login.png`.
  - Clicked `#btn-login` -> transitioned to Screen L2.
  - Verdict: **PASS**

- **Screen L2 (Form Report)**:
  - Read-only location displayed: `Pelabuhan Kalimas Manado` (exact match with `app_users.pos_name`).
  - Pre-filled fields: Tanggal `11-11-2026`, Waktu `22.45` (WITA Asia/Makassar).
  - Filled report fields:
    - Kendala: `SMOKE TES abaikan`
    - Penyebab: `Pengujian smoke otomatis prod`
    - Solusi sementara: `Abaikan tiket ini`
    - Durasi error: `5 menit`
  - Captured screenshot: `docs/screenshots/lapor-smoke/02-form-filled.png`.
  - Intercepted Web Share Level 2 (`navigator.share`) to avoid headless abort.
  - Clicked `#btn-send` -> API call returned HTTP 201 (`{"id":"task_1794408339491_2689","message":"..."}`).
  - Verdict: **PASS**

- **Screen L3 (Success / Terkirim)**:
  - Transitioned to Screen L3.
  - Meta header: Lokasi `Pelabuhan Kalimas Manado`.
  - Subtitle: `22.45 · Teknisi manado sudah dapat alarm.`.
  - Formatted Telegram report displayed in `#l3-message` (length: 306 characters).
  - Captured screenshot: `docs/screenshots/lapor-smoke/03-success.png`.
  - Verdict: **PASS**

---

## 3. Server-side & Database Verification

- **Task Row in `daily_tasks_manado`**:
  - `id`: `task_1794408339491_2689`
  - `tanggal`: `2026-11-11`
  - `kategori`: `error`
  - `status`: `pending`
  - `pos_name`: `Pelabuhan Kalimas Manado`
  - `judul`: `SMOKE TES abaikan`
  - `teknisi_nama`: `Smoke Tes`
  - `peserta`: `""`
  - `deskripsi`: Formatted deskripsi confirmed containing `Pelapor: Smoke Tes`.
  - Verdict: **PASS**

- **Push Trigger (`error-push` via `pg_net`)**:
  - Queried `net._http_response`:
    - Latest row id: `21`
    - `status_code`: `200`
    - `created`: `2026-11-11 14:45:39.702362+00`
  - Verdict: **PASS**

---

## 4. Negative Security & Boundary Checks

| Check | Scenario | Expected | Actual | Verdict |
|---|---|---|---|---|
| 4a | Wrong password login attempt (`auth-login`) | `401 Unauthorized` | `401` | **PASS** |
| 4b | `admin_pos` session calling `daily-tasks` other action (`list`) | `403 Forbidden` | `403` | **PASS** |
| 4c | `admin_pos` session calling `ai-vision` | `403 Forbidden` | `403` | **PASS** |
| 4d | Deactivated account (`aktif = false`) submitting `admin_report` | `403 Forbidden` | `403` | **PASS** |
| 4e | Deactivated account (`aktif = false`) login attempt | `401 Unauthorized` | `401` | **PASS** |

---

## 5. Mandatory Cleanup

- **Deleted Task Rows**:
  - `delete from public.daily_tasks_manado where judul = 'SMOKE TES abaikan' or id = 'task_1794402323130_4037';`
- **Deleted User Rows**:
  - `delete from public.app_users where username = 'smoketes-pkm';`
- **Verification Queries**:
  - `select count(*) from public.daily_tasks_manado where judul = 'SMOKE TES abaikan' or id = 'task_1794402323130_4037';` -> **0**
  - `select count(*) from public.app_users where username = 'smoketes-pkm';` -> **0**
- **Verdict**: **PASS (Clean state restored)**

---

## 6. Action Items for Aan (Sheet `Error` Cleanup)

Since Google Apps Script `Error` sheet rows cannot be deleted through the Supabase REST/Management API, Aan must manually delete the following task rows from the Google Sheet `Error`:
1. `task_1794408339491_2689` (Created at ~22:45 WITA)
2. `task_1794408058631_2595` (Created at ~22:40 WITA during initial run)
3. `task_1794402323130_4037` (Older leftover task referenced in specification, if present in Sheet)

---

## 7. Telegram Notifications

Sent via `rtk anpidhs-notify`:
- `01-login.png` -> OK: Foto berhasil dikirim ke Telegram anpidhs.
- `02-form-filled.png` -> OK: Foto berhasil dikirim ke Telegram anpidhs.
- `03-success.png` -> OK: Foto berhasil dikirim ke Telegram anpidhs.
