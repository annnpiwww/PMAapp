import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bssparking_timemark/data/models/daily_task_model.dart';
import 'package:bssparking_timemark/data/models/maintenance_submission.dart';
import 'package:bssparking_timemark/data/models/template_model.dart';
import 'package:bssparking_timemark/data/services/daily_task_service.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';
import 'package:bssparking_timemark/data/repositories/template_repository.dart';
import 'package:bssparking_timemark/features/maintenance/screens/maintenance_checklist_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    await TemplateRepository.instance.init();
  });

  group('MaintenanceSubmission taskId & copyWith Tests', () {
    test('MaintenanceSubmission serializes taskId correctly', () {
      final now = DateTime.now();
      final sub = MaintenanceSubmission(
        id: 'maint_test_1',
        templateId: 'tpl_maint_pos',
        templateName: 'Maintenance Pos',
        userId: 'tek_01',
        userName: 'Ahmad BSS',
        userNpp: '12345',
        posId: 'POS 01',
        posName: 'Pos 1 Keluar',
        cabangName: 'Mall Phinisi',
        points: [
          const MaintenancePointResult(
            pointId: 'pos_1_01',
            label: 'Pembersihan Total Printer Pos',
            status: PointStatus.sesuai,
          ),
          const MaintenancePointResult(
            pointId: 'pos_1_02',
            label: 'Kerapian Jalur Kabel Stopkontak',
            status: PointStatus.belumFoto,
          ),
        ],
        createdAt: now,
        updatedAt: now,
        taskId: 'daily_task_99',
      );

      final json = sub.toJson();
      expect(json['taskId'], equals('daily_task_99'));

      final fromJson = MaintenanceSubmission.fromJson(json);
      expect(fromJson.taskId, equals('daily_task_99'));
      expect(fromJson.doneCount, equals(1));
      expect(fromJson.totalPoints, equals(2));
      expect(fromJson.isComplete, isFalse);

      final copied = fromJson.copyWith(taskId: 'daily_task_updated');
      expect(copied.taskId, equals('daily_task_updated'));
      expect(copied.id, equals(sub.id));
    });
  });

  group('DailyTaskService.getOngoingMaintenance Tests', () {
    test('Returns ongoing submission when taskId matches directly', () {
      final now = DateTime.now();
      final task = DailyTaskModel(
        id: 'task_001',
        tanggal: '2026-10-05',
        teknisiId: 'tek_01',
        teknisiNama: 'Ahmad BSS',
        posName: 'Pos 1 Keluar',
        posTag: 'POS 01',
        judul: 'Maintenance Pos 1',
        templateId: 'tpl_maint_pos',
        kategori: 'maintenance',
      );

      final sub = MaintenanceSubmission(
        id: 'sub_123',
        templateId: 'tpl_maint_pos',
        templateName: 'Maintenance Pos',
        userId: 'tek_01',
        userName: 'Ahmad BSS',
        userNpp: '12345',
        posId: 'POS 01',
        posName: 'Pos 1 Keluar',
        cabangName: 'Mall Phinisi',
        points: [
          const MaintenancePointResult(pointId: 'p1', label: 'Point 1', status: PointStatus.sesuai),
          const MaintenancePointResult(pointId: 'p2', label: 'Point 2', status: PointStatus.belumFoto),
        ],
        createdAt: now,
        updatedAt: now,
        taskId: 'task_001',
      );

      final result = DailyTaskService.getOngoingMaintenance(task, submissions: [sub]);
      expect(result, isNotNull);
      expect(result!.id, equals('sub_123'));
      expect(result.doneCount, equals(1));
    });

    test('Returns ongoing submission when templateId & location match (even without taskId initially)', () {
      final now = DateTime.now();
      final task = DailyTaskModel(
        id: 'task_002',
        tanggal: '2026-10-05',
        teknisiId: 'tek_01',
        teknisiNama: 'Ahmad BSS',
        posName: 'Mall Panakkukang Pos 2',
        posTag: 'POS 02',
        judul: 'Maintenance Pos 2',
        templateId: 'tpl_maint_pos',
        kategori: 'maintenance',
      );

      final sub = MaintenanceSubmission(
        id: 'sub_456',
        templateId: 'tpl_maint_pos',
        templateName: 'Maintenance Pos',
        userId: 'tek_01',
        userName: 'Ahmad BSS',
        userNpp: '12345',
        posId: 'POS 02',
        posName: 'Pos 2 Panakkukang',
        cabangName: 'Mall Panakkukang',
        points: [
          const MaintenancePointResult(pointId: 'p1', label: 'Point 1', status: PointStatus.sesuai),
          const MaintenancePointResult(pointId: 'p2', label: 'Point 2', status: PointStatus.sesuai),
          const MaintenancePointResult(pointId: 'p3', label: 'Point 3', status: PointStatus.sesuai),
          const MaintenancePointResult(pointId: 'p4', label: 'Point 4', status: PointStatus.belumFoto),
        ],
        createdAt: now,
        updatedAt: now,
      );

      final result = DailyTaskService.getOngoingMaintenance(task, submissions: [sub]);
      expect(result, isNotNull);
      expect(result!.id, equals('sub_456'));
      expect(result.doneCount, equals(3));
      expect(result.totalPoints, equals(4));
    });

    test('Ignores submission if it is 100% complete', () {
      final now = DateTime.now();
      final task = DailyTaskModel(
        id: 'task_003',
        tanggal: '2026-10-05',
        teknisiId: 'tek_01',
        teknisiNama: 'Ahmad BSS',
        posName: 'Pos 1 Keluar',
        posTag: 'POS 01',
        judul: 'Maintenance Pos 1',
        templateId: 'tpl_maint_pos',
        kategori: 'maintenance',
      );

      final subCompleted = MaintenanceSubmission(
        id: 'sub_completed',
        templateId: 'tpl_maint_pos',
        templateName: 'Maintenance Pos',
        userId: 'tek_01',
        userName: 'Ahmad BSS',
        userNpp: '12345',
        posId: 'POS 01',
        posName: 'Pos 1 Keluar',
        cabangName: 'Mall Phinisi',
        points: [
          const MaintenancePointResult(pointId: 'p1', label: 'Point 1', status: PointStatus.sesuai),
        ],
        createdAt: now,
        updatedAt: now,
        taskId: 'task_003',
      );

      expect(subCompleted.isComplete, isTrue);

      final result = DailyTaskService.getOngoingMaintenance(task, submissions: [subCompleted]);
      expect(result, isNull);
    });

    testWidgets('MaintenanceChecklistScreen retains 3-4 verified photos when resumed via existingSubmission', (tester) async {
      final now = DateTime.now();
      final draftSubmission = MaintenanceSubmission(
        id: 'sub_ongoing_preserve',
        templateId: 'tpl_maint_barrier',
        templateName: 'Maintenance Barrier Gate',
        userId: 'tek_01',
        userName: 'Teknisi BSS',
        userNpp: '12345',
        posId: 'GATE 01',
        posName: 'Barrier Gate 1',
        cabangName: 'Mall Phinisi',
        points: [
          const MaintenancePointResult(
            pointId: 'bar_1_01',
            label: 'Barrier Gate 1 - Dudukan Mesin & Baut Dinabolt',
            status: PointStatus.sesuai,
            imagePath: '/mock/photo1.jpg',
          ),
          const MaintenancePointResult(
            pointId: 'bar_1_02',
            label: 'Barrier Gate 1 - Fisik Palang Tertutup (0° Lurus)',
            status: PointStatus.sesuai,
            imagePath: '/mock/photo2.jpg',
          ),
          const MaintenancePointResult(
            pointId: 'bar_1_03',
            label: 'Barrier Gate 1 - Fisik Palang Terbuka (90° Lancar)',
            status: PointStatus.sesuai,
            imagePath: '/mock/photo3.jpg',
          ),
          const MaintenancePointResult(
            pointId: 'bar_1_04',
            label: 'Barrier Gate 1 - Pelumasan Mekanikal (Spring/Bearing)',
            status: PointStatus.belumFoto,
          ),
        ],
        createdAt: now,
        updatedAt: now,
        taskId: 'task_gate_1',
      );

      final tpl = TemplateRepository.instance.templates.firstWhere(
        (t) => t.jenis == TemplateCategory.maintBarrier,
        orElse: () => TemplateRepository.defaultTemplates.first,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MaintenanceChecklistScreen(
            template: tpl,
            existingSubmission: draftSubmission,
            dailyTaskId: 'task_gate_1',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Memastikan progress tertera 3 foto selesai dan tidak kereset ke 0
      expect(find.textContaining('3/4'), findsWidgets);
      // Memastikan label poin yang sudah selesai berstatus sesuai
      expect(find.textContaining('Dudukan Mesin & Baut Dinabolt'), findsOneWidget);
    });
  });
}
