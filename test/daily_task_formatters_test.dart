import 'package:flutter_test/flutter_test.dart';
import 'package:bssparking_timemark/data/models/daily_task_model.dart';
import 'package:bssparking_timemark/data/services/daily_task_service.dart';
import 'package:bssparking_timemark/data/services/whatsapp_report_service.dart';

void main() {
  group('DailyTaskService Formatter Tests', () {
    test('formatPerTaskReport outputs pure caption with only notes and without task title', () {
      final res = DailyTaskService.formatPerTaskReport(
        judul: 'Backup server, hapus foto, upload cloud & HDD',
        notes: 'Selamat siang izin update backup server.',
      );
      expect(res, equals('Selamat siang izin update backup server.'));
      expect(res.contains('Backup server'), isFalse);
      expect(res.contains('Dokumentasi:'), isFalse);
      expect(res.contains('Notes:'), isFalse);
      expect(res.contains('Laporan Daily Hari ini'), isFalse);
    });

    test('formatPerTaskReport falls back to judul if notes is empty or dash', () {
      final resEmpty = DailyTaskService.formatPerTaskReport(
        judul: 'Backup server, hapus foto, upload cloud & HDD',
        notes: '',
      );
      expect(resEmpty, equals('Backup server, hapus foto, upload cloud & HDD'));

      final resDash = DailyTaskService.formatPerTaskReport(
        judul: 'Backup server, hapus foto, upload cloud & HDD',
        notes: '-',
      );
      expect(resDash, equals('Backup server, hapus foto, upload cloud & HDD'));
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
      expect(res.contains('Selamat siang izin update backup server.'), isFalse);
      expect(res, contains('2. Pengecatan markah panah (Selesai 14:15 WITA)'));
      expect(res.contains('Markah panah gate masuk selesai dicat ulang.'), isFalse);
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

    test('formatSpvTeamRecap outputs standard PMA format with technician status and proper sections', () {
      final task1 = DailyTaskModel(
        id: '1',
        tanggal: '2026-10-06',
        teknisiId: 'tek_01',
        teknisiNama: 'Ryan Lumasuge',
        posName: 'TBM',
        posTag: 'TBM',
        judul: 'Pengecatan markah panah',
        catatanTeknisi: 'Selesai dua jalur',
        jamSelesai: '09:49 WITA',
        status: TaskStatus.completed,
      );
      final task2 = DailyTaskModel(
        id: '2',
        tanggal: '2026-10-06',
        teknisiId: 'tek_01',
        teknisiNama: 'Ryan Lumasuge',
        posName: 'TBM',
        posTag: 'TBM',
        judul: 'Perbaikan sensor loop',
        status: TaskStatus.pending,
      );
      final task3 = DailyTaskModel(
        id: '3',
        tanggal: '2026-10-06',
        teknisiId: 'tek_02',
        teknisiNama: 'Raldy Sangkop',
        posName: 'MTC',
        posTag: 'MTC',
        judul: 'Maintenance PC Kasir',
        jamSelesai: '11:15 WITA',
        status: TaskStatus.completed,
      );

      final recap = DailyTaskService.formatSpvTeamRecap(
        tanggal: '2026-10-06',
        tasks: [task1, task2, task3],
        spvName: 'Junifer SPV',
      );

      expect(recap, contains('REKAP DAILY TEAM PMA KC BSG'));
      expect(recap, contains('SPV : JUNIFER SPV'));
      expect(recap, contains('Proggress : 2/3 (66%)'));
      expect(recap, contains('Status Daily Teknisi :'));
      expect(recap, contains('Ryan Lumasuge : 1/2 selesai'));
      expect(recap, contains('Raldy Sangkop : 1/1 selesai'));
      expect(recap, contains('Selesai (2):'));
      expect(recap, contains('1. Ryan Lumasuge - Pengecatan markah panah (TBM) [09:49 WITA]'));
      expect(recap.contains('Catatan:'), isFalse);
      expect(recap, contains('2. Raldy Sangkop - Maintenance PC Kasir (MTC) [11:15 WITA]'));
      expect(recap, contains('Belum Selesai (1):'));
      expect(recap, contains('1. Ryan Lumasuge - Perbaikan sensor loop (TBM)'));
      expect(recap, contains('Terimakasih'));
      expect(recap.contains('PMA app made by'), isFalse);
    });
  });
}
