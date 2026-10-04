# Design Specification: WhatsApp Share from Maintenance History

- Date: 2026-08-29
- Author: Antigravity / Opencode
- Target Project: BssparkingTimeMark (Flutter)

---

## 1. Objective
Memungkinkan teknisi membagikan ulang (atau pertama kali membagikan) laporan maintenance langsung dari halaman **Riwayat (HistoryListScreen)** ke WhatsApp, tanpa harus membuka ulang kamera atau checklist screen. Format teks pesan otomatis disesuaikan dengan standar pelaporan BSS Parking (Barrier Gate, Pos Kasir, Manless, Server) dan secara otomatis melampirkan seluruh foto ber-watermark yang ada pada submission tersebut.

---

## 2. User Flow & UI Components

### 2.1 Kartu Riwayat Maintenance (`HistoryListScreen`)
Pada tab **Maintenance (Per-Point)** di `HistoryListScreen`:
1. Setiap item riwayat yang memiliki foto (`doneCount > 0`) akan menampilkan tombol aksi cepat hijau:
   - **"Bagikan ke WhatsApp"** (dengan ikon WhatsApp / Share & badge jumlah foto).
2. Jika kartu di-expand (accordion detail poin checklist):
   - Di bagian bawah daftar poin, disediakan dua tombol rapi:
     - Tombol 1: **"Bagikan ke WhatsApp"** (warna hijau WhatsApp, melampirkan teks resmi + file foto).
     - Tombol 2: **"Buka / Lanjutkan Checklist"** (untuk melanjutkan poin yang belum selesai).

### 2.2 Template Teks & Category Resolver
- Template kategori diambil langsung dari ID template submission (`tpl_maint_barrier`, `tpl_maint_pos`, `tpl_maint_manless`, `tpl_maint_server`) atau dicocokkan melalui `TemplateRepository`.
- Format pesan tetap seragam sesuai standar BSS yang disepakati:
  - Salam waktu otomatis (Pagi/Siang/Sore/Malam).
  - Nama lokasi pos & tanggal laporan bahasa Indonesia.
  - Nama support / teknisi.
  - Daftar ringkasan checklist per item (OK / Perlu Perbaikan).
  - Kalimat penutup: *"Terima kasih 🙏"*.

### 2.3 File Attachment Handling
- Mengambil daftar file foto dari `item.points.map((p) => p.imagePath)`.
- Hanya menyertakan path file yang benar-benar ada di disk (`File(path).existsSync()`).
- Menggunakan `WhatsAppReportService.shareToWhatsApp`.

---

## 3. Verification & Testing
- Unit test verifikasi integrasi tombol share pada submission riwayat.
- Pastikan tidak ada error kompilasi dan semua test suite (`flutter test`) lulus 100%.
- Build APK debug dan install ke perangkat Android.
