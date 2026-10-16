import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bssparking_timemark/data/models/maintenance_submission.dart';
import 'package:bssparking_timemark/data/models/template_model.dart';
import 'package:bssparking_timemark/data/repositories/template_repository.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';
import 'package:bssparking_timemark/data/services/whatsapp_report_service.dart';
import 'package:bssparking_timemark/features/maintenance/screens/maintenance_history_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  group('Barrier Gate 1:1 9 Points & Report Tests', () {
    test('Template tpl_maint_barrier contains exactly 9 standardized sopPoints', () {
      final tpl = TemplateRepository.defaultTemplates
          .firstWhere((t) => t.id == 'tpl_maint_barrier');

      expect(tpl.sopPoints.length, equals(9));
      expect(tpl.sopPoints[0].label, equals('Dudukan Mesin & Baut Dynabolt'));
      expect(tpl.sopPoints[1].label, equals('Fisik Palang Tertutup Lurus'));
      expect(tpl.sopPoints[2].label, equals('Fisik Palang Terbuka'));
      expect(tpl.sopPoints[3].label, equals('Pelumas (Spring/Bearing)'));
      expect(tpl.sopPoints[4].label, equals('Sensor Loop Detector'));
      expect(tpl.sopPoints[5].label, equals('Jalur Kabel Sensor'));
      expect(tpl.sopPoints[6].label, equals('Stiker Receiver Barrier Gate'));
      expect(tpl.sopPoints[7].label, equals('Tiang CCTV & Housing'));
      expect(tpl.sopPoints[8].label, equals('Speedbump Gate'));
    });

    test('generateReportText outputs all 9 points exactly 1:1 and gate header for single gate', () {
      final now = DateTime.now();
      final points = [
        const MaintenancePointResult(pointId: 'bar_1_01', label: 'Gate 1 - Dudukan Mesin & Baut Dynabolt', status: PointStatus.sesuai),
        const MaintenancePointResult(pointId: 'bar_1_02', label: 'Gate 1 - Fisik Palang Tertutup Lurus', status: PointStatus.sesuai),
        const MaintenancePointResult(pointId: 'bar_1_03', label: 'Gate 1 - Fisik Palang Terbuka', status: PointStatus.sesuai),
        const MaintenancePointResult(pointId: 'bar_1_04', label: 'Gate 1 - Pelumas (Spring/Bearing)', status: PointStatus.sesuai),
        const MaintenancePointResult(pointId: 'bar_1_05', label: 'Gate 1 - Sensor Loop Detector', status: PointStatus.sesuai),
        const MaintenancePointResult(pointId: 'bar_1_06', label: 'Gate 1 - Jalur Kabel Sensor', status: PointStatus.sesuai),
        const MaintenancePointResult(pointId: 'bar_1_07', label: 'Gate 1 - Stiker Receiver Barrier Gate', status: PointStatus.sesuai),
        const MaintenancePointResult(pointId: 'bar_1_08', label: 'Gate 1 - Tiang CCTV & Housing', status: PointStatus.sesuai),
        const MaintenancePointResult(pointId: 'bar_1_09', label: 'Gate 1 - Speedbump Gate', status: PointStatus.sesuai),
      ];

      final sub = MaintenanceSubmission(
        id: 'sub_barrier_1',
        templateId: 'tpl_maint_barrier',
        templateName: 'Maintenance: Barrier Gate',
        userId: 'usr_1',
        userName: 'Farhan Lakoro',
        userNpp: 'BSS-001',
        posId: 'pos_1',
        posName: 'Pasar Bersehati Manado',
        cabangName: 'PBM',
        points: points,
        createdAt: now,
        updatedAt: now,
      );

      final report = WhatsAppReportService.generateReportText(
        submission: sub,
        category: TemplateCategory.maintBarrier,
        unitCount: 1,
      );

      // Gate header
      expect(report, contains('Gate : 1'));

      // 9 Poin harus tercetak 1:1
      expect(report, contains('1. *dudukan mesin & Baut dynabolt* :'));
      expect(report, contains('2. *fisik palang tertutup lurus* :'));
      expect(report, contains('3. *fisik palang terbuka* :'));
      expect(report, contains('4. *pelumas (spring/bearing)* :'));
      expect(report, contains('5. *sensor loop detector* :'));
      expect(report, contains('6. *jalur kabel sensor* :'));
      expect(report, contains('7. *stiker receiver barrier gate* :'));
      expect(report, contains('8. *tiang cctv & Housing* :'));
      expect(report, contains('9. *speedbump gate* :'));

      // Tidak boleh ada teks liar lama
      expect(report.contains('cat body BG bagus'), isFalse);
    });

    test('generateReportText handles multi-gate with issues correctly', () {
      final now = DateTime.now();
      final points = [
        const MaintenancePointResult(pointId: 'bar_1_01', label: 'Gate 1 - Dudukan Mesin & Baut Dynabolt', status: PointStatus.sesuai),
        const MaintenancePointResult(pointId: 'bar_2_01', label: 'Gate 2 - Dudukan Mesin & Baut Dynabolt', status: PointStatus.tidakSesuai, alasan: 'Baut kendor perlu dikencangkan'),
        const MaintenancePointResult(pointId: 'bar_1_07', label: 'Gate 1 - Stiker Receiver Barrier Gate', status: PointStatus.sesuai),
        const MaintenancePointResult(pointId: 'bar_2_07', label: 'Gate 2 - Stiker Receiver Barrier Gate', status: PointStatus.sesuai),
      ];

      final sub = MaintenanceSubmission(
        id: 'sub_barrier_2',
        templateId: 'tpl_maint_barrier',
        templateName: 'Maintenance: Barrier Gate',
        userId: 'usr_1',
        userName: 'Farhan Lakoro',
        userNpp: 'BSS-001',
        posId: 'pos_1',
        posName: 'Pasar Bersehati Manado',
        cabangName: 'PBM',
        points: points,
        createdAt: now,
        updatedAt: now,
      );

      final report = WhatsAppReportService.generateReportText(
        submission: sub,
        category: TemplateCategory.maintBarrier,
        unitCount: 2,
      );

      expect(report, contains('Gate : 2 Unit (Gate 1 - Gate 2)'));
      expect(report, contains('1. *dudukan mesin & Baut dynabolt* :'));
      expect(report, contains('⚠️ Gate 2: Baut kendor perlu dikencangkan'));
    });

    test('generateReportText maintains sequential Gate 1..4 order in mixed status (no gate jumping)', () {
      final now = DateTime.now();
      // Scenario Point 4: Gate 3 is OK, Gate 1, 2, 4 are issues
      final points = [
        const MaintenancePointResult(
          pointId: 'bar_3_04',
          label: 'Barrier Gate 3 - Pelumas (Spring/Bearing)',
          status: PointStatus.sesuai,
          alasan: 'Per spring dan bearing terlumasi grease baru',
        ),
        const MaintenancePointResult(
          pointId: 'bar_1_04',
          label: 'Barrier Gate 1 - Pelumas (Spring/Bearing)',
          status: PointStatus.tidakSesuai,
          alasan: 'Bearing as tampak berkarat dan belum terlumasi grease baru',
        ),
        const MaintenancePointResult(
          pointId: 'bar_4_04',
          label: 'Barrier Gate 4 - Pelumas (Spring/Bearing)',
          status: PointStatus.tidakSesuai,
          alasan: 'Per spring tampak kering dan tidak terlumasi grease baru',
        ),
        const MaintenancePointResult(
          pointId: 'bar_2_04',
          label: 'Barrier Gate 2 - Pelumas (Spring/Bearing)',
          status: PointStatus.tidakSesuai,
          alasan: 'Per spring dan bearing berkarat serta belum terlumasi grease baru',
        ),
      ];

      final sub = MaintenanceSubmission(
        id: 'sub_barrier_mixed',
        templateId: 'tpl_maint_barrier',
        templateName: 'Maintenance: Barrier Gate',
        userId: 'usr_1',
        userName: 'Raldy Sangkop',
        userNpp: 'BSS-002',
        posId: 'pos_1',
        posName: 'Pasar Bersehati Manado',
        cabangName: 'PBM',
        points: points,
        createdAt: now,
        updatedAt: now,
      );

      final report = WhatsAppReportService.generateReportText(
        submission: sub,
        category: TemplateCategory.maintBarrier,
        unitCount: 4,
      );

      // Verify Gate header
      expect(report, contains('Gate : 4 Unit (Gate 1 - Gate 4)'));

      // Poin 4 must have Gate 1, then Gate 2, then Gate 3, then Gate 4 in exact line sequence
      final idxGate1 = report.indexOf('⚠️ Barrier Gate 1: Bearing as tampak berkarat');
      final idxGate2 = report.indexOf('⚠️ Barrier Gate 2: Per spring dan bearing berkarat');
      final idxGate3 = report.indexOf('✅ Barrier Gate 3: Per spring dan bearing terlumasi grease baru');
      final idxGate4 = report.indexOf('⚠️ Barrier Gate 4: Per spring tampak kering');

      expect(idxGate1, isNot(-1));
      expect(idxGate2, isNot(-1));
      expect(idxGate3, isNot(-1));
      expect(idxGate4, isNot(-1));

      // Strictly sequential: Gate 1 < Gate 2 < Gate 3 < Gate 4
      expect(idxGate1 < idxGate2, isTrue, reason: 'Gate 1 must precede Gate 2');
      expect(idxGate2 < idxGate3, isTrue, reason: 'Gate 2 must precede Gate 3');
      expect(idxGate3 < idxGate4, isTrue, reason: 'Gate 3 must precede Gate 4');
    });

    test('prepareSortedSharePhotos orders photos by Unit 1..N and SOP 1..9', () async {
      final now = DateTime.now();
      final tempDir = await Directory.systemTemp.createTemp('share_test');
      final f1 = File('${tempDir.path}/g1_01.jpg')..writeAsStringSync('dummy');
      final f2 = File('${tempDir.path}/g1_02.jpg')..writeAsStringSync('dummy');
      final f3 = File('${tempDir.path}/g2_05.jpg')..writeAsStringSync('dummy');
      final f4 = File('${tempDir.path}/g4_09.jpg')..writeAsStringSync('dummy');

      // Masukkan secara acak/terbalik: Gate 4 dulu, Gate 1_02, Gate 2_05, Gate 1_01
      final points = [
        MaintenancePointResult(
          pointId: 'bar_4_09',
          label: 'Barrier Gate 4 - Speedbump Gate',
          status: PointStatus.sesuai,
          imagePath: f4.path,
        ),
        MaintenancePointResult(
          pointId: 'bar_1_02',
          label: 'Barrier Gate 1 - Fisik Palang Tertutup',
          status: PointStatus.sesuai,
          imagePath: f2.path,
        ),
        MaintenancePointResult(
          pointId: 'bar_2_05',
          label: 'Barrier Gate 2 - Sensor Loop Detector',
          status: PointStatus.sesuai,
          imagePath: f3.path,
        ),
        MaintenancePointResult(
          pointId: 'bar_1_01',
          label: 'Barrier Gate 1 - Dudukan Mesin & Baut Dynabolt',
          status: PointStatus.sesuai,
          imagePath: f1.path,
        ),
      ];

      final sub = MaintenanceSubmission(
        id: 'sub_barrier_sort',
        templateId: 'tpl_maint_barrier',
        templateName: 'Maintenance: Barrier Gate',
        userId: 'usr_1',
        userName: 'Raldy Sangkop',
        userNpp: 'BSS-002',
        posId: 'pos_1',
        posName: 'Pasar Bersehati Manado',
        cabangName: 'PBM',
        points: points,
        createdAt: now,
        updatedAt: now,
      );

      final sortedPaths = await WhatsAppReportService.prepareSortedSharePhotos(
        sub,
        overrideTempDir: tempDir,
      );
      expect(sortedPaths.length, equals(4));

      // Harus terurut: bar_1_01 -> bar_1_02 -> bar_2_05 -> bar_4_09
      expect(sortedPaths[0], contains('01_bar_1_01'));
      expect(sortedPaths[1], contains('02_bar_1_02'));
      expect(sortedPaths[2], contains('03_bar_2_05'));
      expect(sortedPaths[3], contains('04_bar_4_09'));

      // Cleanup
      tempDir.deleteSync(recursive: true);
    });
  });

  group('MaintenanceHistoryScreen Tests', () {
    testWidgets('renders Draft Berjalan and Selesai 100% tabs correctly', (tester) async {
      final now = DateTime.now();
      final draftSub = MaintenanceSubmission(
        id: 'draft_1',
        templateId: 'tpl_maint_barrier',
        templateName: 'Maintenance: Barrier Gate',
        userId: 'usr_1',
        userName: 'Farhan Lakoro',
        userNpp: 'BSS-001',
        posId: 'pos_1',
        posName: 'Pos 1 Megamas',
        cabangName: 'Manado',
        points: [
          const MaintenancePointResult(pointId: 'bar_1_01', label: 'Gate 1 - Dudukan Mesin', status: PointStatus.sesuai),
          const MaintenancePointResult(pointId: 'bar_1_02', label: 'Gate 1 - Fisik Palang', status: PointStatus.belumFoto),
        ],
        createdAt: now,
        updatedAt: now,
      );

      final completedSub = MaintenanceSubmission(
        id: 'comp_1',
        templateId: 'tpl_maint_barrier',
        templateName: 'Maintenance: Barrier Gate',
        userId: 'usr_1',
        userName: 'Farhan Lakoro',
        userNpp: 'BSS-001',
        posId: 'pos_2',
        posName: 'Pos 2 Mantos',
        cabangName: 'Manado',
        points: [
          const MaintenancePointResult(pointId: 'bar_1_01', label: 'Gate 1 - Dudukan Mesin', status: PointStatus.sesuai),
          const MaintenancePointResult(pointId: 'bar_1_02', label: 'Gate 1 - Fisik Palang', status: PointStatus.sesuai),
        ],
        createdAt: now,
        updatedAt: now,
      );

      await StorageService.saveMaintenanceSubmissions([draftSub, completedSub]);

      await tester.pumpWidget(
        const MaterialApp(
          home: MaintenanceHistoryScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Check Tab existence
      expect(find.text('Draft Berjalan'), findsOneWidget);
      expect(find.text('Selesai 100%'), findsOneWidget);

      // In Tab 1 (Draft Berjalan): draft card is visible
      expect(find.text('Pos 1 Megamas • ${WhatsAppReportService.formatIndonesianDate(now)}'), findsOneWidget);
      expect(find.text('Lanjutkan Pengerjaan'), findsOneWidget);

      // Switch to Tab 2 (Selesai 100%)
      await tester.tap(find.text('Selesai 100%'));
      await tester.pumpAndSettle();

      // Completed card is visible
      expect(find.text('100% Selesai'), findsOneWidget);
      expect(find.text('Pos 2 Mantos • Farhan Lakoro'), findsOneWidget);
      expect(find.text('Lihat Detail & Share ›'), findsOneWidget);
    });
  });
}

