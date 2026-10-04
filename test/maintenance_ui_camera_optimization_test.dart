import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bssparking_timemark/data/models/maintenance_submission.dart';
import 'package:bssparking_timemark/data/repositories/template_repository.dart';
import 'package:bssparking_timemark/features/maintenance/widgets/maintenance_setup_dialog.dart';
import 'package:bssparking_timemark/features/maintenance/screens/maintenance_checklist_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Maintenance Setup Dialog UI & Dynamic Calculation Tests', () {
    final serverTemplate = TemplateRepository.defaultTemplates
        .firstWhere((t) => t.id == 'tpl_maint_server');

    testWidgets('Displays PC Server & PC Kasir terms and calculates dynamic photos correctly', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MaintenanceSetupDialog(
              initialTemplate: serverTemplate,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify header & titles use Maintenance: Server & Kasir
      expect(find.text('Maintenance: Server & Kasir'), findsWidgets);
      expect(find.text('Pemeriksaan PC Server dan PC Kasir'), findsWidgets);
      expect(find.text('PC Server & PC Kasir Terpisah'), findsOneWidget);
      expect(find.text('1 PC Server (Wajib 6 foto)'), findsOneWidget);
      expect(find.text('Jumlah PC Kasir'), findsOneWidget);

      // Default state: Terpisah ON, 1 PC Kasir -> 12 photos
      expect(find.textContaining('Total Wajib: 12 Foto (1 PC Server + 1 PC Kasir)'), findsOneWidget);
      expect(find.textContaining('6 foto PC Server + 6 foto PC Kasir (1 unit × 6 foto)'), findsOneWidget);

      // Increment PC Kasir counter
      final addKasirBtn = find.byIcon(Icons.add_rounded);
      expect(addKasirBtn, findsOneWidget);
      await tester.tap(addKasirBtn);
      await tester.pumpAndSettle();

      // Now 2 PC Kasir -> 18 photos
      expect(find.textContaining('Total Wajib: 18 Foto (1 PC Server + 2 PC Kasir)'), findsOneWidget);
      expect(find.textContaining('6 foto PC Server + 12 foto PC Kasir (2 unit × 6 foto)'), findsOneWidget);

      // Toggle Switch to Gabung (OFF)
      final allInOneSwitch = find.byType(Switch);
      expect(allInOneSwitch, findsOneWidget);
      await tester.tap(allInOneSwitch);
      await tester.pumpAndSettle();

      // Gabung OFF -> 6 photos total
      expect(find.text('OFF: Gabung (1 Komputer)'), findsOneWidget);
      expect(find.textContaining('Total Wajib: 6 Foto (1 Unit PC Server & Kasir Gabung)'), findsOneWidget);
      expect(find.textContaining('6 foto SOP PC Server & PC Kasir gabung (1 komputer)'), findsOneWidget);
    });

    testWidgets('Tapping Hanya Kasir card hides server options and calculates kasir photos correctly', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MaintenanceSetupDialog(
              initialTemplate: serverTemplate,
            ),
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
      expect(find.text('Pemeriksaan Unit PC Kasir'), findsWidgets);

      // Server options should be hidden
      expect(find.text('PC Server & PC Kasir Terpisah'), findsNothing);
      expect(find.text('Sistem Operasi Server'), findsNothing);

      // Default 1 PC Kasir -> 6 photos
      expect(find.textContaining('Total Wajib: 6 Foto (1 PC Kasir)'), findsOneWidget);

      // Increment to 3 PC Kasir
      final addBtn = find.byIcon(Icons.add_rounded);
      await tester.tap(addBtn);
      await tester.pumpAndSettle();
      await tester.tap(addBtn);
      await tester.pumpAndSettle();

      // 3 PC Kasir -> 18 photos
      expect(find.textContaining('Total Wajib: 18 Foto (3 PC Kasir)'), findsOneWidget);
      expect(find.textContaining('18 foto SOP PC Kasir (3 unit × 6 foto)'), findsOneWidget);
    });
  });

  group('Checklist Screen Modal Status Banner Position Tests', () {
    final serverTemplate = TemplateRepository.defaultTemplates
        .firstWhere((t) => t.id == 'tpl_maint_server');

    testWidgets('Modal shows status banner prominently at top above checkpoints', (tester) async {
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
          MaintenancePointResult(
            pointId: 'srv_1_01',
            label: 'PC Server & Kasir - Pembersihan Storage Linux (df -h & /tmp)',
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

      // Verify Status badge appears in bottom sheet
      expect(find.text('Status: Sesuai'), findsOneWidget);

      // Verify checkpoint guidelines are also present
      expect(find.text('CHECKPOINT WAJIB DIPERIKSA:'), findsOneWidget);

      // Verify vertical positioning: Status badge must be higher on screen than Checkpoints header
      final statusTop = tester.getTopLeft(find.text('Status: Sesuai')).dy;
      final checkpointsTop = tester.getTopLeft(find.text('CHECKPOINT WAJIB DIPERIKSA:')).dy;
      expect(statusTop, lessThan(checkpointsTop));
    });
  });
}
