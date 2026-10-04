# BSS Parking Optimization & Field Operations Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Mengimplementasikan optimasi performa kamera, auto-cleanup foto usang, pembersihan storage base64, dukungan senter (Torch mode), offline queue sync, serta generator laporan WhatsApp lengkap dengan lampiran foto per-point.

**Architecture:** 
- `CameraManagerService` untuk pre-warm background kamera dan pengaturan torch mode.
- `PhotoCleanupService` untuk membersihkan foto temporary berumur >7 hari secara periodik.
- `WhatsAppReportService` untuk generate format teks laporan resmi BSS dan share foto via `share_plus`.
- Update model `MaintenanceSubmission` dan `MaintenancePointResult` untuk menghapus base64 dari storage lokal dan mencatat status sinkronisasi offline.

**Tech Stack:** Flutter, Dart, camera, share_plus, path_provider, GoogleFonts.

## Global Constraints
- Target platform: Android.
- Orientation: Portrait only.
- Strict anti-lag: background operations non-blocking.
- All tests must pass: `flutter test`.

---

### Task 1: WhatsApp Report Service & Model Cleanup
**Files:**
- Create: `lib/data/services/whatsapp_report_service.dart`
- Create: `test/whatsapp_report_test.dart`
- Modify: `lib/data/models/maintenance_submission.dart`
- Modify: `lib/features/maintenance/screens/maintenance_checklist_screen.dart`

**Description:**
Buat generator teks laporan WhatsApp resmi BSS (Barrier Gate, Pos Kasir, Manless, Server) sesuai format yang diberikan user dan sediakan helper share multi-foto via `Share.shareXFiles`. Bersihkan penyimpanan base64 dari model `MaintenancePointResult` agar SharedPreferences tetap ringan.

- [ ] **Step 1: Buat unit test WhatsAppReportService**
- [ ] **Step 2: Implementasikan WhatsAppReportService**
- [ ] **Step 3: Update model MaintenanceSubmission & MaintenancePointResult (hilangkan imageBase64 dari toJson/fromJson SharedPreferences)**
- [ ] **Step 4: Tambahkan tombol "Bagikan ke WhatsApp" di MaintenanceChecklistScreen**
- [ ] **Step 5: Jalankan `flutter test` untuk verifikasi**

---

### Task 2: Photo Cleanup Service (Hapus Foto >7 Hari)
**Files:**
- Create: `lib/data/services/photo_cleanup_service.dart`
- Create: `test/photo_cleanup_test.dart`
- Modify: `lib/main.dart`

**Description:**
Buat service pembersih foto temporary di direktori aplikasi yang berumur lebih dari 7 hari agar memori internal HP teknisi tidak kepenuhan.

- [ ] **Step 1: Buat unit test PhotoCleanupService**
- [ ] **Step 2: Implementasikan PhotoCleanupService**
- [ ] **Step 3: Pasang panggilan pembersihan di background `main.dart`**
- [ ] **Step 4: Jalankan `flutter test` untuk verifikasi**

---

### Task 3: Flash Mode Torch (Senter Tempat Gelap) & Camera Pre-Warm
**Files:**
- Modify: `lib/features/camera/screens/camera_capture_screen.dart`
- Modify: `lib/features/maintenance/screens/point_camera_view.dart`

**Description:**
Tambahkan dukungan `FlashMode.torch` (senter menyala terus) pada siklus tombol flash di viewfinder utama dan point camera view. Sempurnakan pre-warm inisialisasi controller.

- [ ] **Step 1: Tambahkan FlashMode.torch pada CameraCaptureScreen & PointCameraView**
- [ ] **Step 2: Update ikon UI flash agar menampilkan ikon torch/senter saat aktif**
- [ ] **Step 3: Jalankan `flutter test` & verifikasi build**

---

### Task 4: Build, Testing, & Install Perangkat
**Files:**
- Output APK: `build/app/outputs/flutter-apk/app-debug.apk`

**Description:**
Build APK debug dan install langsung ke HP via adb untuk pengujian langsung di tangan pengguna.

- [ ] **Step 1: Jalankan `flutter test` lengkap**
- [ ] **Step 2: Jalankan `flutter build apk --debug`**
- [ ] **Step 3: Install ke perangkat via `adb install -r`**
