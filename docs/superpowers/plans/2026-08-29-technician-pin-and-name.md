# Implementation Plan: Technician PIN Lock & Dynamic Support Name

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Mengamankan fitur maintenance dengan PIN teknisi (`123321`) dan menambahkan input nama teknisi dinamis di dialog setup untuk pelaporan WhatsApp yang bersih (tanpa NIP/NPP).

**Architecture:**
- `StorageService` ditambahkan method penyimpanan & pembacaan `technicianPin` dan `lastTechnicianName`.
- `TechnicianPinDialog` dibuat sebagai gatekeeper sebelum membuka form maintenance.
- `MaintenanceSetupDialog` ditambahkan TextFormField `Nama Teknisi / Support`.
- `MaintenanceChecklistScreen` menerima parameter nama teknisi yang diinputkan dan menyimpannya ke submission.

## Global Constraints
- Target platform: Android.
- Orientation: Portrait only.
- Strict non-blocking UI.
- All tests must pass: `flutter test`.

---

### Task 1: Update StorageService & Buat TechnicianPinDialog
**Files:**
- Modify: `lib/data/services/storage_service.dart`
- Create: `lib/features/maintenance/widgets/technician_pin_dialog.dart`
- Create: `test/technician_pin_test.dart`

- [ ] **Step 1: Tambahkan method pin & last technician name di StorageService**
- [ ] **Step 2: Buat widget TechnicianPinDialog**
- [ ] **Step 3: Buat unit test TechnicianPinDialog & PIN storage logic**
- [ ] **Step 4: Jalankan `flutter test test/technician_pin_test.dart`**

---

### Task 2: Tambahkan Input Nama Teknisi di MaintenanceSetupDialog & Checklist
**Files:**
- Modify: `lib/features/maintenance/widgets/maintenance_setup_dialog.dart`
- Modify: `lib/features/maintenance/screens/maintenance_checklist_screen.dart`
- Modify: `lib/features/camera/screens/camera_capture_screen.dart`

- [ ] **Step 1: Tambahkan input field Nama Teknisi di MaintenanceSetupDialog**
- [ ] **Step 2: Hubungkan pemilihan template maintenance di CameraCaptureScreen dengan TechnicianPinDialog**
- [ ] **Step 3: Teruskan nama teknisi ke MaintenanceChecklistScreen & Submission**
- [ ] **Step 4: Jalankan `flutter test` untuk verifikasi penuh**

---

### Task 3: Build APK Debug & Install ke HP via ADB
**Files:**
- Output: `build/app/outputs/flutter-apk/app-debug.apk`

- [ ] **Step 1: Jalankan `flutter test` semua unit tests**
- [ ] **Step 2: Jalankan `flutter build apk --debug`**
- [ ] **Step 3: Install ke HP via `adb install -r`**
