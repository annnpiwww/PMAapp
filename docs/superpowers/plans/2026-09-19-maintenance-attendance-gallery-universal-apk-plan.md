# Maintenance, Attendance Retake, Gallery Download & Universal APK Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Memperbaiki dan menyelaraskan 5 fitur utama: 1:1 laporan barrier gate, layar riwayat maintenance (draft & 100% selesai), alur absensi bebas retake tanpa premature lock-in, tombol download & multi-select di galeri foto, serta universal APK build untuk semua Android.

**Architecture:**
- **Report & Template Sync**: Sinkronisasi 9 poin baku checklist Barrier Gate secara 1:1 di `template_repository.dart`, `maintenance_checklist_screen.dart`, dan `whatsapp_report_service.dart`.
- **Maintenance History UI**: Pembuatan `MaintenanceHistoryScreen` dengan 2 Tab (`Draft Berjalan` & `Selesai 100%`) dan detail review dialog yang mendukung re-share ke WhatsApp & Telegram.
- **Attendance Flow Decoupling**: Pemisahan evaluasi AI dari penyimpanan transaksi absensi di `camera_capture_screen.dart`, sehingga teknisi bebas retake/cancel tanpa tersimpan status "Masuk".
- **Gallery Download**: Penambahan tombol download di `PhotoPreviewDialog` dan mode pemilihan massal (`Pilih Foto`) di `GalleryScreen` yang memanggil `ShareHelper.savePhotoToGallery`.
- **Universal Build**: Konfigurasi NDK multi-ABI (`arm64-v8a` + `armeabi-v7a`) di `build.gradle.kts` untuk menghasilkan universal release APK.

**Tech Stack:** Flutter 3.41+ / Dart 3.11+, Material 3, SharedPreferences, Gal 2.3.1, NDK Multi-ABI.

## Global Constraints
- Bahasa teks laporan WhatsApp & Telegram tetap baku dan rapi dengan format salam otomatis dan tanggal Indonesia.
- Seluruh 149 tes unit & integrasi yang sudah ada harus tetap 100% lulus tanpa regresi.
- `flutter analyze` harus menghasilkan 0 issue / 0 warning (100% clean).

---

### Task 1: Standarisasi 1:1 9 Poin Barrier Gate di Template, Checklist & WhatsApp Report Service

**Files:**
- Modify: `lib/data/repositories/template_repository.dart`
- Modify: `lib/features/maintenance/screens/maintenance_checklist_screen.dart`
- Modify: `lib/data/services/whatsapp_report_service.dart`
- Test: `test/barrier_report_and_history_test.dart`

**Interfaces:**
- `WhatsAppReportService.generateReportText(...)`: menghasilkan teks laporan untuk `TemplateCategory.maintBarrier` yang memuat persis ke-9 poin dengan header Gate In/Out.
- `template_repository.dart`: template `tpl_maint_barrier` memiliki 9 `sopPoints` identik dengan checklist.

- [ ] **Step 1: Tulis tes yang memverifikasi 9 poin laporan barrier gate secara 1:1**
Create `test/barrier_report_and_history_test.dart` dengan pengujian bahwa teks laporan memuat 9 poin yang benar dan mencakup header Gate.

- [ ] **Step 2: Jalankan tes untuk memverifikasi kegagalan awal**
Run: `flutter test test/barrier_report_and_history_test.dart`
Expected: FAIL karena laporan saat ini masih berisi poin lama / grouping yang tidak sesuai.

- [ ] **Step 3: Update `template_repository.dart` dan `maintenance_checklist_screen.dart`**
Pastikan ke-9 poin memiliki ID dan label yang seragam:
1. `Dudukan Mesin & Baut Dinabolt`
2. `Fisik Palang Tertutup (0° Lurus)`
3. `Fisik Palang Terbuka (90° Lancar)`
4. `Pelumasan Mekanikal (Spring/Bearing)`
5. `Sensor Loop Detector (LED Detect Aktif)`
6. `Jalur Coran Aspal Sensor Loop`
7. `Pengukuran Voltase Listrik (Avometer)`
8. `Casing Sensor Receiver Anti Air`
9. `Tiang CCTV & Speed Bump Gate`

- [ ] **Step 4: Update `_appendBarrierGroupedNotes` di `whatsapp_report_service.dart`**
Format ke-9 poin tersebut dengan Model 1 Formatter dan sertakan header `Gate : ...`.

- [ ] **Step 5: Jalankan tes untuk memastikan lulus**
Run: `flutter test test/barrier_report_and_history_test.dart`
Expected: PASS

---

### Task 2: Buat Layar Riwayat Maintenance (`MaintenanceHistoryScreen`) & Integrasi Drawer

**Files:**
- Create: `lib/features/maintenance/screens/maintenance_history_screen.dart`
- Modify: `lib/features/camera/screens/camera_capture_screen.dart`
- Test: `test/barrier_report_and_history_test.dart`

**Interfaces:**
- `MaintenanceHistoryScreen`: Widget layar dengan 2 tab: "Draft Berjalan" dan "Selesai 100%".
- Tap item selesai: membuka modal detail dengan thumbnail foto, status AI, dan tombol share ke WhatsApp/Telegram.
- Drawer di `CameraCaptureScreen`: mengganti "Lanjutkan Maintenance" menjadi "Riwayat Maintenance" yang menavigasikan ke `MaintenanceHistoryScreen`.

