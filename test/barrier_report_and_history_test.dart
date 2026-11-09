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
import 'package:bssparking_timemark/features/maintenance/screens/maintenance_checklist_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  group('Barrier Gate 1:1 9 Points & Report Tests', () {
    test(
      'Template tpl_maint_barrier contains exactly 9 standardized sopPoints',
      () {
        final tpl = TemplateRepository.defaultTemplates.firstWhere(
          (t) => t.id == 'tpl_maint_barrier',
        );

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
      },
    );

    test(
      'generateReportText outputs all 9 points exactly 1:1 and gate header for single gate',
      () {
        final now = DateTime.now();
        final points = [
          const MaintenancePointResult(
            pointId: 'bar_1_01',
            label: 'Gate 1 - Dudukan Mesin & Baut Dynabolt',
            status: PointStatus.sesuai,
          ),
          const MaintenancePointResult(
            pointId: 'bar_1_02',
            label: 'Gate 1 - Fisik Palang Tertutup Lurus',
            status: PointStatus.sesuai,
          ),
          const MaintenancePointResult(
            pointId: 'bar_1_03',
            label: 'Gate 1 - Fisik Palang Terbuka',
            status: PointStatus.sesuai,
          ),
          const MaintenancePointResult(
            pointId: 'bar_1_04',
            label: 'Gate 1 - Pelumas (Spring/Bearing)',
            status: PointStatus.sesuai,
          ),
          const MaintenancePointResult(
            pointId: 'bar_1_05',
            label: 'Gate 1 - Sensor Loop Detector',
            status: PointStatus.sesuai,
          ),
          const MaintenancePointResult(
            pointId: 'bar_1_06',
            label: 'Gate 1 - Jalur Kabel Sensor',
            status: PointStatus.sesuai,
          ),
          const MaintenancePointResult(
            pointId: 'bar_1_07',
            label: 'Gate 1 - Stiker Receiver Barrier Gate',
            status: PointStatus.sesuai,
          ),
          const MaintenancePointResult(
            pointId: 'bar_1_08',
            label: 'Gate 1 - Tiang CCTV & Housing',
            status: PointStatus.sesuai,
          ),
          const MaintenancePointResult(
            pointId: 'bar_1_09',
            label: 'Gate 1 - Speedbump Gate',
            status: PointStatus.sesuai,
          ),
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
        expect(report, contains('1. *dudukan mesin & baut dynabolt* :'));
        expect(report, contains('2. *fisik palang tertutup lurus* :'));
        expect(report, contains('3. *fisik palang terbuka* :'));
        expect(report, contains('4. *pelumas (spring/bearing)* :'));
        expect(report, contains('5. *sensor loop detector* :'));
        expect(report, contains('6. *jalur kabel sensor* :'));
        expect(report, contains('7. *stiker receiver barrier gate* :'));
        expect(report, contains('8. *tiang cctv & housing* :'));
        expect(report, contains('9. *speedbump gate* :'));

        // Tidak boleh ada teks liar lama
        expect(report.contains('cat body BG bagus'), isFalse);
      },
    );

    test('generateReportText handles multi-gate with issues correctly', () {
      final now = DateTime.now();
      final points = [
        const MaintenancePointResult(
          pointId: 'bar_1_01',
          label: 'Gate 1 - Dudukan Mesin & Baut Dynabolt',
          status: PointStatus.sesuai,
        ),
        const MaintenancePointResult(
          pointId: 'bar_2_01',
          label: 'Gate 2 - Dudukan Mesin & Baut Dynabolt',
          status: PointStatus.tidakSesuai,
          alasan: 'Baut kendor perlu dikencangkan',
        ),
        const MaintenancePointResult(
          pointId: 'bar_1_07',
          label: 'Gate 1 - Stiker Receiver Barrier Gate',
          status: PointStatus.sesuai,
        ),
        const MaintenancePointResult(
          pointId: 'bar_2_07',
          label: 'Gate 2 - Stiker Receiver Barrier Gate',
          status: PointStatus.sesuai,
        ),
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
      expect(report, contains('1. *dudukan mesin & baut dynabolt* :'));
      expect(report, contains('⚠️ Gate 2: Baut kendor perlu dikencangkan'));
    });

    test('arah gate ditandai teknisi: temuan dikelompokkan per Gate IN dan Gate OUT', () {
      final now = DateTime.now();
      final points = [
        // Gate 1 (IN): stiker receiver rusak
        const MaintenancePointResult(
          pointId: 'bar_1_07',
          label: 'Barrier Gate 1 (IN) - Stiker Receiver Barrier Gate',
          status: PointStatus.tidakSesuai,
          alasan: 'stiker receiver rusak dan tidak terpasang dengan benar',
        ),
        // Gate 2 (OUT): stiker receiver rusak
        const MaintenancePointResult(
          pointId: 'bar_2_07',
          label: 'Barrier Gate 2 (OUT) - Stiker Receiver Barrier Gate',
          status: PointStatus.tidakSesuai,
          alasan: 'stiker receiver kuning terkelupas dari permukaan',
        ),
        // Gate 3 (IN): stiker receiver masih terbaca
        const MaintenancePointResult(
          pointId: 'bar_3_07',
          label: 'Barrier Gate 3 (IN) - Stiker Receiver Barrier Gate',
          status: PointStatus.sesuai,
          alasan: 'stiker receiver menempel rapi dan masih terbaca',
        ),
        // Gate 4 (OUT): stiker receiver aman
        const MaintenancePointResult(
          pointId: 'bar_4_07',
          label: 'Barrier Gate 4 (OUT) - Stiker Receiver Barrier Gate',
          status: PointStatus.sesuai,
          alasan: 'stiker receiver utuh dan warnanya masih jelas',
        ),
      ];

      final sub = MaintenanceSubmission(
        id: 'sub_barrier_arah',
        templateId: 'tpl_maint_barrier',
        templateName: 'Maintenance: Barrier Gate',
        userId: 'usr_1',
        userName: 'Farhan Lakoro',
        userNpp: 'BSS-001',
        posId: 'pos_1',
        posName: 'Pasar Pinasungkulan Manado',
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

      // Header arah muncul, Gate IN dulu baru Gate OUT.
      expect(report, contains('   *Gate IN*'));
      expect(report, contains('   *Gate OUT*'));
      expect(
        report.indexOf('*Gate IN*'),
        lessThan(report.indexOf('*Gate OUT*')),
      );

      // Di dalam kelompok, tanda (IN)/(OUT) tidak diulang di tiap baris.
      expect(report, contains('⚠️ Gate 1: stiker receiver rusak'));
      expect(report, contains('⚠️ Gate 2: stiker receiver kuning terkelupas'));
      expect(report, contains('✅ Gate 3: stiker receiver menempel rapi'));
      expect(report, contains('✅ Gate 4: stiker receiver utuh'));
      expect(report.contains('Gate 1 (IN):'), isFalse);
      expect(report.contains('Gate 2 (OUT):'), isFalse);

      // Gate IN harus muncul sebelum gate OUT di dalam blok yang sama.
      expect(
        report.indexOf('Gate 1: stiker receiver rusak'),
        lessThan(report.indexOf('Gate 2: stiker receiver kuning')),
      );
    });

    test('tanpa tanda arah, laporan tetap satu blok seperti sebelumnya', () {
      final now = DateTime.now();
      final points = [
        const MaintenancePointResult(
          pointId: 'bar_1_07',
          label: 'Barrier Gate 1 - Stiker Receiver Barrier Gate',
          status: PointStatus.tidakSesuai,
          alasan: 'stiker receiver rusak di sisi kiri tiang',
        ),
        const MaintenancePointResult(
          pointId: 'bar_2_07',
          label: 'Barrier Gate 2 - Stiker Receiver Barrier Gate',
          status: PointStatus.sesuai,
          alasan: 'stiker receiver masih menempel rapi',
        ),
      ];

      final sub = MaintenanceSubmission(
        id: 'sub_barrier_tanpa_arah',
        templateId: 'tpl_maint_barrier',
        templateName: 'Maintenance: Barrier Gate',
        userId: 'usr_1',
        userName: 'Farhan Lakoro',
        userNpp: 'BSS-001',
        posId: 'pos_1',
        posName: 'Pasar Pinasungkulan Manado',
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

      expect(report.contains('*Gate IN*'), isFalse);
      expect(report.contains('*Gate OUT*'), isFalse);
      expect(report, contains('⚠️ Gate 1: stiker receiver rusak di sisi kiri tiang'));
      expect(report, contains('✅ Gate 2: stiker receiver masih menempel rapi'));
    });

    test(
      'generateReportText maintains sequential Gate 1..4 order in mixed status (no gate jumping)',
      () {
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
            alasan:
                'Bearing as tampak berkarat dan belum terlumasi grease baru',
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
            alasan:
                'Per spring dan bearing berkarat serta belum terlumasi grease baru',
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
        final idxGate1 = report.indexOf(
          '⚠️ Gate 1: Bearing as tampak berkarat',
        );
        final idxGate2 = report.indexOf(
          '⚠️ Gate 2: Per spring dan bearing berkarat',
        );
        final idxGate3 = report.indexOf(
          '✅ Gate 3: Per spring dan bearing terlumasi grease baru',
        );
        final idxGate4 = report.indexOf('⚠️ Gate 4: Per spring tampak kering');

        expect(idxGate1, isNot(-1));
        expect(idxGate2, isNot(-1));
        expect(idxGate3, isNot(-1));
        expect(idxGate4, isNot(-1));

        // Strictly sequential: Gate 1 < Gate 2 < Gate 3 < Gate 4
        expect(
          idxGate1 < idxGate2,
          isTrue,
          reason: 'Gate 1 must precede Gate 2',
        );
        expect(
          idxGate2 < idxGate3,
          isTrue,
          reason: 'Gate 2 must precede Gate 3',
        );
        expect(
          idxGate3 < idxGate4,
          isTrue,
          reason: 'Gate 3 must precede Gate 4',
        );
      },
    );

    test(
      'prepareSortedSharePhotos orders photos by Unit 1..N and SOP 1..9',
      () async {
        final now = DateTime.now();
        final tempDir = await Directory.systemTemp.createTemp('share_test');
        final f1 = File('${tempDir.path}/g1_01.jpg')
          ..writeAsStringSync('dummy');
        final f2 = File('${tempDir.path}/g1_02.jpg')
          ..writeAsStringSync('dummy');
        final f3 = File('${tempDir.path}/g2_05.jpg')
          ..writeAsStringSync('dummy');
        final f4 = File('${tempDir.path}/g4_09.jpg')
          ..writeAsStringSync('dummy');

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

        final sortedPaths =
            await WhatsAppReportService.prepareSortedSharePhotos(
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
      },
    );
  });

  group('MaintenanceHistoryScreen Tests', () {
    testWidgets(
      'renders Draft Berjalan and Selesai 100% tabs correctly',
      skip: true, // redesign layout, TODO post-2.0.135
      (tester) async {
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
          const MaintenancePointResult(
            pointId: 'bar_1_01',
            label: 'Gate 1 - Dudukan Mesin',
            status: PointStatus.sesuai,
          ),
          const MaintenancePointResult(
            pointId: 'bar_1_02',
            label: 'Gate 1 - Fisik Palang',
            status: PointStatus.belumFoto,
          ),
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
          const MaintenancePointResult(
            pointId: 'bar_1_01',
            label: 'Gate 1 - Dudukan Mesin',
            status: PointStatus.sesuai,
          ),
          const MaintenancePointResult(
            pointId: 'bar_1_02',
            label: 'Gate 1 - Fisik Palang',
            status: PointStatus.sesuai,
          ),
        ],
        createdAt: now,
        updatedAt: now,
      );

      await StorageService.saveMaintenanceSubmissions([draftSub, completedSub]);

      await tester.pumpWidget(
        const MaterialApp(home: MaintenanceHistoryScreen()),
      );
      await tester.pumpAndSettle();

      // Check Tab existence
      expect(find.textContaining('Draft Berjalan'), findsWidgets);
      expect(find.textContaining('Selesai 100%'), findsWidgets);

      // In Tab 1 (Draft Berjalan): draft card is visible
      expect(
        find.text(
          'Pos 1 Megamas • ${WhatsAppReportService.formatIndonesianDate(now)}',
        ),
        findsOneWidget,
      );
      expect(find.text('Lanjutkan Pengerjaan'), findsOneWidget);

      // Switch to Tab 2 (Selesai 100%)
      await tester.tap(find.textContaining('Selesai 100%'));
      await tester.pumpAndSettle();

      // Completed card is visible
      expect(find.text('100% Selesai'), findsOneWidget);
      expect(find.text('Pos 2 Mantos • Farhan Lakoro'), findsOneWidget);
      expect(find.text('Lihat Detail & Share ›'), findsOneWidget);
    });
  });

  group('Identifikasi Gate IN/OUT di Laporan', () {
    MaintenanceSubmission sub2Gate(List<MaintenancePointResult> points) {
      final now = DateTime(2026, 10, 17, 21, 30);
      return MaintenanceSubmission(
        id: 'sub_gate_io',
        templateId: 'tpl_maint_barrier',
        templateName: 'Maintenance: Barrier Gate',
        userId: 'u1',
        userName: 'Alessandro Sulistyo',
        userNpp: 'BSS-001',
        posId: 'NBM',
        posName: 'New Bendar Manado',
        cabangName: 'NBM',
        points: points,
        createdAt: now,
        updatedAt: now,
      );
    }

    test(
      'Gate yang bermasalah disebut per unit, gate yang aman tetap kebaca',
      () {
        final report = WhatsAppReportService.generateReportText(
          submission: sub2Gate([
            const MaintenancePointResult(
              pointId: 'bar_1_03',
              label: 'Barrier Gate 1 - Fisik Palang Terbuka',
              status: PointStatus.sesuai,
              alasan: 'Palang naik terbuka penuh tegak 90° dan gerakan lancar.',
            ),
            const MaintenancePointResult(
              pointId: 'bar_2_03',
              label: 'Barrier Gate 2 - Fisik Palang Terbuka',
              status: PointStatus.tidakSesuai,
              alasan: 'Palang terbuka tidak sampai 90° dan macet di tengah.',
              urgensi: TingkatUrgensi.urgent,
            ),
          ]),
          category: TemplateCategory.maintBarrier,
          unitCount: 2,
        );

        // Gate rusak & gate aman dipisah, sebutan unit konsisten "Gate N"
        expect(
          report,
          contains(
            '⚠️ Gate 2: Palang terbuka tidak sampai 90° dan macet di tengah *(harus diganti)*',
          ),
        );
        expect(
          report,
          contains(
            '✅ Gate 1: Palang naik terbuka penuh tegak 90° dan gerakan lancar',
          ),
        );
        expect(report, isNot(contains('Barrier Gate 2:')));
      },
    );

    test('Wording palang tertutup dan terbuka tidak boleh sama', () {
      final report = WhatsAppReportService.generateReportText(
        // alasan dikosongkan -> laporan pakai teks cadangan per tema
        submission: sub2Gate([
          const MaintenancePointResult(
            pointId: 'bar_1_02',
            label: 'Barrier Gate 1 - Fisik Palang Tertutup Lurus',
            status: PointStatus.sesuai,
          ),
          const MaintenancePointResult(
            pointId: 'bar_1_03',
            label: 'Barrier Gate 1 - Fisik Palang Terbuka',
            status: PointStatus.sesuai,
          ),
        ]),
        category: TemplateCategory.maintBarrier,
        unitCount: 1,
      );

      expect(
        report,
        contains('✅ palang turun rata menutup jalan & bautnya kencang'),
      );
      expect(
        report,
        contains('✅ palang naik tegak waktu dibuka & gerakannya lancar'),
      );
    });

    test('Penanda arah gate (IN/OUT) ikut kebaca di laporan', () {
      final report = WhatsAppReportService.generateReportText(
        submission: sub2Gate([
          const MaintenancePointResult(
            pointId: 'bar_1_03',
            label: 'Barrier Gate 1 (IN) - Fisik Palang Terbuka',
            status: PointStatus.sesuai,
            alasan: 'Palang naik terbuka penuh tegak 90° dan gerakan lancar.',
          ),
          const MaintenancePointResult(
            pointId: 'bar_2_03',
            label: 'Barrier Gate 2 (OUT) - Fisik Palang Terbuka',
            status: PointStatus.tidakSesuai,
            alasan: 'Palang terbuka tidak sampai 90° dan macet di tengah.',
            urgensi: TingkatUrgensi.urgent,
          ),
          const MaintenancePointResult(
            pointId: 'bar_1_07',
            label: 'Barrier Gate 1 (IN) - Stiker Receiver Barrier Gate',
            status: PointStatus.sesuai,
            alasan: 'Stiker receiver kuning terpasang utuh.',
          ),
          const MaintenancePointResult(
            pointId: 'bar_2_07',
            label: 'Barrier Gate 2 (OUT) - Stiker Receiver Barrier Gate',
            status: PointStatus.sesuai,
            alasan: 'Stiker receiver kuning terpasang utuh.',
          ),
        ]),
        category: TemplateCategory.maintBarrier,
        unitCount: 2,
      );

      // Temuan dan poin aman dikelompokkan per arah, tanda (IN)/(OUT) tidak
      // diulang di tiap baris karena header kelompok sudah menyebut arahnya.
      expect(
        report,
        contains(
          '   *Gate OUT*\n'
          '   ⚠️ Gate 2: Palang terbuka tidak sampai 90° dan macet di tengah *(harus diganti)*',
        ),
      );
      expect(
        report,
        contains(
          '   *Gate IN*\n'
          '   ✅ Gate 1: Palang naik terbuka penuh tegak 90° dan gerakan lancar',
        ),
      );
      expect(report, contains('Gate : 2 Unit (Gate 1 IN - Gate 2 OUT)'));
      // Poin aman dicetak per arah, bukan diringkas jadi "Gate 1 - 2".
      expect(
        report,
        contains(
          '   *Gate IN*\n'
          '   ✅ Gate 1: Stiker receiver kuning terpasang utuh\n'
          '   *Gate OUT*\n'
          '   ✅ Gate 2: Stiker receiver kuning terpasang utuh',
        ),
      );
      expect(report, isNot(contains('Gate 1 - 2')));
      expect(report, isNot(contains('Gate 1 (IN):')));
      expect(report, isNot(contains('Gate 2 (OUT):')));
    });

    testWidgets(
      'Label gate di checklist pakai penanda arah dari setup',
      skip: true, // redesign layout, TODO post-2.0.135
      (tester) async {
      final tpl = TemplateRepository.defaultTemplates.firstWhere(
        (t) => t.id == 'tpl_maint_barrier',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MaintenanceChecklistScreen(
            template: tpl,
            unitNumbers: const [1, 2],
            unitRoles: const {1: 'IN', 2: 'OUT'},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Penanda arah ikut ke label point & ringkasan unit di header.
      expect(find.textContaining('Barrier Gate 1 (IN) - '), findsWidgets);
      expect(find.textContaining('Barrier Gate 2 (OUT) - '), findsWidgets);
    });
  });
}
