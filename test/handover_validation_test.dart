import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bssparking_timemark/data/services/absensi_setup_service.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  group('Daily Job & Handover Validation (Isi Daily Dulu Ya)', () {
    test('isDailyHandoverComplete returns false when fields are default or empty', () {
      final setup = AbsensiSetupService.instance;
      setup.updateNextShift('-');
      setup.updatePekerjaanSelesai('-');
      expect(setup.isDailyHandoverComplete(), isFalse);
    });

    test('isDailyHandoverComplete returns false when next shift is missing', () {
      final setup = AbsensiSetupService.instance;
      setup.updateNextShift('-');
      setup.updatePekerjaanSelesai('1. Pembersihan printer tiket');
      expect(setup.isDailyHandoverComplete(), isFalse);
    });

    test('isDailyHandoverComplete returns false when completed tasks are missing', () {
      final setup = AbsensiSetupService.instance;
      setup.updateNextShift('Ryan Lumasuge');
      setup.updatePekerjaanSelesai('-');
      expect(setup.isDailyHandoverComplete(), isFalse);
    });

    test('isDailyHandoverComplete returns true when valid next technician and tasks exist', () {
      final setup = AbsensiSetupService.instance;
      setup.updateNextShift('Ryan Lumasuge');
      setup.updatePekerjaanSelesai('1. Pembersihan printer tiket\n2. Kalibrasi barrier');
      expect(setup.isDailyHandoverComplete(), isTrue);
    });

    test('isDailyHandoverComplete accepts shift terakhir / tidak ada pengganti as valid next shift', () {
      final setup = AbsensiSetupService.instance;
      setup.updateNextShift('Shift Terakhir / Tidak Ada Pengganti');
      setup.updatePekerjaanSelesai('1. Backup log');
      expect(setup.isDailyHandoverComplete(), isTrue);
    });

    test('StorageService persists daily completion for today', () async {
      expect(StorageService.isDailyReportCompletedToday(), isFalse);
      await StorageService.markDailyReportCompletedToday();
      expect(StorageService.isDailyReportCompletedToday(), isTrue);
    });

    test('Minimum work duration rules (4h for Shift 2.2, 8h for normal shifts)', () {
      expect(AbsensiSetupService.getMinimumWorkDuration('Shift 2.2 (10:00 - 14:00)'), const Duration(hours: 4));
      expect(AbsensiSetupService.getMinimumWorkDuration('Shift 1 (03:00 - 11:00)'), const Duration(hours: 8));
      expect(AbsensiSetupService.getMinimumWorkDuration('Shift 2 (10:00 - 18:00)'), const Duration(hours: 8));
      expect(AbsensiSetupService.getMinimumWorkDuration('Shift 3 (14:00 - 22:00)'), const Duration(hours: 8));
    });

    test('getRemainingWorkTime returns correct remaining time and zero when met', () {
      final now = DateTime(2026, 9, 13, 18, 0); // 18:00
      final checkIn9MinsAgo = DateTime(2026, 9, 13, 17, 51); // 9 menit lalu

      final remaining = AbsensiSetupService.getRemainingWorkTime(
        shift: 'Shift 3 (14:00 - 22:00)',
        checkInTime: checkIn9MinsAgo,
        currentTime: now,
      );
      expect(remaining, isNotNull);
      expect(remaining!.inHours, 7);
      expect(remaining.inMinutes.remainder(60), 51);

      final checkIn8HoursAgo = DateTime(2026, 9, 13, 10, 0);
      final remainingDone = AbsensiSetupService.getRemainingWorkTime(
        shift: 'Shift 2 (10:00 - 18:00)',
        checkInTime: checkIn8HoursAgo,
        currentTime: now,
      );
      expect(remainingDone, Duration.zero);
    });
  });
}
