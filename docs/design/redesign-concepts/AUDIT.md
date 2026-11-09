# PMA App UI/UX Redesign Audit: Anti-Card Slop & Ground Truth Analysis

This audit establishes the baseline for redesigning the PMA (Project Maintenance Assembly) Flutter application (`BssparkingTimeMark`). It catalogs all visible data fields, interactive actions, and currently bloated Card / Container-with-border-or-shadow surfaces across the 7 primary operational screens.

---

## 1. Executive Summary: Problem & Taste Alignment

### Aan's Taste vs Current App
* **Current App Syndrome (AI Slop Defaults)**:
  * Excessive nesting of cards (`Card` inside `Container` with border and soft drop-shadow, inside another card).
  * Rounded pill shapes applied haphazardly to badges, buttons, inputs, and container tiles.
  * Inconsistent elevations causing surfaces to visually float and compete with one another.
  * Information density is compromised: a user must scroll past oversized padded cards to see basic operational facts.
* **Aan's Real Taste (from `docs/design_references/`)**:
  * **Ground truth reference (`photo_2026-11-08_13-14-04.jpg`)**: Clean, purposeful layout with zero gratuitous cards. Flat high-contrast header, inline status tiles, flat list rows separated by hairline dividers, strong typographic hierarchy.
  * **Field Operator Context**: Technicians and supervisors work on-site under sunlight, frequently holding devices one-handed. Screens must prioritize scannability, rapid task execution (<30s), minimum 12sp legible typography, 44dp touch targets, and zero decorative noise.
  * **Card Budget Mandate**: Maximum **1 elevated surface per screen** (excluding temporary modal sheets/dialogs). Never card-in-card.

---

## 2. Screen-by-Screen Ground Truth Inventory & Baseline Counts

### Screen 1: Camera & Navigation Hub (`CameraCaptureScreen` & `CameraDrawer`)
* **Source Files**:
  * `lib/features/camera/screens/camera_capture_screen.dart` (lines 2054–3370)
  * `lib/features/camera/widgets/camera_drawer.dart` (lines 88–524)
* **Visible Data Fields & Status Elements**:
  * GPS Address / Current Pos: `currentAddress` from `_location` or `_activePos` (line 2059, 2259)
  * Live Watermark: GPS lat/lng, timestamp WITA, kode verifikasi, template name, pos tag chip (lines 2246–2270)
  * Daily Task Pending Count Badge: `DailyTaskService.pendingCountNotifier` on hamburger menu (lines 2341–2415)
  * Aspect Ratio Label: `_aspectRatio.label` (line 2464)
  * Timer Countdown Indicator: `_timerSeconds` (line 2545)
  * Flash Mode Status: `_flashMode` icon (line 2610)
  * Zoom Level Multiplier: 1x, 2x, 5x indicators (lines 2679–2735)
  * Attendance Shift Status Pill: Shift name, elapsed work hours/minutes, 'Masuk' / 'Pulang' status (lines 2951–3105)
  * Latest Capture Thumbnail: `lastSubmission.imagePath` (lines 3163–3182)
  * Navigation Drawer User Profile: User name, role badge ('IT Support KC BSG'), branch name, app version (lines 435–513)
* **Interactive Actions**:
  * Open Navigation Drawer (hamburger tap, line 2379)
  * Tap to focus with reticle ring (line 2117)
  * Shortcut Realtime Location Picker (line 2282)
  * Ratio Picker Modal (line 2426)
  * Timer Picker Modal (line 2496)
  * Toggle Flash (Off/Auto/On/Torch) (line 2626)
  * Flip Camera (front/back) (line 2665)
  * Select Zoom (1x, 2x, 5x) (line 2687)
  * Open Attendance Setup / Pulang Sheet from shortcut pill (line 3023)
  * Open Photo Gallery (line 3124)
  * Shutter Button (take photo / cancel timer) (line 3230)
  * Open SOP Template Quick Picker (line 3312)
  * Drawer Navigation: Penugasan Teknisi (SPV), Daily Task (Teknisi), Riwayat Maintenance, Map Maintenance, Arsip Kehadiran, Mode Gelap toggle, Logout (lines 140–460)
