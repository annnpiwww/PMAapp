# Handover Pulang & Daily Job Gating Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement mandatory daily job logging (with intelligent auto-numbering `1. `, `2. `, `3. `) and incoming IT Support before technicians can capture an attendance check-out (Pulang) photo, with the prompt copy "Isi daily dulu ya!".

**Architecture:** Approach A (Shutter Intercept Guard & Bottom Sheet). Tapping the camera shutter button in Pulang mode checks if the daily report has been completed for today. If not, shutter capture is paused and `DailyPulangBottomSheet` slides up with banner "Isi daily dulu ya!", allowing the technician to select the next technician and type completed/pending tasks with automatic list numbering. Saving the sheet unlocks and triggers the shutter.

**Tech Stack:** Flutter, Dart, SharedPreferences (`StorageService`), Plus Jakarta Sans typography.

## Global Constraints

- **Language Style:** Clean Dart, zero analyzer warnings (`flutter analyze`).
- **Typography & Theme:** Midnight dark theme matching existing BSS TimeMark styling (`#0B132B`, `#0F172A`, `#1E293B`, Sky Blue `#38BDF8`, Amber `#F59E0B`).
- **Copy Rule:** Replace the word "handover" with "Isi daily dulu ya!" in all UI badges, headers, and toast/snackbars.
- **No Quick Templates:** Free-form typing only; auto-numbering automatically manages line prefixes.
- **Zero-Grep Policy:** Use CodeGraph & Graphify for code navigation and synchronization.

---

### Task 1: AutoNumberTextController for Intelligent List Numbering

**Files:**
- Create: `lib/core/utils/auto_number_text_controller.dart`
- Test: `test/auto_number_text_controller_test.dart`

**Interfaces:**
- Consumes: Flutter `TextEditingController`.
- Produces: `class AutoNumberTextController extends TextEditingController` that automatically prefixes `1. ` on the first line and adds `N+1. ` when a newline is created.

- [ ] **Step 1: Write the failing unit test**

Create `test/auto_number_text_controller_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bssparking_timemark/core/utils/auto_number_text_controller.dart';

void main() {
  group('AutoNumberTextController', () {
    test('automatically prefixes 1. when typing on empty controller', () {
      final controller = AutoNumberTextController();
      controller.text = 'Perbaikan printer';
      expect(controller.text, '1. Perbaikan printer');
    });

    test('automatically adds next number on newline', () {
      final controller = AutoNumberTextController();
      controller.text = '1. Perbaikan printer\n';
      controller.handleNewline();
      expect(controller.text, '1. Perbaikan printer\n2. ');
    });

    test('cleans and formats multi-line raw text', () {
      final result = AutoNumberTextController.formatNumberedLines('Line one\nLine two\nLine three');
      expect(result, '1. Line one\n2. Line two\n3. Line three');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/auto_number_text_controller_test.dart`
Expected: FAIL (file or class not found).

- [ ] **Step 3: Implement AutoNumberTextController**

