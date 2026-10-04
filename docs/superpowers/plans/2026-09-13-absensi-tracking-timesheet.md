# Absensi Tracking & Lembar Kerja (Arsip 30 Hari) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement full shift auto-detection, dynamic shutter pill (`Masuk : Shift(x)` and `Pulang (Jam Kerja)`), 30-day auto-pruning attendance timesheet ("Arsip"), watermark scale & font proportionality, isolated watermark pinch gesture, and technician name auto-sync.

**Architecture:** 
- `AttendanceRecord` data model tracking check-in/out, GPS, location, shift, duration, and AI verification status.
- `StorageService` extended with 30-day auto-pruning retention logic ensuring maximum ~25MB storage footprint.
- `CameraCaptureScreen` enhanced with dynamic status pill above camera shutter and drawer menu integration for "Arsip (Lembar Kerja Saya)".
- Viewfinder scale gestures isolated to watermark only.
- `AttendanceArchiveScreen` providing tabular timesheet view and CSV/Sheets export.

**Tech Stack:** Flutter / Dart, Shared Preferences, File I/O, Image Watermark Processor.

## Global Constraints
- Do NOT build APK during or at the end of implementation until explicitly requested by user.
- Watermark scale default is 1.0 (100%).
- Location text font size must be proportionally enlarged (13px - 13.5px bold/semi-bold).
- Viewfinder pinch must NOT zoom camera; zoom is only via on-screen buttons (1x, 2x, 5x).
- Attendance records auto-pruned to 30 days retention.
- All Flutter tests must pass with zero analyzer warnings or errors.

---

### Task 1: Cleanup Feature Tutorial Modal & Revert First-Launch Hook

**Files:**
- Delete: `lib/features/camera/widgets/feature_tutorial_modal.dart`
- Delete: `test/feature_tutorial_modal_test.dart`
- Modify: `lib/features/camera/screens/camera_capture_screen.dart:36-40,240-255`

**Interfaces:**
- Consumes: `CameraCaptureScreen` lifecycle
- Produces: Clean camera launch without tutorial modal interruption

- [ ] **Step 1: Check existing references to FeatureTutorialModal**

Run:
```bash
git grep -n "FeatureTutorialModal"
```

- [ ] **Step 2: Remove FeatureTutorialModal invocation and import in camera_capture_screen.dart**

In `lib/features/camera/screens/camera_capture_screen.dart`, remove:
```dart
import '../widgets/feature_tutorial_modal.dart';
```
and remove the post-frame callback:
```dart
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!StorageService.getHasSeenTutorial()) {
        FeatureTutorialModal.show(context);
      }
    });
```

- [ ] **Step 3: Delete feature_tutorial_modal.dart and its test**

Run:
```bash
rm -f lib/features/camera/widgets/feature_tutorial_modal.dart test/feature_tutorial_modal_test.dart
```

- [ ] **Step 4: Verify analyzer and test pass**

Run:
```bash
flutter analyze
```
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add lib/features/camera/screens/camera_capture_screen.dart
git commit -m "refactor: remove feature tutorial modal and first-launch hook"
```

---

### Task 2: Isolate Viewfinder Pinch Gesture (Watermark Resize Only)

**Files:**
- Modify: `lib/features/camera/screens/camera_capture_screen.dart:1560-1585`

**Interfaces:**
- Consumes: Viewfinder `GestureDetector`
- Produces: Pinch touches do not scale camera lens; watermark card handles its own pinch-resize

- [ ] **Step 1: Inspect gesture detector in camera preview**

In `lib/features/camera/screens/camera_capture_screen.dart`, locate viewfinder `GestureDetector`:
```dart
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (details) {
                      _handleTapToFocus(details.localPosition, frameW, frameH);
                    },
                    onScaleStart: (_) {
                      _baseCameraZoom = _currentZoom;
                    },
                    onScaleUpdate: (details) {
                      if (details.pointerCount >= 2) {
                        ...
                      }
                    },
```

- [ ] **Step 2: Remove onScaleStart and onScaleUpdate from viewfinder GestureDetector**

Modify to:
```dart
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (details) {
                      _handleTapToFocus(details.localPosition, frameW, frameH);
                    },