* **Current Card / Bordered Surface Count**:
  * **First Viewport**: **12** bordered/shadowed surfaces (Top bar circular buttons x3, ratio pill, timer pill, zoom pill x3, location shortcut, shift shortcut pill, gallery thumbnail card, shutter multi-ring).
  * **Total Surfaces**: **18** (including drawer cards, verification step card).

---

### Screen 2: Teknisi Daily Tasks (`TeknisiDailyTasksScreen`)
* **Source File**: `lib/features/daily_tasks/screens/teknisi_daily_tasks_screen.dart` (lines 286–740)
* **Visible Data Fields & Status Elements**:
  * User identity & branch in AppBar: `user.nama`, 'IT Support KC BSG' (lines 317–323)
  * Progress Block: '$done dari $total selesai', completion icon, remaining count 'Sisa X' or 'Semua selesai' (lines 447–471)
  * Linear Progress Bar: `done / total` (line 479)
  * Info Laporan Pulang notice text: auto-export explanation (line 502)
  * Section Headers: 'Tugas Hari Ini' ($total tugas), 'Tugas Shift Sebelumnya' (lines 373, 392)
  * Task Title: `task.judul` with conditional strikethrough if completed (line 596)
  * Task Status: 'Selesai', 'Proses X/Y', 'Belum dikerjakan' with status icon (line 576)
  * Task Meta Row: Pos name, category ('Tugas Khusus' / 'Maintenance'), date badge (line 632)
  * Shared / Handover Meta: 'Bersama X, Y' or 'Lanjutan dari Z' (line 642)
  * Task Description: `task.deskripsi` (line 655)
  * Ongoing Maintenance Progress Bar: `ongoing.progress` (line 665)
  * Completed Time: `task.jamSelesai` WITA (line 681, 698)
* **Interactive Actions**:
  * Refresh Tasks (AppBar action & Pull-to-refresh) (lines 330, 366)
  * Catat Kerjaan baru (Bottom bar FilledButton) (line 347)
  * View Completed Task Modal / Bukti Foto (line 585, 678)
  * Belum Selesai / Serahkan Tugas handover action (line 707)
  * Kerjakan / Lanjutkan Task (opens custom task or maintenance checklist) (line 721)
* **Current Card / Bordered Surface Count**:
  * **First Viewport**: **5** bordered/elevated surfaces (Progress block, info banner, 2 task cards, bottom action bar).
  * **Total Surfaces**: **11+** (all task item cards + handover cards).

---

### Screen 3: SPV Task Dispatcher (`SpvTaskDispatcherScreen`)
* **Source File**: `lib/features/daily_tasks/screens/spv_task_dispatcher_screen.dart` (lines 955–1865)
* **Visible Data Fields & Status Elements**:
  * Header Title: 'Daily Task' with Back button (lines 1041–1050)
  * Progress Metric: Circular completion ring, percentage, completed/total count, date subtitle + tech suffix (lines 1807–1813)
  * Status Filter Bar: 'SEMUA ($total)', 'PENDING ($pending)', 'SELESAI ($completed)' (lines 1815–1822)
  * Technician Filter Strip: Horizontal chips for 'SEMUA' and each technician with pending badge count (lines 1824–1835)
  * Active Filter Banner: Notice of filtered view when a specific technician is selected (line 1838)
  * All Done Banner: Congratulatory banner when 100% tasks are complete (line 1842)
  * Task Card: Category tag, task title, pos name, technician name, handover status, description (lines 1853–1864)
* **Interactive Actions**:
  * Back navigation (line 1034)
  * Format Briefing WA / Telegram modal (line 1057)
  * Kontrol Tim & Rekap modal (line 1063)
  * Filter by status tab (Semua, Pending, Selesai) (line 1821)
  * Filter by technician chip (line 1833)
  * Expand/collapse task detail (line 1860)
  * Alihkan Tugas handover action (line 1857)
  * Hapus Tugas action (line 1858)
  * FAB 'Buat Tugas' (opens dispatch form bottom sheet) (line 987)
  * Pull-to-refresh (line 1012)
