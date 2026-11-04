# Audit Bug + Konsep Fitur Teknisi (PMA App v2.0.119+2132)

Tanggal: 1 November 2026. Basis: working tree (banyak perubahan belum di-commit).

Baseline: `flutter analyze` 0 issue, `flutter test` 444 lulus + 3 skip. Temuan di bawah lolos dari test yang ada.

Tanda: **[V]** = sudah dicek langsung ke kode. Tanpa tanda = hasil audit baca kode, cek ulang baris sebelum patch. `[INFERENCE]` = belum terbukti.

---

## A. P0 (keamanan / data hilang)

| # | File | Masalah | Fix |
|---|---|---|---|
| 1 [V] | `lib/data/repositories/auth_repository.dart:122-183` | Password hardcoded (`flakoro05`, `teknisi123`, `spvbali`, `spvho`) jadi fallback login, termasuk saat server bilang password salah | Hapus daftar akun lokal, auth server-side |
| 2 [V] | `auth_repository.dart:63-72` | Alias backdoor `spv123` / `farhan123` untuk akun yang namanya mengandung `farhan` | Hapus |
| 3 [V] | `lib/data/models/ai_vision_config.dart:117` | Gemini API key literal di `defaultValue`, ikut ke APK & bundle web | Rotate key, panggil lewat edge function `supabase/functions/ai-vision` |
| 4 | `auth_repository.dart:42-45` + RLS `app_users` | Login `select=*` ikut ambil kolom `password` plaintext pakai anon key. Status apply `2026-10-22_security_rls_lockdown.sql` `[INFERENCE]` | RLS + revoke kolom, hash password |
| 5 | `auth_repository.dart:76-77`, `user_model.dart` | Role murni client-side (prefs `bss_current_user`), token palsu `sb_token_<id>` | Supabase Auth JWT + RLS per role |
| 6 [V] | `lib/data/services/google_sheets_service.dart:257-263` | `flushPendingQueue`: exception lalu `break`, sisa item tidak masuk `remaining`, antrean ditimpa. Item 3 dst hilang permanen | `remaining.addAll(listStr.skip(i))` sebelum `break` |
| 7 [V] | `lib/data/services/daily_task_service.dart:1817-1823` | Pola sama di `flushPendingTaskCreationQueue`: tugas offline sisa hilang | Sama dengan #6 |
| 8 [V] | `daily_task_service.dart:1091-1145` | Upload bukti gagal (timeout 15s / file tak terbaca) ditelan, PATCH tetap `status: completed` tanpa `foto_bukti` | Jangan PATCH completed kalau upload gagal, antre ulang dengan foto |
| 9 [V] | `daily_task_service.dart:1081-1088` | Tugas `local_` diselesaikan offline: foto bukti tidak pernah di-upload saat flush | Bawa path foto di antrean, upload saat flush |
| 10 | `daily_task_service.dart` flush completions + creations | Antrean dibaca di awal, ditulis di akhir tanpa lock, flush jalan tiap poll 25s. Entri baru yang masuk saat flush tertimpa | Mutex atau re-read lalu hapus per id |
| 11 | `lib/data/services/photo_cleanup_service.dart:7-35` | Cleanup 7 hari hapus semua jpg/png di temp & documents tanpa cek antrean pending | Exclude path milik submission/task pending |
| 12 | `storage_service.dart:527-545` | Hapus riwayat absensi ikut hapus foto yang masih dipakai submission pending | Cek referensi sebelum hapus file |

## B. P1 (perilaku salah)

**Auth / sesi**
- `auth_repository.dart:33-44`: identity mentah masuk filter PostgREST `or=(...ilike...)`. Input `*` atau `,` cocok banyak akun. Validasi karakter atau query per kolom.
- Password dibandingkan `toLowerCase()`. Tidak ada rate limit login.
- Logout cuma hapus `bss_current_user`. Submission, absensi, cache tugas, flag `bss_spv_qa_bypass_mode_v1` tetap ada untuk user berikutnya di HP yang sama.
- QA bypass (`storage_service.dart:34-46`) tanpa gate `kDebugMode`, dipakai skip cek 8 jam di `camera_capture_screen.dart` & `absensi_kategori_dialog.dart`. `_isSpvFarhan()` pakai substring nama.
- `BranchService.determineBranch` fallback ke cabang sesi sebelumnya, keyword substring pendek (`ale`, `dika`) bisa salah cabang.

**Daily task**
- `transferTask` / `claimTask`: PATCH cuma `id=eq.`, dua teknisi klaim bareng sama-sama sukses (last write wins). Tambah precondition `teknisi_nama=eq.<lama>`.
- `transferTask` cek 200/204 saja, bukan `patchResponseAccepted`. Row terhapus hidup lagi di cache.
- `getOpenHandoverTasks`: hasil server kosong (valid) jatuh ke cache, tugas yang sudah diklaim tetap tampil terbuka.
- `_matchesTechnician`: `contains` dua arah, `adi` cocok `ADI SUPRIADI`, nama kosong cocok semua.
- `submissionMatchesTask`: `Pos 1` cocok `Pos 10`. `getOngoingMaintenance`: pos kosong cocok semua lokasi.
- Notifikasi: `_knownPendingTaskIds.isEmpty` dianggap init pertama (tugas pertama tidak bunyi). Set tidak direset saat logout / ganti cabang (spam alert).
- Antrean penyelesaian yang ditolak server (4xx / `[]`) tidak pernah dibuang, upload ulang foto tiap 25s. Semua 4xx (termasuk 401/408/429) di antrean pembuatan langsung dibuang.

