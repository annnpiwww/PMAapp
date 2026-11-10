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

## Notification
Unchanged (phase 1): new open error ticket not created by current user -> `Lokasi error: <posName>`, body = judul.

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
