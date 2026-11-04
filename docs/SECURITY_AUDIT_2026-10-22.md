# Audit Keamanan — BssparkingTimeMark (v2.0.103+2100)

Tanggal: 2026-10-22 · Scope: repo `BssparkingTimeMark` (Flutter mobile + web PWA), backend Supabase, integrasi AI/Telegram/Sheets.
Metode: bukti lokal + probe read-only ke backend sendiri (tidak ada data yang diubah/diubah isinya).

Ringkasan: **3 temuan P0, 4 P1, 5 P2, 4 P3.** Semua P0 ada di sisi backend (RLS Supabase longgar) + kredensial yang tertanam di client.

---

## 0. Skor per dimensi

| Dimensi | Status | Catatan |
|---|---|---|
| Pentest | ❌ 3 P0 | Privilege escalation & kredensial bocor via client + RLS |
| Vulntest | ⚠️ 2 P1 | Key AI terpasang di client, bucket storage publik |
| Leaktest | ❌ 1 P0 | `app_users` (password plaintext) terbaca publik |
| Porttest | ✅ bersih | Hanya 443, TLS 1.2+, cleartext dimatikan |
| Phistest | ❌ 1 P0 | QA bypass bisa dinyalakan siapa saja ( spoof nama) |
| Stresstest | ✅ bersih | 2.000 poin < 1 dtk, 50k karakter aman, cache rusak aman |
| Smoketest | ✅ lulus | analyze 0 issue, 413+ test hijau, web & APK build sukses |

---

## 1. P0 — `app_users` bisa dibaca publik, password plaintext (leaktest)

**Bukti** (probe read-only, anon key dari APK):

```
GET /rest/v1/app_users?select=*&limit=1   -> 200
[{"id":"usr_farhan","username":"farhan","email":"farhan@bssparking.id",
  "nama":"Farhan Lakoro","password":"flakoro05","role":"spv", ...}]
```

**Dampak**: siapa pun (tanpa login, tanpa app) bisa mengambil username + password **plaintext** semua teknisi & SPV di 3 cabang. Akun SPV = akses penuh ke semua tugas & data antar cabang.

**Perbaikan (sudah disiapkan, harus dijalankan di Supabase)**:
`supabase/migrations/2026-10-22_security_rls_lockdown.sql` blok A:
hapus kolom `password`, `REVOKE ALL ON public.app_users FROM anon, authenticated`, drop policy lama, lalu verifikasi login lewat Edge Function server-side (password di-hash, minimal bcrypt/argon2).

---

## 2. P0 — Anon key bisa UPDATE + DELETE data (pentest)

**Bukti**:

```
PATCH  /rest/v1/app_users?id=eq.__probe_no_match__  -> 200 []   (RLS izinkan update)
DELETE /rest/v1/app_users?id=eq.__probe_no_match__  -> 204       (RLAS izinkan delete)
GET    /rest/v1/daily_tasks_bali                    -> 200       (baca semua cabang)
```

Filter di atas tidak menunjuk baris nyata, jadi tidak ada data yang berubah saat probe.

**Dampak**: fitur "hapus tugas SPV" yang baru kita tambahkan **tidak role-protected di lapisan data**. Siapa pun yang punya APK bisa `DELETE /rest/v1/daily_tasks_bali?id=eq.<id>` — hapus tugas, bukti, dan jejak audit. Logika app (UI) bukan security boundary.

**Perbaikan**:
1. Blok B di SQL: `REVOKE DELETE ON public.daily_tasks* FROM anon` → hapus tugas hanya lewat Edge Function yang mengecek role SPV.
2. Audio Meanwhile: `DailyTaskService.deleteTask` sudah menolak tugas *completed* (server-side + UI), jadi jalur yang paling merusak (menghapus bukti jadi completed) sudah tertutup.

---

## 3. P0 — Bucket `task-proofs` bisa di-list & diunduh tanpa auth (vulntest)

**Bukti**:

```
POST /storage/v1/object/list/task-proofs  -> 200  (daftar file: proof_task_..._.jpg)
GET  /storage/v1/object/task-proofs/<file>  -> 200  (150 KB JPEG, TANPA header auth)
```

**Dampak**: semua foto bukti (wajah + seragam + GPS device) bisa diunduh siapa pun. Metadata EXIF memuat model HP dan timestamp.