```

- [ ] **Step 3: Verify camera zoom controls remain functional via quick buttons**

Verify `_setZoom(1.0)`, `_setZoom(2.0)`, `_setZoom(5.0)` remain functional in sidebar controls.

- [ ] **Step 4: Run flutter analyze**

Run:
```bash
flutter analyze
```

- [ ] **Step 5: Commit**

```bash
git add lib/features/camera/screens/camera_capture_screen.dart
git commit -m "fix(camera): isolate pinch gesture to watermark card only, zoom via buttons"
```

---

### Task 3: Re-Scale Watermark Default to 100% & Proportional Location Font

**Files:**
- Modify: `lib/data/models/watermark_config.dart:100-115,170-180`
- Modify: `lib/features/camera/widgets/interactive_watermark.dart:335-360,510-530`
- Modify: `lib/core/utils/watermark_painter.dart:230-260,490-515`
- Test: `test/watermark_config_test.dart`

**Interfaces:**
- Consumes: `WatermarkConfig`
- Produces: Default watermark scale 1.0 (100%) and 13px bold location text

- [ ] **Step 1: Write test verifying WatermarkConfig default scale is 1.0**

Create `test/watermark_config_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bssparking_timemark/data/models/watermark_config.dart';

void main() {
  test('WatermarkConfig defaults to 1.0 scale and proportional values', () {
    const config = WatermarkConfig();
    expect(config.scale, equals(1.0));
  });
}
```

- [ ] **Step 2: Update WatermarkConfig default scale from 0.5 to 1.0**

In `lib/data/models/watermark_config.dart`:
Change:
```dart
    this.scale = 0.5,
```
To:
```dart
    this.scale = 1.0,
```
And in `fromJson`:
```dart
        scale: (json['scale'] as num?)?.toDouble() ?? 1.0,
```

- [ ] **Step 3: Enlarge location text font size in InteractiveWatermark and WatermarkPainter**

In `lib/features/camera/widgets/interactive_watermark.dart`:
Update location font size to `13.0` with `FontWeight.w700`.
In `lib/core/utils/watermark_painter.dart`:
Update location font size to `13.0` with `FontWeight.w700`.

- [ ] **Step 4: Run test and flutter analyze**

Run:
```bash
flutter test test/watermark_config_test.dart
flutter analyze
```
Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/data/models/watermark_config.dart lib/features/camera/widgets/interactive_watermark.dart lib/core/utils/watermark_painter.dart test/watermark_config_test.dart
git commit -m "feat(watermark): set default scale to 100% and enlarge location font to 13px"
```

---

### Task 4: AttendanceRecord Data Model & 30-Day Auto-Pruning Storage

**Files:**
- Create: `lib/data/models/attendance_record.dart`
- Modify: `lib/data/services/storage_service.dart`
- Test: `test/attendance_storage_test.dart`

**Interfaces:**
- Consumes: SharedPreferences
- Produces: `AttendanceRecord` serialization, `saveAttendanceRecord`, `getAttendanceRecords`, `autoPruneAttendanceRecords30Days`

- [ ] **Step 1: Write test for AttendanceRecord and 30-day pruning**

Create `test/attendance_storage_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bssparking_timemark/data/models/attendance_record.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  test('AttendanceRecord serialization works', () {
    final record = AttendanceRecord(
      id: 'att_1',
      timestamp: DateTime.now(),
      type: AttendanceType.masuk,
      shiftName: 'Shift 1 (03:00 - 11:00)',
      technicianName: 'Farhan Lakoro',
      posName: 'PKM Kalimas',
      lat: 1.500147,
      lng: 124.850032,
      fullAddress: 'Singkil Satu, Manado',
      isAiVerified: true,
      aiStatusText: 'SESUAI SOP',
    );

    final json = record.toJson();
    final restored = AttendanceRecord.fromJson(json);

    expect(restored.id, equals('att_1'));
    expect(restored.type, equals(AttendanceType.masuk));
    expect(restored.technicianName, equals('Farhan Lakoro'));
  });

  test('StorageService autoPruneAttendanceRecords removes entries older than 30 days', () async {
    final now = DateTime.now();
    final freshRecord = AttendanceRecord(
      id: 'fresh',
      timestamp: now.subtract(const Duration(days: 5)),
      type: AttendanceType.masuk,
      shiftName: 'Shift 1',
      technicianName: 'Farhan',
      posName: 'PKM',
      lat: 1.5,
      lng: 124.8,
      fullAddress: 'Manado',
    );

    final expiredRecord = AttendanceRecord(
      id: 'expired',
      timestamp: now.subtract(const Duration(days: 35)),
      type: AttendanceType.pulang,
      shiftName: 'Shift 1',
      technicianName: 'Farhan',
      posName: 'PKM',
      lat: 1.5,
      lng: 124.8,
      fullAddress: 'Manado',
    );

    await StorageService.saveAttendanceRecord(freshRecord);
    await StorageService.saveAttendanceRecord(expiredRecord);

    await StorageService.autoPruneAttendanceRecords(retentionDays: 30);
    final records = StorageService.getAttendanceRecords();

    expect(records.length, equals(1));
    expect(records.first.id, equals('fresh'));
  });
}
```

- [ ] **Step 2: Implement AttendanceRecord model**

