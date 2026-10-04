import 'package:flutter_test/flutter_test.dart';
import 'package:bssparking_timemark/data/models/daily_task_model.dart';
import 'package:bssparking_timemark/data/services/daily_task_service.dart';
import 'package:bssparking_timemark/data/services/whatsapp_report_service.dart';

void main() {
  group('DailyTaskService Formatter Tests', () {
    test('formatPerTaskReport outputs Dokumentasi + Notes format', () {
      final res = DailyTaskService.formatPerTaskReport(
        judul: 'Backup server, hapus foto, upload cloud & HDD',
        notes: 'Selamat siang izin update backup server.',
      );
      expect(res, contains('Dokumentasi: Backup server, hapus foto, upload cloud & HDD'));
      expect(res, contains('Notes: Selamat siang izin update backup server.'));
      expect(res.contains('Laporan Daily Hari ini'), isFalse);
    });

    test('formatFinalDailyReport outputs macro report correctly when all completed', () {
      final task1 = DailyTaskModel(
        id: '1',
        tanggal: '2026-10-04',
        teknisiId: 'tek_01',
        teknisiNama: 'Raldy',
        posName: 'Parkir Mall Manado',
        posTag: 'PBM',
        judul: 'Backup server, hapus foto, upload cloud & HDD',
        catatanTeknisi: 'Selamat siang izin update backup server.',
        jamSelesai: '11:30 WITA',
        status: TaskStatus.completed,
      );
      final task2 = DailyTaskModel(
        id: '2',
        tanggal: '2026-10-04',
        teknisiId: 'tek_01',
        teknisiNama: 'Raldy',
        posName: 'Parkir Mall Manado',
        posTag: 'PBM',
        judul: 'Pengecatan markah panah',
        catatanTeknisi: 'Markah panah gate masuk selesai dicat ulang.',
        jamSelesai: '14:15 WITA',
        status: TaskStatus.completed,
      );

      final res = DailyTaskService.formatFinalDailyReport(
        teknisiNama: 'Raldy',
        tanggal: '2026-10-04',
        lokasi: 'Parkir Mall Manado',
        posTag: 'PBM',
        completedTasks: [task1, task2],
        pendingTasks: [],
        notes: '-',
      );

      expect(res, contains('Laporan Daily Hari ini'));
      expect(res, contains('Teknisi : Raldy'));
      expect(res, contains('Lokasi : PBM'));
      expect(res, contains('Daftar list pekerjaan :'));
      expect(res, contains('1. Backup server, hapus foto, upload cloud & HDD (Selesai 11:30 WITA)'));
      expect(res, contains('   Selamat siang izin update backup server.'));
      expect(res, contains('2. Pengecatan markah panah (Selesai 14:15 WITA)'));
      expect(res, contains('   Markah panah gate masuk selesai dicat ulang.'));
      expect(res, contains('Status : 2 Selesai, 0 Pending'));
      expect(res, contains('Notes:\n-'));
      expect(res.contains('Pekerjaan Belum Selesai :'), isFalse);
    });

    test('formatFinalDailyReport includes pending section when tasks remain incomplete', () {
      final task1 = DailyTaskModel(
        id: '1',
        tanggal: '2026-10-04',
        teknisiId: 'tek_01',
        teknisiNama: 'Raldy',
        posName: 'Parkir Mall Manado',
        posTag: 'PBM',
        judul: 'Backup server',
        catatanTeknisi: 'Done',
        jamSelesai: '11:00 WITA',
        status: TaskStatus.completed,
      );
      final pendingTask = DailyTaskModel(
        id: '2',
        tanggal: '2026-10-04',
        teknisiId: 'tek_01',
        teknisiNama: 'Raldy',
        posName: 'Parkir Mall Manado',
        posTag: 'PBM',
        judul: 'Pengecekan sensor loop gate keluar',
        status: TaskStatus.pending,
      );

      final res = DailyTaskService.formatFinalDailyReport(
        teknisiNama: 'Raldy',
        tanggal: '2026-10-04',
        lokasi: 'Parkir Mall Manado',
        posTag: 'PBM',
        completedTasks: [task1],
        pendingTasks: [pendingTask],
      );

      expect(res, contains('Pekerjaan Belum Selesai :'));
      expect(res, contains('- Pengecekan sensor loop gate keluar (Pending)'));
      expect(res, contains('Status : 1 Selesai, 1 Pending'));
    });

    test('WhatsAppReportService formatAutoNumberedList keeps sub-notes aligned without extra numbering', () {
      const input = '''1. Pengecekan Barrier Gate & Loop Sensor
Palang gate berfungsi normal dan baut kencang
2. Pembersihan Thermal Printer & Scanner
Printer bersih dan hasil cetak tiket jelas''';

      final formatted = WhatsAppReportService.formatAutoNumberedList(input);
      expect(formatted, contains('1. Pengecekan Barrier Gate & Loop Sensor'));
      expect(formatted, contains('Palang gate berfungsi normal dan baut kencang'));
      expect(formatted, contains('2. Pembersihan Thermal Printer & Scanner'));
      expect(formatted, contains('Printer bersih dan hasil cetak tiket jelas'));
      // Pastikan catatan tidak diubah menjadi nomor '2. Palang...' atau '4. Printer...'
      expect(formatted.contains('2. Palang gate'), isFalse);
      expect(formatted.contains('4. Printer bersih'), isFalse);
    });
  });
}