**Absensi / kamera**
- Gate pulang pakai shift yang sedang dipilih, bukan shift saat check-in. Ganti shift setelah masuk bisa memajukan jam pulang.
- Lupa pulang kemarin: Masuk hari ini dicatat sebagai Pulang, durasi dihitung dari kemarin.
- `pulangAllowedFrom` (`absensi_setup_service.dart:156-174`) anchor jam akhir shift ke tanggal check-in. Shift lintas tengah malam (Shift 3, JP 2) bisa salah `[INFERENCE]`.
- Watermark gagal / timeout: `applyWatermarkToFile` balikin path mentah, caller anggap sukses. Foto tanpa watermark masuk riwayat & share.
- `takePicture` gagal ditelan `catch (_) {}`, flow lanjut tanpa foto.
- `_initCamera` tanpa cek `mounted`, controller lama tidak di-dispose saat init overlap (resume cepat).
- Koordinat fallback POS disimpan seperti GPS asli, `AttendanceRecord` tidak punya flag fallback.
- `SecureTimeService`: flag tampered/skew sticky seumur sesi, sync waktu cuma sekali saat start.

**Maintenance / laporan**
- Resume draft Maintenance Lengkap dari daily task / history: `unitNumbers`, `manlessUnits`, `posUnits`, `includeServer` balik default. Poin hilang, AI verify jalan tanpa checkpoint.
- Migrasi template (`template_repository.dart:662-675`) menimpa template barrier/manless yang sudah diedit user (cek label `Receiver` tidak cocok `Stiker Receiver Barrier Gate`, cek panjang list). Template baru muncul lagi setelah dihapus.
- `whatsapp_report_service.dart:794-796`: setup 1 gate selalu tertulis `Gate : 1`, role OUT hilang.
- Antrean Sheets dipotong ke 50 item tanpa peringatan. Timeout setelah server sudah tulis = baris dobel saat flush (dedupe di Apps Script belum ketemu di repo).
- Prune 150 submission (`storage_service.dart:249`, `submission_repository.dart:37`) tanpa cek status sync.

## C. P2

- Telegram `parse_mode: HTML` tanpa escape `judul` / `deskripsi`, karakter `<` `&` bikin kirim gagal diam.
- `WITA` hardcoded + `DateTime.now()` device.
- `deleteTask` cek completed dari cache lokal saja.
- Payload Sheets offline beda skema dari online (`perangkat`, `totalPoin`, `daftarUrgent` hilang). `secretToken` ikut tersimpan di tiap item antrean.
- `ui.Image` di watermark processor tidak di-dispose, `http.Client` di secure time tidak di-close.
- Override `custom_supabase_url` / `custom_supabase_anon_key` dari prefs tanpa writer.

---

## D. Konsep Fitur Teknisi (urut dampak)

1. **Pusat Sinkron**. Badge di HUD: jumlah tugas, penyelesaian, foto bukti, laporan Sheets yang belum terkirim. Tiap item ada status, tombol kirim ulang, dan label "bukti belum terkirim". Sekaligus jadi wadah fix P0 #6 sampai #12.
2. **Banner sesi belum ditutup**. Kalau check-in kemarin belum pulang: tampil banner, teknisi tutup sesi dengan alasan, SPV approve. Shift dikunci saat check-in.
3. **Temuan jadi tugas lanjutan**. Kartu "Yang Perlu Diperbaiki" dari AI bisa jadi daily task untuk shift berikutnya, ditutup dengan foto sesudah perbaikan (pasangan foto sebelum/sesudah otomatis di laporan).
4. **Riwayat per unit**. Timeline Gate / Manless / Pos: temuan, perbaikan, foto terakhir. Flag "temuan berulang" kalau masalah sama muncul 3x dalam 30 hari. Dibuka sebelum mulai checklist.
5. **QR di unit**. Stiker QR per gate/pos: scan buka checklist unit yang benar + bukti teknisi berdiri di unit itu. Menggantikan pilihan unit manual yang rawan salah.
6. **Catat kertas & sparepart**. Ganti roll thermal / sparepart dicatat dari app per gate (aturan roll 1000 tiket, guard 700 sama dengan bot Roki). Stok per pos kelihatan SPV.
7. **Panduan troubleshooting offline**. Langkah perbaikan per perangkat (printer macet, barrier tidak naik, loop detector) bisa dibaca tanpa sinyal, ditautkan dari poin checklist yang gagal.
8. **Rekap pribadi teknisi**. Tugas selesai, tepat waktu, temuan ditutup per minggu. Data sudah ada di tabel cabang + arsip absensi.

Urutan kerja yang disarankan: fix P0 antrean & bukti (#6 sampai #12) dibungkus fitur Pusat Sinkron, lalu P0 keamanan (#1 sampai #5, butuh migrasi Supabase Auth), baru fitur 2 sampai 8.
