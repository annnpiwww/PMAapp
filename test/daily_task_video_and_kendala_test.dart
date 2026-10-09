import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bssparking_timemark/data/models/daily_task_model.dart';
import 'package:bssparking_timemark/data/models/maintenance_submission.dart';
import 'package:bssparking_timemark/data/models/template_model.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';
import 'package:bssparking_timemark/data/services/whatsapp_report_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  group('Daily Task Video & Kendala Fisik Tests', () {
    test('MaintenancePointResult supports kendalaFisik and serializes to JSON properly', () {
      final point = MaintenancePointResult(
        pointId: 'manless_1',
        label: 'Kebersihan stiker panduan',
        status: PointStatus.tidakSesuai,
        alasan: 'Stiker kusam dan sobek',
        kendalaFisik: 'Butuh Pengadaan Stiker Baru dari Kantor',
      );

      expect(point.kendalaFisik, equals('Butuh Pengadaan Stiker Baru dari Kantor'));

      final json = point.toJson();
      expect(json['kendala_fisik'], equals('Butuh Pengadaan Stiker Baru dari Kantor'));

      final deserialized = MaintenancePointResult.fromJson(json);
      expect(deserialized.kendalaFisik, equals('Butuh Pengadaan Stiker Baru dari Kantor'));
    });

    test('WhatsApp report prints kendala fisik clearly when present', () {
      final sub = MaintenanceSubmission(
        id: 'sub_test_kendala_1',
        templateId: 'tpl_manless',
        templateName: 'Checklist Manless',
        userId: 'u_1',
        userName: 'Alessandro Sulistyo',
        userNpp: 'BSS-001',
        posId: 'pos_mpp',
        posName: 'Gate In 1 MPP',
        cabangName: 'Cabang Manado',
        createdAt: DateTime(2026, 10, 6, 14, 30),
        updatedAt: DateTime(2026, 10, 6, 14, 30),
        points: [
          MaintenancePointResult(
            pointId: 'p1',
            label: 'Pembersihan printer tiket',
            status: PointStatus.sesuai,
            alasan: 'Printer bersih',
          ),
          MaintenancePointResult(
            pointId: 'p2',
            label: 'Kebersihan luar manless & stiker panduan',
            status: PointStatus.tidakSesuai,
            alasan: 'Stiker panduan kusam dan mengelupas',
            kendalaFisik: 'Butuh Pengadaan Stiker Baru',
          ),
          MaintenancePointResult(
            pointId: 'p3',
            label: 'Kondisi fisik lantai dan beton pulau gate',
            status: PointStatus.tidakSesuai,
            alasan: 'Lantai pulau gate retak dan cat pudar',
            kendalaFisik: 'Kerusakan Fisik / Cor Pulau Retak Butuh Sipil',
          ),
        ],
      );

      final report = WhatsAppReportService.generateReportText(
        submission: sub,
        category: TemplateCategory.maintManless,
      );

      expect(report, contains('HASIL MAINTENANCE'));
      expect(report, contains('👉 KENDALA: Butuh Pengadaan Stiker Baru'));
      expect(report, contains('👉 KENDALA: Kerusakan Fisik / Cor Pulau Retak Butuh Sipil'));
      // Pastikan deskripsi AI tidak menggunakan kata semrawut
      expect(report, isNot(contains('kabel tampak semrawut')));
      expect(report, isNot(contains('tampak semrawut')));
    });

    test('DailyTaskModel properly handles task completion and multiple media formats', () {
      final task = DailyTaskModel(
        id: 'task_001',
        tanggal: '2026-10-06',
        teknisiId: 'tek_1',
        teknisiNama: 'Alessandro Sulistyo',
        posName: 'Toko Bintang Manado (TBM)',
        posTag: 'TBM',
        judul: 'Pengecekan Barrier Gate Macet',
        kategori: 'khusus',
        status: TaskStatus.completed,
        jamSelesai: '14:45 WITA',
        catatanTeknisi: 'Sudah diganti spring dan direkam video bukti pergerakan palang',
        fotoBuktiUrls: [
          'https://pb.domain/files/task_001/bukti_1.jpg',
          'https://pb.domain/files/task_001/video_bukti_1.mp4',
        ],
      );

      expect(task.isCompleted, isTrue);
      expect(task.fotoBuktiUrls.length, equals(2));
      expect(task.fotoBuktiUrls.any((u) => u.endsWith('.mp4')), isTrue);

      final json = task.toJson();
      expect(json['status'], equals('completed'));
      expect(json['jam_selesai'], equals('14:45 WITA'));
      expect(json['foto_bukti'], contains('https://pb.domain/files/task_001/video_bukti_1.mp4'));

      final fromJson = DailyTaskModel.fromJson(json);
      expect(fromJson.status, equals(TaskStatus.completed));
      expect(fromJson.fotoBuktiUrls.length, equals(2));
    });
  });
}
