import 'package:flutter_test/flutter_test.dart';
import 'package:bssparking_timemark/data/models/template_model.dart';
import 'package:bssparking_timemark/data/models/maintenance_submission.dart';
import 'package:bssparking_timemark/data/repositories/template_repository.dart';
import 'package:bssparking_timemark/data/services/whatsapp_report_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Maintenance Unit Range & SOP Analogies', () {
    test('pos_06 template specifies single logo BSS Parking sticker on front', () {
      final templates = TemplateRepository.defaultTemplates;
      final posTemplate = templates.firstWhere((t) => t.id == 'tpl_maint_pos');

      final pos06 = posTemplate.sopPoints.firstWhere((p) => p.id == 'pos_06');
      expect(pos06.label, contains('Stiker Logo BSS Parking'));
      expect(pos06.deskripsi, contains('hanya tampil logo BSS Parking'));
      expect(pos06.checkpoints.any((c) => c.contains('Bukan stiker kuning Parkways')), isTrue);
    });

    test('Selected pos range 1 to 3 generates exactly points for Pos 1, 2, and 3', () {
      final templates = TemplateRepository.defaultTemplates;
      final posTemplate = templates.firstWhere((t) => t.id == 'tpl_maint_pos');
      final units = [1, 2, 3];

      final points = <SopPoint>[];
      for (final u in units) {
        for (final sp in posTemplate.sopPoints) {
          points.add(SopPoint(
            id: '${sp.id.split('_').first}_${u}_${sp.id.split('_').last}',
            label: 'Pos $u - ${sp.label}',
            deskripsi: sp.deskripsi,
          ));
        }
      }

      // 3 Pos x 9 SOP points = 27 points
      expect(points.length, equals(27));
      expect(points.where((p) => p.id.startsWith('pos_1_')).length, equals(9));
      expect(points.where((p) => p.id.startsWith('pos_2_')).length, equals(9));
      expect(points.where((p) => p.id.startsWith('pos_3_')).length, equals(9));
      expect(points.where((p) => p.id.startsWith('pos_4_')).isEmpty, isTrue);
    });

    test('Selected pos range 3 to 6 generates exactly points for Pos 3, 4, 5, and 6', () {
      final templates = TemplateRepository.defaultTemplates;
      final posTemplate = templates.firstWhere((t) => t.id == 'tpl_maint_pos');
      final units = [3, 4, 5, 6];

      final points = <SopPoint>[];
      for (final u in units) {
        for (final sp in posTemplate.sopPoints) {
          points.add(SopPoint(
            id: '${sp.id.split('_').first}_${u}_${sp.id.split('_').last}',
            label: 'Pos $u - ${sp.label}',
            deskripsi: sp.deskripsi,
          ));
        }
      }

      // 4 Pos x 9 SOP points = 36 points
      expect(points.length, equals(36));
      expect(points.where((p) => p.id.startsWith('pos_1_')).isEmpty, isTrue);
      expect(points.where((p) => p.id.startsWith('pos_2_')).isEmpty, isTrue);
      expect(points.where((p) => p.id.startsWith('pos_3_')).length, equals(9));
      expect(points.where((p) => p.id.startsWith('pos_4_')).length, equals(9));
      expect(points.where((p) => p.id.startsWith('pos_5_')).length, equals(9));
      expect(points.where((p) => p.id.startsWith('pos_6_')).length, equals(9));
    });

    test('WhatsApp report formats Gate Out range correctly from submission points', () {
      final submission = MaintenanceSubmission(
        id: 'maint_test_range',
        templateId: 'tpl_maint_pos',
        templateName: 'Maintenance: Pos Parkir',
        userId: 'tech_01',
        userName: 'Ahmad BSS',
        userNpp: 'BSS-001',
        posId: 'pos_pbm',
        posName: 'PBM - Pakuwon Mall Jogja',
        cabangName: 'Jogja',
        points: [
          const MaintenancePointResult(
            pointId: 'pos_3_01',
            label: 'Pos 3 - Pembersihan Total Printer Pos',
            status: PointStatus.sesuai,
          ),
          const MaintenancePointResult(
            pointId: 'pos_6_09',
            label: 'Pos 6 - Kondisi Pulau Parkir',
            status: PointStatus.sesuai,
          ),
        ],
        createdAt: DateTime(2026, 9, 13, 10, 0),
        updatedAt: DateTime(2026, 9, 13, 10, 30),
      );

      final report = WhatsAppReportService.generateReportText(
        submission: submission,
        category: TemplateCategory.maintPos,
        unitCount: 4,
      );

      expect(report, contains('Gate Out : 4 (Pos 3 - Pos 6)'));
    });
  });
}