Create `lib/data/models/attendance_record.dart`:
```dart
enum AttendanceType { masuk, pulang }

class AttendanceRecord {
  final String id;
  final DateTime timestamp;
  final AttendanceType type;
  final String shiftName;
  final String technicianName;
  final String posName;
  final double lat;
  final double lng;
  final String fullAddress;
  final String? photoPath;
  final String? workDuration;
  final bool isAiVerified;
  final String aiStatusText;

  AttendanceRecord({
    required this.id,
    required this.timestamp,
    required this.type,
    required this.shiftName,
    required this.technicianName,
    required this.posName,
    required this.lat,
    required this.lng,
    required this.fullAddress,
    this.photoPath,
    this.workDuration,
    this.isAiVerified = true,
    this.aiStatusText = 'SESUAI SOP',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'timestamp': timestamp.toIso8601String(),
    'type': type.name,
    'shiftName': shiftName,
    'technicianName': technicianName,
    'posName': posName,
    'lat': lat,
    'lng': lng,
    'fullAddress': fullAddress,
    'photoPath': photoPath,
    'workDuration': workDuration,
    'isAiVerified': isAiVerified,
    'aiStatusText': aiStatusText,
  };

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) => AttendanceRecord(
    id: json['id'] as String,
    timestamp: DateTime.parse(json['timestamp'] as String),
    type: (json['type'] as String) == 'pulang' ? AttendanceType.pulang : AttendanceType.masuk,
    shiftName: json['shiftName'] as String? ?? '',
    technicianName: json['technicianName'] as String? ?? '',
    posName: json['posName'] as String? ?? '',
    lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
    lng: (json['lng'] as num?)?.toDouble() ?? 0.0,
    fullAddress: json['fullAddress'] as String? ?? '',
    photoPath: json['photoPath'] as String?,
    workDuration: json['workDuration'] as String?,
    isAiVerified: json['isAiVerified'] as bool? ?? true,
    aiStatusText: json['aiStatusText'] as String? ?? 'SESUAI SOP',
  );
}
```

- [ ] **Step 3: Implement Attendance methods in StorageService**

In `lib/data/services/storage_service.dart`, add:
- `static const String _keyAttendanceRecords = 'bss_attendance_records_v1';`
- `static List<AttendanceRecord> getAttendanceRecords()`
- `static Future<void> saveAttendanceRecord(AttendanceRecord record)`
- `static Future<void> deleteAttendanceRecord(String id)`
- `static Future<void> autoPruneAttendanceRecords({int retentionDays = 30})`

- [ ] **Step 4: Run tests and verify 100% pass**

Run:
```bash
flutter test test/attendance_storage_test.dart
flutter analyze
```

- [ ] **Step 5: Commit**

```bash
git add lib/data/models/attendance_record.dart lib/data/services/storage_service.dart test/attendance_storage_test.dart
git commit -m "feat(attendance): add AttendanceRecord and 30-day auto-pruning storage"
```

---

### Task 5: Dynamic Shutter Shortcut Pill (`Masuk: Shift(x)` & `Pulang (Jam Kerja)`) & Technician Sync

**Files:**
- Modify: `lib/features/camera/screens/camera_capture_screen.dart`
- Modify: `lib/features/templates/widgets/absensi_kategori_dialog.dart`
- Test: `test/attendance_flow_test.dart`

**Interfaces:**
- Consumes: `AbsensiSetupService`, `StorageService`
- Produces: Real-time dynamic pill above camera shutter, technician name sync to maintenance

- [ ] **Step 1: Write test for shift detection & technician sync**

