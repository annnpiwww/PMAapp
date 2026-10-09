# Multi-Branch Universal (Manado & Bali) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement clean Multi-Branch architecture in 1 Universal APK supporting KC Manado and KC Bali with dynamic branch config, isolated technicians, shifts, 15 Bali locations, custom recap header, and offline fallback.

**Architecture:** A centralized `BranchService` provides branch definitions (`AppBranch`), active branch state persistence via `StorageService`, and dynamic data loaders for technicians, shifts, and locations. `LoginScreen` adds branch selection with auto-detection on login. `SpvTaskDispatcherScreen`, `AbsensiSetupService`, and `DailyTaskService.formatSpvTeamRecap` dynamically consume `BranchService.currentBranch`.

**Tech Stack:** Flutter (Dart 3.11), SharedPreferences (`StorageService`), PocketBase REST/SSE (`DailyTaskService`).

## Global Constraints
- Single Universal APK (no separate branch folders, no hardcoded APK drift).
- Watermark photo remains labeled "Absensi" (not "KC Bali").
- WhatsApp SPV recap for Bali must strictly use header `REKAP DAILY TEAM PMA KC BALI` and `SPV : Indra Yohana`.
- Offline fallback credentials must allow seamless login in basements without signal.
- 100% existing tests (222 tests) must remain green with zero regressions.

---

### Task 1: Create `BranchService` & `AppBranch` Model

**Files:**
- Create: `lib/data/services/branch_service.dart`
- Test: `test/branch_service_test.dart`

**Interfaces:**
- Produces: `enum AppBranch`, `class BranchService` with `AppBranch get currentBranch`, `void setBranch(AppBranch branch)`, `List<String> getTechnicians()`, `List<String> getShifts()`, `List<String> getLocationTags()`.

- [ ] **Step 1: Write unit tests for `BranchService`**
  - Verify default branch is `KC Manado`.
  - Verify switching to `KC Bali` provides 6 technicians (Putu Hyan, Alif Candra, I Putu Indra, I Putu Gede, Aditya, Anak Agung).
  - Verify Bali shifts provide 6 shifts starting from `Shift 1 (06.00-14.00)` to `Shift 4.1 (08.00-12.00)`.
  - Verify Bali location tags provide 15 pos (`PBKD`, `PCD`, `PKRD`, `PAS`, `PSD`, `PGA`, `TBB`, `TBG`, `KIH`, `BMS`, `BMK`, `SPD`, `GYS`, `PBB`, `RSPM`).
- [ ] **Step 2: Implement `BranchService` and `AppBranch`**
  - Implement enum and service with `ChangeNotifier` and `StorageService` persistence.
- [ ] **Step 3: Run tests and verify green**

---

### Task 2: Dynamic Header in `DailyTaskService.formatSpvTeamRecap`

**Files:**
- Modify: `lib/data/services/daily_task_service.dart`
- Test: `test/daily_task_formatters_test.dart`

**Interfaces:**
- Modifies: `DailyTaskService.formatSpvTeamRecap({required String tanggal, required List<DailyTaskModel> tasks, String? spvName, String? cabangName, AppBranch? branch})`

- [ ] **Step 1: Write test for Bali SPV team recap format**
  - Verify output header contains `REKAP DAILY TEAM PMA KC BALI`.
  - Verify output contains `SPV : Indra Yohana` (or provided SPV name).
- [ ] **Step 2: Implement dynamic header logic in `DailyTaskService`**
- [ ] **Step 3: Run tests and verify green**

---

### Task 3: Bali Accounts & Offline Fallback in `AuthRepository`

**Files:**
- Modify: `lib/data/repositories/auth_repository.dart`
- Test: `test/auth_repository_test.dart`

**Interfaces:**
- Produces: SPV Bali account (`indra@pma.com` / `spvbali`), 5 Technician Bali accounts (`parta@pma.com`, `toro@pma.com`, `suardana@pma.com`, `dika@pma.com`, `cokagung@pma.com`).
- Updates `BranchService.setBranch(AppBranch.bali)` automatically upon Bali user login.

- [ ] **Step 1: Write unit tests for Bali login**
- [ ] **Step 2: Update `hardcodedAccounts` and online login mapping in `AuthRepository`**
- [ ] **Step 3: Run tests and verify green**

---

### Task 4: Connect Branch Data to `AbsensiSetupService`, `LocationService`, & `SpvTaskDispatcherScreen`

**Files:**
- Modify: `lib/data/services/absensi_setup_service.dart`
- Modify: `lib/data/services/location_service.dart`
- Modify: `lib/features/daily_tasks/screens/spv_task_dispatcher_screen.dart`
- Modify: `lib/features/templates/widgets/absensi_kategori_dialog.dart`

- [ ] **Step 1: Seed 15 Bali locations in `LocationService`**
- [ ] **Step 2: Adapt `AbsensiSetupService` shift options and autoDetectShift to current branch**
- [ ] **Step 3: Adapt `SpvTaskDispatcherScreen` technician dropdown and default pos (`PBKD` for Bali, `TBM` for Manado)**
- [ ] **Step 4: Adapt `AbsensiKategoriDialog` technician picker to current branch**

---

### Task 5: Branch Selector UI on `LoginScreen`

**Files:**
- Modify: `lib/features/auth/screens/login_screen.dart`

- [ ] **Step 1: Add branch selector pills `[ 📍 KC Manado ]` and `[ 📍 KC Bali ]` above login inputs**
- [ ] **Step 2: Wire state change to `BranchService`**
- [ ] **Step 3: Verify visual rendering**

---

### Task 6: Quality Verification, Version Bump, & Telegram APK Delivery

**Files:**
- Modify: `pubspec.yaml` (bump to 2.0.75+83)
- Modify: `CHANGELOG.md`
- Modify: `Memory/Projects/BssparkingTimeMark.md`

- [ ] **Step 1: Run `flutter analyze` (must be 0 issues)**
- [ ] **Step 2: Run full test suite `flutter test` (all tests passing)**
- [ ] **Step 3: Build split APKs (arm32 & arm64)**
- [ ] **Step 4: Send both APKs to Telegram bot via `tools/telegram_notify.sh`**