* **Current Card / Bordered Surface Count**:
  * **First Viewport**: **7** surfaces (Progress ring card, status segment bar, tech filter chips, 2 task cards, FAB with elevation).
  * **Total Surfaces**: **16+** (every task is an elevated card).

---

### Screen 4: Maintenance Location Detail (`MaintenanceLocationDetailScreen`)
* **Source File**: `lib/features/maintenance/screens/maintenance_location_detail_screen.dart` (lines 420–740)
* **Visible Data Fields & Status Elements**:
  * Pos Title: `status.location.posName` (22/700) (line 434)
  * Location Tag: `locationTag` chip ('PBM') (line 448)
  * Location Address Row: Wilayah & full address with pin icon (line 455)
  * Technician Row: 'Teknisi: {nama}' with person icon (line 458)
  * Timestamp Row: Date & time WITA with clock icon (line 461)
  * Progres Maintenance Header: 'Progres Maintenance', '{doneCount} / 4 Fase' (line 522)
  * 4 Phase Cards: 'Fase 1..4', points score ('{sesuai} / {total}') or date range ('8–14'), status pill ('Aman', 'Temuan', 'Belum') (lines 606–670)
  * Phase Description Banner: Status message & icon inside progress card (lines 690–710)
  * Tabs: 'Checklist (N)' and 'Temuan (N)' (line 725)
  * Checklist Items: Point label, category, status icon (sesuai/temuan/tidak ada)
  * Temuan Items: Temuan label, reason text, urgent badge, status badge ('Belum diperbaiki' / 'Sudah diperbaiki')
  * Fix Meta: Fixed time, technician name, catatan, proof photo thumbnails, WhatsApp share button
* **Interactive Actions**:
  * Back navigation & refresh
  * 'Buka di Maps' tonal button (opens Google Maps intent) (line 465)
  * Select Phase 1..4 (toggles selected phase view) (line 620)
  * Switch Tab (Checklist vs Temuan) (line 725)
  * 'Tandai Sudah Diperbaiki' (opens proof camera sheet)
  * 'Kirim ulang laporan WA' (shares fix report via WhatsApp)
* **Current Card / Bordered Surface Count**:
  * **First Viewport**: **8** surfaces (Header card, Buka di Maps button, Progres Maintenance card, **4 nested phase cards [Card-in-Card violation!]**, phase message banner).
  * **Total Surfaces**: **18+** (all checklist rows and temuan cards).

---

### Screen 5: Maintenance Map Screen (`MaintenanceMapScreen`)
* **Source File**: `lib/features/maintenance/screens/maintenance_map_screen.dart` (lines 766–1200)
* **Visible Data Fields & Status Elements**:
  * Screen Title: 'Map Maintenance' with Back & Refresh actions (lines 788–804)
  * Offline Banner: 'Offline, menampilkan data lokal · Update HH:mm' (line 963)
  * Month Switcher: Current month & year display with chevrons (line 1016)
  * Wilayah Dropdown: Selected branch/area chip ('Semua', 'Manado') (line 1040)
  * Phase Strip: 4 Phase tabs with date ranges and summary status pills (line 824)
  * Interactive Map View: OpenStreetMap tiles with location pins color-coded by status (green/orange/grey) (line 831)
  * Empty filter notice (when no markers match rank) (line 881)
* **Interactive Actions**:
  * Back navigation
  * Refresh map data (line 803)
  * Month previous/next switcher
  * Open Wilayah selection dialog (line 1033)
  * Switch Phase 1..4 (line 824)
  * Tap map pin (opens `MaintenanceLocationDetailScreen` or cluster sheet) (line 754, 1897)
  * Center Map floating button (line 928)
  * Zoom in/out controls pill (line 934)
* **Current Card / Bordered Surface Count**:
  * **First Viewport**: **7** surfaces (Top filter bar, month switcher pill, wilayah chip, phase strip with 4 buttons, center button, zoom pill).
  * **Total Surfaces**: **10**.

---

