# Technical Specification: Maintenance & Reporting System Refinements

**Date:** 2026-09-11  
**Project:** BssparkingTimeMark  
**Status:** Approved  

---

## 1. Objectives & Scope
Perbaikan komprehensif pada sistem pelaporan maintenance, manajemen lokasi, jadwal shift teknisi, dan keamanan template SOP BSS Parking.

### Item Poin Perubahan:
1. **Validasi AI Vision pada Status Hijau**: Tampilkan deskripsi alasan AI Vision nyata (`p.alasan`), bukan hanya kata "sesuai".
2. **Kondisi Unit Tunggal**: Hilangkan prefix `Pos 1:` jika hanya 1 unit yang diperiksa. Format `Pos X:` hanya berlaku jika unit > 1.
3. **Standarisasi Format Pelaporan**: Rapikan layout pesan untuk WhatsApp & Telegram dengan header, indentasi, dan penutup ramah.
4. **Optimasi UI Lokasi di Hamburger Menu**: Buat daftar lokasi compact, scrollable, dan tidak merusak layout drawer saat ratusan lokasi dimuat.
5. **Penyederhanaan Form Tambah/Edit Lokasi**: Hanya Nama Lokasi, Tag Card, Cabang, dan Warna Badge. Koordinat GPS diambil realtime otomatis di background.
6. **Text Wrap & Anti-Truncation Lokasi**: Wrap teks nama lokasi di watermark card & viewfinder agar tidak terpotong elipsis (`...`).
7. **Placeholder Nama Farhan Lakoro**: Jadikan `Farhan Lakoro` murni sebagai placeholder/hintText di field nama teknisi tanpa pre-fill text.
8. **Jadwal Shift 2.2 (10:00 - 14:00)**: Tambahkan tombol shift 2.2 berdampingan dengan Shift 1, 2, 3. Sinkronisasi ucapan `Selamat Pagi` (masuk) dan `Selamat Siang` (pulang).
9. **Auto-Numbering List Pekerjaan Selesai**: Auto formatting nomor baris (`1. ...`, `2. ...`) saat pengisian laporan absensi pulang.
10. **Pilihan Rekan IT Support Selanjutnya**: Pilihan nama rekan (`Junifer Manua`, `Ryan Lumasuge`, `Alessandro Sulistyo`, `Raldy Sangkop`) via dropdown/chips + opsi custom.
11. **Ganti Teks "Nama Pos"**: Rename semua label `Nama Pos` menjadi `Nama Lokasi`.
12. **Hak Akses Template SOP**: Sembunyikan tombol "Kelola" di template picker teknisi, hanya admin ber-PIN yang dapat mengelola template SOP.

---

## 2. Technical Architecture & Modifications

### A. Report Engine (`whatsapp_report_service.dart`)
- Update `_formatOkAlasan()` dan `_findBestOkAlasan()` untuk mengembalikan deskripsi AI Vision jika status `PointStatus.sesuai`.
- Modifikasi `_appendThematicModel1Line()`:
  - Cek `isSingleUnit`: jika true, cetak `✅ [hasil validasi]` tanpa `Pos 1:`.
- Sinkronisasi greeting berbasis jam kepulangan:
  - 10:00 - 10:59: Selamat Pagi
  - 11:00 - 14:59: Selamat Siang (termasuk jam pulang shift 2.2 pukul 14:00)
  - 15:00 - 18:59: Selamat Sore
  - 19:00+: Selamat Malam

### B. Shift & Absensi Service (`absensi_setup_service.dart` & `absensi_kategori_dialog.dart`)
- Tambahkan pilihan tombol `Shift 2.2 (10:00 - 14:00)` pada `_shiftOptions` di dialog absensi teknisi (sejajar 4 tombol: Shift 1, Shift 2.2, Shift 2, Shift 3).
- Implementasikan auto-numbering formatter pada controller `_pekerjaanSelesaiCtrl`.
- Tambahkan dropdown nama rekan IT Support selanjutnya: `Junifer Manua`, `Ryan Lumasuge`, `Alessandro Sulistyo`, `Raldy Sangkop`.

### C. Manajemen Lokasi (`location_management_screen.dart` & `location_picker_modal.dart`)
- Hapus field alamat manual & lat/long dari form dialog.
- Ubah label `Nama Pos` -> `Nama Lokasi`.
- Otomatis query `LocationService.getCurrentLocation()` saat dialog dibuka / disimpan.

### D. Viewfinder & Drawer UI (`camera_capture_screen.dart` & `interactive_watermark.dart`)
- Wrap teks lokasi dengan `softWrap: true` dan `maxLines: 3`.
- Sembunyikan tombol `Kelola` di quick template picker modal.
- Buat drawer location list scrollable dan rapi.

---

## 3. Verification & Testing Plan
1. Jalankan unit test `flutter test` untuk memverifikasi model dan logic formatter.
2. Generate HTML preview laporan dan kirim notifikasi via bot Telegram `tools/telegram_notify.sh`.