**Perbaikan**: blok C di SQL → `UPDATE storage.buckets SET public = false WHERE id='task-proofs'` + hapus policy storage publik. App lalu memakai **signed URL** (Edge Function `sign-url`) agar teknisi tetap bisa melihat bukti miliknya.

---

## 4. P0 — Kredensial SPV & teknisi tertanam di client (pentest + phistest)

**Bukti** — `lib/data/repositories/auth_repository.dart`:

- 4 alias akun SPV + password plaintext (`flakoro05`) dan 3 varian alias password yang **lolos terhadap password asli di database** (baris 63-72 & 253-258).
- 30+ akun teknisi lokal (`teknisi123`) sebagai fallback offline.

**Dampak**: extract dari APK/web (strings) → login sebagai SPV. Karena tabel `app_users` juga terbuka (P0 #1), daftar akun + password bisa diambil tanpa membongkar APK sama sekali.

**Perbaikan (arah)**: auth pindah ke server. Edge Function `auth-login` (bcrypt/argon2 verify) mengembalikan token sesi; RLS memakai token itu. Fallback offline dipertahankan **tanpa** daftar akun di dalam binary (mis. seed dari storage terenkripsi atau cache token perangkat).

---

## 5. P0 — QA bypass bisa dinyalakan siapa saja (phistest)

**Bukti (lama)**: `camera_capture_screen._isSpvFarhan()` dulu mengembalikan `true` bila `StorageService.getLastTechnicianName()` mengandung "farhan". Nama teknisi = input bebas ("Nama Teknisi / Support" di setup maintenance) → siapa pun bisa menulis "Farhan" lalu 5-ketuk untuk menyalakan **ROOT QA BYPASS**: AI absensi auto-ijau + durasi shift bebas pulang.

**Perbaikan (sudah dikerjakan di commit ini)**: `_isSpvFarhan()` kini wajib `currentUser.role == supervisor` **dan** nama/email mengandung "farhan". Tidak bisa diaktifkan tanpa login SPV sungguhan.

Sisa: jalur fallback akun lokal (P0 #4) masih memberi role supervisor → harus beres sebelum rilis publik.

---

## 6. P1 — API key Gemini terpasang di APK & web (leaktest)

**Bukti**: `lib/data/models/ai_vision_config.dart` menyisipkan key secara terpecah (`'AQ.Ab8RN6' 'JWug2Q5a' ...`) — cara lolos grep biasa, tapi tetap ada di source, di git history (6 kemunculan), dan di setiap build.

**Dampak**: siapa pun bisa ambil key → memakai kuota AI dan tagihannya ke BSS. Selain itu key ini milik BSS (bukan akun pribadi), jadi risiko tagihan.

**Perbaikan (sudah disiapkan, AI TIDAK mati)**: `supabase/functions/ai-vision/index.ts` — Edge Function yang menyimpan `GEMINI_API_KEY` sebagai secret server dan meneruskan request apa adanya (format OpenAI-compatible tidak berubah).

- Client (`ai_vision_service.dart`) sekarang memanggil proxy dulu; **kalau proxy belum di-deploy (404/501) otomatis fallback ke panggilan langsung** → validasi AI tetap jalan tanpa jeda.
- Deploy: `supabase secrets set GEMINI_API_KEY=...` lalu `supabase functions deploy ai-vision`.
- Setelah proxy aktif: hapus konstanta key dari source + rotasi key lama di AI Studio (key lama harus dianggap bocor karena sudah ikut tersebar).

---

## 7. P1 — Admin mode SOP tanpa PIN (vulntest / regression dari permintaan hapus PIN)

Permintaan "hapus technician_pin_dialog.dart" sudah dikerjakan. Efek samping: `TemplateListScreen` (yang saat ini tidak terreach dari UI mana pun — hanya dipakai test) kini bisa buka Mode Admin tanpa PIN. Dampak rendah karena screen itu tidak terjangkau, tapi **jika nanti screen ini disambungkan kembali**, sofort pasang guard role.

---

## 8. P2 — Temuan lain

| # | Temuan | Bukti | Saran |
|---|---|---|---|
| P2-1 | Log `debugPrint` memuat nama teknisi/lokasi | `daily_task_service.dart:255,317`, `auth_repository.dart:109` | Jangan log PII di release; cukupkode status |
| P2-2 | Tidak ada header CSP & Permissions-Policy di web | `curl -I https://bssparking-pma.vercel.app` | Tambah CSP `default-src 'self'` + `Permissions-Policy` di `vercel.json` |
| P2-3 | Prompt AI menerima foto raw (PII ke pihak ketiga) | request body berisi `image_url` base64 | Informasikan ke management (DPAs) + opsi blur/watermark default |
| P2-4 | Alias password SPV tetap diterima **di database** | `auth_repository.dart:63-72` | Hapus jalur ini begitu auth pindah server-side |
| P2-5 | `StorageService` masih menyimpan `custom_supabase_anon_key` dari UI | `storage_service.dart` | Kunci key ke server |

## 9. P3 — Minor / housekeeping

| # | Temuan | Saran |
|---|---|---|
| P3-1 | `_keySpvQaBypassMode` masih ada di storage (meski toggle-nya sudah dikunci) | Bersihkan saat auth server-side siap |
| P3-2 | Tidak ada rate limit di sisi app untuk upload foto | X-App-Token + kuota per akun di Edge Function |
| P3-3 | Tidak ada lockout login di sisi server (klaim 5×/60s masih lokal) | Rate limit di Edge Function auth |
| P3-4 | `vercel.json` belum menyertakan `Cross-Origin-Opener-Policy` | Tambahkan di iterasi web berikutnya |

---

## 10. Porttest

- Host yang dipakai app: `sxsjixnnlzhjinzcyhjb.supabase.co`, `generativelanguage.googleapis.com`, `api.telegram.org`, `api.whatsapp.com`, `t.me`, `bssparking-pma.vercel.app` — semuanya 443/TLS1.2+ (ECDHE-AES).
- `usesCleartextTraffic="false"` + `network_security_config` (cleartext ditolak, CA sistem saja) ✓
- Tidak ada listener dev yang bind ke `0.0.0.0` di mesin build ✓
- Tidak ada WebView / intent custom scheme / `innerHTML` (tidak ada sink XSS) ✓
- `FileProvider` tidak exported ✓, `allowBackup=false` ✓

## 11. Stresstest (regresi permanen: `test/security_stress_audit_test.dart`)

| Skenario | Hasil |
|---|---|
| Laporan 2.000 poin | < 1 dtk, tidak quadratic ✓ |
| Judul tugas 50.000 karakter + catatan 20.000 | aman, < 3 dtk ✓ |
| Teks bebas 5.000 baris | aman ✓ |
| Karakter aneh/unicode/HTML-ish | aman, tidak bisa injeksi ✓ |
| Cache JSON rusak | fallback aman, tidak crash ✓ |
| Antrean 150 item | utuh, tidak korup ✓ |

## 12. Smoketest

- `flutter analyze` → 0 issue.
- `flutter test` → semua lulus (1 skip).
- `flutter build web --release` & `flutter build apk --release` (arm64 + arm32) → sukses, signature & zipalign diverifikasi (`apksigner verify` OK, `zipalign -c -P 16` OK).
- Web produksi: `https://bssparking-pma.vercel.app` → 200, header HSTS/frame-options/sniff aktif.

---

## 13. Checklist tindakan (urutan pengerjaan)

**Langsung (sudah di commit ini)**
- [x] `technician_pin_dialog.dart` + storage PIN API + default PIN `123321` dihapus.
- [x] QA bypass wajib login SPV sungguhan.
- [x] Proxy AI Vision + Edge Function `ai-vision` (key bisa disembunyikan tanpa mematikan AI).
- [x] `deleteTask` menolak tugas completed (server + UI).
- [x] Script SQL lockdown RLS siap.

**Butuh aksi owner (tidak bisa dari repo)**
1. Jalankan `supabase/migrations/2026-10-22_security_rls_lockdown.sql` (mulai dari blok A & B).
2. `supabase secrets set GEMINI_API_KEY=<key>` → `supabase functions deploy ai-vision` → uji 1 foto absensi → lalu rotasi key lama di AI Studio + hapus konstanta key dari source.
3. Buat Edge Function `auth-login` (bcrypt verify) + `admin-delete-task` (role check) → matikan daftar akun hardcoded & alias password.
4. Bucket `task-proofs` privat + signed URL.
5. Update QR login / briefing SPV supaya teknisi tahu kalau akun bocor harus ganti password.