- [ ] **Step 1: Tambahkan skenario tes untuk `MaintenanceHistoryScreen` dan filtering status selesai di `test/barrier_report_and_history_test.dart`**

- [ ] **Step 2: Buat file `lib/features/maintenance/screens/maintenance_history_screen.dart`**
Implementasikan UI TabBar (Draft vs Selesai), kartu riwayat, detail dialog, dan tombol re-share.

- [ ] **Step 3: Update Drawer di `lib/features/camera/screens/camera_capture_screen.dart`**
Arahkan klik menu maintenance ke `MaintenanceHistoryScreen`.

- [ ] **Step 4: Jalankan tes widget & integrasi**
Run: `flutter test test/barrier_report_and_history_test.dart`
Expected: PASS

---

### Task 3: Perbaiki Alur Absensi Bebas Retake (Cegah Premature Check-In Lock-in)

**Files:**
- Modify: `lib/features/camera/screens/camera_capture_screen.dart`
- Test: `test/attendance_retake_test.dart`

**Interfaces:**
- `_handleCapturePhoto`: tidak memanggil `StorageService.saveLastCheckInTime` atau `StorageService.saveAttendanceRecord` saat capture selesai.
- `SopVerificationModal.onRetake`: hanya menutup modal dan membuka kamera kembali, status check-in tetap bersih (`getLastCheckInTime() == null`).
- `SopVerificationModal.onSave` / `onShareWhatsApp` / `onShareTelegram`: melakukan commit status absensi secara resmi.

- [ ] **Step 1: Tulis tes `test/attendance_retake_test.dart`**
Menguji bahwa pengambilan foto atau penutupan modal tanpa simpan tidak menyimpan status check-in ke `StorageService`.

- [ ] **Step 2: Jalankan tes untuk memverifikasi kegagalan awal**
Run: `flutter test test/attendance_retake_test.dart`
Expected: FAIL

- [ ] **Step 3: Modifikasi `camera_capture_screen.dart`**
Pindahkan logika commit persistensi absensi masuk/pulang dari blok capture otomatis ke callback tombol simpan/share di modal.

- [ ] **Step 4: Jalankan tes**
Run: `flutter test test/attendance_retake_test.dart`
Expected: PASS

---

### Task 5: Implementasi Tombol Download & Mode Multi-Select Galeri Foto

**Files:**
- Modify: `lib/features/maintenance/widgets/photo_preview_dialog.dart`
- Modify: `lib/features/history/screens/gallery_screen.dart`
- Test: `test/gallery_download_test.dart`

**Interfaces:**
- `PhotoPreviewDialog`: menambahkan tombol download di header/footer yang memanggil `ShareHelper.savePhotoToGallery`.
- `GalleryScreen`: menambahkan mode multi-select dengan checkbox pada foto, tombol "Pilih Semua", dan tombol "Download (X Foto)".

- [ ] **Step 1: Tulis tes `test/gallery_download_test.dart`**
Menguji logika seleksi foto di galeri dan integrasi download.

- [ ] **Step 2: Jalankan tes untuk memverifikasi kegagalan**
Run: `flutter test test/gallery_download_test.dart`
Expected: FAIL

- [ ] **Step 3: Tambahkan tombol download pada `PhotoPreviewDialog`**
Tampilkan icon `Icons.download_rounded` dengan visual feedback SnackBar.

- [ ] **Step 4: Tambahkan mode "Pilih Foto" dan tombol download massal pada `GalleryScreen`**
Implementasikan state seleksi foto, checkbox UI, dan aksi unduh批量.

- [ ] **Step 5: Jalankan tes untuk memastikan lulus**
Run: `flutter test test/gallery_download_test.dart`
Expected: PASS

---

### Task 6: Konfigurasi Universal Android APK & Build Release

**Files:**
- Modify: `android/app/build.gradle.kts`
- Modify: `pubspec.yaml` (bump patch version ke `v2.0.42+48`)

**Interfaces:**
- `android/app/build.gradle.kts`: `abiFilters` mendukung `arm64-v8a` dan `armeabi-v7a`.

- [ ] **Step 1: Update `android/app/build.gradle.kts`**
Ubah `abiFilters` menjadi `listOf("arm64-v8a", "armeabi-v7a")`.

- [ ] **Step 2: Bump versi di `pubspec.yaml`**
Update versi ke `2.0.42+48`.

- [ ] **Step 3: Jalankan full test suite dan static analysis**
Run: `flutter test && flutter analyze`
Expected: 100% tests PASS dan 0 issues found.

- [ ] **Step 4: Build APK release universal**
Run: `flutter build apk --release`
Expected: Build sukses menghasilkan APK universal di `build/app/outputs/flutter-apk/app-release.apk`.

- [ ] **Step 5: Salin file APK ke `bsstimemark/`**
Simpan dengan nama `bsstimemark/BSS-TimeMark-v2.0.42-Universal-Release.apk`.

---

## Self-Review Checklist
1. **Spec coverage**: Semua 5 poin dari spesifikasi telah memiliki task terinci yang dapat diuji.
2. **Placeholder scan**: Tidak ada TBD/TODO, semua path file dan kode spesifik telah didefinisikan.
3. **Type consistency**: Nama interface dan model (`MaintenanceSubmission`, `TemplateCategory`, `ShareHelper.savePhotoToGallery`) konsisten di semua task.
