# UI/UX & Design System Comprehensive Audit
**Application**: BSS Parking Timemark (Flutter)  
**Standard**: `design.md` (AI Design Standards — High-Level UI/UX Engineering Guide)  
**Date**: 2026-10-03  
**Auditor**: Senior Product Designer & Accessibility Specialist  

---

## 1. Executive Summary & Audit Scope

A comprehensive inspection was conducted across the entire accessible scope of the **BssparkingTimeMark** codebase, comprising **12 screens**, **9 modals/sheets/dialogs**, and shared design tokens (`AppColors`, `AppTheme`).

The audit evaluated compliance against the ten non-negotiable principles of `design.md`:
1. User goals before decoration.
2. Clarity over cleverness.
3. Consistency over improvisation.
4. Prevent errors before explaining them.
5. Show system status.
6. Progressive disclosure.
7. Accessibility is a baseline (WCAG 2.2 AA).
8. Responsive by design.
9. Evidence before assumptions.
10. Functional fidelity.

---

## 2. Application Inventory

### Screens Inspected
1. `SplashScreen` (`lib/features/splash/screens/splash_screen.dart`): Animated startup, camera warm-up synchronization.
2. `CameraCaptureScreen` (`lib/features/camera/screens/camera_capture_screen.dart`): Primary HUD viewfinder, top/bottom bars, sidebar drawer, quick pickers.
3. `MaintenanceChecklistScreen` (`lib/features/maintenance/screens/maintenance_checklist_screen.dart`): Multi-unit checkpoint inspection, photo capture, dynamic criteria.
4. `PointCameraView` (`lib/features/maintenance/screens/point_camera_view.dart`): Targeted checkpoint camera view with draggable live watermark.
5. `MaintenanceHistoryScreen` (`lib/features/maintenance/screens/maintenance_history_screen.dart`): Dual tab (Draft Berjalan & Selesai 100%), report generation.
6. `AttendanceArchiveScreen` (`lib/features/history/screens/attendance_archive_screen.dart`): 30-day tabular attendance history, CSV export, auto-pruning.
7. `GalleryScreen` (`lib/features/history/screens/gallery_screen.dart`): Album selector, multi-select download, grid photo browser.
8. `AiVisionSettingsScreen` (`lib/features/settings/screens/ai_vision_settings_screen.dart`): Model configuration, API key, endpoint test.
9. `LocationManagementScreen` (`lib/features/locations/screens/location_management_screen.dart`): Pos and branch CRUD, GPS coordinates, tag colors.
10. `TemplateListScreen` (`lib/features/templates/screens/template_list_screen.dart`): SOP template catalog, category filters, PIN unlock.
11. `TemplateEditorScreen` (`lib/features/templates/screens/template_editor_screen.dart`): SOP point builder, dynamic criteria editor.
12. `CardTemplateManagementScreen` (`lib/features/templates/screens/card_template_management_screen.dart`): Card template customization.

### Dialogs & Modals Inspected
1. `SOPVerificationModal` (`lib/features/camera/widgets/sop_verification_modal.dart`)
2. `DailyPulangBottomSheet` (`lib/features/camera/widgets/daily_pulang_bottom_sheet.dart`)
3. `WatermarkCustomizerModal` (`lib/features/camera/widgets/watermark_customizer_modal.dart`)
4. `WatermarkEditModal` (`lib/features/camera/widgets/watermark_edit_modal.dart`)
5. `AbsensiKategoriDialog` (`lib/features/templates/widgets/absensi_kategori_dialog.dart`)
6. `LocationPickerModal` (`lib/features/locations/widgets/location_picker_modal.dart`)
7. `MaintenanceSetupDialog` (`lib/features/maintenance/widgets/maintenance_setup_dialog.dart`)
8. `TechnicianPinDialog` (`lib/features/maintenance/widgets/technician_pin_dialog.dart`)
9. `PhotoPreviewDialog` (`lib/features/maintenance/widgets/photo_preview_dialog.dart`)

---

## 3. Design Issue Register

