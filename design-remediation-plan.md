# UI/UX Design Remediation Plan
**Application**: BSS Parking Timemark  
**Standard**: `design.md`  
**Execution Order**: P1 High Impact -> P2 Consistency & Tokens -> P3 Polish  

---

## 1. Remediation Phases

### Phase 1: High Severity (P1) Usability & Error Prevention
1. **Fix ISSUE-01 & ISSUE-02 (`LocationManagementScreen`)**:
   - Enlarge color picker touch targets to minimum 44x44px.
   - Implement strict non-empty form validation on `nameController` and `tagController` before allowing save.
   - Wrap dialog body in safe keyboard insets scroll view to prevent soft-keyboard overflow.
2. **Fix ISSUE-04 (`AttendanceArchiveScreen`)**:
   - Strengthen destructive clear archive dialog: display exact record count, warning callout, and button "Ekspor CSV Dulu" beside "Hapus Permanen".
3. **Fix ISSUE-06 (`TemplateListScreen`)**:
   - Ensure `AbsensiKategoriModal` and edit dialogs handle keyboard insets smoothly on small screens.

### Phase 2: Medium Severity (P2) Accessibility, Tokens & Ergonomics
1. **Fix ISSUE-03 (`AttendanceArchiveScreen`, `GalleryScreen`)**:
   - Add descriptive tooltips to all icon-only buttons (Export CSV, Hapus Arsip, Filter, Unduh Galeri, Back).
2. **Fix ISSUE-05 (`AiVisionSettingsScreen`)**:
   - Provide inline helper hints and example syntax chips for Base URL and Model Name fields.
3. **Fix ISSUE-07 (`AppColors` & Shared Design Tokens)**:
   - Normalize scattered hex codes (`0xFFF8FAFC`, `0xFFF1F5F9`, `0xFF0F172A`) to semantic tokens.
4. **Fix ISSUE-08 (`CameraCaptureScreen` Drawer Header & Tiles)**:
   - Expand drawer close button hit test area to 44x44px.
   - Refine item spacing and add semantic tooltips.
5. **Fix ISSUE-09 (`MaintenanceChecklistScreen`)**:
   - Add dual-coding indicators (check icon + distinct high-contrast border) to unit and status filter chips.

### Phase 3: Verification & Definition of Done
1. Execute `flutter analyze` (target: 0 issues).
2. Execute full test suite `flutter test` (target: 174+ passing tests).
3. Generate `design-verification.md` documenting verified improvements and residual limitations.
