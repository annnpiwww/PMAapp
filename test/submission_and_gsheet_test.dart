import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bssparking_timemark/data/models/submission_model.dart';
import 'package:bssparking_timemark/data/models/maintenance_submission.dart';
import 'package:bssparking_timemark/data/models/template_model.dart';
import 'package:bssparking_timemark/data/repositories/submission_repository.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';
import 'package:bssparking_timemark/data/services/google_sheets_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    await SubmissionRepository.instance.init();
  });

  group('SubmissionRepository & Supervisor Override Tests', () {
    test('addSubmission saves and retrieves correctly', () async {
      final repo = SubmissionRepository.instance;
      await repo.clearAll();

      final sub = SubmissionModel(
        id: 'sub_001',
        templateId: 'tpl_att_teknisi',
        templateName: 'Absensi Teknisi',
        userId: 'tech_01',
        userName: 'Aan Teknisi',
        userNpp: 'BSS-8801',
        posId: 'POS-01',
        posName: 'Pos Pasar Bersehati',
        cabangName: 'KC Manado',
        kodeVerifikasi: 'V123456789',
        timestampCapture: DateTime(2026, 9, 11, 8, 30),
        status: VerificationStatus.perluCekManual,
        alasanAI: 'Wajah terdeteksi, perlu verifikasi ID card',
        createdAt: DateTime(2026, 9, 11, 8, 30),
      );

      await repo.addSubmission(sub);
      expect(repo.submissions.length, equals(1));
      expect(repo.submissions.first.id, equals('sub_001'));
      expect(repo.submissions.first.status, equals(VerificationStatus.perluCekManual));
    });

    test('overrideSubmissionStatus updates status, note, and supervisor name', () async {
      final repo = SubmissionRepository.instance;
      await repo.clearAll();

      final sub = SubmissionModel(
        id: 'sub_override_01',
        templateId: 'tpl_att_admin',
        templateName: 'Absensi Admin',
        userId: 'adm_01',
        userName: 'Siti Admin',
        userNpp: 'BSS-8802',
        posId: 'POS-01',
        posName: 'Pos Pasar Bersehati',
        cabangName: 'KC Manado',
        kodeVerifikasi: 'V987654321',
        timestampCapture: DateTime(2026, 9, 11, 7, 55),
        status: VerificationStatus.perluCekManual,
        alasanAI: 'Pencahayaan redup',
        createdAt: DateTime(2026, 9, 11, 7, 55),
      );

      await repo.addSubmission(sub);

      // Supervisor melakukan override approval
      await repo.overrideSubmissionStatus(
        submissionId: 'sub_override_01',
        newStatus: VerificationStatus.sesuai,
        note: 'Diverifikasi langsung oleh SPV di lokasi pos, seragam lengkap.',
        supervisorName: 'Jefri Wowor (SPV)',
      );

      final updated = repo.submissions.firstWhere((s) => s.id == 'sub_override_01');
      expect(updated.status, equals(VerificationStatus.sesuai));
      expect(updated.overrideNote, equals('Diverifikasi langsung oleh SPV di lokasi pos, seragam lengkap.'));
      expect(updated.overriddenBy, equals('Jefri Wowor (SPV)'));
    });

    test('filter by status, templateId, and query string', () async {
      final repo = SubmissionRepository.instance;
      await repo.clearAll();

      final s1 = SubmissionModel(
        id: 's1',
        templateId: 'tpl_1',
        templateName: 'Absensi Teknisi',
        userId: 'u1',
        userName: 'Aan',
        userNpp: '8801',
        posId: 'p1',
        posName: 'Pasar Bersehati',
        cabangName: 'KC Manado',
        kodeVerifikasi: 'V111',
        timestampCapture: DateTime.now(),
        status: VerificationStatus.sesuai,
        alasanAI: 'Lolos',
        createdAt: DateTime.now(),
      );

      final s2 = SubmissionModel(
        id: 's2',
        templateId: 'tpl_2',
        templateName: 'Barrier Gate',
        userId: 'u2',
        userName: 'Budi',
        userNpp: '8802',
        posId: 'p2',
        posName: 'Kallamas',
        cabangName: 'KC Manado',
        kodeVerifikasi: 'V222',
        timestampCapture: DateTime.now(),
        status: VerificationStatus.tidakSesuai,
        alasanAI: 'Gagal',
        createdAt: DateTime.now(),
      );

      await repo.addSubmission(s1);
      await repo.addSubmission(s2);

      expect(repo.filter(status: VerificationStatus.sesuai).length, equals(1));
      expect(repo.filter(status: VerificationStatus.tidakSesuai).length, equals(1));
      expect(repo.filter(query: 'Bersehati').length, equals(1));
      expect(repo.filter(query: 'Budi').length, equals(1));
      expect(repo.filter(query: 'V111').length, equals(1));
      expect(repo.filter(query: 'TidakAda').length, equals(0));
    });
  });

  group('GoogleSheetsService & Offline Queue Tests', () {
    test('Offline queue fallback handles network failure gracefully and saves to queue', () async {
      // Atur URL Apps Script dummy yang akan gagal koneksi (offline/invalid)
      await GoogleSheetsService.saveAppsScriptUrl('http://127.0.0.1:54321/invalid_webhook');

      final submission = MaintenanceSubmission(
        id: 'maint_test_offline',
        templateId: 'tpl_barrier',
        templateName: 'Barrier Gate',
        userId: 'tech_01',
        userName: 'Aan SPV',
        userNpp: 'BSS-771',
        posId: 'POS-01',
        posName: 'Pasar Bersehati',
        cabangName: 'KC Manado',
        createdAt: DateTime(2026, 9, 11, 10, 0),
        updatedAt: DateTime(2026, 9, 11, 10, 15),
        points: [
          const MaintenancePointResult(
            pointId: 'bar_01',
            label: 'Dudukan Mesin & Baut Dinabolt',
            status: PointStatus.sesuai,
          ),
          const MaintenancePointResult(
            pointId: 'bar_02',
            label: 'Fisik Palang Tertutup',
            status: PointStatus.tidakSesuai,
            alasan: 'Baut kendor 2mm',
          ),
        ],
      );

      // syncMaintenanceToGoogleSheet harus return false saat offline tapi tidak melempar Exception
      final success = await GoogleSheetsService.syncMaintenanceToGoogleSheet(
        submission: submission,
        category: TemplateCategory.maintBarrier,
      );

      expect(success, isFalse);

      // Cek antrean SharedPreferences tersimpan
      final prefs = await SharedPreferences.getInstance();
      final queue = prefs.getStringList('bss_pending_gsheet_queue_v1') ?? [];
      expect(queue.isNotEmpty, isTrue);
      expect(queue.first, contains('maint_test_offline'));
      expect(queue.first, contains('Pasar Bersehati'));
    });

    test('flushPendingQueue returns 0 when queue is empty', () async {
      final flushed = await GoogleSheetsService.flushPendingQueue();
      expect(flushed, equals(0));
    });
  });
}
