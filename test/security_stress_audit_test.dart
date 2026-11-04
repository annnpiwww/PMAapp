import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bssparking_timemark/data/models/daily_task_model.dart';
import 'package:bssparking_timemark/data/models/maintenance_submission.dart';
import 'package:bssparking_timemark/data/models/template_model.dart';
import 'package:bssparking_timemark/data/services/daily_task_service.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';
import 'package:bssparking_timemark/data/services/whatsapp_report_service.dart';

/// Stress/fuzz audit: pastikan input patologis tidak bikin crash, memory
/// membengkak, atau waktu proses meledak (indeks quadratic).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  MaintenancePointResult buildPoint(String id, String label) =>
      MaintenancePointResult(
        pointId: id,
        label: label,
        status: PointStatus.sesuai,
        alasan: 'kelihatan bersih dan terpasang baik',
      );

  MaintenanceSubmission buildSubmission(List<MaintenancePointResult> points) =>
      MaintenanceSubmission(
        id: 'stress',
        templateId: 'tpl_maint_manless',
        templateName: 'Maintenance: Manless & Pulau Gate',
        userId: 'u1',
        userName: 'Teknisi BSS',
        userNpp: 'BSS-001',
        posId: 'p1',
        posName: 'PBM',
        cabangName: 'Manado',
        points: points,
        createdAt: DateTime(2026, 10, 22, 9),
        updatedAt: DateTime(2026, 10, 22, 9),
      );

  group('Stress & fuzz input patologis', () {
    test('laporan 2.000 poin selesai cepat (tidak quadratic)', () {
      final points = List.generate(
        2000,
        (i) => buildPoint('man_${i % 8 + 1}_${i % 8 + 1}', 'Manless ${i % 8 + 1} - Poin $i'),
      );

      final sw = Stopwatch()..start();
      final report = WhatsAppReportService.generateReportText(
        submission: buildSubmission(points),
        category: TemplateCategory.maintManless,
      );
      sw.stop();

      expect(report.length, greaterThan(0));
      expect(
        sw.elapsedMilliseconds,
        lessThan(5000),
        reason: 'laporan 2.000 poin terlalu lambat: ${sw.elapsedMilliseconds}ms',
      );
    });

    test('judul tugas 50.000 karakter tidak bikin crash atau timeout', () {
      final longTitle = 'A' * 50000;
      final task = DailyTaskModel(
        id: 'x1',
        tanggal: '2026-10-22',
        teknisiId: 't1',
        teknisiNama: 'Raldy',
        posName: 'PBM',
        posTag: 'PBM',
        judul: longTitle,
        status: TaskStatus.pending,
        catatanTeknisi: 'B' * 20000,
      );

      final sw = Stopwatch()..start();
      final report = DailyTaskService.formatFinalDailyReport(
        teknisiNama: 'Raldy',
        tanggal: '2026-10-22',
        lokasi: 'PBM',
        posTag: 'PBM',
        completedTasks: const [],
        pendingTasks: [task],
      );
      sw.stop();

      expect(report.contains('Pekerjaan Belum Selesai :'), isTrue);
      expect(sw.elapsedMilliseconds, lessThan(3000));
    });

    test('teks bebas 5.000 baris di-format tanpa error', () {
      final raw = List.generate(5000, (i) => 'Pekerjaan $i (Alasan $i)').join('\n');
      final out = WhatsAppReportService.formatUnfinishedJobList(raw);
      expect(out.split('\n').length, greaterThan(5000));
    });

    test('karakter aneh & unicode tidak merusak format laporan', () {
      final weird = '⚡ <script>alert(1)</script> "quote" \\ backslash\nBaris 2';
      final parts = WhatsAppReportService.splitJobAndAlasan(weird);
      expect(parts.judul.isNotEmpty, isTrue);

      final report = WhatsAppReportService.generateReportText(
        submission: buildSubmission([buildPoint('man_1_01', weird)]),
        category: TemplateCategory.maintManless,
      );
      expect(report.contains('Manless'), isTrue);
    });

    test('cache rusak tidak bikin crash saat dibaca', () {
      StorageService.setString(DailyTaskService.localCacheKey, '{bukan json valid');
      expect(DailyTaskService.getCachedTasksLocally(), isEmpty);
    });

    test('antrean pembuatan tugas tetap utuh & terpotong sesuai batas', () {
      final items = List.generate(
        150,
        (i) => jsonEncode({
          'localId': 'local_$i',
          'payload': {'judul': 'Tugas $i'},
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );
      StorageService.setStringList('pending_daily_task_creations_v1', items);
      final read = StorageService.getStringList('pending_daily_task_creations_v1')!;
      expect(read.length, 150);
      expect(
        jsonDecode(read.last)['localId'],
        'local_149',
      );
    });
  });
}