Create `lib/core/utils/auto_number_text_controller.dart`:
```dart
import 'package:flutter/material.dart';

class AutoNumberTextController extends TextEditingController {
  bool _isFormatting = false;

  AutoNumberTextController({String? text}) : super(text: text) {
    if (text != null && text.isNotEmpty) {
      _applyInitialFormatting(text);
    }
  }

  void _applyInitialFormatting(String raw) {
    final formatted = formatNumberedLines(raw);
    if (formatted != raw) {
      this.text = formatted;
    }
  }

  static String formatNumberedLines(String? raw) {
    if (raw == null || raw.trim().isEmpty || raw.trim() == '-') return '-';
    final lines = raw
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    if (lines.isEmpty) return '-';
    final numbered = <String>[];
    int counter = 1;

    for (final line in lines) {
      final numRegex = RegExp(r'^(\d+[\.\)]|\-|\*|\•)\s*');
      final clean = numRegex.hasMatch(line)
          ? line.replaceFirst(numRegex, '').trim()
          : line;
      if (clean.isNotEmpty) {
        numbered.add('$counter. $clean');
        counter++;
      }
    }
    return numbered.isEmpty ? '-' : numbered.join('\n');
  }

  void handleNewline() {
    if (_isFormatting) return;
    final current = text;
    if (current.isEmpty) {
      text = '1. ';
      selection = const TextSelection.collapsed(offset: 3);
      return;
    }

    final lines = current.split('\n');
    final nextNum = lines.length + 1;
    final newText = current.endsWith('\n') ? '$current$nextNum. ' : '$current\n$nextNum. ';
    _isFormatting = true;
    text = newText;
    selection = TextSelection.collapsed(offset: newText.length);
    _isFormatting = false;
  }

  @override
  set value(TextEditingValue newValue) {
    if (_isFormatting) {
      super.value = newValue;
      return;
    }

    final oldText = text;
    final newText = newValue.text;

    // Jika teks berubah dari kosong menjadi mulai mengetik tanpa prefix angka
    if (oldText.isEmpty && newText.isNotEmpty && !newText.startsWith(RegExp(r'^\d+\.\s*'))) {
      _isFormatting = true;
      final updated = '1. $newText';
      super.value = TextEditingValue(
        text: updated,
        selection: TextSelection.collapsed(offset: updated.length),
      );
      _isFormatting = false;
      return;
    }

    // Jika menekan enter (terdeteksi newline baru di ujung)
    if (newText.length > oldText.length && newText.endsWith('\n')) {
      final lines = newText.substring(0, newText.length - 1).split('\n');
      final nextNum = lines.length + 1;
      final updated = '$newText$nextNum. ';
      _isFormatting = true;
      super.value = TextEditingValue(
        text: updated,
        selection: TextSelection.collapsed(offset: updated.length),
      );
      _isFormatting = false;
      return;
    }

    super.value = newValue;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/auto_number_text_controller_test.dart`
Expected: PASS.

- [ ] **Step 5: Verify static analysis**

Run: `flutter analyze`
Expected: No issues found!

---

### Task 2: Handover Validation & Persistence in AbsensiSetupService & StorageService

**Files:**
- Modify: `lib/data/services/storage_service.dart`
- Modify: `lib/data/services/absensi_setup_service.dart`
- Test: `test/handover_validation_test.dart`

**Interfaces:**
- Produces:
  - `AbsensiSetupService.isDailyHandoverComplete()`: Checks if `shiftSelanjutnya` and `pekerjaanSelesai` are properly filled.
  - `StorageService.isHandoverCompletedToday()`
  - `StorageService.markHandoverCompletedToday(bool)`

- [ ] **Step 1: Write the failing unit test**

Create `test/handover_validation_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bssparking_timemark/data/services/absensi_setup_service.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  test('isDailyHandoverComplete returns false when fields are default/empty', () {
    final setup = AbsensiSetupService.instance;
    setup.updateNextShift('-');
    setup.updatePekerjaanSelesai('-');
    expect(setup.isDailyHandoverComplete(), isFalse);
  });

  test('isDailyHandoverComplete returns true when valid next shift and completed tasks exist', () {
    final setup = AbsensiSetupService.instance;
    setup.updateNextShift('Ryan Lumasuge');
    setup.updatePekerjaanSelesai('1. Pembersihan printer');
    expect(setup.isDailyHandoverComplete(), isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/handover_validation_test.dart`
Expected: FAIL (`isDailyHandoverComplete` not defined).

- [ ] **Step 3: Implement validation in AbsensiSetupService and StorageService**

Update `lib/data/services/absensi_setup_service.dart`:
```dart
  bool isDailyHandoverComplete() {
    final next = shiftSelanjutnya.trim();
    final selesai = pekerjaanSelesai.trim();

    final hasNext = next.isNotEmpty &&
        next != '-' &&
        !next.toLowerCase().contains('tidak ada petugas');

    final hasSelesai = selesai.isNotEmpty &&
        selesai != '-' &&
        selesai != '1. -' &&
        selesai.length >= 3;

    return hasNext && hasSelesai;
  }
```

