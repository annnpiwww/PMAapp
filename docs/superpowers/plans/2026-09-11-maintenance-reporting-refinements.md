# Implementation Plan: Maintenance & Reporting System Refinements

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement 12 items of maintenance & reporting enhancements, form simplification, shift 2.2 synchronization, auto-numbering, and security restriction.

**Architecture:** 
3 layers:
1. `whatsapp_report_service.dart` & `absensi_setup_service.dart` for text generation, AI vision result extraction, single-pos detection, shift 2.2 time-greeting rules, and task auto-numbering.
2. `absensi_kategori_dialog.dart`, `location_management_screen.dart`, and `location_picker_modal.dart` for UI forms, Shift 2.2 button, colleague dropdown, and location field simplification.
3. `maintenance_setup_dialog.dart`, `camera_capture_screen.dart`, and `template_list_screen.dart` for placeholder Farhan Lakoro, SOP template management security, and Telegram HTML/CSS report generation.

**Tech Stack:** Flutter / Dart, Material 3, SharedPreferences, Telegram Bot API.

---

### Task 1: Report Engine & Text Formatter Refactor (Poin 1, 2, 3, 8)
**Files:**
- Modify: `lib/data/services/whatsapp_report_service.dart`
- Modify: `lib/data/services/absensi_setup_service.dart`
- Test: `test/whatsapp_report_test.dart`

- [ ] **Step 1: Write test for AI vision description in green status & single unit prefix omission**
- [ ] **Step 2: Run test to verify failure**
- [ ] **Step 3: Implement `_formatOkAlasan`, single-unit check, Shift 2.2 time greetings**
- [ ] **Step 4: Run test to verify pass**

### Task 2: Absensi Pulang Auto-Numbering & Rekan IT Support Dropdown (Poin 9, 10, 8 UI)
**Files:**
- Modify: `lib/features/templates/widgets/absensi_kategori_dialog.dart`
- Modify: `lib/data/services/absensi_setup_service.dart`

- [ ] **Step 1: Add Shift 2.2 (10:00 - 14:00) 4-column button layout**
- [ ] **Step 2: Add auto-numbering parser for completed tasks**
- [ ] **Step 3: Add IT Support colleague dropdown options**

### Task 3: Location Management & Form Simplification (Poin 4, 5, 6, 11)
**Files:**
- Modify: `lib/features/locations/screens/location_management_screen.dart`
- Modify: `lib/features/locations/widgets/location_picker_modal.dart`
- Modify: `lib/features/camera/widgets/interactive_watermark.dart`
- Modify: `lib/features/camera/screens/camera_capture_screen.dart`

- [ ] **Step 1: Rename "Nama Pos" to "Nama Lokasi" across location forms**
- [ ] **Step 2: Simplify location form to only Name, Tag Card, Cabang, Badge Color (auto GPS in background)**
- [ ] **Step 3: Add text wrapping and flexible constraints to watermark card & drawer**

### Task 4: Technician Setup & SOP Management Security (Poin 7, 12)
**Files:**
- Modify: `lib/features/maintenance/widgets/maintenance_setup_dialog.dart`
- Modify: `lib/features/camera/screens/camera_capture_screen.dart`

- [ ] **Step 1: Set Farhan Lakoro strictly as hintText/placeholder**
- [ ] **Step 2: Remove/hide "Kelola" button from quick template SOP picker**

### Task 5: Verification, Telegram HTML/CSS Report & Notification
**Files:**
- Create/Modify: `tools/generate_report_preview.py`
- Run: `flutter test`
- Execute: `tools/telegram_notify.sh`

- [ ] **Step 1: Run all Flutter unit tests to verify no regressions**
- [ ] **Step 2: Generate HTML/CSS report preview**
- [ ] **Step 3: Send Telegram summary via bot**
