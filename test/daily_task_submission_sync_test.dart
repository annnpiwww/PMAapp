import 'package:flutter_test/flutter_test.dart';
import 'package:bssparking_timemark/data/models/daily_task_model.dart';
import 'package:bssparking_timemark/data/models/maintenance_submission.dart';
import 'package:bssparking_timemark/data/services/daily_task_service.dart';

/// Regresi Bali (20 Okt 2026): maintenance selesai dari menu template membuat
/// tugas tampil "done" di HP teknisi lewat cross-check submission, tapi baris
/// Supabase tetap pending karena tidak pernah ada PATCH.
void main() {
  DailyTaskModel task({
    String tanggal = '2026-10-19',
    String? templateId = 'tpl_maint_pos',
    String posName = 'TBG',
  }) {
    return DailyTaskModel(
      id: 'task_1792387051061_1607',
      tanggal: tanggal,
      teknisiId: '',
      teknisiNama: 'I PUTU GEDE SUARDANA PUTRA',
      posName: posName,
      posTag: posName,
      judul: 'Maintenance Pos Kasir TBG',
      kategori: 'maintenance',
      templateId: templateId,
    );
  }

  MaintenanceSubmission submission({
    required DateTime createdAt,
    String? taskId,
    String templateId = 'tpl_maint_pos',
    String posName = 'TBG',
  }) {
    return MaintenanceSubmission(
      id: 'maint_1',
      templateId: templateId,
      templateName: 'Maintenance: Pos Parkir & Booth',
      userId: 'usr_1',
      userName: 'I PUTU GEDE SUARDANA PUTRA',
      userNpp: '-',
      posId: 'TBG',
      posName: posName,
      cabangName: 'Bali',
      points: const [],
      createdAt: createdAt,
      updatedAt: createdAt,
      taskId: taskId,
    );
  }

  test('submission hari yang sama + template + pos dianggap menyelesaikan tugas', () {
    final s = submission(createdAt: DateTime(2026, 10, 19, 14, 10));
    expect(DailyTaskService.submissionMatchesTask(task(), s), isTrue);
  });

  test('submission tanggal lain tidak menandai tugas hari ini selesai', () {
    final s = submission(createdAt: DateTime(2026, 10, 18, 14, 10));
    expect(DailyTaskService.submissionMatchesTask(task(), s), isFalse);
  });

  test('taskId yang sama tetap cocok walau tanggal submission beda', () {
    final s = submission(
      createdAt: DateTime(2026, 10, 18, 14, 10),
      taskId: 'task_1792387051061_1607',
    );
    expect(DailyTaskService.submissionMatchesTask(task(), s), isTrue);
  });

  test('template atau pos berbeda tidak dianggap cocok', () {
    final s = submission(
      createdAt: DateTime(2026, 10, 19, 14, 10),
      templateId: 'tpl_maint_barrier',
    );
    expect(DailyTaskService.submissionMatchesTask(task(), s), isFalse);

    final otherPos = submission(
      createdAt: DateTime(2026, 10, 19, 14, 10),
      posName: 'GYS',
    );
    expect(DailyTaskService.submissionMatchesTask(task(), otherPos), isFalse);
  });

  test('PATCH 200 dengan array kosong dianggap gagal (tidak ada baris ter-update)', () {
    expect(DailyTaskService.patchResponseAccepted(200, '[]'), isFalse);
  });

  test('PATCH 200 dengan baris hasil update dianggap sukses', () {
    expect(
      DailyTaskService.patchResponseAccepted(200, '[{"id":"task_1"}]'),
      isTrue,
    );
  });

  test('PATCH 204 tanpa body tetap sukses, status non-2xx gagal', () {
    expect(DailyTaskService.patchResponseAccepted(204, ''), isTrue);
    expect(DailyTaskService.patchResponseAccepted(500, '[]'), isFalse);
  });
}
