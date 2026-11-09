# Build plan: redesign "Tiket" + release 2.0.135

Aan 2026-11-09: build every screen first, then one release (APK arm32 + arm64, web, Telegram, Vercel) with What's New. Contract: `redesign-tiket.md`. Mockups: `docs/design/redesign-v3/` (`light-390-*`, `dark-390-*`). Inventory with labels and handlers: `docs/design/inventory/daily-flow-{a,b}.md`, `docs/design/redesign-concepts/AUDIT.md`.

Each group owns its files only (disjoint allowlists, shared tree). Verify per group: `flutter analyze <files>` + group widget test + PNGs at 360/390 light/dark under `docs/screenshots/tiket-<group>/`. Look and layout only: no logic, handler, or label changes.

| Group | Screens (mockup frame) | Files | Owner | Status |
|---|---|---|---|---|
| G0 | Tokens + widget kit | `lib/core/constants/tiket_colors.dart`, `lib/core/widgets/tiket/**` | coder | done (6a25) |
| G1 | Login (14), Drawer (15) | `login_screen.dart`, `camera_drawer.dart` | coder | retry 1/1 (68ed) |
| G2a | Camera chrome, zoom removed, ratio to right column (01) | `camera_capture_screen.dart` | coder2 | in progress (5830) |
| G2b | Camera states: memproses foto (10a/10b), verifikasi absensi (11a-c) | `camera_capture_screen.dart` | coder2 | after G2a |
| G3 | Template SOP (09), Atur Shift (16), Laporan Pulang (17), Pilih Lokasi (18) | `template_quick_picker_modal.dart`, `absensi_kategori_dialog.dart`, `daily_pulang_bottom_sheet.dart`, `location_picker_modal.dart` | coder2 | after G2b |
| G4 | Daily Task teknisi + states (02, 02b, 08a-c), Lihat Bukti (22), Serah terima (23) | `teknisi_daily_tasks_screen.dart`, `completed_daily_task_modal.dart`, `task_handover_dialog.dart` | coder | after G1 |
| G5 | Penugasan SPV + dialog teknisi (03), Buat Tugas (24) | `spv_task_dispatcher_screen.dart`, `spv_task_card.dart` | coder | done (67ec) |
| G6 | Map (04), Detail Lokasi (05), Tandai Sudah Diperbaiki (25) | `maintenance_map_screen.dart`, `maintenance_location_detail_screen.dart`, `temuan_fix_sheet.dart` | ui | when ui pane is logged in |
| G7 | Checklist + dialog status (06), Klarifikasi temuan (12), Kendala Fisik (26), Setup Maintenance (21) | `maintenance_checklist_screen.dart`, `maintenance_setup_dialog.dart` | coder | after G5 |
| G8 | Kamera per poin (19), Preview + analisa ulang (13a), Hasil Analisa AI (13b) | `point_camera_view.dart`, `photo_preview_dialog.dart`, `ai_result_dialog.dart` | coder2 | after G3 |
| G9 | Riwayat Kerja / Arsip (07), Riwayat Maintenance (27, 27b), Galeri (20) | `attendance_archive_screen.dart`, `maintenance_history_screen.dart`, `gallery_screen.dart` | ui | after G6 |
| G10 | Apa yang baru (28) sheet restyle | `whats_new_sheet.dart` | ui | after G9 |
| QA | Before shots (7731), then after shots per group vs mockups, full `flutter analyze` + `flutter test` | `test/visual/**`, `docs/screenshots/**` | qa | before shots in progress |
| REL | Bump 2.0.135+2148, `WhatsNewService.current` copy (Aan approves), CHANGELOG, split APK, web, Telegram, Vercel `--archive tgz` | `pubspec.yaml`, `whats_new_service.dart`, `CHANGELOG.md` | qa | last, after all groups approved |

Rules for every group spec:
- Read the frame PNGs and the inventory section first; reuse `lib/core/widgets/tiket/` (band, row, pill, segmented, dropdown + picker dialog, status marker/chip, bottom bar). No hex literals outside `TiketColors`.
- Horizontal chip scrollers become dropdown + centered picker dialog (DESIGN.md "Dropdown field + dialog").
- Orange only for attention, danger only for destructive/Urgent, status never color only.
- App name text is `PMApp` everywhere except the watermark footer `PMAapp powered by annnpii`.
- The em dash in `maintenance_setup_dialog.dart:2124-2125` becomes " · ".


Speed rules from 2026-11-09 (apply to every remaining spec): one screen/sheet per task (G7 and G8 split per file), `"isolate": true`, PNG only 390 light + dark, spec names line ranges and says "restyle in place, smallest diff", antislop rules embedded in the spec (workers do not re-read the skills).
Release gate (REL): every group approved, QA after-shots reviewed by Mandor, full test suite green, `sec` not needed (no auth/data logic change), Aan OK on What's New copy.
