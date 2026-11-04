import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bssparking_timemark/data/models/template_model.dart';
import 'package:bssparking_timemark/data/models/maintenance_submission.dart';
import 'package:bssparking_timemark/data/repositories/template_repository.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';
import 'package:bssparking_timemark/data/services/whatsapp_report_service.dart';
import 'package:bssparking_timemark/features/maintenance/screens/maintenance_checklist_screen.dart';
import 'package:bssparking_timemark/features/maintenance/widgets/maintenance_setup_dialog.dart';

MaintenanceSubmission _submissionWith(List<MaintenancePointResult> points) {
  return MaintenanceSubmission(
    id: 'maint_lengkap_test',
    templateId: 'tpl_maint_lengkap',
    templateName: 'Maintenance: Lengkap',
    userId: 'tech_1',
    userName: 'Farhan Lakoro',
    userNpp: 'BSS-001',
    posId: 'pos_bersehati',
    posName: 'PASAR BERSEHATI',
    cabangName: 'Manado',
    points: points,
    createdAt: DateTime(2026, 10, 19, 9),
    updatedAt: DateTime(2026, 10, 19, 9),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Maintenance Lengkap (1 tugas semua area)', () {
    test('template default tpl_maint_lengkap ada, kategori lengkap, poin diturunkan runtime', () {
      final tpl = TemplateRepository.defaultTemplates.firstWhere(
        (t) => t.id == 'tpl_maint_lengkap',
      );

      expect(tpl.jenis, TemplateCategory.maintLengkap);
      expect(tpl.jenis.isMaintenance, isTrue);
      expect(tpl.jenis.displayName, 'Maintenance Lengkap');
      // Poin sengaja dikosongkan: diambil dari template area saat runtime.
      expect(tpl.sopPoints, isEmpty);
      expect(tpl.sopCriteria, isNotEmpty);
    });

    test('fromString mengenali kategori lengkap dari beberapa penulisan', () {
      expect(
        TemplateCategory.fromString('maintLengkap'),
        TemplateCategory.maintLengkap,
      );
      expect(
        TemplateCategory.fromString('Maintenance Lengkap'),
        TemplateCategory.maintLengkap,
      );
    });

    testWidgets('checklist lengkap menggabung poin gate + manless + pos + server', (
      tester,
    ) async {
      final lengkap = TemplateRepository.defaultTemplates.firstWhere(
        (t) => t.id == 'tpl_maint_lengkap',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MaintenanceChecklistScreen(
            template: lengkap,
            unitNumbers: const [1, 2],
            unitRoles: const {1: 'IN', 2: 'OUT'},
            manlessUnits: const [1, 2],
            posUnits: const [1],
            includeServer: true,
            serverOs: 'linux',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 2 gate x 9 + 2 manless x 8 + 1 pos x 10 + 1 server x 6 = 50 foto
      expect(find.textContaining('0/50 foto selesai'), findsOneWidget);
      expect(
        find.textContaining(
          'Semua area: Barrier Gate + Manless + Pos Kasir + PC Server',
        ),
        findsOneWidget,
      );
      // Area gate tampil paling atas dan sudah pakai arah IN/OUT dari setup.
      expect(
        find.textContaining('Barrier Gate 1 (IN) - Dudukan Mesin & Baut Dynabolt'),
        findsOneWidget,
      );
    });

    testWidgets('cakupan 3 area tidak menghasilkan poin server', (tester) async {
      final lengkap = TemplateRepository.defaultTemplates.firstWhere(
        (t) => t.id == 'tpl_maint_lengkap',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MaintenanceChecklistScreen(
            template: lengkap,
            unitNumbers: const [1],
            manlessUnits: const [1],
            posUnits: const [1],
            includeServer: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1 gate x 9 + 1 manless x 8 + 1 pos x 10 = 27 foto
      expect(find.textContaining('0/27 foto selesai'), findsOneWidget);
      expect(
        find.textContaining('Semua area: Barrier Gate + Manless + Pos Kasir •'),
        findsOneWidget,
      );
      expect(find.textContaining('PC Server'), findsNothing);
    });

    testWidgets('dialog setup lengkap: default 3 area, server bisa dinyalakan', (
      tester,
    ) async {
      final lengkap = TemplateRepository.defaultTemplates.firstWhere(
        (t) => t.id == 'tpl_maint_lengkap',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showDialog(
                    context: ctx,
                    builder: (_) =>
                        MaintenanceSetupDialog(initialTemplate: lengkap),
                  ),
                  child: const Text('buka'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('buka'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Cek: 2 Gate + 2 Manless + 1 Pos'),
        findsOneWidget,
      );
      expect(find.textContaining('Target: 43 Foto'), findsOneWidget);

      await tester.ensureVisible(find.byType(Switch));
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Cek: 2 Gate + 2 Manless + 1 Pos + 1 PC Server'),
        findsOneWidget,
      );
      expect(find.textContaining('Target: 49 Foto'), findsOneWidget);
    });

    testWidgets('filter per area: chip Barrier/Manless/Pos/Server menyaring checklist', (
      tester,
    ) async {
      final lengkap = TemplateRepository.defaultTemplates.firstWhere(
        (t) => t.id == 'tpl_maint_lengkap',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MaintenanceChecklistScreen(
            template: lengkap,
            unitNumbers: const [1, 2],
            unitRoles: const {1: 'IN', 2: 'OUT'},
            manlessUnits: const [2],
            posUnits: const [1],
            includeServer: true,
            serverOs: 'linux',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 2 gate x 9 + 1 manless x 8 + 1 pos x 10 + 1 server x 6 = 42 foto
      expect(find.text('Semua Area (42)'), findsOneWidget);
      expect(find.text('Barrier Gate (18)'), findsOneWidget);
      expect(find.text('Manless (8)'), findsOneWidget);
      expect(find.text('Pos Kasir (10)'), findsOneWidget);

      // Chip Server ada di ujung baris chip, geser dulu biar kelihatan.
      await tester.drag(find.text('Manless (8)'), const Offset(-400, 0));
      await tester.pumpAndSettle();
      expect(find.text('PC Server (6)'), findsOneWidget);

      // Tekan chip PC Server: header ikut area itu dan poin gate hilang dari daftar.
      await tester.tap(find.text('PC Server (6)'));
      await tester.pumpAndSettle();

      expect(find.textContaining('PC Server • 0/6 foto selesai'), findsOneWidget);
      expect(
        find.textContaining('Barrier Gate 1 (IN) - Dudukan Mesin & Baut Dynabolt'),
        findsNothing,
      );
      expect(
        find.textContaining('PC Server - Pembersihan Storage & File Temp'),
        findsOneWidget,
      );

      // Balik ke Semua Area.
      await tester.drag(find.text('PC Server (6)'), const Offset(400, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Semua Area (42)'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining(
          'Semua area: Barrier Gate + Manless + Pos Kasir + PC Server',
        ),
        findsOneWidget,
      );
    });

    test('laporan lengkap 1 header + seksi per area yang sudah ada', () {
      SharedPreferences.setMockInitialValues({});
      return StorageService.init().then((_) {
        final text = WhatsAppReportService.generateReportText(
          submission: _submissionWith([
            const MaintenancePointResult(
              pointId: 'bar_1_01',
              label: 'Barrier Gate 1 (IN) - Dudukan Mesin & Baut Dynabolt',
              status: PointStatus.sesuai,
            ),
            const MaintenancePointResult(
              pointId: 'man_1_01',
              label: 'Manless 1 - Pembersihan Total Printer Tiket',
              status: PointStatus.sesuai,
            ),
            const MaintenancePointResult(
              pointId: 'pos_1_01',
              label: 'Pos 1 - Pembersihan Total Printer Pos',
              status: PointStatus.sesuai,
            ),
            const MaintenancePointResult(
              pointId: 'srv_1_01',
              label: 'PC Server - Pembersihan Storage & File Temp',
              status: PointStatus.sesuai,
            ),
          ]),
          category: TemplateCategory.maintLengkap,
        );

        expect(
          text,
          contains(
            'Izin melaporkan hasil Maintenance Lengkap (Barrier Gate + Manless + Pos Kasir + PC Server)',
          ),
        );
        expect(text, contains('Lokasi : PASAR BERSEHATI'));
        // Tiap area tetap dilaporkan dengan penulis laporan area aslinya.
        expect(text, contains('— BARRIER GATE —'));
        expect(text, contains('dudukan mesin & baut dynabolt'));
        expect(text, contains('— MANLESS —'));
        expect(text, contains('Pembersihan total printer tiket'));
        expect(text, contains('— POS KASIR —'));
        expect(text, contains('Pembersihan total printer pos'));
        expect(text, contains('— PC SERVER —'));
        expect(text, contains('Pembersihan storage & file temp'));
        expect(text, contains('Total Point: 4'));
      });
    });

    test('laporan 3 area tidak menulis seksi area yang belum dicek', () {
      SharedPreferences.setMockInitialValues({});
      return StorageService.init().then((_) {
        final text = WhatsAppReportService.generateReportText(
          submission: _submissionWith([
            const MaintenancePointResult(
              pointId: 'bar_1_01',
              label: 'Barrier Gate 1 (IN) - Dudukan Mesin & Baut Dynabolt',
              status: PointStatus.sesuai,
            ),
            const MaintenancePointResult(
              pointId: 'pos_1_01',
              label: 'Pos 1 - Pembersihan Total Printer Pos',
              status: PointStatus.sesuai,
            ),
          ]),
          category: TemplateCategory.maintLengkap,
        );

        expect(
          text,
          contains(
            'Izin melaporkan hasil Maintenance Lengkap (Barrier Gate + Pos Kasir)',
          ),
        );
        expect(text, contains('— BARRIER GATE —'));
        expect(text, contains('— POS KASIR —'));
        expect(text, isNot(contains('— MANLESS —')));
        expect(text, isNot(contains('— PC SERVER —')));
      });
    });
  });
}
