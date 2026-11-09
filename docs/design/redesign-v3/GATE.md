# Delivery Gate: PMA App redesign "Tiket" (mockup)

Deliverable: static FigCraft mockup `pma-tiket-hitam.figcraft` (29 frames) + `../DESIGN.md`. No app code changed. Skills applied: `antislop`, `antislop-ui`, `antislop-human`, `antislop-layoutmobile`, `antislop-copywriting`, `antislop-code`.

Automated checks over all 29 frames (FigCraft node tree): 258 interactive nodes, 0 em or en dashes in screen text, 1 node past a frame edge (a row hairline below the fold inside a scroll list, expected). Contrast numbers come from `antislop-human/contrast-check.py`.

## Block 1: Hard Gate

- R-02 PASS: 0 em/en dashes in frame text; DESIGN.md and this file checked with grep.
- R-03 PASS: frames at 360 (floor, `daily_task_team_pma_spec.md:404`), 390, and 834; no horizontal scroll (chip scrollers replaced by dropdown + dialog); every interactive node is at least 44 except the camera location pill (64x32 visual set by Aan, wrapped in a 64x48 hit box) and map pins (32 visual, 48x60 hit area in DESIGN.md).
- R-17 PASS: every number is labelled sample data on the canvas ("Data contoh untuk mockup").
- R-18 PASS: no testimonials.
- R-23 PASS: no logo, photos, or avatars generated; people use initials, photos are grey placeholders.
- R-24 PASS: every destination exists in the app today (drawer: Daily Task, Penugasan, Riwayat Maintenance, Map, Arsip; AUDIT.md line refs).
- R-25 PASS: light white on blue 9.59, blue on white 9.59, band caption 7.03, white on band-raise 7.38, body 6.48, signal-text 5.50, ok 4.83, white on ok 4.83, black on orange 7.11, danger chip 4.90; dark text 18.42, sub 8.79, ok text 6.82, orange text 7.86, danger 7.97. Failing pairs found on the way were replaced: ok on tint 4.24, orange marker on white 2.95, green on band 1.99 (white ring added), grey empty ring on band-raise 2.14 (caption color used).
- R-26 PASS: every control maps to existing behavior (see Control map below); dropdowns open the dialog frames `03 Penugasan SPV · dialog teknisi` and `06 Checklist Maintenance · dialog status`.
- R-27 PASS: `08a Daily Task · Kosong`, `08b Daily Task · Memuat`, `08c Daily Task · Offline` with cause + next action; map keeps its existing offline line.
- R-28 PASS: no FAQ.
- R-32 PASS (spec): focus ring 2px ink / white, never orange; dialogs close with Esc, Back, scrim, `Tutup`. Keyboard behavior is verified at implementation.
- R-33 PASS: no patch scripts.
- R-34 PASS: light (blue band, blue actions) and dark (black band, white actions) frames, contrast measured in both.
- R-35 PASS (static mockup, nothing to run): verified by screenshot review of every frame at each step and by the control map below.
- R-36 PASS: no security, performance, or customer claims.
- R-37 PASS: direction = DESIGN.md (Uber structure, Aan's BSS blue picked on his phone, Aan's light/dark split).
- R-38 PASS: sample data labelled; invented technician "Rendi" removed; names come from the project capsule.
- R-39 PASS (spec): every icon-only control has a semantic label in its layer name; reduced motion = instant.
- R-40 N/A: no HTML page.

## Block 2: Purpose-Gate

- R-01 PASS: no gradients; BSS blue is the owner's brand choice (the app's existing primary), orange marks attention only.
- R-04 PASS: 2px-stroke glyphs only where they name the action (back, refresh, camera, pin, map, clock, CSV, send, users); ambiguous actions also carry text.
- R-06 PASS: Plus Jakarta Sans, already bundled in the app and geometric like Uber Move; mobile scale reduced on Aan's feedback.
- R-07 PASS: no background pattern; the perforation row is the identity motif.
- R-08 PASS: no decorative arrows; chevrons only on dropdowns and the shift pill, where they mean "opens".
- R-09 PASS: badges show real counts (pending tasks).
- R-10, R-13 PASS: no glass, no glow.
- R-12 PASS: shadows only on bottom bar, FAB, map controls, dialogs.
- R-14 PASS: no feature cards; rows, not cards.
- R-19 PASS: MOTION 1 (press 100ms, sheet/dialog 220ms, band collapse on scroll).
- R-22 PASS: no illustrations.

