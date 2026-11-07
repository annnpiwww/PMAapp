import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bssparking_timemark/data/models/attendance_record.dart';
import 'package:bssparking_timemark/data/models/maintenance_submission.dart';
import 'package:bssparking_timemark/data/models/submission_model.dart';
import 'package:bssparking_timemark/data/services/maintenance_log_service.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    StorageService.resetForTesting();
  });

  group('CODE-16: Maintenance report completion timestamp derivation', () {
    test('Job 23:45 to 00:20 completed date and time both use updatedAt', () {
      final start = DateTime(2026, 11, 7, 23, 45);
      final finish = DateTime(2026, 11, 8, 0, 20);

      final submission = MaintenanceSubmission(
        id: 'sub-cross-midnight',
        templateId: 'tpl-1',
        templateName: 'Checklist Pos',
        userId: 'usr-1',
        userName: 'Teknisi 1',
        userNpp: 'NPP-1',
        posId: 'pos-1',
        posName: 'Pos Barat',
        cabangName: 'Manado',
        points: [
          MaintenancePointResult(
            pointId: 'pos_cctv_1',
            label: 'CCTV Check',
            status: PointStatus.sesuai,
            imagePath: 'https://example.com/p1.jpg',
            timestamp: finish,
          ),
        ],
        createdAt: start,
        updatedAt: finish,
      );

      final entries = MaintenanceLogService.entriesFromSubmission(submission);
      expect(entries.isNotEmpty, isTrue);
      final entry = entries.first;

      expect(entry.tanggal, '2026-11-08');
      expect(entry.jamSelesai, '00:20');
    });
  });

  group('CODE-17: StorageService in-memory caching', () {
    test('Multiple reads decode attendance records from prefs only once', () async {
      final record1 = AttendanceRecord(
        id: 'att-1',
        timestamp: DateTime(2026, 11, 7, 8, 0),
        type: AttendanceType.masuk,
        shiftName: 'Pagi',
        technicianName: 'Budi',
        posName: 'Pos 1',
        lat: -6.2,
        lng: 106.8,
        fullAddress: 'Jl. Test No. 1',
      );

      await StorageService.saveAttendanceRecord(record1);
      StorageService.resetForTesting();

      final firstRead = StorageService.getAttendanceRecords();
      expect(firstRead.length, 1);
      expect(StorageService.attendanceRecordsDecodeCountForTesting, 1);

      final secondRead = StorageService.getAttendanceRecords();
      expect(secondRead.length, 1);
      expect(StorageService.attendanceRecordsDecodeCountForTesting, 1);

      final record2 = AttendanceRecord(
        id: 'att-2',
        timestamp: DateTime(2026, 11, 7, 16, 0),
        type: AttendanceType.pulang,
        shiftName: 'Pagi',
        technicianName: 'Budi',
        posName: 'Pos 1',
        lat: -6.2,
        lng: 106.8,
        fullAddress: 'Jl. Test No. 1',
      );

      await StorageService.saveAttendanceRecord(record2);
      expect(StorageService.attendanceRecordsDecodeCountForTesting, 1);

      final thirdRead = StorageService.getAttendanceRecords();
      expect(thirdRead.length, 2);
      expect(thirdRead.map((r) => r.id), containsAll(['att-1', 'att-2']));
    });

    test('init() clears in-memory cache when binding a new SharedPreferences instance', () async {
      final record = AttendanceRecord(
        id: 'att-persist',
        timestamp: DateTime(2026, 11, 7, 8, 0),
        type: AttendanceType.masuk,
        shiftName: 'Pagi',
        technicianName: 'Budi',
        posName: 'Pos 1',
        lat: -6.2,
        lng: 106.8,
        fullAddress: 'Jl. Test No. 1',
      );

      await StorageService.saveAttendanceRecord(record);
      expect(StorageService.getAttendanceRecords().length, 1);

      // Re-init with empty mock prefs
      SharedPreferences.setMockInitialValues({});
      await StorageService.init();

      expect(StorageService.getAttendanceRecords(), isEmpty);
    });

    test('Multiple reads decode daily submissions from prefs only once', () async {
      final sub1 = SubmissionModel(
        id: 'subm-1',
        templateId: 'tpl-d1',
        templateName: 'Daily Report',
        userId: 'usr-1',
        userName: 'Budi',
        userNpp: 'NPP-1',
        posId: 'pos-1',
        posName: 'Pos 1',
        cabangName: 'Manado',
        timestampCapture: DateTime(2026, 11, 7, 9, 0),
        kodeVerifikasi: 'KV-1234',
        status: VerificationStatus.sesuai,
        alasanAI: 'OK',
        createdAt: DateTime(2026, 11, 7, 9, 0),
      );

      await StorageService.saveSubmissions([sub1]);
      StorageService.resetForTesting();

      final read1 = StorageService.getSubmissions();
      expect(read1?.length, 1);
      expect(StorageService.submissionsDecodeCountForTesting, 1);

      final read2 = StorageService.getSubmissions();
      expect(read2?.length, 1);
      expect(StorageService.submissionsDecodeCountForTesting, 1);

      await StorageService.deleteSubmission('subm-1');
      expect(StorageService.getSubmissions()?.isEmpty ?? true, isTrue);
    });
  });

  group('CODE-18: Per-draft incremental save in StorageService', () {
    test('Saving 1 point in a draft does not re-serialize other drafts and keeps other drafts byte-identical', () async {
      final draft1 = MaintenanceSubmission(
        id: 'draft-alpha',
        templateId: 'tpl-1',
        templateName: 'Draft A',
        userId: 'usr-1',
        userName: 'User 1',
        userNpp: 'NPP-1',
        posId: 'pos-1',
        posName: 'Pos 1',
        cabangName: 'Manado',
        points: const [
          MaintenancePointResult(
            pointId: 'p1',
            label: 'Point 1',
            status: PointStatus.sesuai,
            imagePath: 'https://example.com/b1.jpg',
          ),
        ],
        createdAt: DateTime(2026, 11, 7, 10, 0),
        updatedAt: DateTime(2026, 11, 7, 10, 0),
      );

      final draft2 = MaintenanceSubmission(
        id: 'draft-beta',
        templateId: 'tpl-2',
        templateName: 'Draft B',
        userId: 'usr-2',
        userName: 'User 2',
        userNpp: 'NPP-2',
        posId: 'pos-2',
        posName: 'Pos 2',
        cabangName: 'Bali',
        points: const [
          MaintenancePointResult(
            pointId: 'p2',
            label: 'Point 2',
            status: PointStatus.belumFoto,
          ),
        ],
        createdAt: DateTime(2026, 11, 7, 10, 5),
        updatedAt: DateTime(2026, 11, 7, 10, 5),
      );

      await StorageService.saveMaintenanceSubmissions([draft1, draft2]);

      final prefs = await SharedPreferences.getInstance();
      final initialRawStr = prefs.getString('bss_maintenance_submissions')!;
      final initialRawList = (jsonDecode(initialRawStr) as List<dynamic>)
          .cast<Map<String, dynamic>>();
      final betaRawBefore = jsonEncode(
          initialRawList.firstWhere((s) => s['id'] == 'draft-beta'));

      // Now update only draft1 with a new point result
      final updatedDraft1 = MaintenanceSubmission(
        id: draft1.id,
        templateId: draft1.templateId,
        templateName: draft1.templateName,
        userId: draft1.userId,
        userName: draft1.userName,
        userNpp: draft1.userNpp,
        posId: draft1.posId,
        posName: draft1.posName,
        cabangName: draft1.cabangName,
        points: [
          draft1.points[0],
          const MaintenancePointResult(
            pointId: 'p2-new',
            label: 'Point 2 Added',
            status: PointStatus.sesuai,
            imagePath: 'https://example.com/b2.jpg',
          ),
        ],
        createdAt: draft1.createdAt,
        updatedAt: DateTime(2026, 11, 7, 10, 15),
      );

      // Perform upsert
      await StorageService.upsertMaintenanceSubmission(updatedDraft1);

      final afterRawStr = prefs.getString('bss_maintenance_submissions')!;
      final afterRawList = (jsonDecode(afterRawStr) as List<dynamic>)
          .cast<Map<String, dynamic>>();
      expect(afterRawList.length, 2);

      final betaRawAfter = jsonEncode(
          afterRawList.firstWhere((s) => s['id'] == 'draft-beta'));
      // Byte-identical raw string check for untouched draft
      expect(betaRawAfter, equals(betaRawBefore));

      // In-memory cache returns updated draft1 and unchanged draft2
      final drafts = StorageService.getMaintenanceSubmissions();
      expect(drafts, isNotNull);
      final readDraft1 = drafts!.firstWhere((d) => d.id == 'draft-alpha');
      expect(readDraft1.points.length, 2);
      expect(readDraft1.points[1].pointId, 'p2-new');
    });
  });
}
