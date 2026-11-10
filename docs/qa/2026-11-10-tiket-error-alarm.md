# QA Verification Report: Tiket Error v2 (Alarm Overlay, ErrorAlarmService & Branch-Wide Error Tickets)

**Date**: 2026-11-10  
**Target**: Tiket Error v2 Regression & Release APK Build  
**Auditor**: Tukang QA (worker: qa)  

---

## 1. Static Analysis (`flutter analyze`)

- **Command**: `flutter analyze`
- **Exit Code**: `0`
- **Result**: `No issues found! (ran in 15.0s)`

---

## 2. Full Test Suite (`flutter test`)

- **Command**: `flutter test`
- **Exit Code**: `1`
- **Summary**:
  - **Passed**: 893
  - **Skipped**: 42
  - **Failed**: 1

### Failing Test (Stale Due to Intended Spec Change)
- **File**: `test/daily_task_teknisi_scope_test.dart:83:7`
- **Test Name**: `reserved PostgREST characters in the name are stripped from the filter`
- **Status**: **Stale Test** (Not a production bug)
- **Root Cause**:
  `DailyTaskService.getTasksForTeknisi` was updated in Tiket Error v2 so technicians receive branch-wide open error tickets regardless of individual assignment, appending an `and(kategori.eq.error,status.eq.pending)` clause into the PostgREST filter string. The test's internal query string parser:
  ```dart
  final group = filter.substring(filter.lastIndexOf('or(') + 3, filter.length - 2);
  ```
  splits across commas and asserts all segments match `^(teknisi_nama|peserta)\.ilike\.\*[^,()*:.]+\*$`. The newly introduced error ticket condition `and(kategori.eq.error` violates that legacy regex assumption.
- **Log Excerpt**:
  ```text
  00:36 +465 ~30 -1: /home/annnpii/Product development annpii/BssparkingTimeMark/test/daily_task_teknisi_scope_test.dart: reserved PostgREST characters in the name are stripped from the filter [E]
    Expected: match '^(teknisi_nama|peserta)\.ilike\.\*[^,()*:.]+\*$'
      Actual: 'and(kategori.eq.error'
    un-sanitized filter segment: and(kategori.eq.error
    
    package:matcher                                     expect
    package:flutter_test/src/widget_tester.dart 473:18  expect
    test/daily_task_teknisi_scope_test.dart 83:7        main.<fn>
  ```

---

## 3. Read-Only Edge Function Audit: `supabase/functions/daily-tasks/index.ts`

**Question**: What happens when a technician session completes (`PATCH status completed`) an error task whose `teknisi_nama` is another user (e.g. SPV)? `403` or allowed?

**Answer**:
1. **HTTP Method Rejection (`405 Method Not Allowed`)**:
   - `supabase/functions/daily-tasks/index.ts:53-55`: The function only accepts `POST` requests. Direct HTTP `PATCH` requests are rejected immediately with `405`.
2. **Technician Permission Gate (`403 Forbidden`)**:
   - `supabase/functions/daily-tasks/index.ts:63`: `const spv = isSpv(session);`
   - `supabase/functions/daily-tasks/index.ts:101-103`:
     ```ts
     if (!spv && action !== 'create') {
       return json({ error: 'forbidden' }, 403);
     }
     ```
     If a non-SPV technician session calls `daily-tasks` with any action other than `create` (such as `transfer` or `delete`), it is blocked with `403 Forbidden`. The edge function does not provide a task completion action.
3. **Client Architecture Reality**:
   - In `lib/data/services/daily_task_service.dart:1247-1257`, completing a task is executed via a direct PostgREST call (`PATCH /rest/v1/$tasksTable?id=eq.$taskId`), completely bypassing the `daily-tasks` edge function.

---

## 4. Release APK Build (arm64-v8a)

- **Command**: `flutter build apk --release --split-per-abi --target-platform android-arm64`
- **Exit Code**: `0`
- **Artifact Path**: `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`
- **Size**: 24.6 MB (24,629,380 bytes / 23.5 MiB)
- **Resource Verification (`error_alarm.ogg`)**:
  - Source file: `android/app/src/main/res/raw/error_alarm.ogg` (7,161 bytes) kept via `android/app/src/main/res/raw/keep.xml` (`tools:keep="@raw/error_alarm"`).
  - AAPT2 resource table verification (`aapt2 dump resources build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`):
    ```text
    type raw id=0d entryCount=1
      resource 0x7f0d0000 raw/error_alarm
        () (file) res/yX.ogg
    ```
  - In release mode, AAPT2/AGP resource optimization renamed the physical entry inside the zip file to `res/yX.ogg` (7,161 bytes), while preserving the resource symbol `raw/error_alarm` (ID `0x7f0d0000`) in `resources.arsc`. Direct `unzip -l | grep error_alarm` matched 0 entries due to the collapsed zip path name, but the resource is verified present and properly mapped.

---

## 5. Device Installation Status

- **Command**: `adb devices`
- **Exit Code**: `0`
- **Output**:
  ```text
  List of devices attached
  (no devices listed)
  ```
- **Result**: No connected Infinix or Android device detected via ADB; APK installation skipped.
