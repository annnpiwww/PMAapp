import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bssparking_timemark/data/models/daily_task_model.dart';
import 'package:bssparking_timemark/data/models/maintenance_submission.dart';
import 'package:bssparking_timemark/data/models/template_model.dart';
import 'package:bssparking_timemark/data/repositories/template_repository.dart';
import 'package:bssparking_timemark/data/services/branch_service.dart';
import 'package:bssparking_timemark/data/services/daily_task_service.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';
import 'package:bssparking_timemark/data/services/whatsapp_report_service.dart';
import 'package:bssparking_timemark/features/maintenance/screens/maintenance_checklist_screen.dart';
import 'package:bssparking_timemark/features/maintenance/widgets/maintenance_setup_dialog.dart';

MaintenanceSubmission _submissionWith(List<MaintenancePointResult> points) {
  return MaintenanceSubmission(
    id: 'maint_manless_role_test',
    templateId: 'tpl_maint_manless',
    templateName: 'Maintenance: Manless & Pulau Gate',
    userId: 'tech_1',
    userName: 'Farhan Lakoro',
    userNpp: 'BSS-001',
    posId: 'pos_bersehati',
    posName: 'PASAR BERSEHATI',
    cabangName: 'Manado',
    points: points,
    createdAt: DateTime(2026, 10, 22, 9),
    updatedAt: DateTime(2026, 10, 22, 9),
  );
}

MaintenancePointResult _point(String id, String label) => MaintenancePointResult(
  pointId: id,
  label: label,
  status: PointStatus.sesuai,
  alasan: 'bersih dan tidak berdebu',
);

TemplateModel get _manlessTemplate => TemplateRepository.defaultTemplates
    .firstWhere((t) => t.id == 'tpl_maint_manless');

TemplateModel get _lengkapTemplate => TemplateRepository.defaultTemplates
    .firstWhere((t) => t.id == 'tpl_maint_lengkap');

