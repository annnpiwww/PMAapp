import 'package:flutter_test/flutter_test.dart';
import 'package:bssparking_timemark/data/models/daily_task_model.dart';

void main() {
  group('DailyTaskModel Unit Tests', () {
    test('Serialization and Deserialization works properly', () {
      final task = DailyTaskModel(
        id: 'task_001',
        tanggal: '2026-10-04',
        teknisiId: 'tek_ryan',
        teknisiNama: 'Ryan Lumasuge',
        posName: 'Pos Gate Utama',
        posTag: 'GATE 1',
        judul: 'Maintenance Manless Gate In',
        deskripsi: 'Cek printer dan loop detector',
        kategori: 'maintenance',
        templateId: 'tpl_maint_manless',
        status: TaskStatus.pending,
      );

      final jsonMap = task.toJson();
      expect(jsonMap['id'], equals('task_001'));
      expect(jsonMap['teknisi_nama'], equals('Ryan Lumasuge'));
      expect(jsonMap['status'], equals('pending'));

      final fromJson = DailyTaskModel.fromJson(jsonMap);
      expect(fromJson.id, equals('task_001'));
      expect(fromJson.judul, equals('Maintenance Manless Gate In'));
      expect(fromJson.isCompleted, isFalse);

      final completed = fromJson.copyWith(
        status: TaskStatus.completed,
        jamSelesai: '10:30 WITA',
        catatanTeknisi: 'Normal siap pakai',
      );
      expect(completed.isCompleted, isTrue);
      expect(completed.jamSelesai, equals('10:30 WITA'));
    });
  });
}