### Screen 6: Maintenance Checklist Screen (`MaintenanceChecklistScreen`)
* **Source File**: `lib/features/maintenance/screens/maintenance_checklist_screen.dart` (lines 2590–3200)
* **Visible Data Fields & Status Elements**:
  * AppBar Title: Template name e.g. 'Barrier Gate Manless' (line 2677)
  * Top Progress Indicator: Linear bar of completed points (line 2712)
  * Header Card: Cabang & Pos name, checklist description / area labels, done/total count, percentage, overall status pill ('PROSES', 'SELESAI') (lines 2765–2846)
  * Status Filter Bar: 'Semua (N)', 'Belum Foto (N)', 'Sesuai (N)', 'Perlu Cek (N)', 'Tidak Ada (N)' (lines 2868–2899)
  * Unit / Area Tab Filter: 'Semua Gate' / 'Gate 1', 'Gate 2' or 'Area Server', 'Area Kasir' (lines 2911–3023)
  * Checklist Point Items: Item name, SOP standard description, photo preview thumbnail, AI verification status badge, score (lines 3044–3060)
  * Bottom Action Bar: Laporan status and 'Simpan & Selesaikan Laporan' button (lines 3105–3192)
* **Interactive Actions**:
  * Back navigation & open Riwayat Maintenance (line 2691)
  * Filter status chip tap (line 2868)
  * Filter unit/area tab tap (line 2911)
  * Retake / Take photo for point (opens camera) (line 3048)
  * Preview photo dialog & re-analyze AI (line 3050)
  * Save & Submit report (sync to Google Sheets & complete linked Daily Task) (line 3108)
* **Current Card / Bordered Surface Count**:
  * **First Viewport**: **8** surfaces (Header card, icon container, status badge, status filter strip, unit filter strip, point item cards x2, bottom action card).
  * **Total Surfaces**: **25+** (every single checklist point has an elevated card!).

---

### Screen 7: Attendance Archive Screen (`AttendanceArchiveScreen`)
* **Source File**: `lib/features/history/screens/attendance_archive_screen.dart` (lines 364–870)
* **Visible Data Fields & Status Elements**:
  * AppBar Title: 'Riwayat Kerja' (line 391)
  * Technician Profile Card: Technician name, branch / pos location tag chip ('PBM'), pos full name (lines 459–494)
  * Retention Info Banner: 'Riwayat catatan absensi hanya tersimpan otomatis selama 30 hari' (line 531)
  * KPI Summary Cards: 3 cards showing 'Hadir (count)', 'Pulang (count)', 'Terlambat (count)' (lines 552–579)
  * Attendance Record Card: Entry type ('Masuk' / 'Pulang'), date string, time WITA, verification code, photo thumbnail with zoom icon, location name (lines 831–870)
  * Bottom Sheet Export Bar: 'Export ke Sheets (CSV)' (lines 654–694)
* **Interactive Actions**:
  * Back navigation
  * Export CSV / Excel (line 408, 688)
  * Clear History confirmation dialog (line 413)
  * Tap photo thumbnail to view full photo (line 783)
  * Pull to refresh (line 421)
* **Current Card / Bordered Surface Count**:
  * **First Viewport**: **7** surfaces (Profile card, retention banner, KPI Hadir card, KPI Pulang card, KPI Terlambat card, record card, bottom sheet).
  * **Total Surfaces**: **16+** (every attendance record is an elevated bordered card).

---

## 3. Redesign Concepts: Card Count Comparison & Budget Compliance

