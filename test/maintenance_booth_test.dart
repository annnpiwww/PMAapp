import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bssparking_timemark/data/models/template_model.dart';
import 'package:bssparking_timemark/data/models/maintenance_submission.dart';
import 'package:bssparking_timemark/data/repositories/template_repository.dart';
import 'package:bssparking_timemark/data/services/whatsapp_report_service.dart';
import 'package:bssparking_timemark/features/maintenance/screens/maintenance_checklist_screen.dart';
import 'package:bssparking_timemark/features/maintenance/widgets/maintenance_setup_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Mode Booth Parkir punya 5 poin SOP dengan caption sesuai permintaan', () {
    final points = TemplateRepository.boothParkirPoints;

    expect(points.length, equals(5));
    expect(points[0].label, equals('Pembersihan Printer'));
    expect(points[0].deskripsi,
        equals('Head printer, roller karet, dan tempat kertas bersih'));
    expect(points[1].deskripsi, equals('Booth dalam keadaan bersih'));
    expect(points[2].deskripsi, contains('tab/device Harvard'));
    expect(points[3].deskripsi, contains('tanpa barcode yang memudar'));
    expect(points[4].deskripsi,
        contains('sistem berjalan dengan normal'));
  });

  test('Template Pos Parkir 10 poin (kipas angin di tengah) dan sudah digabung dengan Booth', () {
    final tpl = TemplateRepository.defaultTemplates
        .firstWhere((t) => t.id == 'tpl_maint_pos');

    expect(tpl.nama, equals('Maintenance: Pos Parkir & Booth'));
    expect(tpl.sopPoints.length, equals(10));
    expect(tpl.sopPoints[4].label, equals('Pembersihan Kipas Angin'));
  });

  testWidgets('Setup dialog: pilih Booth memakai target 5 foto', (tester) async {
    final tpl = TemplateRepository.defaultTemplates
        .firstWhere((t) => t.id == 'tpl_maint_pos');

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (ctx) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showDialog(
                  context: ctx,
                  builder: (_) => MaintenanceSetupDialog(initialTemplate: tpl),
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

    await tester.ensureVisible(find.text('Booth'));
    await tester.tap(find.text('Booth'));
    await tester.pumpAndSettle();

    expect(find.text('Pilih Booth Maintenance'), findsOneWidget);
    expect(find.textContaining('Cek Booth 1 saja'), findsOneWidget);
    expect(
      find.textContaining('Target: 5 Foto (1 Booth × 5 foto)'),
      findsOneWidget,
    );
  });

  testWidgets('Checklist mode Booth cuma 5 poin & mode Pos 10 poin', (
    tester,
  ) async {
    final tpl = TemplateRepository.defaultTemplates
        .firstWhere((t) => t.id == 'tpl_maint_pos');

    await tester.pumpWidget(
      MaterialApp(
        home: MaintenanceChecklistScreen(
          template: tpl,
          unitCount: 1,
          unitNumbers: const [1],
          posMode: 'booth',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('0/5 foto selesai'), findsOneWidget);
    expect(find.textContaining('Booth 1 - Pembersihan Printer'), findsWidgets);

    // Pump ulang widget berbeda tipe dulu supaya State booth tidak dipakai lagi.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      MaterialApp(
        home: MaintenanceChecklistScreen(
          template: tpl,
          unitCount: 1,
          unitNumbers: const [1],
          posMode: 'pos',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('0/10 foto selesai'), findsOneWidget);
    expect(find.textContaining('Pos 1 - Pembersihan Total Printer Pos'),
        findsWidgets);
  });

  test('Laporan Booth pakai tema booth & label Booth, bukan tema Pos', () {
    final submission = MaintenanceSubmission(
      id: 'maint_booth_test',
      templateId: 'tpl_maint_pos',
      templateName: 'Maintenance: Pos Parkir & Booth',
      userId: 'tech_booth',
      userName: 'Farhan Lakoro',
      userNpp: '12345',
      posId: 'pos_pbm',
      posName: 'Pasar Bersehati Manado (PBM)',
      cabangName: 'Manado',
      points: const [
        MaintenancePointResult(
          pointId: 'booth_1_01',
          label: 'Booth 1 - Pembersihan Printer',
          status: PointStatus.sesuai,
        ),
        MaintenancePointResult(
          pointId: 'booth_1_02',
          label: 'Booth 1 - Pembersihan Booth',
          status: PointStatus.sesuai,
        ),
        MaintenancePointResult(
          pointId: 'booth_1_03',
          label: 'Booth 1 - Standarisasi Item Booth',
          status: PointStatus.sesuai,
        ),
        MaintenancePointResult(
          pointId: 'booth_1_04',
          label: 'Booth 1 - Tiket Printer Gate Out',
          status: PointStatus.tidakSesuai,
          alasan: 'barcode tiket mulai pudar',
        ),
        MaintenancePointResult(
          pointId: 'booth_1_05',
          label: 'Booth 1 - Aplikasi Payment',
          status: PointStatus.sesuai,
        ),
      ],
      createdAt: DateTime(2026, 10, 20, 9, 0),
      updatedAt: DateTime(2026, 10, 20, 9, 30),
    );

    final text = WhatsAppReportService.generateReportText(
      submission: submission,
      category: TemplateCategory.maintPos,
      unitCount: 1,
    );

    expect(text.contains('Izin melaporkan hasil maintenance BOOTH'), isTrue);
    expect(text.contains('Booth : 1 (Booth 1)'), isTrue);
    expect(text.contains('1. *Pembersihan printer booth* :\n   ✅'), isTrue);
    expect(text.contains('5. *Aplikasi payment* :\n   ✅'), isTrue);
    expect(text.contains('4. *Tiket printer gate out* :\n   ⚠️'), isTrue);
    expect(text.contains('Gate Out'), isFalse);
    expect(text.contains('Kerapian jalur kabel'), isFalse);
  });
}