## Block 3: Liveliness

- Dials declared: ENERGY 2 / RHYTHM 2 / MOTION 1 (DESIGN.md front matter).
- Focal point per screen: the band number (1/4, 6/9, 22/24, 18/24, 24/24/1); on Map the orange Temuan tile.
- One accent: signal orange, only where something needs attention.
- Identity motif: the band with the perforated edge, on every screen.
- Design Read declared at the top of DESIGN.md.

## Block 4: Craftsmanship and Quality Locks

- C-1 PASS: every choice has a written reason in DESIGN.md.
- C-2 PASS: no dead controls (control map).
- C-3 PASS: screens are the app's real screens; nothing added for decoration.
- C-4 PASS: 360/390/834, light/dark, empty/loading/offline, 200% text rule.
- C-5 PASS: no claims.
- R-05 PASS: app screens built around each screen's decision, no template layout.
- R-11 PASS: radius varies by role (pill actions, 12 cells, 0 fields, 20 dialogs, 8 thumbs).
- R-15 PASS: labels copied verbatim from the app.
- R-16 PASS: no buzzwords.
- R-20 PASS: band + perforation + one number is specific to this app.
- R-21 PASS: light default plus working dark mode (the app already has the toggle).
- R-29 PASS: BSS blue + orange on neutrals; green/red only as status.
- R-30 PASS: Uber structure adapted, not cloned (own color, motif, density).
- R-31 PASS: reasons written in DESIGN.md.

## Skill checklists

- layoutmobile: all yes. Distinct mobile layout; states at 360, 390, 600+ cap; mobile type scale; no colliding grids; no overflow; targets 44+ with 8px gaps; no hover-only actions; navigation stays the app's drawer behind a labelled `Menu`; bars respect safe areas and lists get bottom padding; verified at each width.
- human: all yes. Every pair run through the checker; non-text rings 3.45 to 5.34; focus ring specified for both themes; empty/loading/offline present and not color only (marker shapes + text); 200% text rule; semantic labels; reduced motion.
- ui: all yes. Palette from DESIGN.md; one accent; no emoji; RHYTHM 2 respected; no bento, terminal, stripes, eyebrow badges; dots mark real states (decorative avatar dots removed); numbers labelled as sample.
- copywriting: all yes. No fabricated claims; no buzzwords; no em dash; no caps emphasis; new copy names its actor ("SPV belum membagi tugas buat kamu"); CTAs verbatim.
- code: N/A. No code or comments were written in this task.

## Control map (static verification)

| Control | Existing behavior |
|---|---|
| Menu (camera) | opens `CameraDrawer` (camera_capture_screen.dart:2379) |
| Timer, Flash, Flip, Rasio (zoom row removed by Aan) | camera_capture_screen.dart:2496, 2626, 2665, 2426 |
| Lokasi pin | location picker, Semantics 'Pilih lokasi realtime' (:2278) |
| Shift pill | attendance setup / pulang sheet (:3023) |
| Galeri, Shutter, Template | :3124, :3230, :3312 |
| Lihat Bukti, Lanjutkan, Kerjakan, Belum Selesai | teknisi_daily_tasks_screen.dart:585, 721, 707 |
| Catat Kerjaan baru | teknisi_daily_tasks_screen.dart:347 |
| Briefing, Rekap, Buat Tugas, kebab, status segment | spv_task_dispatcher_screen.dart:1057, 1063, 987, 1857-1858, 1821 |
| Teknisi dropdown | replaces technician chips (:1833), same filter |
| Month, Wilayah, Fase, stat tiles, pins, map controls | maintenance_map_screen.dart:1016, 1033, 824, 1291, 754, 928-934 |
| Buka di Maps, Temuan/Checklist, Tandai Sudah Diperbaiki, Kirim ulang laporan WA | maintenance_location_detail_screen.dart:465, 725, temuan fix flow |
| Status / Unit dropdowns, Foto, Riwayat, Simpan & Selesaikan Laporan | maintenance_checklist_screen.dart:2868, 2911, 3048, 2691, 3108 |
| Export CSV, Opsi (Hapus riwayat), foto zoom | attendance_archive_screen.dart:408, 413, 783 |

