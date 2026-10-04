import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bssparking_timemark/data/models/template_model.dart';
import 'package:bssparking_timemark/data/models/maintenance_submission.dart';
import 'package:bssparking_timemark/data/repositories/template_repository.dart';
import 'package:bssparking_timemark/data/services/whatsapp_report_service.dart';
import 'package:bssparking_timemark/features/maintenance/screens/maintenance_checklist_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Server Maintenance OS Selector & Dynamic Checklist Tests', () {
    final serverTemplate = TemplateRepository.defaultTemplates
        .firstWhere((t) => t.id == 'tpl_maint_server');

    testWidgets('Generates Linux checklist when serverOs is linux', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MaintenanceChecklistScreen(
            template: serverTemplate,
            unitCount: 2, // 1 server + 1 kasir
            kasirCount: 1,
            serverOs: 'linux',
            isServerKasirGabung: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify points generated for PC Server
      expect(find.textContaining('PC Server - Pembersihan Storage & File Temp'), findsOneWidget);
      expect(find.textContaining('PC Server - Nonaktifkan Update, Antivirus & Firewall'), findsOneWidget);
      expect(find.textContaining('PC Server - Fungsi Keyboard & Mouse (Input Console Test)'), findsOneWidget);

      // Tap filter chip for PC Kasir 1 to view PC Kasir points
      final kasirChip = find.textContaining('PC Kasir 1');
      expect(kasirChip, findsOneWidget);
      await tester.tap(kasirChip);
      await tester.pumpAndSettle();

      // Verify PC Kasir still has Windows points
      expect(find.textContaining('PC Kasir 1 - Pembersihan Storage & File Temp'), findsOneWidget);
      expect(find.textContaining('PC Kasir 1 - Fungsi Keyboard & Mouse (KeyTest / Notepad)'), findsOneWidget);
    });

    testWidgets('Generates Windows checklist when serverOs is windows', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MaintenanceChecklistScreen(
            template: serverTemplate,
            unitCount: 1,
            serverOs: 'windows',
            isServerKasirGabung: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('PC Server & Kasir - Pembersihan Storage & File Temp'), findsOneWidget);
      expect(find.textContaining('PC Server & Kasir - Fungsi Keyboard & Mouse (KeyTest / Notepad)'), findsOneWidget);
    });

    test('WhatsApp report outputs clean theme labels without "linux df -h" and contains factual AI observations', () {
      final submission = MaintenanceSubmission(
        id: 'maint_test_srv',
        templateId: 'tpl_maint_server',
        templateName: 'Maintenance: Server & Kasir',
        userId: 'tech_1',
        userName: 'Farhan Lakoro',
        userNpp: 'BSS-001',
        posId: 'pos_bersehati',
        posName: 'PASAR BERSEHATI',
        cabangName: 'Manado',
        points: [
          MaintenancePointResult(
            pointId: 'srv_1_01',
            label: 'Server Utama - Pembersihan Storage & File Temp',
            status: PointStatus.sesuai,
            alasan: 'Kapasitas partisi root pada df -h aman dan folder /tmp bersih',
          ),
          MaintenancePointResult(
            pointId: 'srv_1_02',
            label: 'Server Utama - Nonaktifkan Update, Antivirus & Firewall',
            status: PointStatus.sesuai,
            alasan: 'Status firewall ufw inactive dan auto-update dinonaktifkan',
          ),
          MaintenancePointResult(
            pointId: 'srv_2_01',
            label: 'Kasir 1 - Pembersihan Storage & File Temp',
            status: PointStatus.sesuai,
            alasan: 'Kapasitas Drive C aman indikator biru dan folder temp bersih',
          ),
        ],
        createdAt: DateTime(2026, 9, 19, 17, 30),
        updatedAt: DateTime(2026, 9, 19, 17, 30),
      );

      final report = WhatsAppReportService.generateReportText(
        submission: submission,
        category: TemplateCategory.maintServer,
      );

      // Verify clean title without 'linux df -h'
      expect(report, contains('1. *Pembersihan storage & file temp* :'));
      expect(report, isNot(contains('linux df -h')));
      expect(report, isNot(contains('Normal :')));

      // Verify factual observation from AI is included
      expect(report, contains('Kapasitas partisi root pada df -h aman dan folder /tmp bersih'));
      expect(report, contains('Kapasitas Drive C aman indikator biru'));
      expect(report, contains('Status firewall ufw inactive dan auto-update dinonaktifkan'));
    });

    testWidgets('Generates checklist for Hanya Kasir without PC Server', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MaintenanceChecklistScreen(
            template: serverTemplate,
            isOnlyKasir: true,
            kasirCount: 2,
            unitCount: 2,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify no PC Server points exist
      expect(find.textContaining('PC Server -'), findsNothing);
      expect(find.textContaining('PC Server & Kasir -'), findsNothing);

      // Verify PC Kasir 1 points exist
      expect(find.textContaining('PC Kasir 1 - Pembersihan Storage & File Temp'), findsOneWidget);
      expect(find.textContaining('PC Kasir 1 - Fungsi Keyboard & Mouse (KeyTest / Notepad)'), findsOneWidget);

      // Verify filter tabs use PC Kasir
      expect(find.textContaining('Semua PC Kasir'), findsOneWidget);
      expect(find.textContaining('PC Kasir 1'), findsWidgets);
      expect(find.textContaining('PC Kasir 2 (6)'), findsOneWidget);
    });

    test('WhatsApp report outputs Komputer Kasir title and device count when only kasir points exist', () {
      final submission = MaintenanceSubmission(
        id: 'maint_test_only_kasir',
        templateId: 'tpl_maint_server',
        templateName: 'Maintenance: Server & Kasir',
        userId: 'tech_1',
        userName: 'Farhan Lakoro',
        userNpp: 'BSS-001',
        posId: 'pos_bersehati',
        posName: 'PASAR BERSEHATI',
        cabangName: 'Manado',
        points: [
          MaintenancePointResult(
            pointId: 'srv_1_01',
            label: 'PC Kasir 1 - Pembersihan Storage & File Temp',
            status: PointStatus.sesuai,
            alasan: 'Drive C aman dan file temp bersih',
          ),
          MaintenancePointResult(
            pointId: 'srv_2_01',
            label: 'PC Kasir 2 - Pembersihan Storage & File Temp',
            status: PointStatus.sesuai,
            alasan: 'Drive C lega dan folder temp sudah dikosongkan',
          ),
        ],
        createdAt: DateTime(2026, 9, 21, 10, 0),
        updatedAt: DateTime(2026, 9, 21, 10, 0),
      );

      final report = WhatsAppReportService.generateReportText(
        submission: submission,
        category: TemplateCategory.maintServer,
      );

      expect(report, contains('Izin melaporkan hasil maintenance Komputer Kasir'));
      expect(report, contains('Perangkat : 2 PC Kasir'));
      expect(report, isNot(contains('Server & Komputer Kasir')));
      expect(report, isNot(contains('Server Utama')));
    });
  });
}
