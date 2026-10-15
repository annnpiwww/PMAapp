import 'package:flutter_test/flutter_test.dart';
import 'package:bssparking_timemark/data/models/daily_task_model.dart';
import 'package:bssparking_timemark/data/services/branch_service.dart';
import 'package:bssparking_timemark/data/services/daily_task_service.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    BranchService.instance.resetForTesting();
  });

  group('SPV Morning Dispatch Formatter Tests', () {
    test('formatMorningDispatchReport outputs exact WhatsApp/Telegram template', () {
      final task1 = DailyTaskModel(
        id: '1',
        tanggal: '2026-10-12',
        teknisiId: 'tek_raldy',
        teknisiNama: 'Raldy Sangkop',
        posName: 'Gate In Ojek',
        posTag: 'KC',
        judul: 'Ganti pcless Gatein ojek dengan pcless stok kc',
      );

      final task2 = DailyTaskModel(
        id: '2',
        tanggal: '2026-10-12',
        teknisiId: 'tek_ryan',
        teknisiNama: 'Ryan Lumasuge',
        posName: 'PPM',
        posTag: 'PPM',
        judul: 'Maintenance mingguan : Pembersihan pos parkir -- PPM',
      );

      final task3 = DailyTaskModel(
        id: '3',
        tanggal: '2026-10-12',
        teknisiId: 'tek_junifer',
        teknisiNama: 'Junifer Manua',
        posName: 'MPP',
        posTag: 'MPP',
        judul: 'Maintenace mingguan : Pembersihan pos parkir -- MPP',
      );

      final task4 = DailyTaskModel(
        id: '4',
        tanggal: '2026-10-12',
        teknisiId: 'tek_junifer',
        teknisiNama: 'Junifer Manua',
        posName: 'MPP',
        posTag: 'MPP',
        judul: 'Backup server, hapus foto, upload cloud & HDD MPP',
      );

      final techShiftMap = {
        'Raldy Sangkop': 'Shift 1 (03:00 - 11:00)',
        'Ryan Lumasuge': 'Shift 2 (10:00 - 14:00)',
        'Junifer Manua': 'Shift 3 (14:00 - 22:00)',
      };

      final result = DailyTaskService.formatMorningDispatchReport(
        tasks: [task1, task2, task3, task4],
        techShiftMap: techShiftMap,
        branch: AppBranch.manado,
      );

      expect(result.contains('Selamat pagi'), isTrue);
      expect(result.contains('List pekerjaan hari ini'), isTrue);
      expect(result.contains('Shift 1 (03:00 - 11:00) : Raldy Sangkop'), isTrue);
      expect(result.contains('1. Ganti pcless Gatein ojek dengan pcless stok kc'), isTrue);
      expect(result.contains('Shift 2 (10:00 - 14:00) : Ryan Lumasuge'), isTrue);
      expect(result.contains('1. Maintenance mingguan : Pembersihan pos parkir -- PPM'), isTrue);
      expect(result.contains('Shift 3 (14:00 - 22:00) : Junifer Manua'), isTrue);
      expect(result.contains('1. Maintenace mingguan : Pembersihan pos parkir -- MPP'), isTrue);
      expect(result.contains('2. Backup server, hapus foto, upload cloud & HDD MPP'), isTrue);
      expect(result.endsWith('Tetap semangat team🔥'), isTrue);
    });

    test('formatMorningDispatchReport orders shifts properly (Shift 1 before Shift 2 before Shift 3)', () {
      final taskShift3 = DailyTaskModel(
        id: '3',
        tanggal: '2026-10-12',
        teknisiId: 'tek_junifer',
        teknisiNama: 'Junifer Manua',
        posName: 'MPP',
        posTag: 'MPP',
        judul: 'Tugas Shift 3',
      );

      final taskShift1 = DailyTaskModel(
        id: '1',
        tanggal: '2026-10-12',
        teknisiId: 'tek_raldy',
        teknisiNama: 'Raldy Sangkop',
        posName: 'KC',
        posTag: 'KC',
        judul: 'Tugas Shift 1',
      );

      final techShiftMap = {
        'Junifer Manua': 'Shift 3 (14:00 - 22:00)',
        'Raldy Sangkop': 'Shift 1 (03:00 - 11:00)',
      };

      // Input taskShift3 first in list
      final result = DailyTaskService.formatMorningDispatchReport(
        tasks: [taskShift3, taskShift1],
        techShiftMap: techShiftMap,
        branch: AppBranch.manado,
      );

      final shift1Index = result.indexOf('Shift 1 (03:00 - 11:00)');
      final shift3Index = result.indexOf('Shift 3 (14:00 - 22:00)');

      expect(shift1Index, isNot(-1));
      expect(shift3Index, isNot(-1));
      expect(shift1Index, lessThan(shift3Index));
    });

    test('StorageService saves and retrieves SPV tech shift preferences', () async {
      expect(StorageService.getSpvTechShifts().isEmpty, isTrue);

      await StorageService.saveSpvTechShift('Raldy Sangkop', 'Shift 1 (03:00 - 11:00)');
      await StorageService.saveSpvTechShift('Junifer Manua', 'Shift 3 (14:00 - 22:00)');

      final shifts = StorageService.getSpvTechShifts();
      expect(shifts['Raldy Sangkop'], equals('Shift 1 (03:00 - 11:00)'));
      expect(shifts['Junifer Manua'], equals('Shift 3 (14:00 - 22:00)'));
    });
  });
}
