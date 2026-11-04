# Full Regression — 2026-11-04

Read-only verification of the combined tree after four approved tasks. No source or test files were modified.

| Item | Value |
|---|---|
| Repo | `BssparkingTimeMark` |
| Commit | `0c1454f` (working tree, uncommitted changes present) |
| App version | `2.0.127+2140` |
| Flutter | 3.41.7 (stable) |
| Command env | `export PATH="$HOME/flutter/bin:$PATH"` |

## 1. Summary

| Check | Command | Result | Exit |
|---|---|---|---|
| Static analysis | `flutter analyze` | **0 issues** ("No issues found!", 8.3s) | 0 |
| Test suite | `flutter test` (full) | **527 passed / 0 failed / 3 skipped**, 43s | 0 |

Raw test output saved at `/tmp/opencode/ftest_20261104.log`. Final line of run: `00:43 +527 ~3: All tests passed!`

## 2. Failures

None. No `[E]`, no `Some tests failed`, no exception traces.

| # | File:line | Error | Attribution |
|---|---|---|---|
| — | — | — | — |

Failures attributed per task id: **none for any of the four tasks** (no failures at all).

## 3. Skips (3)

| Skip reason | Scope |
|---|---|
| `Test ini menulis task nyata ke Supabase produksi. Jalankan dengan --dart-define=ALLOW_LIVE_WRITE=true bila memang perlu.` | Live-write test, gated by design |
| `IndexedDB hanya tersedia di web` | Web-only platform test |
| `blob URL hanya tersedia di web` | Web-only platform test |

All three are intentional platform/credential gates, not regressions.

## 4. Task coverage check (by existing tests, no edits)

| Task | Change | Test evidence | Status |
|---|---|---|---|
| `t20261104-070811-3345` | Stale shift reset + wrong-shift dialog | `test/shift_session_reset_test.dart` (12 tests, all pass) | PASS |
| `t20261104-071641-772c` | Version bump v2.0.127 | `pubspec.yaml` = `2.0.127+2140`; suite green on this tree | PASS |
| `t20261103-233950-5fe7` | Dynamic technician list in `daily_pulang_bottom_sheet` | `test/daily_pulang_rekan_branch_test.dart` — "pulang dropdown lists only the active branch technicians" passes | PASS |
| `t20261104-075745-0764` | Dispatch share ` - <lokasi>` | `test/daily_task_morning_dispatch_test.dart` — location suffix + dedupe assertions pass | PASS |

## 5. Edge-case spot checks (read-only)

### 5.1 Shift reset must not fire during an active Masuk session

Implementation `AbsensiSetupService.shouldResetShift` (`lib/data/services/absensi_setup_service.dart:104-118`): returns `false` while `now - lastCheckIn < 16h`, and while `now - shiftSetAt < 4h`.

Covered by `test/shift_session_reset_test.dart:8-16` — active 2h session returns `false`; also `:28-36` (manual shift picked 1h ago, no session) and `:42-50` (manual shift 5h ago → reset). PASS.

### 5.2 `isLikelyWrongShift` boundaries 120 / 1080

Implementation (`lib/data/services/absensi_setup_service.dart:125-134`): `lateMin > 120 && lateMin < 1080`, i.e. exactly 120 is **not** wrong, exactly 1080 is **not** wrong.

- 120 boundary: covered. `test/shift_session_reset_test.dart:91-99` → 12:00 for a 10:00 shift = exactly 120 → `false`. `:81-89` → 12:01 = 121 → `true`. PASS.
- 1080 boundary: **not covered by an exact-boundary test.** Closest tests are `:71-79` (21:30 vs 03:00, `lateMin` = 1110 → `false`) and `:54-59` (15:55 vs 03:00, `lateMin` = 665 → `true`). The `lateMin == 1080` case (e.g. 21:00 for a 03:00 shift) has no assertion. INFO-level coverage gap only — implementation is consistent with the documented 18h window; no behavioral defect observed.

### 5.3 Dispatch line with no location must not end with ` - `

Implementation `DailyTaskService.formatMorningDispatchReport` (`lib/data/services/daily_task_service.dart:1398-1406`): `lokasiSuffix` is `''` when the location is empty or already present in the title.

Covered by `test/daily_task_morning_dispatch_test.dart:109-119`:
- `posTag: 'PKM'` → `1. Pemasangan lampu pos - PKM`
- `posName: 'PKM'` fallback → same
- no tag, no name → `1. Pemasangan lampu pos` (no trailing ` - `)
- title already ending in ` - PKM` → no duplicate suffix
- shared task → `... - PKM (bersama Budi)`

PASS.

## 6. Findings

- INFO: `isLikelyWrongShift` 1080-minute upper boundary has no exact-boundary assertion (`test/shift_session_reset_test.dart`). Suggested (not applied — outside this task's scope): one test at 21:00 for `Shift 1 (03:00 - 11:00)` expecting `false`.
- No CRITICAL / HIGH / MEDIUM / LOW findings. `flutter analyze` clean, no security-relevant test disabled.

## 7. Verdict

**SHIP** — 0 analyzer issues, 527/527 executed tests passing (3 intentional platform/live-write skips), all four approved tasks covered by passing tests. The single INFO item is a test-coverage nit, not a release blocker.

## 8. Scope compliance

Files written by this task: `docs/qa/regression_2026-11-04.md` only. No `dart format`, no source/test edits. `docs/design/daily_task_team_redesign_concept.md` (parallel UI task) untouched.