Update `lib/data/services/storage_service.dart`:
Add methods to persist whether handover has been verified for today:
```dart
  static const _keyLastHandoverDate = 'last_handover_date';

  static bool isHandoverCompletedToday() {
    final dateStr = _prefs?.getString(_keyLastHandoverDate);
    if (dateStr == null) return false;
    final now = DateTime.now();
    final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return dateStr == today;
  }

  static Future<void> markHandoverCompletedToday() async {
    final now = DateTime.now();
    final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    await _prefs?.setString(_keyLastHandoverDate, today);
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/handover_validation_test.dart`
Expected: PASS.

---

### Task 3: Build Reusable HandoverPulangBottomSheet

**Files:**
- Create: `lib/features/camera/widgets/handover_pulang_bottom_sheet.dart`

**Interfaces:**
- Produces: `static Future<bool?> show(BuildContext context)` returning `true` when technician saves valid handover data.

- [ ] **Step 1: Implement HandoverPulangBottomSheet**

Create `lib/features/camera/widgets/handover_pulang_bottom_sheet.dart`:
- Match Midnight Dark theme (`#0F172A`, `#1E293B`).
- IT Support Shift Selanjutnya selector with existing technicians + `Shift Terakhir / Tidak Ada Pengganti`.
- `AutoNumberTextController` for `pekerjaanSelesai` and `pekerjaanBelum`.
- "Simpan & Lanjut Foto SOP Pulang" button with form validation.
- Updates `AbsensiSetupService`, calls `StorageService.markHandoverCompletedToday()`, and pops `true`.

- [ ] **Step 2: Verify with flutter analyze**

Run: `flutter analyze`
Expected: No issues found!

---

### Task 4: Integrate Shutter Intercept Guard in CameraCaptureScreen

**Files:**
- Modify: `lib/features/camera/screens/camera_capture_screen.dart`

**Interfaces:**
- Consumes: `HandoverPulangBottomSheet.show(context)`, `AbsensiSetupService.instance.isDailyHandoverComplete()`.

- [ ] **Step 1: Add Shutter Intercept in `_handleCapturePhoto()`**

In `lib/features/camera/screens/camera_capture_screen.dart`, at the start of `_handleCapturePhoto()`:
```dart
    final absSetup = AbsensiSetupService.instance;
    final isAbsensi = _selectedTemplate.jenis == TemplateCategory.absensi;
    final isPulangMode = absSetup.tipeLaporan == 'Pulang';

    if (isAbsensi && isPulangMode && !absSetup.isDailyHandoverComplete()) {
      _isProcessingAI = false;
      _captureStep = 0;
      final saved = await HandoverPulangBottomSheet.show(context);
      if (saved == true && mounted) {
        // Handover berhasil disimpan, langsung jepret foto SOP Pulang
        _handleCapturePhoto();
      }
      return;
    }
```

- [ ] **Step 2: Update Attendance Shortcut Pill in Camera**

When in Pulang mode and `!isDailyHandoverComplete()`, display a warning badge: `Pulang (Kerja: Xj Ym) • Wajib Handover`. Tapping the pill also opens `HandoverPulangBottomSheet.show(context)`.

- [ ] **Step 3: Run static analysis**

Run: `flutter analyze`
Expected: No issues found!

---

### Task 5: End-to-End Test Suite & Sync Knowledge Graph

**Files:**
- Modify: `test/attendance_flow_test.dart`

- [ ] **Step 1: Add end-to-end unit tests for Handover Intercept Flow**

Add test cases to `test/attendance_flow_test.dart`:
1. Auto-pulang mode triggers handover gating when empty.
2. Form completion marks handover valid and allows attendance completion.
3. Next technician is correctly embedded in WhatsApp share text.

- [ ] **Step 2: Run all unit tests**

Run: `flutter test`
Expected: All tests pass!

- [ ] **Step 3: Update Graphify knowledge graph**

Run: `graphify update .`
Expected: AST synced with 0 errors.