Future<void> _openSetupDialog(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (ctx) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showDialog(
                context: ctx,
                builder: (_) =>
                    MaintenanceSetupDialog(initialTemplate: _manlessTemplate),
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
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    BranchService.instance.resetForTesting();
  });

  group('SOP Manless OUT & PEP', () {
    test('OUT = 8 poin IN + 4 perangkat dengan caption sesuai', () {
      final extras = TemplateRepository.manlessOutExtraPoints;
      expect(extras.length, 4);
      expect(extras[0].label, 'Pembersihan Item Mini PC');
      expect(
        extras[0].deskripsi,
        'Mini pc dalam keadaan bersih dan tidak berdebu',
      );
      expect(extras[1].label, 'Pembersihan AINO');
      expect(extras[1].deskripsi, 'AINO dalam keadaan bersih dan tidak berdebu');
      expect(extras[2].label, 'Pembersihan Scanner');
      expect(
        extras[2].deskripsi,
        'Scanner dalam keadaan bersih dan tidak berdebu',
      );
      expect(extras[3].label, 'Pembersihan Layar Monitor');
      expect(
        extras[3].deskripsi,
        'Layar monitor dalam keadaan bersih dan tidak berdebu',
      );
    });

    test('PEP punya 5 poin pulau & kunci', () {
      final pep = TemplateRepository.manlessPepPoints;
      expect(pep.length, 5);
      expect(
        pep[0].deskripsi,
        'Bagian dalam manless bersih dan perkabelan rapih',
      );
      expect(
        pep[1].deskripsi,
        'Body luar manless bersih dan stiker petunjuk terbaca jelas',
      );
      expect(pep[2].deskripsi, 'Dudukan dynabolt kuat dan kokoh, tidak goyang');
      expect(
        pep[3].deskripsi,
        'Pulau kokoh, tidak hancur dan cat pulau masih jelas',
      );
      expect(
        pep[4].deskripsi,
        'Kunci pintu manless berfungsi normal dan tidak berkarat',
      );
    });
  });

  group('Setup dialog role Manless', () {
    testWidgets('HO menampilkan IN / OUT / PEP dan hitungan foto ikut role', (
      tester,
    ) async {
      await BranchService.instance.setBranch(AppBranch.ho);
      await _openSetupDialog(tester);

      expect(find.text('IN'), findsOneWidget);
      expect(find.text('OUT'), findsOneWidget);
      expect(find.text('PEP'), findsOneWidget);
      expect(
        find.text('Pilih manless yang dicek (8 foto/unit)'),
        findsOneWidget,
      );

      await tester.tap(find.text('OUT'));
      await tester.pumpAndSettle();
      expect(
        find.text('Pilih manless yang dicek (12 foto/unit)'),
        findsOneWidget,
      );

      await tester.tap(find.text('PEP'));
      await tester.pumpAndSettle();
      expect(
        find.text('Pilih manless yang dicek (5 foto/unit)'),
        findsOneWidget,
      );
    });

    testWidgets('Manado hanya IN / PEP (tanpa OUT)', (tester) async {
      await BranchService.instance.setBranch(AppBranch.manado);
      await _openSetupDialog(tester);

      expect(find.text('IN'), findsOneWidget);
      expect(find.text('OUT'), findsNothing);
      expect(find.text('PEP'), findsOneWidget);
    });
  });

  group('Checklist role Manless', () {
    testWidgets('OUT memakai 12 poin dan label (OUT)', (tester) async {
      // Layar tinggi supaya 12 kartu poin ikut ter-render (ListView lazy).
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: MaintenanceChecklistScreen(
            template: _manlessTemplate,
            unitNumbers: const [1],
            unitCount: 1,
            manlessRole: 'OUT',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('0/12 foto selesai'), findsOneWidget);
      expect(
        find.textContaining('Manless 1 (OUT) - Pembersihan Item Mini PC'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Manless 1 (OUT) - Pembersihan Total Printer Tiket'),
        findsOneWidget,
      );
    });

    testWidgets('PEP memakai 5 poin dan label (PEP)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MaintenanceChecklistScreen(
            template: _manlessTemplate,
            unitNumbers: const [1],
            unitCount: 1,
            manlessRole: 'PEP',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('0/5 foto selesai'), findsOneWidget);
      expect(
        find.textContaining('Manless 1 (PEP) - Kebersihan & Kerapihan Kabel'),
        findsOneWidget,
      );
    });
  });

  group('Maintenance Lengkap + role Manless', () {
    testWidgets('OUT menambah 4 poin manless & labelnya (OUT)', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: MaintenanceChecklistScreen(
            template: _lengkapTemplate,
            unitNumbers: const [1],
            manlessUnits: const [1],
            posUnits: const [1],
            manlessRole: 'OUT',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1 gate x 9 + 1 manless x 12 + 1 pos x 10 = 31 foto
      expect(find.textContaining('0/31 foto selesai'), findsOneWidget);
      expect(
        find.textContaining('Manless 1 (OUT) - Pembersihan Item Mini PC'),
        findsOneWidget,
      );
    });

    testWidgets('PEP memakai 5 poin manless di area lengkap', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: MaintenanceChecklistScreen(
            template: _lengkapTemplate,
            unitNumbers: const [1],
            manlessUnits: const [1],
            posUnits: const [1],
            manlessRole: 'PEP',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1 gate x 9 + 1 manless x 5 + 1 pos x 10 = 24 foto
      expect(find.textContaining('0/24 foto selesai'), findsOneWidget);
      expect(
        find.textContaining('Manless 1 (PEP) - Kunci Manless'),
        findsOneWidget,
      );
    });

    testWidgets('setup lengkap menampilkan pemilih SOP Manless', (
      tester,
    ) async {
      await BranchService.instance.setBranch(AppBranch.ho);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showDialog(
                    context: ctx,
                    builder: (_) =>
                        MaintenanceSetupDialog(initialTemplate: _lengkapTemplate),
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

      expect(find.text('Pilih SOP Manless'), findsOneWidget);
      expect(
        find.text('Manless 8 foto/unit • Pos Kasir 9 foto/pos • Server 6 foto'),
        findsOneWidget,
      );

      await tester.ensureVisible(find.byKey(const ValueKey('manless_role_OUT')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('manless_role_OUT')));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Manless 12 foto/unit • Pos Kasir 9 foto/pos • Server 6 foto',
        ),
        findsOneWidget,
      );
    });
  });

  group('Laporan WhatsApp Manless', () {
    test('OUT memakai header Gate Out dan memuat 4 item perangkat', () {
      final report = WhatsAppReportService.generateReportText(
        submission: _submissionWith([
          _point('mout_1_01', 'Manless 1 (OUT) - Pembersihan Item Mini PC'),
          _point('mout_1_02', 'Manless 1 (OUT) - Pembersihan AINO'),
          _point('mout_1_03', 'Manless 1 (OUT) - Pembersihan Scanner'),
          _point('mout_1_04', 'Manless 1 (OUT) - Pembersihan Layar Monitor'),
        ]),
        category: TemplateCategory.maintManless,
      );

      expect(report, contains('Gate Out : 1'));
      expect(report, isNot(contains('Gate In')));
      expect(report, contains('Pembersihan item mini PC'));
      expect(report, contains('Pembersihan AINO'));
      expect(report, contains('Pembersihan scanner'));
      expect(report, contains('Pembersihan layar monitor'));
      expect(report, isNot(contains('belum diperiksa')));
    });

    test('PEP memakai header Manless PEP tanpa tema IN yang tidak ada', () {
      final report = WhatsAppReportService.generateReportText(
        submission: _submissionWith([
          _point(
            'mpep_1_01',
            'Manless 1 (PEP) - Kebersihan & Kerapihan Kabel dalam Manless',
          ),
          _point(
            'mpep_1_02',
            'Manless 1 (PEP) - Kebersihan Body Luar Manless & Stiker',
          ),
          _point('mpep_1_03', 'Manless 1 (PEP) - Dudukan Dynabolt Manless'),
          _point('mpep_1_04', 'Manless 1 (PEP) - Kondisi Fisik Pulau Manless'),
          _point('mpep_1_05', 'Manless 1 (PEP) - Kunci Manless'),
        ]),
        category: TemplateCategory.maintManless,
      );

      expect(report, contains('Manless PEP : 1'));
      expect(report, isNot(contains('Gate In')));
      expect(report, isNot(contains('Pembersihan total printer tiket')));
      expect(report, isNot(contains('belum diperiksa')));
      expect(report, contains('Kunci manless & gembok'));
    });
  });

  group('Hapus daily task SPV', () {
    test('pending lokal terhapus dari cache dan antrean', () async {
      final task = await DailyTaskService.createTask(
        tanggal: '2026-10-22',
        teknisiNama: 'Ryan Lumasuge',
        posName: 'PBM',
        posTag: 'PBM',
        judul: 'Tugas salah input',
      );
      expect(task, isNotNull);
      expect(task!.id, startsWith('local_'));
      expect(
        StorageService.getStringList('pending_daily_task_creations_v1'),
        isNotEmpty,
      );

      final deleted = await DailyTaskService.deleteTask(task);

      expect(deleted, isTrue);
      expect(
        DailyTaskService.getCachedTasksLocally().any((t) => t.id == task.id),
        isFalse,
      );
      final queue =
          StorageService.getStringList('pending_daily_task_creations_v1') ?? [];
      expect(
        queue.any((raw) => jsonDecode(raw)['localId'] == task.id),
        isFalse,
      );
    });

    test('tugas completed tidak boleh dihapus (bukti audit aman)', () async {
      final task = DailyTaskModel(
        id: 'task_completed_1',
        tanggal: '2026-10-22',
        teknisiId: 'tech_1',
        teknisiNama: 'Ryan Lumasuge',
        posName: 'PBM',
        posTag: 'PBM',
        judul: 'Tugas selesai',
        status: TaskStatus.completed,
      );

      expect(await DailyTaskService.deleteTask(task), isFalse);
    });
  });
}
