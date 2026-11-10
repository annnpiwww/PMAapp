# Contract: Tiket Error (from Telegram paste)

Owner: Mandor. Phase 1 data = coder (done, t20261110-104551-4ac3). Phase 1b parser/report = coder. Phase 2 UI = ui (after Aan approves mockup).

## Decisions (Aan, 2026-11-10)
- Input: paste from clipboard in the existing "Catat Kerjaan" dialog (`AdHocTaskDialog`). No Android share target, no new dependency.
- Who: technician and SPV.
- Location: taken from the admin message `Lokasi` field, matched to a pos; user confirms or changes.
- Map Maintenance: open error ticket = red radar on that pos marker; in-app notification "Lokasi error: <pos>" to users of the same branch.
- Daily Task sync: ticket shows in the creator's Daily Task as a normal task (owner = creator). Hand-off uses the existing Serah Terima flow. No separate badge or sort order on the Daily Task card.
- SPV support (Aan, 2026-11-10): SPV can report and finish error tickets too. Entry = secondary pill 'Laporan Error' next to 'Buat Tugas' on the SPV dispatcher, opening the same AdHocTaskDialog in error mode with owner = SPV name. SPV-owned open error tasks show a 'Kerjakan' action on SpvTaskCard that opens CustomTaskExecutionScreen (same E5/E6 flow).
- App focuses on Kendala, Penyebab, Solusi. Date/time come from the message; missing ones fall back to paste time.
- Completion produces the technician reply in the group format below; Durasi Perbaikan = reported time until completion; optional Catatan.

## Admin message format (real sample, 2026-11-10)
```
Selamat pagi, izin melaporkan, telah terjadi kendala dengan kronologi sebagai berikut:

Tanggal : 07-11-2026
Waktu : 05.35

Lokasi : PBM

Kendala : Pos 1 Palang Tidak bisa terangkat 

Penyebab : Tidak diketahui 

Solusi sementara : Pos 1 ditutup Smntra

Durasi Error : 

Berikut kami lampirkan dokumentasi kerusakan.

Terima kasih.
```

## Technician reply format (real sample, 2026-11-10)
```
Selamat pagi
Izin melaporkan hasil support  maintenance rabu 03, juni 2026

- Kendala : Gate in 3 tidak keluar karcis

- Penyebab : printer error

- Solusi Perbaikan : perbaiki posisi thermal

- Durasi Perbaikan : 8 menit

Terima Kasih 🙏
```
App output (normalized): greeting by completion time (pagi < 11:00, siang < 15:00, sore < 18:00, else malam), date = admin report date (`reportedAt`; completion date only when the message had no Tanggal/Waktu, Aan 2026-11-10) as `Rabu, 03 Juni 2026`, `- Catatan : ...` block only when non-empty, placed after Durasi.

## Data (no migration)
- Ticket = row in the daily tasks table with `kategori = 'error'`, created via `DailyTaskService.createTask(..., kategori: 'error')`.
- `judul` = parsed Kendala (trimmed, max 120); if Kendala missing, first non-empty line that is not a greeting.
- `deskripsi` = `ErrorReport.toDeskripsi()`: normalized block (Tanggal, Waktu, Lokasi, Kendala, Penyebab, Solusi sementara, one per line `Label : value`), blank line, then the original pasted text; total max 2000 chars (truncate the original part). Reading back uses the same parser, so tickets survive offline cache and other devices.
- Completion: `catatan_teknisi` = `Penyebab : X\nSolusi Perbaikan : Y` plus `\nCatatan : Z` when present. Existing photo/video proof unchanged.
- Open = `kategori = 'error' AND status = 'pending'`. Closed = existing completion flow.

## API
`lib/data/services/error_ticket_service.dart` (exists): `fetchOpen()`, `guessPos(text, options)`, `openPosNames(open)`.

