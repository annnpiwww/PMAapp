# Design Specification: Maintenance, Attendance Retake, Gallery Download & Universal APK

- **Date**: 2026-09-19
- **Project**: BssparkingTimeMark
- **Author**: Antigravity & Lead Engineer
- **Status**: Approved for Implementation

---

## 1. Overview & Objectives

Dokumen ini mendefinisikan rancangan perbaikan untuk 5 kendala utama yang diidentifikasi dalam operasional harian aplikasi BssparkingTimeMark:
1. **Standarisasi 1:1 Laporan Barrier Gate**: Menyelaraskan 9 poin checklist teknisi di aplikasi dengan format laporan yang dikirim ke WhatsApp/Telegram.
2. **Riwayat Maintenance Selesai 100%**: Menyediakan antarmuka khusus di Drawer untuk melihat, meninjau, dan membagikan ulang (re-share) pekerjaan maintenance yang telah selesai 100%, berdampingan dengan tab draft yang masih berjalan.
3. **Absensi Bebas Retake (Zero Early Lock-in)**: Mencegah penyimpanan otomatis status "Masuk" sebelum teknisi mengonfirmasi foto, memungkinkan foto ulang (retake) berkali-kali tanpa risiko terkunci jam kerja.
4. **Download Foto Galeri**: Menyediakan tombol download per-foto pada preview dan mode multi-select untuk mengunduh banyak foto sekaligus ke album galeri perangkat.
5. **Universal Android APK**: Mengonfigurasi NDK ABI filters agar mendukung perangkat Android 32-bit (`armeabi-v7a`) dan 64-bit (`arm64-v8a`) sehingga APK dapat diinstal di semua jenis HP Android.

---

## 2. Detailed Technical Design

### 2.1. Bug 1: Sinkronisasi Baku 1:1 Laporan Barrier Gate

#### Masalah Saat Ini
- `template_repository.dart` mendefinisikan poin yang tidak identik dengan `maintenance_checklist_screen.dart`.
- `whatsapp_report_service.dart` menggunakan grouping tematik hardcoded dengan kata kunci yang meleset (misal: poin *Dudukan Mesin* dicuri oleh *Cat body BG*, dan poin *Pengukuran Voltase Listrik Avometer* hilang sama sekali).
- Header gate tidak menampilkan jumlah atau rentang gate yang dikerjakan.

#### Solusi
1. **Standarisasi 9 Poin Checklist**:
   - Poin 1: `Dudukan Mesin & Baut Dinabolt` (id: `bar_01`)
   - Poin 2: `Fisik Palang Tertutup (0° Lurus)` (id: `bar_02`)
   - Poin 3: `Fisik Palang Terbuka (90° Lancar)` (id: `bar_03`)
   - Poin 4: `Pelumasan Mekanikal (Spring/Bearing)` (id: `bar_04`)
   - Poin 5: `Sensor Loop Detector (LED Detect Aktif)` (id: `bar_05`)
   - Poin 6: `Jalur Coran Aspal Sensor Loop` (id: `bar_06`)
   - Poin 7: `Pengukuran Voltase Listrik (Avometer)` (id: `bar_07`)
   - Poin 8: `Casing Sensor Receiver Anti Air` (id: `bar_08`)
   - Poin 9: `Tiang CCTV & Speed Bump Gate` (id: `bar_09`)
2. Sinkronkan definisi di `TemplateRepository.defaultTemplates` (`tpl_maint_barrier`) dan `MaintenanceChecklistScreen._generatePointsForUnits`.
3. Perbarui `WhatsAppReportService._appendBarrierGroupedNotes` untuk menampilkan persis ke-9 poin ini secara berurutan:
   - Evaluasi setiap poin sesuai statusnya (✅ `sesuai` atau ⚠️ catatan perbaikan).
   - Mendukung multi-gate (misal: Gate 1, Gate 2) dengan format Model 1.
4. Tambahkan baris header pada laporan Barrier Gate:
   - `Gate : $gateCount Unit ($gateRangeNote)` jika multi-gate, atau `Gate : $gateLabel` jika single gate.

---

### 2.2. Bug 2: Layar Riwayat Maintenance (Draft & Selesai 100%)

#### Masalah Saat Ini
- Data maintenance 100% selesai tersimpan di `StorageService.getMaintenanceSubmissions()`, tetapi Drawer menu hanya memiliki menu "Lanjutkan Maintenance" dengan filter `.where((s) => !s.isComplete)`. Saat selesai, item tersebut tidak dapat diakses kembali oleh teknisi.

#### Solusi
1. Buat layar baru: `MaintenanceHistoryScreen` di `lib/features/maintenance/screens/maintenance_history_screen.dart`.
2. Integrasikan ke Sidebar Drawer di `CameraCaptureScreen`:
   - Ganti menu "Lanjutkan Maintenance" menjadi **"Riwayat Maintenance"** (Icon `Icons.handyman_rounded`).
   - Tampilkan badge oranye jika terdapat draft yang masih berjalan.
3. Struktur Layar `MaintenanceHistoryScreen`:
   - Menggunakan `DefaultTabController` dengan 2 Tab:
     - **Tab 1: Draft Berjalan**: Menampilkan submission yang belum lengkap (`!s.isComplete`). Setiap kartu memiliki tombol "Lanjutkan Pengerjaan" yang mengarahkan ke `MaintenanceChecklistScreen`.
     - **Tab 2: Selesai 100%**: Menampilkan submission yang sudah selesai (`s.isComplete`). Setiap kartu menampilkan badge hijau `100% Selesai`, nama pos, tanggal & jam, teknisi, serta ringkasan poin.
