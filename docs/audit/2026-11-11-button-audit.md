# UI Button & Action Alignment Audit

- **Date**: 2026-11-11
- **Task**: `t20261111-013045-4f45` (Read-only UI audit)
- **Reference Evidence**: `docs/design/aan-feedback/2026-11-11-alihkan-too-big.png`, `docs/design/aan-feedback/2026-11-11-belum-selesai-misaligned.png`
- **Scope**: Screens and widgets across `lib/features/**` and `lib/core/widgets/tiket`
- **Exclusions**: `spv_task_card.dart` & `teknisi_daily_tasks_screen.dart` (fixed in parallel), bottom bars/primary CTAs that are intentionally full-width (height 48+), camera chrome.

---

## Problem Categories
- **A**: Secondary / inline card actions with visual height > 40 or full-width where a compact pill fits
- **B**: Action buttons centered (`Center` / `Align` center / `mainAxisAlignment.center`) under left-aligned text in list rows/cards
- **C**: One row mixing buttons of different heights or styles
- **D**: Title-case labels on buttons where the app convention uses sentence case (e.g. 'Belum Selesai')

---

## Audit Findings Table (Sorted by User-Visible Screen, 28 Items)

| File:Line | Screen / Context | Problem | Current Size / Alignment | Proposed Fix (One Line) |
|---|---|:---:|---|---|
| `lib/features/maintenance/screens/maintenance_location_detail_screen.dart:387` | Detail Lokasi (Error Card) | A | `TiketPill(height: 48, expand: true)` in inline error card | Reduce height to compact 36 and remove expand (left-aligned). |
| `lib/features/maintenance/screens/maintenance_location_detail_screen.dart:832` | Detail Lokasi (WA Dialog) | C | `TextButton` mixed with `FilledButton(StadiumBorder)` in action row | Standardize dialog actions with matching `TiketPill(height: 40)`. |
| `lib/features/maintenance/screens/maintenance_location_detail_screen.dart:1242` | Detail Lokasi (Temuan Tab) | D | `StatusChip(label: 'Perlu Cek')` Title Case | Change label to sentence case `'Perlu cek'`. |
| `lib/features/maintenance/screens/maintenance_location_detail_screen.dart:1263` | Detail Lokasi (Temuan Card) | A | `TiketPill(label: 'Tandai sudah diperbaiki', height: 48, expand: true)` | Use compact pill `TiketPill(height: 36, expand: false)` aligned left. |
| `lib/features/daily_tasks/screens/spv_task_dispatcher_screen.dart:250` | SPV Dispatcher (Reset Dialog) | C | `TiketPill(height: 40)` mixed with `FilledButton(minimumSize: Size(0, 40))` | Standardize both dialog actions to uniform `TiketPill(height: 40)`. |
| `lib/features/daily_tasks/screens/spv_task_dispatcher_screen.dart:258` | SPV Dispatcher (Reset Dialog) | D | `FilledButton(child: Text('Reset Tugas'))` Title Case | Change button label to sentence case `'Reset tugas'`. |
| `lib/features/daily_tasks/screens/spv_task_dispatcher_screen.dart:623` | SPV Dispatcher (Dispatch Sheet) | D | `TiketPill(label: 'Salin Format')` Title Case | Change label to sentence case `'Salin format'`. |
| `lib/features/daily_tasks/screens/spv_task_dispatcher_screen.dart:832` | SPV Dispatcher (Broadcast Dialog) | D | `TiketPill(label: 'Kirim Sekarang')` Title Case | Change label to sentence case `'Kirim sekarang'`. |
| `lib/features/daily_tasks/screens/spv_task_dispatcher_screen.dart:1002` | SPV Dispatcher (Discard Dialog) | C | `TiketPill(height: 40)` mixed with `FilledButton` | Harmonize dialog action buttons with matching styles. |
| `lib/features/daily_tasks/screens/spv_task_dispatcher_screen.dart:1010` | SPV Dispatcher (Discard Dialog) | D | `FilledButton(child: Text('Buang Draft'))` Title Case | Change label to sentence case `'Buang draf'`. |
| `lib/features/daily_tasks/screens/spv_task_dispatcher_screen.dart:1860` | SPV Dispatcher (Team Recap Card) | A | `TextButton.icon(minimumSize: Size(0, 44))` in card | Replace with compact `TiketPill(height: 36)`. |
| `lib/features/daily_tasks/screens/spv_task_dispatcher_screen.dart:1865` | SPV Dispatcher (Team Recap Card) | D | `Text('Bagikan Rekap Tim via WA / Telegram')` Title Case | Change label to sentence case `'Bagikan rekap tim via WA / Telegram'`. |
| `lib/features/daily_tasks/screens/spv_task_dispatcher_screen.dart:1911` | SPV Dispatcher (Empty State) | D | `TiketPill(label: 'Buat Tugas Baru')` Title Case | Change label to sentence case `'Buat tugas baru'`. |
| `lib/features/daily_tasks/screens/spv_task_dispatcher_screen.dart:1951` | SPV Dispatcher (Filter Empty State) | D | `TiketPill(label: 'Reset Filter')` Title Case | Change label to sentence case `'Reset filter'`. |
| `lib/features/maintenance/screens/maintenance_history_screen.dart:90` | Maintenance History (Hapus Dialog) | C | `TextButton` mixed with `ElevatedButton` in dialog actions | Standardize dialog actions with matching `TiketPill(height: 40)`. |
| `lib/features/maintenance/screens/maintenance_history_screen.dart:355` | Maintenance History (Draft Card) | D | `TiketPill(label: 'Lanjutkan Draft')` Title Case | Change label to sentence case `'Lanjutkan draf'`. |
| `lib/features/maintenance/screens/maintenance_history_screen.dart:430` | Maintenance History (Item Card) | D | `TiketPill(label: 'Lihat Detail')` Title Case | Change label to sentence case `'Lihat detail'`. |
| `lib/features/maintenance/screens/maintenance_history_screen.dart:466` | Maintenance History (Draft Card) | A | `_DangerOutlinePill` minHeight 48, minimumSize 44 | Replace with compact `TiketPill(height: 36, kind: danger)`. |
| `lib/features/maintenance/screens/maintenance_history_screen.dart:466` | Maintenance History (Draft Card) | B | `Center(child: OutlinedButton(...))` under left text | Remove `Center`, align left alongside `Lanjutkan draf`. |
| `lib/features/maintenance/screens/maintenance_history_screen.dart:478` | Maintenance History (Draft Card) | D | `Text('Hapus Draft')` Title Case | Change label to sentence case `'Hapus draf'`. |
| `lib/features/maintenance/screens/maintenance_history_screen.dart:714` | Maintenance History (Share Bar) | A | `OutlinedButton.icon` padding vertical 12 (height ~46) | Replace with standard `TiketPill(height: 36, kind: secondary)`. |
| `lib/features/maintenance/screens/maintenance_history_screen.dart:727` | Maintenance History (Share Bar) | D | `Text('Share WhatsApp')` & `Text('Share Telegram')` Title Case | Change to sentence case `'Bagikan ke WhatsApp'` & `'Bagikan ke Telegram'`. |
| `lib/features/maintenance/screens/maintenance_checklist_screen.dart:1421` | Maintenance Checklist (Keluar Dialog) | C | `OutlinedButton` mixed with `ElevatedButton` | Standardize dialog action styles with matching `TiketPill(height: 40)`. |
| `lib/features/maintenance/screens/maintenance_checklist_screen.dart:1460` | Maintenance Checklist (Keluar Dialog) | D | `Text('Simpan & Keluar')` Title Case | Change label to sentence case `'Simpan & keluar'`. |
| `lib/features/maintenance/screens/maintenance_checklist_screen.dart:1551` | Maintenance Checklist (Reset Dialog) | C | `OutlinedButton` mixed with `ElevatedButton` in action row | Standardize dialog actions with matching `TiketPill(height: 40)`. |
| `lib/features/maintenance/screens/maintenance_checklist_screen.dart:1575` | Maintenance Checklist (Reset Dialog) | D | `Text('Reset Semua')` Title Case | Change label to sentence case `'Reset semua'`. |
| `lib/features/maintenance/screens/maintenance_checklist_screen.dart:1854` | Maintenance Checklist (Kendala Sheet) | C | Row mixes default `TiketPill(height: 36)` and `TiketPill(height: 48)` | Harmonize both action pills to uniform `height: 40`. |
| `lib/features/maintenance/screens/maintenance_checklist_screen.dart:1879` | Maintenance Checklist (Kendala Sheet) | D | `TiketPill(label: 'Simpan Kendala')` Title Case | Change label to sentence case `'Simpan kendala'`. |

---

## Summary Count per Problem

| Problem Category | Count | Description |
|---|:---:|---|
| **Problem A** | 5 | Secondary / inline card actions oversized (>40) or full-width |
| **Problem B** | 1 | Action buttons centered under left-aligned content in cards |
| **Problem C** | 7 | Mixed button styles / heights in the same action row or sheet |
| **Problem D** | 15 | Title Case labels on buttons where sentence case is standard |
| **Total Occurrences** | **28** | (Cataloged across the 4 most visible primary user screens) |