`lib/data/models/error_report.dart` (new, pure, no Flutter imports):
```dart
class ErrorReport {
  final DateTime? reportedAt;   // Tanggal + Waktu
  final String lokasi, kendala, penyebab, solusiSementara; // '' when missing
  static ErrorReport parse(String text);          // tolerant line parser
  ErrorReport withFallbackTime(DateTime now);     // fill reportedAt when null
  String toDeskripsi(String original);
  String judul(String original);
}
String formatDurasi(Duration d);                  // "8 menit", "1 jam 20 menit", "2 hari 3 jam"; < 1 menit -> "1 menit"; negative -> ""
String buildErrorReply({required String kendala, required String penyebab, required String solusiPerbaikan, required DateTime? reportedAt, required DateTime selesai, String catatan = ''});
String errorCatatanTeknisi({required String penyebab, required String solusiPerbaikan, String catatan = ''});
```
### Parser rules
1. Per line: `^\s*[-•*]?\s*<label>\s*:\s*(.*)$`, case-insensitive, label whitespace collapsed. Labels: `tanggal`, `waktu|jam`, `lokasi`, `kendala`, `penyebab`, `solusi sementara|solusi`, `durasi error` (ignored).
2. Tanggal: `dd-mm-yyyy`, `dd/mm/yyyy`, `dd.mm.yyyy`, 2-digit year = 20yy. Waktu: `HH.mm` or `HH:mm`. Invalid -> null. Only Tanggal -> time 00:00 not used: reportedAt = null unless both parse (keeps duration honest).
3. Values trimmed; `-` or empty -> ''.
4. Lokasi value is passed to `guessPos` first; if no match, `guessPos` on the whole text.

## Notification (superseded 2026-11-10 v2 by "Alarm & branch visibility" below)
Phase 1 per-screen poll + `Lokasi error: <posName>` notification is replaced by `ErrorAlarmService`.

## Map (phase 2)
Marker whose `posName.toLowerCase().trim()` is in `openPosNames` gets the radar regardless of month or status filter.

## Google Sheets "Error" log (Aan, 2026-11-10; Manado only)
- Spreadsheet `1b-ifRsQzt1yfyoBxgx5fV3pveYkXAHyt3LwW4xS7eqg` (same as sheet `Maintenance`), new sheet `Error`, auto-created with header.
- Path: app -> `GoogleSheetsService` endpoint (`functions/v1/sheets-sync`, session verified, offline queue reused) -> Apps Script `tools/google_apps_script_maintenance.js`.
- Payload `{"kind":"error", "id", "stage":"open"|"done", ...}`; payloads without `kind` keep the old Maintenance behaviour byte-for-byte.
- Manado gate: client sends only when `BranchService.instance.currentBranch` is Manado; `sheets-sync` rejects `kind:error` with 403 unless `resolveTasksTableForCabang(session.cabang) === 'daily_tasks_manado'` (copy the function into `_shared` or import from daily-tasks; HO and Bali rejected).
- Upsert by `ID Tiket` (column A): stage `open` appends the row if the ID is absent (idempotent on retries); stage `done` updates the existing row, or appends a full row if missing.
- Columns: `ID Tiket | Tanggal Lapor | Waktu Lapor | Lokasi | Kendala | Penyebab | Solusi Sementara | Pelapor | Status | Teknisi | Solusi Perbaikan | Selesai | Durasi Perbaikan | Catatan`. Status `Belum selesai` / `Selesai`. On `done`, Penyebab is overwritten with the technician's final value. Dates `dd-MM-yyyy`, times `HH.mm`, Selesai `dd-MM-yyyy HH.mm`, timezone Asia/Makassar.
- Hooks (data layer, no UI): after `createTask` succeeds with `kategori == 'error'` -> stage open; after `completeTask` succeeds for a task whose cached `kategori == 'error'` -> stage done (Penyebab/Solusi/Catatan parsed back from `errorCatatanTeknisi` lines, Durasi = `formatDurasi(now - reportedAt)`). Fire-and-forget: never blocks or fails task create/complete.

## Alarm & branch visibility (Aan, 2026-11-10 v2)
Bugs from Aan: (1) tapping an error location on Map Maintenance shows only maintenance temuan, no error info; (2) error ticket created by SPV does not appear on technician accounts; (3) wants a red "zombie warning" UI + alarm sound whenever an error location exists.
Decisions: open error tickets are visible to EVERY logged-in user of the branch (teknisi + SPV), whoever created them; owner stays the creator (Daily Task list unchanged, only the owner sees 'Kerjakan'). Alarm rings until the user taps the notification or the in-app banner. Alarm also rings while the app is in background as long as the process is alive (Android notification with alarm sound); force-closed app = no alarm (no FCM). Web: banner + vignette only, no sound.