4. Fitur Interaktif pada Item Selesai:
   - Saat kartu di-tap, buka dialog detail / bottom sheet:
     - Review status seluruh poin checklist dan foto thumbnail (tap-to-zoom).
     - Tombol **Kirim ke WhatsApp** dan **Kirim ke Telegram** untuk membagikan ulang laporan resmi dan foto kapan saja.

---

### 2.3. Bug 3: Alur Absensi Bebas Retake (Zero Early Lock-in)

#### Masalah Saat Ini
- Di `CameraCaptureScreen._handleCapturePhoto()`, saat AI mendeteksi foto sesuai (`aiResult.isSesuai`), sistem langsung menjalankan:
  ```dart
  await StorageService.saveLastCheckInTime(capturedTimestamp);
  await StorageService.saveAttendanceRecord(attRecord);
  ```
- Jika teknisi menekan tombol "Foto Ulang (Retake)" di modal, check-in tidak dibatalkan sehingga status terkunci menjadi "Sudah Masuk".

#### Solusi
1. Pisahkan fase *Verifikasi AI* dari fase *Commit Persistence*:
   - Saat foto selesai diambil dan dievaluasi AI, tampilkan `SopVerificationModal` dengan foto preview dan status AI.
   - **JANGAN** simpan ke `StorageService.saveLastCheckInTime` atau `StorageService.saveAttendanceRecord` pada tahap ini.
2. Penanganan Aksi pada Modal:
   - **Tombol "Foto Ulang" (Retake)**: Tutup modal (`Navigator.pop()`), buka kamera kembali, biarkan teknisi mengambil foto ulang. Tidak ada state yang berubah di storage.
   - **Tombol "Batal"**: Tutup modal, kembali ke viewfinder kamera. State absensi tetap bersih.
   - **Tombol "Simpan" / "Kirim ke WhatsApp / Telegram"**: Di titik inilah transaksi absensi di-commit secara atomik:
     1. Simpan `AttendanceRecord` ke storage.
     2. Simpan `saveLastCheckInTime(capturedTimestamp)`.
     3. Picu notifikasi instan & terjadwal via `NotificationService`.
     4. Update `AbsensiSetupService` ke status `Pulang`.
     5. Simpan ke `SubmissionRepository`.

---

### 2.4. Bug 4: Fitur Download & Multi-Select Galeri Foto HP

#### Masalah Saat Ini
- Di `GalleryScreen` dan `PhotoPreviewDialog`, foto hanya dapat dilihat tanpa opsi untuk menyimpannya ke memori galeri perangkat Android.

#### Solusi
1. **Download Per-Foto di Preview**:
   - Di `PhotoPreviewDialog`, tambahkan tombol icon download di bar atas.
   - Saat ditekan, panggil `ShareHelper.savePhotoToGallery(imagePath)`.
   - Berikan feedback SnackBar: `✓ Foto berhasil disimpan ke Galeri HP (Album BSS Parking)`.
2. **Mode Multi-Select ("Pilih Foto") di `GalleryScreen`**:
   - Tambahkan tombol toggle `Pilih` di AppBar `GalleryScreen` dan detail folder.
   - Saat mode pilih aktif:
     - Setiap thumbnail foto menampilkan checkbox di sudut atas.
     - Tap pada kartu foto akan meng-toggle status centang (bukan membuka dialog preview).
     - AppBar menampilkan jumlah yang dipilih (misal: `3 Foto Dipilih`), tombol `Pilih Semua`, dan tombol `Batal`.
     - Tampilkan Floating Action Button / Bottom Bar: `Download (X Foto)`.
     - Saat ditekan, jalankan loop penyimpanan foto terpilih via `ShareHelper.savePhotoToGallery`.
     - Tampilkan SnackBar ringkasan: `✓ X foto berhasil disimpan ke Galeri`.

---

### 2.5. Bug 5: Universal Android APK Build

#### Masalah Saat Ini
- `android/app/build.gradle.kts` membatasi `abiFilters` hanya ke `arm64-v8a`:
  ```kotlin
  ndk {
      abiFilters.clear()
      abiFilters.addAll(listOf("arm64-v8a"))
  }
  ```
- Smartphone Android 32-bit (banyak digunakan pada HP operasional entry-level) menolak instalasi APK.

#### Solusi
1. Ubah konfigurasi `abiFilters` di `android/app/build.gradle.kts`:
  ```kotlin
  ndk {
      abiFilters.clear()
      abiFilters.addAll(listOf("arm64-v8a", "armeabi-v7a"))
  }
  ```
2. Build command: Jalankan `flutter build apk --release` untuk menghasilkan satu file APK universal fat binary yang berisi binary native untuk kedua arsitektur (`arm64-v8a` dan `armeabi-v7a`).

---

## 3. Verification & Testing Strategy

1. **Unit & Integration Tests**:
   - Uji `WhatsAppReportService.generateReportText` untuk `maintBarrier`: memastikan ke-9 poin tercetak utuh dan sinkron dengan status unit.
   - Uji persistensi `StorageService.getMaintenanceSubmissions()` untuk submission yang berstatus `isComplete == true`.
   - Uji alur absensi: memastikan `getLastCheckInTime()` tetap `null` saat foto diambil tetapi sebelum tombol simpan/kirim ditekan.
2. **Flutter Analyze**:
   - Menjamin 0 issues / 0 warnings (`flutter analyze` clean).
3. **Build APK Verification**:
   - Pastikan build release APK sukses dengan nama universal `BSS-TimeMark-v2.0.42-Universal-Release.apk`.
