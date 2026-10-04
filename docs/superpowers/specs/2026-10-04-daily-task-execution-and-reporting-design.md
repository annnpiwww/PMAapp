# Spesifikasi Desain: Alur Pengerjaan Tugas Khusus, Input Manual Lokasi SPV & Pelaporan Daily

- **Tanggal**: 2026-10-04
- **Versi**: v2.0.50
- **Status**: Disetujui (Approved)
- **Target Platform**: Flutter Mobile (Android arm64-v8a & armeabi-v7a / iOS)
- **Pedoman Visual**: `design.md` (Anti-AI Slop, Impeccable Design, High Usability)

---

## 1. Latar Belakang & Masalah
1. Tombol "Kerjakan" pada tugas kategori khusus (non-maintenance SOP) sebelumnya tidak merespons karena belum terhubung ke layar kerja mandiri.
2. Form penugasan SPV sebelumnya masih menggunakan nama pos panjang ("Pos Gate Utama") atau dropdown kaku yang tidak fleksibel untuk lokasi dinamis seperti `TBM`, `MTC`, dll.
3. Kebutuhan teknisi di lapangan untuk mendokumentasikan 1 sampai multi-foto (fleksibel) tanpa batasan kaku.
4. Laporan berkala ke grup WhatsApp / Telegram membutuhkan format ringkas, to the point, dan langsung bisa dibagikan setelah data tersimpan aman di server database.
5. Menghindari duplikasi kerja saat absensi pulang shift di akhir hari.

---

## 2. Prinsip Desain & Visual Tokens
- **Palet Warna**:
  - Background Utama: `#0A1120` (Dark Navy)
  - Card / Surface: `#111827` & `#1E293B` (Slate)
  - Border: `#334155` (1px solid, clean outline, no neon glow)
  - Primary Accent: `#FF6500` (BSS Orange)
  - Success: `#10B981` (Emerald)
  - Error: `#EF4444` (Red)
- **Tipografi**: `Plus Jakarta Sans` / System Font, kontras tinggi, hierarki tegas.
- **Area Sentuh**: Semua tombol utama minimum tinggi 44–48 px.
- **Bahasa UI**: Singkat, padat, tanpa jargon atau teks bertele-tele.

---

## 3. Alur Kerja & Arsitektur Komponen

### A. Form Penugasan SPV (`SpvTaskDispatcherScreen`)
1. **Jenis Tugas (Segmented Control)**:
   - `Tugas Khusus` (default)
   - `Maintenance SOP`
2. **Pilih Teknisi**:
   - Dropdown memuat teknisi resmi dari database (`Ryan Lumasuge`, `Raldy Sangkop`, dll). Field wajib `*`.
3. **Lokasi (Field Manual Murni)**:
   - Satu field teks tunggal berlabel: `Lokasi *`
   - Placeholder: `Contoh: TBM`
   - Hapus seluruh dropdown pos lama dan quick-select chip.
4. **Detail Pekerjaan**:
   - Field teks berlabel: `Detail Pekerjaan *`
   - Placeholder: `Contoh: Pengecatan markah panah lokasi TBM`
5. **Aksi & Proteksi**:
   - Tombol utama: `Kirim Tugas` (tinggi 46px).
   - Anti-Double Submit: Tombol disabled saat state `isLoading`.
   - Konfirmasi sukses via SnackBar ringkas: `"Tugas berhasil dikirim"`.

### B. List Tugas Teknisi (`TeknisiDailyTasksScreen` & `DailyTaskListCard`)
1. **Tampilan Kartu**:
   - Judul pekerjaan.
   - Lokasi singkat: `Lokasi: TBM`.
   - Tombol di kanan bawah: `Kerjakan`.
2. **Routing Tombol Kerjakan**:
   - Jika `templateId != null && templateId.isNotEmpty`: Buka dialog `MaintenanceSetupDialog` (alur checklist POS per-point).
   - Jika `templateId == null || templateId.isEmpty`: Buka layar baru **`CustomTaskExecutionScreen`**.

### C. Layar Pengerjaan Tugas Khusus (`CustomTaskExecutionScreen`)
1. **Detail Kartu Header**:
   - Menampilkan `judul`, `lokasi`, dan status `Pending`.
2. **Dynamic Photo Deck**:
   - Menampilkan grid thumbnail foto yang telah diambil.
   - Setiap foto memiliki tombol hapus `[✕]` dan badge nomor foto (`Foto 1`, `Foto 2`).
   - Tombol `+ Tambah` bermotif dashed oranye untuk membuka kamera watermark BSS.
   - Bebas menambah foto dokumentasi (1, 2, 3, 5+ foto).
3. **Catatan Ringkas**:
   - Textarea dengan label `Catatan` dan placeholder `Catatan Laporan`.
4. **Single Primary Action**:
   - Satu tombol utama di bawah: `Selesaikan Tugas`.
   - Saat ditekan:
     1. Menampilkan loading indicator inline pada tombol.
     2. Mengirim HTTP request ke PocketBase (`completeTask`) membawa seluruh foto bukti dan catatan.
     3. Menunggu respons HTTP 200 dari server (jangan klaim sukses sebelum terkonfirmasi).
     4. Jika gagal: Tampilkan pesan error ringkas dan tombol `Coba Lagi`.
     5. Jika sukses: Membuka dialog **"Laporan Berhasil Disimpan"**.

### D. Dialog Pasca-Simpan (`PostSaveShareDialog`) & Integrasi Laporan
1. **Opsi Berbagi**:
   - Tombol `Kirim ke WhatsApp / Telegram` (warna hijau emerald).
   - Tombol `Tutup` (kembali ke layar utama).
2. **Format Pesan WA/Telegram**:
   ```text
   Laporan Daily Hari ini
   Teknisi : Ryan
   Tanggal : 04 Oktober 2026
   Lokasi : TBM
   Pekerjaan : Pengecatan markah panah lokasi TBM
   Status : Selesai (13:45)
   ----
   Catatan :
   "Catatan Laporan"
   ```
   *Catatan: Jika ada foto bukti lokal, file foto dibagikan bersamaan menggunakan `SharePlus`.*

### E. Integrasi Absensi Pulang Shift (`DailyPulangBottomSheet`)
- Tidak ada tombol absensi pulang di dalam layar pengerjaan tugas.
- Absen pulang tetap dilakukan teknisi di rute kepulangan shift yang sudah ada saat jam pulang tiba.
- Saat bottom sheet kepulangan dibuka, kolom "Pekerjaan Selesai" otomatis memuat seluruh tugas berstatus `completed` dengan prefix centang:
  ```text
  ✅ Pengecatan markah panah lokasi TBM
  ```

---

## 4. Rencana Pengujian & Validasi
1. **Unit Test**: Serialisasi dan deserialisasi `DailyTaskModel` dengan multi-foto bukti.
2. **Flutter Analyze**: 0 warnings, 0 errors.
3. **Widget & Flow Testing**:
   - SPV membuat tugas dengan field lokasi manual (`TBM`).
   - Teknisi mengambil tugas di list dan membuka `CustomTaskExecutionScreen`.
   - Mengambil 2 foto, mengisi catatan, dan menekan `Selesaikan Tugas`.
   - Memastikan data tersimpan di PocketBase CT 105.
   - Memastikan format string WhatsApp/Telegram sesuai standar singkat.