Create `test/attendance_flow_test.dart`:
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

  test('Auto-detect shift returns valid shift string', () {
    final morning = DateTime(2026, 9, 14, 8, 30);
    expect(AbsensiSetupService.autoDetectShift(morning), contains('Shift 1'));

    final noon = DateTime(2026, 9, 14, 10, 15);
    expect(AbsensiSetupService.autoDetectShift(noon), contains('Shift 2.2'));

    final afternoon = DateTime(2026, 9, 14, 12, 0);
    expect(AbsensiSetupService.autoDetectShift(afternoon), contains('Shift 2'));

    final evening = DateTime(2026, 9, 14, 15, 0);
    expect(AbsensiSetupService.autoDetectShift(evening), contains('Shift 3'));
  });

  test('Technician name sync persists to StorageService', () async {
    await StorageService.saveLastTechnicianName('Farhan Lakoro');
    expect(StorageService.getLastTechnicianName(), equals('Farhan Lakoro'));
  });
}
```

- [ ] **Step 2: Add technician name picker in AbsensiKategoriDialog**

In `lib/features/templates/widgets/absensi_kategori_dialog.dart`:
When `setup.selectedKategori == AbsensiKategori.teknisi`, add text/dropdown field for technician name. On save, call `StorageService.saveLastTechnicianName(name)`.

- [ ] **Step 3: Add dynamic shortcut pill above camera shutter in camera_capture_screen.dart**

In `lib/features/camera/screens/camera_capture_screen.dart`:
Above the shutter button:
- When not checked in: `[ 🟢 Masuk : ${AbsensiSetupService.autoDetectShift()} ▾ ]`
- When checked in: `[ 🔵 Pulang (Kerja: $workDuration) ▾ ]`
- Tapping pill opens `AbsensiKategoriDialog`.
- On photo capture completion:
  - If Masuk: saves check-in time and `AttendanceRecord`, switches UI to Pulang mode.
  - If Pulang: saves check-out `AttendanceRecord` with total work duration.

- [ ] **Step 4: Run tests and analyzer**

Run:
```bash
flutter test test/attendance_flow_test.dart
flutter analyze
```

- [ ] **Step 5: Commit**

```bash
git add lib/features/templates/widgets/absensi_kategori_dialog.dart lib/features/camera/screens/camera_capture_screen.dart test/attendance_flow_test.dart
git commit -m "feat(attendance): dynamic shift pill, work timer, and technician sync"
```

---

### Task 6: "Arsip (Lembar Kerja Saya)" Screen & Hamburger Menu Integration

**Files:**
- Create: `lib/features/history/screens/attendance_archive_screen.dart`
- Modify: `lib/features/camera/screens/camera_capture_screen.dart` (drawer menu item)
- Test: `test/attendance_archive_screen_test.dart`

**Interfaces:**
- Consumes: `StorageService.getAttendanceRecords()`
- Produces: `AttendanceArchiveScreen` table, CSV export, image modal

- [ ] **Step 1: Write test for AttendanceArchiveScreen**

Create `test/attendance_archive_screen_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bssparking_timemark/data/models/attendance_record.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';
import 'package:bssparking_timemark/features/history/screens/attendance_archive_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    await StorageService.saveAttendanceRecord(
      AttendanceRecord(
        id: 'test_1',
        timestamp: DateTime(2026, 9, 14, 8, 15),
        type: AttendanceType.masuk,
        shiftName: 'Shift 1 (03:00 - 11:00)',
        technicianName: 'Farhan Lakoro',
        posName: 'PKM Kalimas',
        lat: 1.500147,
        lng: 124.850032,
        fullAddress: 'Singkil Satu, Manado',
      ),
    );
  });

  testWidgets('AttendanceArchiveScreen renders table and records', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AttendanceArchiveScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Arsip (Lembar Kerja Saya)'), findsOneWidget);
    expect(find.text('PKM Kalimas'), findsOneWidget);
    expect(find.text('Jam Masuk'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Implement AttendanceArchiveScreen**

Create `lib/features/history/screens/attendance_archive_screen.dart` with:
- Summary KPI Cards: Total Hari Hadir, Total Jam Kerja
- Table with columns: Foto | Status | Waktu | Tanggal | Lokasi & GPS
- Tap on photo opens full-screen dialog
- Action button: `[ 📊 Bagikan / Export ke Sheets (CSV) ]` and `[ 🗑️ Hapus Riwayat ]`
- Retention banner: `🛡️ Hanya 30 hari terakhir dari catatan yang disimpan otomatis.`

- [ ] **Step 3: Add "Arsip (Lembar Kerja Saya)" menu in Drawer of CameraCaptureScreen**

In `lib/features/camera/screens/camera_capture_screen.dart`:
In `_buildDrawer(context)`, add ListTile:
- Leading icon: `Icons.folder_shared_rounded`
- Title: `Arsip (Lembar Kerja Saya)`
- Trailing badge: `30 Hari`
- OnTap: Navigate to `AttendanceArchiveScreen`

- [ ] **Step 4: Run tests and analyzer**

Run:
```bash
flutter test test/attendance_archive_screen_test.dart
flutter analyze
```

- [ ] **Step 5: Commit**

```bash
git add lib/features/history/screens/attendance_archive_screen.dart lib/features/camera/screens/camera_capture_screen.dart test/attendance_archive_screen_test.dart
git commit -m "feat(archive): implement AttendanceArchiveScreen and drawer navigation"
```

---

### Task 7: Comprehensive Suite Verification & Knowledge Graph Sync

**Files:**
- Verify: Full test suite (`flutter test`)
- Verify: Code analysis (`flutter analyze`)
- Run: `graphify update .`

- [ ] **Step 1: Run all unit tests**

Run:
```bash
flutter test
```
Expected: All tests pass.

- [ ] **Step 2: Run Flutter analyze**

Run:
```bash
flutter analyze
```
Expected: `No issues found!`

- [ ] **Step 3: Sync knowledge graph via graphify update**

Run:
```bash
graphify update .
```

- [ ] **Step 4: Update Obsidian Memory Vault**

Update `Memory/Projects/BssparkingTimeMark.md` with session changelog and attendance feature documentation.