## Open for Aan

- Labels keep the app's mixed casing (`Catat Kerjaan baru` vs `Tandai Sudah Diperbaiki`); unify only if Aan wants.

## Daily flow frames 14 to 27b (2026-11-09)

Ground truth: `docs/design/inventory/daily-flow-a.md` (14 to 20) and `daily-flow-b.md` (21 to 27b). PNG per frame in this folder (`light-390-14-*` to `light-390-27b-*`), strip in `00-daily-flow-overview.png`. Antislop mode: during (global preference).

- Logos: Login uses `foto/splash_logo.png` in the circle, the drawer band uses `foto/bssfotologo_transparent.png` (h48, centered). Both are the app's existing assets (Aan 2026-11-09), not generated (R-23 PASS).
- R-02 PASS: node scan over frames 14, 15, 21 to 27b found 0 em/en dashes. The app's own Setup Maintenance summary line (`maintenance_setup_dialog.dart:2124-2125`) contains an em dash and is not drawn; implementation must replace it with " · ".
- R-03 PASS: node scan found 0 controls under 44 and 0 layers past the frame edge. The photo delete circles (28 visual) sit inside 44x44 hit boxes. Reason chips in Serah terima wrap to new rows, no sideways scroll.
- R-25 PASS: new pair danger text `#C81E1E` on white 5.74 (contrast-check.py); every other pair reuses tokens already measured above.
- R-09 PASS: the `100% Selesai` chip is dropped on the Selesai tab of Riwayat Maintenance because every row there is complete; the green check marker carries the state.
- R-06: `PILIH JENIS KENDALA:` is drawn as `Pilih jenis kendala` (sentence case, same as other section headings). Other labels are verbatim.
- Scope notes: Setup Maintenance shows the Server & Kasir template; the OS selector, Manless SOP (IN/OUT/PEP) and Pos mode tiles use the same segmented control. Buat Tugas shows the Tugas Khusus tab; Template SOP (Maintenance tab) and Catatan (Opsional) use the same dropdown/field below the fold.

| Frame | Control | Existing behavior |
|---|---|---|
| 21 Setup Maintenance | Nama Teknisi, Lokasi Parkir, Server & Kasir / Hanya Kasir, switch Terpisah, PC Kasir -/+, Mulai Checklist, Batal | maintenance_setup_dialog.dart:708, 758, 870/933, 1020-1076, 1416-1455, 2251, 2236 |
| 22 Lihat Bukti | Tutup, Unduh Semua, Zoom, Unduh | completed_daily_task_modal.dart:255, 410, 547, 577 |
| 23 Serah terima | Terbuka / teknisi radio, alasan chips, alasan field, Serahkan Tugas, Batal | task_handover_dialog.dart:177, 189, 207-210, 248-265, 290, 319 |
| 24 Buat Tugas | Tutup, Rutin / Maintenance / Tugas Khusus, field dropdowns, Simpan Tugas | spv_task_dispatcher_screen.dart:1397, 1420-1444, 1605-1777, 1498 |
| 25 Tandai Sudah Diperbaiki | Hapus foto, + Ambil Foto, Tindakan, Simpan Perbaikan, Tutup (= back, asks `Buang perbaikan ini?`) | temuan_fix_sheet.dart:277, 423, 475, 555, 147 |
| 26 Tandai Kendala Fisik | reason radios, Batal / Hapus Kendala, Simpan Kendala | maintenance_checklist_screen.dart:2342, 2427, 2464 |
| 27 / 27b Riwayat Maintenance | Kembali, Draft Berjalan / Selesai 100%, Lanjutkan Draft, Hapus Draft, Lihat Detail | maintenance_history_screen.dart:204/234, 398, 415, 548 |