### Data/logic (coder) `lib/data/services/error_alarm_service.dart` (new)
```dart
class ErrorAlarmService {
  static final ErrorAlarmService instance;
  ValueListenable<List<DailyTaskModel>> get openErrors; // branch-wide open error tickets, newest first; [] when logged out
  ValueListenable<bool> get ringing;                    // true while >= 1 open ticket id has not been acknowledged on this device
  void start();                                         // idempotent; Timer.periodic 25 s + immediate tick; each tick checks the logged-in user, logged out => clear lists, cancel alarm, ringing=false
  Future<void> acknowledge();                           // stops sound: cancels alarm notification, adds current ids to the acknowledged set (SharedPreferences), ringing=false
  @visibleForTesting Future<void> tick();
}
```
- `ErrorTicketService.fetchOpen()` must return branch-wide open tickets for technicians too (fix server scoping, see coder spec).
- New unacknowledged id appears => `ringing=true` + Android notification on channel `error_alarm_v1` (Importance.max, raw sound `error_alarm`, AudioAttributesUsage.alarm, `additionalFlags: [4]` FLAG_INSISTENT so the sound loops until opened/cancelled). Title `Lokasi error: <posName>` (multi: `<N> lokasi error`), body = judul. Tapping it = `acknowledge()`.
- Ticket closed (no longer in open list) => removed from acknowledged set; when no open tickets remain => cancel notification, ringing=false.

### UI (ui) `lib/core/widgets/tiket/error_alarm_overlay.dart` (new, pure widget, no service import)
`ErrorAlarmOverlay({required Widget child, required ValueListenable<List<DailyTaskModel>> openErrors, required ValueListenable<bool> ringing, required VoidCallback onLihat})`. Renders only `child` when `openErrors` is empty. Wiring into `MaterialApp.builder` (main.dart: `ErrorAlarmService.instance.start()`, `onLihat` => `acknowledge()` + push `MaintenanceMapScreen`) is a follow-up task after coder + ui land.

### Detail lokasi (coder2) `maintenance_location_detail_screen.dart`
Shows a "Laporan error" section for open tickets whose `posName` matches the screen's pos (trim, lowercase), fields from `ErrorReport.parse(task.deskripsi)`.

## SPV assignment modes (Aan, 2026-11-10 v3; overrides "Daily Task list unchanged" in v2)
When SPV creates a Laporan Error, a required choice "Siapa yang selesaikan" with 3 modes:
| Mode (label) | teknisi_nama | peserta | Who sees it in Daily Task | Who can Kerjakan |
|---|---|---|---|---|
| `Semua teknisi` (default) | released to the EXISTING open list ("tugas terbuka", same representation `transferTask`/`claimTask` use) | '' | every technician of the branch, in the open list | any technician: taps the existing claim action (`DailyTaskService.claimTask`), ticket becomes theirs, then Kerjakan. First claim wins; a later claim on an already-claimed ticket shows 'Tiket sudah diambil <nama>' |
| `Tunjuk teknisi` | chosen penanggung jawab (1, required) | optional pendamping, existing peserta format | PJ + pendamping (existing `isAssignedTo`) | PJ + pendamping |
| `Saya tangani` | SPV name | '' | SPV dispatcher (existing SpvTaskCard 'Kerjakan') | SPV |
- Technician Daily Task shows an error ticket ONLY by these rules (assigned, or in the open list). The v2 rule "every open error ticket in every technician's Daily Task" is removed.
- Map radar, detail lokasi section, banner + alarm: unchanged, ALL users of the branch for every open error ticket regardless of mode (`ErrorTicketService.fetchOpen`).
- Pelapor is kept in the deskripsi normalized block as line `Pelapor : <creator name>` (added by `ErrorReport.toDeskripsi(original, {String pelapor = ''})`, parsed into `ErrorReport.pelapor`). `DailyTaskErrorTicketExt.createdBy` = parsed pelapor, fallback teknisiNama (old tickets). Sheet column Pelapor uses createdBy; detail lokasi "Dilaporkan <x>" uses createdBy.
- Technician-created tickets: unchanged (owner = creator, Pelapor = creator).
