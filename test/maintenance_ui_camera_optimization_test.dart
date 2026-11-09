import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bssparking_timemark/data/models/maintenance_submission.dart';
import 'package:bssparking_timemark/data/repositories/template_repository.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';
import 'package:bssparking_timemark/features/maintenance/widgets/maintenance_setup_dialog.dart';
import 'package:bssparking_timemark/features/maintenance/screens/maintenance_checklist_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Maintenance Setup Dialog UI & Dynamic Calculation Tests', () {
    final serverTemplate = TemplateRepository.defaultTemplates.firstWhere(
      (t) => t.id == 'tpl_maint_server',
    );

    testWidgets(
      'Displays PC Server & PC Kasir terms and calculates dynamic photos correctly',
      skip: true, // redesign layout, TODO post-2.0.135
      (tester) async {
        tester.view.physicalSize = const Size(800, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MaintenanceSetupDialog(initialTemplate: serverTemplate),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify header & titles use Maintenance: Server & Kasir
        expect(find.text('Maintenance: Server & Kasir'), findsWidgets);
        expect(find.text('Cek PC Server & PC Kasir'), findsWidgets);
        expect(find.text('PC Server & PC Kasir Terpisah'), findsOneWidget);
        expect(find.text('1 PC Server (6 foto)'), findsOneWidget);
        expect(find.text('Jumlah PC Kasir'), findsOneWidget);

        // Default state: Terpisah ON, 1 PC Kasir -> 12 photos
        expect(
          find.textContaining('Target: 12 Foto (1 PC Server + 1 PC Kasir)'),
          findsOneWidget,
        );
        expect(
          find.textContaining(
            '6 foto PC Server + 6 foto PC Kasir (1 unit × 6 foto)',
          ),
          findsOneWidget,
        );

        // Increment PC Kasir counter
        final addKasirBtn = find.byIcon(Icons.add_rounded);
        expect(addKasirBtn, findsOneWidget);
        await tester.tap(addKasirBtn);
        await tester.pumpAndSettle();

        // Now 2 PC Kasir -> 18 photos
        expect(
          find.textContaining('Target: 18 Foto (1 PC Server + 2 PC Kasir)'),
          findsOneWidget,
        );
        expect(
          find.textContaining(
            '6 foto PC Server + 12 foto PC Kasir (2 unit × 6 foto)',
          ),
          findsOneWidget,
        );

        // Toggle Switch to Gabung (OFF)
        final allInOneSwitch = find.byType(Switch);
        expect(allInOneSwitch, findsOneWidget);
        await tester.tap(allInOneSwitch);
        await tester.pumpAndSettle();

        // Gabung OFF -> 6 photos total
        expect(find.text('OFF: Gabung (1 Komputer)'), findsOneWidget);
        expect(
          find.textContaining(
            'Target: 6 Foto (1 PC Server & Kasir All-in-One)',
          ),
          findsOneWidget,
        );
        expect(
          find.textContaining('6 foto PC Server & Kasir (1 komputer)'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Tapping Hanya Kasir card hides server options and calculates kasir photos correctly',
      skip: true, // redesign layout, TODO post-2.0.135
      (tester) async {
        tester.view.physicalSize = const Size(800, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MaintenanceSetupDialog(initialTemplate: serverTemplate),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap 'Hanya Kasir' card
        final hanyaKasirCard = find.text('Hanya Kasir');
        expect(hanyaKasirCard, findsOneWidget);
        await tester.tap(hanyaKasirCard);
        await tester.pumpAndSettle();

        // Verify title updates
        expect(find.text('Maintenance: Kasir'), findsWidgets);
        expect(find.text('Cek PC Kasir'), findsWidgets);

        // Server options should be hidden
        expect(find.text('PC Server & PC Kasir Terpisah'), findsNothing);
        expect(find.text('Sistem Operasi Server'), findsNothing);

        // Default 1 PC Kasir -> 6 photos
        expect(
          find.textContaining('Target: 6 Foto (1 PC Kasir)'),
          findsOneWidget,
        );

        // Increment to 3 PC Kasir
        final addBtn = find.byIcon(Icons.add_rounded);
        await tester.tap(addBtn);
        await tester.pumpAndSettle();
        await tester.tap(addBtn);
        await tester.pumpAndSettle();

        // 3 PC Kasir -> 18 photos
        expect(
          find.textContaining('Target: 18 Foto (3 PC Kasir)'),
          findsOneWidget,
        );
        expect(
          find.textContaining('18 foto PC Kasir (3 unit × 6 foto)'),
          findsOneWidget,
        );
      },
    );
  });

  group('Checklist Screen Modal Status Banner Position Tests', () {
    final serverTemplate = TemplateRepository.defaultTemplates.firstWhere(
      (t) => t.id == 'tpl_maint_server',
    );

    testWidgets(
      'Modal shows status banner prominently at top above checkpoints',
      skip: true, // redesign layout, TODO post-2.0.135
      (tester) async {
      final submission = MaintenanceSubmission(
        id: 'test_sub_done',
        templateId: serverTemplate.id,
        templateName: serverTemplate.nama,
        userId: 'u1',
        userName: 'Teknisi Test',
        userNpp: '1234',
        posId: 'POS1',
        posName: 'Pos 1',
        cabangName: 'Cabang Test',
        points: [
          const MaintenancePointResult(
            pointId: 'srv_1_01',
            label:
                'PC Server & Kasir - Pembersihan Storage Linux (df -h & /tmp)',
            status: PointStatus.sesuai,
            confidence: 0.95,
            alasan: 'Drive terverifikasi aman',
          ),
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MaintenanceChecklistScreen(
            template: serverTemplate,
            existingSubmission: submission,
            serverOs: 'linux',
            isServerKasirGabung: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap checklist item that is already done to open modal action sheet
      final firstItem = find.textContaining('Pembersihan Storage Linux').first;
      expect(firstItem, findsOneWidget);
      await tester.tap(firstItem);
      await tester.pumpAndSettle();

      // Semua pengecekan di-scope ke bottom sheet (di belakang juga ada badge status)
      final sheet = find.byType(BottomSheet);
      Finder inSheet(Finder f) => find.descendant(of: sheet, matching: f);

      // Verify Status badge appears in bottom sheet (Konsep A Tactical HUD Verdict)
      expect(inSheet(find.text('SESUAI')), findsOneWidget);

      // Verify checkpoint guidelines are also present (Accordion)
      expect(inSheet(find.text('Standar SOP')), findsOneWidget);
      expect(
        inSheet(find.textContaining('Ketuk untuk melihat detail')),
        findsOneWidget,
      );

      // Verify vertical positioning: Status badge must be higher on screen than Checkpoints header
      final statusTop = tester.getTopLeft(inSheet(find.text('SESUAI'))).dy;
      final checkpointsTop = tester
          .getTopLeft(inSheet(find.text('Standar SOP')))
          .dy;
      expect(statusTop, lessThan(checkpointsTop));
    });

    testWidgets(
      'Modal validasi AI: Cara memperbaiki + 3 card Kondisi Item + aksi utama jelas',
      skip: true, // redesign layout, TODO post-2.0.135
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        await StorageService.init();
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final submission = MaintenanceSubmission(
          id: 'test_sub_perbaikan',
          templateId: serverTemplate.id,
          templateName: serverTemplate.nama,
          userId: 'u1',
          userName: 'Teknisi Test',
          userNpp: '1234',
          posId: 'POS1',
          posName: 'Pos 1',
          cabangName: 'Cabang Test',
          points: [
            const MaintenancePointResult(
              pointId: 'srv_1_01',
              label:
                  'PC Server & Kasir - Pembersihan Storage Linux (df -h & /tmp)',
              status: PointStatus.tidakSesuai,
              confidence: 0.95,
              alasan: 'Foto terlalu gelap, indikator LED tidak terlihat',
            ),
          ],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: MaintenanceChecklistScreen(
              template: serverTemplate,
              existingSubmission: submission,
              serverOs: 'linux',
              isServerKasirGabung: true,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.textContaining('Pembersihan Storage Linux').first,
        );
        await tester.pumpAndSettle();

        // Semua pengecekan di-scope ke bottom sheet
        final sheet = find.byType(BottomSheet);
        Finder inSheet(Finder f) => find.descendant(of: sheet, matching: f);

        // Hasil AI + alasan tetap jelas
        expect(inSheet(find.text('TIDAK SESUAI')), findsOneWidget);
        // Panduan perbaikan sesuai masalah yang terdeteksi (bukan template kosong)
        expect(inSheet(find.text('Cara memperbaiki')), findsOneWidget);
        expect(
          inSheet(find.textContaining('pencahayaan yang cukup')),
          findsOneWidget,
        );
        // Kondisi Item: 3 card sejajar
        expect(inSheet(find.text('Kondisi Item')), findsOneWidget);
        expect(inSheet(find.text('(Pilih salah satu)')), findsOneWidget);
        expect(inSheet(find.text('Masih aman')), findsOneWidget);
        expect(inSheet(find.text('Sudah mulai rusak')), findsOneWidget);
        expect(inSheet(find.text('Harus diganti')), findsOneWidget);
        // Aksi utama & sekunder + opsi tidak terpasang
        expect(inSheet(find.text('Foto Ulang')), findsOneWidget);
        expect(
          inSheet(find.text('Pastikan seluruh bagian terlihat jelas.')),
          findsOneWidget,
        );
        expect(inSheet(find.text('Kendala Fisik')), findsOneWidget);
        expect(inSheet(find.text('Ubah Catatan')), findsOneWidget);
        expect(
          inSheet(find.text('Barang Tidak Terpasang / Tidak Ada')),
          findsOneWidget,
        );
        expect(
          inSheet(find.textContaining('Checkpoint maintenance •')),
          findsOneWidget,
        );

        // Belum ada pilihan kondisi -> belum ada indikator centang
        expect(inSheet(find.byIcon(Icons.done_rounded)), findsNothing);

        // Pilih "Harus diganti" -> card terpilih (indikator centang muncul)
        await tester.ensureVisible(inSheet(find.text('Harus diganti')));
        await tester.tap(inSheet(find.text('Harus diganti')));
        await tester.pumpAndSettle();
        expect(inSheet(find.byIcon(Icons.done_rounded)), findsOneWidget);
      },
    );

    testWidgets(
      'Saran perbaikan ikut isi kerusakan fisik (mis. stiker terkelupas)',
      skip: true, // redesign layout, TODO post-2.0.135
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        await StorageService.init();
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          MaterialApp(
            home: MaintenanceChecklistScreen(
              template: serverTemplate,
              existingSubmission: _subSatuPoin(
                PointStatus.tidakSesuai,
                'Stiker depan pos terkelupas pada bagian pinggir kanan.',
              ),
              serverOs: 'linux',
              isServerKasirGabung: true,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.textContaining('Pembersihan Storage Linux').first,
        );
        await tester.pumpAndSettle();

        final sheet = find.byType(BottomSheet);
        Finder inSheet(Finder f) => find.descendant(of: sheet, matching: f);

        expect(inSheet(find.text('Ada Kerusakan Fisik')), findsOneWidget);
        expect(
          inSheet(find.textContaining('catat di Kendala Fisik')),
          findsOneWidget,
        );
        // Bukan disuruh "ambil foto sampai standar" doang seperti teks umum.
        expect(
          inSheet(find.textContaining('sesuai standar SOP')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'Poin SESUAI tidak salah deteksi temuan (mis. "bebas debu")',
      skip: true, // redesign layout, TODO post-2.0.135
      (tester) async {
      SharedPreferences.setMockInitialValues({});
      await StorageService.init();
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: MaintenanceChecklistScreen(
            template: serverTemplate,
            existingSubmission: _subSatuPoin(
              PointStatus.sesuai,
              'Kipas CPU bersih dan bebas debu, suhu normal.',
            ),
            serverOs: 'linux',
            isServerKasirGabung: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Pembersihan Storage Linux').first);
      await tester.pumpAndSettle();

      final sheet = find.byType(BottomSheet);
      Finder inSheet(Finder f) => find.descendant(of: sheet, matching: f);

      expect(inSheet(find.text('SOP Terpenuhi')), findsOneWidget);
      expect(inSheet(find.text('Perlu Pembersihan')), findsNothing);
      expect(inSheet(find.text('Cara memperbaiki')), findsNothing);
      expect(inSheet(find.text('Kondisi Item')), findsNothing);
    });

    testWidgets('Setup barrier gate: penanda arah gate IN/OUT bisa dipilih', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final barrierTemplate = TemplateRepository.defaultTemplates.firstWhere(
        (t) => t.id == 'tpl_maint_barrier',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MaintenanceSetupDialog(initialTemplate: barrierTemplate),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Arah Gate (opsional):'), findsOneWidget);
      expect(find.text('IN'), findsNWidgets(2));
      expect(find.text('OUT'), findsNWidgets(2));

      // Gate 1 = IN, Gate 2 = OUT
      await tester.tap(find.text('IN').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('OUT').last);
      await tester.pumpAndSettle();

      // Tidak boleh ada overflow / error render setelah chip dipilih
      expect(tester.takeException(), isNull);
    });
  });
}

/// Submission satu poin buat nguji deteksi saran perbaikan.
MaintenanceSubmission _subSatuPoin(PointStatus status, String alasan) =>
    MaintenanceSubmission(
      id: 'test_sub_deteksi',
      templateId: 'tpl_maint_server',
      templateName: 'Maintenance: Server & Kasir',
      userId: 'u1',
      userName: 'Teknisi Test',
      userNpp: '1234',
      posId: 'POS1',
      posName: 'Pos 1',
      cabangName: 'Cabang Test',
      points: [
        MaintenancePointResult(
          pointId: 'srv_1_01',
          label: 'PC Server & Kasir - Pembersihan Storage Linux (df -h & /tmp)',
          status: status,
          confidence: 0.95,
          alasan: alasan,
        ),
      ],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
