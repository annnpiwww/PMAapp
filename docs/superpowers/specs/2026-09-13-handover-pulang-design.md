# Handover Pulang & Daily Job Gating Design Spec

**Date:** 2026-09-13
**Author:** Pair Programming Antigravity & User
**Status:** Approved

---

## 1. Goal & Context
Before technicians can perform attendance check-out (Absensi Pulang) in **BSS Parking TimeMark**, they must complete:
1. **IT Support Shift Selanjutnya**: The incoming technician taking over the next shift (or "Shift Terakhir / Tidak Ada Pengganti").
2. **Daily Pekerjaan Selesai**: Free-form multiline text with intelligent auto-numbering (`1. `, `2. `, `3. `).
3. **Daily Pekerjaan Belum Selesai (Pendingan)**: Free-form multiline text with auto-numbering, or `-` if no pending tasks.

Taking a photo for Pulang is hard-gated: tapping the shutter when these fields are incomplete intercepts the shutter action and opens the Handover Bottom Sheet directly.

---

## 2. Selected Approach: Opsi A (Shutter Intercept Guard & Bottom Sheet)
- **Viewfinder Experience**: Camera viewfinder remains clean and uncluttered.
- **Trigger**: When the attendance status is in **Pulang** mode (either auto-detected or manually set) and the technician taps the camera shutter button:
  - If handover is already filled for today: Shutter takes photo immediately and runs SOP verification.
  - If handover is NOT filled: Shutter does not take photo. A dark-themed bottom sheet (`HandoverPulangBottomSheet`) slides up over the camera viewfinder.
- **Form Behavior**:
  - Technician selects incoming IT Support from a quick dropdown list (`Junifer Manua`, `Ryan Lumasuge`, `Alessandro Sulistyo`, `Raldy Sangkop`, `Shift Terakhir / Tidak Ada Pengganti`).
  - Technician types completed work items freely. On newline / Enter, the input automatically prefixes `2. `, `3. `, etc.
  - Technician types pending tasks or leaves `-`.
  - Tapping **"Simpan & Lanjut Foto SOP Pulang"** validates inputs, stores them in `AbsensiSetupService` & `StorageService`, dismisses sheet, and automatically triggers the shutter photo capture.

---

## 3. Data Flow & Interfaces
- **Validation**:
  ```dart
  bool isDailyHandoverFilled({
    required String shiftSelanjutnya,
    required String pekerjaanSelesai,
    required String pekerjaanBelum,
  });
  ```
- **Text Controller**:
  `AutoNumberTextController` extending `TextEditingController` that handles line formatting and numbering on input changes without jumping cursor.
- **Storage**:
  `StorageService.hasCompletedTodayHandover()` and `StorageService.saveHandoverData(...)`.
- **Watermark & WhatsApp Sync**:
  Values seamlessly propagate to `SubmissionModel` and `WhatsAppReportService`.
