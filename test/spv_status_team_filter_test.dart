import 'package:flutter_test/flutter_test.dart';
import 'package:bssparking_timemark/data/models/daily_task_model.dart';
import 'package:bssparking_timemark/data/services/daily_task_service.dart';

void main() {
  group('SPV Status Team & Daily Recap Tests', () {
    final mockTasks = [
      DailyTaskModel(
        id: 'task_001',
        tanggal: '2026-10-05',
        teknisiId: 'tek_01',
        teknisiNama: 'Ryan Lumasuge',
        posName: 'TBM Pos Masuk',
        posTag: 'TBM',
        judul: 'Pemeriksaan PC POS & Barrier Gate',
        kategori: 'maintenance',
        status: TaskStatus.completed,
        jamSelesai: '10:30 WITA',
        catatanTeknisi: 'Kabel loop diganti dan sensor normal.',
      ),
      DailyTaskModel(
        id: 'task_002',
        tanggal: '2026-10-05',
        teknisiId: 'tek_02',
        teknisiNama: 'Raldy Sangkop',
        posName: 'TBM Manless Gate',
        posTag: 'TBM',
        judul: 'Ganti Thermal Paper & Cek Printer',
        kategori: 'khusus',
        status: TaskStatus.completed,
        jamSelesai: '11:15 WITA',
        catatanTeknisi: 'Struk keluar lancar.',
      ),
      DailyTaskModel(
        id: 'task_003',
        tanggal: '2026-10-05',
        teknisiId: 'tek_03',
        teknisiNama: 'Junifer Manua',
        posName: 'MTC Barrier Gate',
        posTag: 'MTC',
        judul: 'Greasing mekanik palang pintu',
        kategori: 'maintenance',
        status: TaskStatus.pending,
      ),
      DailyTaskModel(
        id: 'task_004',
        tanggal: '2026-10-05',
        teknisiId: 'tek_01',
        teknisiNama: 'Ryan Lumasuge',
        posName: 'TBM Pos Keluar',
        posTag: 'TBM',
        judul: 'Pengecekan CCTV Pos Keluar',
        kategori: 'khusus',
        status: TaskStatus.pending,
      ),
    ];

    test('Filter status ALL, PENDING, COMPLETED works accurately', () {
      // ALL
      final all = mockTasks.where((t) => true).toList();
      expect(all.length, equals(4));

      // PENDING
      final pending = mockTasks.where((t) => !t.isCompleted).toList();
      expect(pending.length, equals(2));
      expect(pending.every((t) => t.status == TaskStatus.pending), isTrue);

      // COMPLETED
      final completed = mockTasks.where((t) => t.isCompleted).toList();
      expect(completed.length, equals(2));
      expect(completed.every((t) => t.status == TaskStatus.completed), isTrue);
    });

    test('Filter technician works accurately', () {
      // Filter Ryan Lumasuge
      final ryanTasks = mockTasks.where((t) => t.teknisiNama == 'Ryan Lumasuge').toList();
      expect(ryanTasks.length, equals(2));
      expect(ryanTasks.every((t) => t.teknisiNama == 'Ryan Lumasuge'), isTrue);

      // Filter Raldy Sangkop
      final raldyTasks = mockTasks.where((t) => t.teknisiNama == 'Raldy Sangkop').toList();
      expect(raldyTasks.length, equals(1));
      expect(raldyTasks.first.judul, contains('Thermal Paper'));

      // Filter Junifer Manua
      final juniferTasks = mockTasks.where((t) => t.teknisiNama == 'Junifer Manua').toList();
      expect(juniferTasks.length, equals(1));
      expect(juniferTasks.first.status, equals(TaskStatus.pending));

      // Filter technician without tasks
      final alessandroTasks = mockTasks.where((t) => t.teknisiNama == 'Alessandro').toList();
      expect(alessandroTasks.isEmpty, isTrue);
    });

    test('Combined filter (Technician + Status) works accurately', () {
      // Ryan + Completed
      final ryanCompleted = mockTasks
          .where((t) => t.teknisiNama == 'Ryan Lumasuge' && t.isCompleted)
          .toList();
      expect(ryanCompleted.length, equals(1));
      expect(ryanCompleted.first.judul, contains('Pemeriksaan PC POS'));

      // Ryan + Pending
      final ryanPending = mockTasks
          .where((t) => t.teknisiNama == 'Ryan Lumasuge' && !t.isCompleted)
          .toList();
      expect(ryanPending.length, equals(1));
      expect(ryanPending.first.judul, contains('CCTV'));
    });

    test('DailyTaskModel isMaintenance getter checks kategori correctly', () {
      expect(mockTasks[0].isMaintenance, isTrue);
      expect(mockTasks[1].isMaintenance, isFalse);
      expect(mockTasks[2].isMaintenance, isTrue);
      expect(mockTasks[3].isMaintenance, isFalse);
    });

    test('formatSpvTeamRecap formats WhatsApp & Telegram report correctly', () {
      final recap = DailyTaskService.formatSpvTeamRecap(
        tanggal: '2026-10-05',
        tasks: mockTasks,
        spvName: 'Pak Budi SPV',
      );

      // Verify headers
      expect(recap, contains('REKAP DAILY TEAM PMA KC BSG'));
      expect(recap, contains('SPV : PAK BUDI SPV'));
      expect(recap, contains('Tanggal :'));
      expect(recap, contains('Proggress : 2/4 (50%)'));
      expect(recap, contains('Status Daily Teknisi :'));
      expect(recap, contains('Ryan Lumasuge : 1/2 selesai'));
      expect(recap, contains('Raldy Sangkop : 1/1 selesai'));
      expect(recap, contains('Junifer Manua : 0/1 selesai'));

      // Verify completed section
      expect(recap, contains('Selesai (2):'));
      expect(recap, contains('1. Ryan Lumasuge - Pemeriksaan PC POS & Barrier Gate (TBM Pos Masuk) [10:30 WITA]'));
      expect(recap.contains('Catatan:'), isFalse);
      expect(recap, contains('2. Raldy Sangkop - Ganti Thermal Paper & Cek Printer (TBM Manless Gate) [11:15 WITA]'));

      // Verify pending section
      expect(recap, contains('Belum Selesai (2):'));
      expect(recap, contains('Junifer Manua - Greasing mekanik palang pintu (MTC Barrier Gate)'));
      expect(recap, contains('Ryan Lumasuge - Pengecekan CCTV Pos Keluar (TBM Pos Keluar)'));

      // Verify footer
      expect(recap, contains('Terimakasih'));
      expect(recap.contains('PMA app made by'), isFalse);
    });

    test('formatSpvTeamRecap handles empty tasks gracefully', () {
      final recap = DailyTaskService.formatSpvTeamRecap(
        tanggal: '2026-10-05',
        tasks: [],
        spvName: 'Supervisor',
      );

      expect(recap, contains('Proggress : 0/0 (0%)'));
      expect(recap.contains('Selesai'), isFalse);
      expect(recap.contains('Belum Selesai'), isFalse);
    });

    test('formatSpvTeamRecap handles 100% completed tasks with zero pending', () {
      final onlyCompleted = [mockTasks[0], mockTasks[1]];
      final recap = DailyTaskService.formatSpvTeamRecap(
        tanggal: '2026-10-05',
        tasks: onlyCompleted,
        spvName: 'Supervisor',
      );

      expect(recap, contains('Proggress : 2/2 (100%)'));
      expect(recap, contains('Selesai (2):'));
      expect(recap.contains('Belum Selesai'), isFalse);
    });
  });
}