| ID | Screen / Component | Category | Current Problem & Evidence | User Impact | Severity | Confidence | Required Change |
|---|---|---|---|---|---|---|---|
| **ISSUE-01** | `LocationManagementScreen` | Accessibility & Interaction | Palette color selection buttons have hitboxes of only `28x28px` without touch target expansion (`minSize: 48x48`). | Technicians in the field with gloves/large fingers struggle to tap color circles, causing missed taps. | **P1** | High | Wrap palette dots in `InkWell`/`GestureDetector` with `padding: EdgeInsets.all(8)` and minimum 44x44px touch target. |
| **ISSUE-02** | `LocationManagementScreen` | Error Prevention & Validation | Location form dialog allows saving with empty or whitespace-only names without inline validation feedback. | Creates blank corrupt location items in storage, leading to null/empty watermark rendering. | **P1** | High | Add explicit text controller validation, disable Save or show clear red inline error text when name/tag is empty. |
| **ISSUE-03** | `AttendanceArchiveScreen` & `GalleryScreen` | Accessibility & Contrast | Multiple icon-only action buttons (`IconButton`) omit `tooltip` and semantic labels. | Screen reader users get unannounced buttons; sighted users get no hover/long-press assistive labels. | **P2** | High | Provide descriptive `tooltip` parameters on all `IconButton` and action buttons. |
| **ISSUE-04** | `AttendanceArchiveScreen` | UX & Safety | `_confirmClearHistory()` has vague dialog text ("Hapus Semua Arsip?") without stating record count or reminding about unexported CSV. | Accidental tap on destructive action can wipe 30 days of unexported timesheet data. | **P1** | High | Show record count in confirmation dialog ("Hapus X catatan?"), emphasize irreversible deletion, and suggest CSV export first. |
| **ISSUE-05** | `AiVisionSettingsScreen` | UX & Clarity | Endpoint and API Key fields lack helper text and examples for required formats (OpenAI vs Gemini vs Claude endpoint formats). | Field technicians or supervisors don't know how to structure custom baseURL or format key. | **P2** | High | Add helper texts and example format chips under baseURL and model name inputs. |
| **ISSUE-06** | `TemplateListScreen` & `LocationManagementScreen` | Responsive & Overflow | Alert dialogs with form fields do not account for small-screen virtual keyboard overlap. | When soft keyboard pops up on compact Android devices (e.g. 5-inch display), form fields get obscured or cause RenderFlex overflow. | **P1** | High | Wrap dialog contents in `SingleChildScrollView` with `keyboardViewInsets` handling and constrained width. |
| **ISSUE-07** | `AppColors` & Global Styling | Design System Consistency | Scattered hardcoded hex colors (`Color(0xFF0F172A)`, `Color(0xFFF8FAFC)`, `Color(0xFFF1F5F9)`) bypass established tokens. | Weakens single source of truth; causes inconsistent subtle gray/border differences. | **P2** | High | Normalize hardcoded colors into semantic tokens in `AppColors` (`AppColors.surfaceContainerLow`, `AppColors.cardBorder`, etc.). |
| **ISSUE-08** | `CameraCaptureScreen` Drawer | Information Hierarchy & Spacing | Drawer items have inconsistent item heights and missing tooltips on close/action buttons. | Navigation feels unpolished and close button touch area is cramped. | **P2** | High | Standardize drawer tile vertical padding (12px), icon container (40x40 squircle), and close button touch target (44x44). |
| **ISSUE-09** | `MaintenanceChecklistScreen` | Accessibility & Status Visibility | Filter chips for unit and status rely heavily on color differences without explicit shape/border distinction for active state. | Violates `design.md` rule: "Never rely on color alone to convey status or selection". | **P2** | High | Add checkmark icon / distinct border width and tactile weight to active filter chips. |
| **ISSUE-10** | `WatermarkCustomizerModal` | Visual & Spacing Consistency | Sliders and switches in watermark customizer lack tabular monospace value indicators. | Sliders show shifting text width when dragged; values are difficult to read at a glance. | **P3** | High | Apply `fontFeatures: [FontFeature.tabularFigures()]` and consistent typography tokens to numeric labels. |

---

## 4. Prioritization Summary
- **P0 (Blocker)**: 0 issues. Core capture and reporting workflows are functional.
- **P1 (High)**: 4 issues (`ISSUE-01`, `ISSUE-02`, `ISSUE-04`, `ISSUE-06`). Accessibility touch targets, destructive data loss safeguards, input validation, and keyboard responsive safety.
- **P2 (Medium)**: 5 issues (`ISSUE-03`, `ISSUE-05`, `ISSUE-07`, `ISSUE-08`, `ISSUE-09`). Design token normalization, accessible names/tooltips, filter chip dual-coding (icon+color), and drawer ergonomics.
- **P3 (Low)**: 1 issue (`ISSUE-10`). Tabular numbers on customizer sliders.