| Screen Name | Current Baseline (1st Viewport / Total) | Concept A: Grouped List (1st Viewport / Total) | Concept B: Ops Board (1st Viewport / Total) | Concept C: Bold Type (1st Viewport / Total) | Card Budget Compliant? (Max 1 Elevated Surface) |
|---|:---:|:---:|:---:|:---:|:---:|
| 1. Camera & Navigation | 12 / 18 | 0 / 0 (Flat overlay) | 0 / 0 (Tactical HUD) | 0 / 0 (Minimal viewfinder) | Yes (0 elevated) |
| 2. Teknisi Daily Tasks | 5 / 11+ | 0 / 0 (Inset grouped list) | 0 / 0 (Rail bands) | 1 / 1 (Hero progress only) | Yes (0-1 elevated) |
| 3. SPV Task Dispatcher | 7 / 16+ | 0 / 0 (Grouped sections) | 0 / 0 (Grid + rail rows) | 1 / 1 (Hero metric only) | Yes (0-1 elevated) |
| 4. Maintenance Location Detail | 8 / 18+ | 0 / 0 (Flat inset groups) | 0 / 0 (Full-bleed panels) | 1 / 1 (Hero header only) | Yes (0-1 elevated) |
| 5. Maintenance Map Screen | 7 / 10 | 0 / 0 (Flat chrome bars) | 0 / 0 (Tactical toolbars) | 0 / 0 (Minimal float pill) | Yes (0 elevated) |
| 6. Maintenance Checklist | 8 / 25+ | 0 / 0 (Grouped rows) | 1 / 1 (Sticky bottom bar) | 1 / 1 (Hero summary only) | Yes (0-1 elevated) |
| 7. Attendance Archive | 7 / 16+ | 0 / 0 (Grouped list rows) | 0 / 0 (Data table rows) | 1 / 1 (Hero KPI only) | Yes (0-1 elevated) |

---

## 4. Feature & Data Parity Checklist (100% Strict Preservation)

Every single data field and user action documented above is preserved across all 3 concepts:

| Feature / Action / Field | In Codebase | Concept A (Grouped List) | Concept B (Ops Board) | Concept C (Bold Type) |
|---|:---:|:---:|:---:|:---:|
| Camera HUD (Ratio, Timer, Flash, Flip, Watermark, Shutter, Zoom) | Yes | Yes | Yes | Yes |
| Shift shortcut pill ('Masuk' / 'Pulang' duration & status) | Yes | Yes | Yes | Yes |
| Drawer menu links (SPV Dispatch, Daily Task, Map, Archive, Dark Mode, Logout) | Yes | Yes | Yes | Yes |
| Daily Task done count, remaining count & progress bar | Yes | Yes | Yes | Yes |
| Daily Task action buttons ('Kerjakan', 'Lanjutkan', 'Lihat Bukti', 'Belum Selesai') | Yes | Yes | Yes | Yes |
| Daily Task handover & shared metadata ('Bersama X', 'Lanjutan Y') | Yes | Yes | Yes | Yes |
| SPV Dispatch completion metric & team control shortcut | Yes | Yes | Yes | Yes |
| SPV Dispatch filters: Status tabs ('Semua', 'Pending', 'Selesai') + Tech chips | Yes | Yes | Yes | Yes |
| SPV Task actions: Alihkan, Hapus, Expand, Buat Tugas FAB | Yes | Yes | Yes | Yes |
| Location Detail: Cabang chip, address, technician name, time WITA | Yes | Yes | Yes | Yes |
| Location Detail: 'Buka di Maps' button | Yes | Yes | Yes | Yes |
| Location Detail: 4 Phase cards with points/dates and status pills ('Aman', 'Temuan', 'Belum') | Yes | Yes | Yes | Yes |
| Location Detail: Checklist items & Temuan items with photo proof & WA share | Yes | Yes | Yes | Yes |
| Map Maintenance: Month switcher, Wilayah dropdown, Phase strip | Yes | Yes | Yes | Yes |
| Map Maintenance: OSM map pins, center button, zoom pill | Yes | Yes | Yes | Yes |
| Maintenance Checklist: Header info, progress bar, status filter, unit filter | Yes | Yes | Yes | Yes |
| Maintenance Checklist: Point rows with AI badge, photo preview & camera retake | Yes | Yes | Yes | Yes |
| Maintenance Checklist: Save & Submit with Google Sheets sync | Yes | Yes | Yes | Yes |
| Attendance Archive: Profile card info, 30-day retention notice | Yes | Yes | Yes | Yes |
| Attendance Archive: KPI metrics (Hadir, Pulang, Terlambat) | Yes | Yes | Yes | Yes |
| Attendance Archive: Record entries with time WITA, verification code, photo thumb | Yes | Yes | Yes | Yes |
| Attendance Archive: Export CSV button & clear history | Yes | Yes | Yes | Yes |

---
**Audit Verdict**: 100% Feature parity maintained. Card-in-card eliminated across all screens. Card budget strictly capped at <= 1 elevated surface.
