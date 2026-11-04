import 'package:flutter_test/flutter_test.dart';
import 'package:bssparking_timemark/data/services/absensi_setup_service.dart';

void main() {
  final now = DateTime(2026, 11, 4, 15, 55);

  group('shouldResetShift', () {
    test('sesi aktif 2 jam tidak me-reset shift', () {
      expect(
        AbsensiSetupService.shouldResetShift(
          lastCheckIn: now.subtract(const Duration(hours: 2)),
          now: now,
        ),
        isFalse,
      );
    });

    test('sesi 17 jam lalu tanpa pilihan manual me-reset shift', () {
      expect(
        AbsensiSetupService.shouldResetShift(
          lastCheckIn: now.subtract(const Duration(hours: 17)),
          now: now,
        ),
        isTrue,
      );
    });

    test('tanpa sesi tapi shift dipilih manual 1 jam lalu tidak di-reset', () {
      expect(
        AbsensiSetupService.shouldResetShift(
          shiftSetAt: now.subtract(const Duration(hours: 1)),
          now: now,
        ),
        isFalse,
      );
    });

    test('tanpa sesi dan tanpa pilihan manual tetap di-reset', () {
      expect(AbsensiSetupService.shouldResetShift(now: now), isTrue);
    });

    test('shift dipilih manual 5 jam lalu tanpa sesi di-reset', () {
      expect(
        AbsensiSetupService.shouldResetShift(
          shiftSetAt: now.subtract(const Duration(hours: 5)),
          now: now,
        ),
        isTrue,
      );
    });
  });

  group('isLikelyWrongShift', () {
    test('Shift 1 (03:00) jam 15:55 dianggap shift basi', () {
      expect(
        AbsensiSetupService.isLikelyWrongShift('Shift 1 (03:00 - 11:00)', now),
        isTrue,
      );
    });

    test('Shift 1 (03:00) jam 03:30 masih wajar', () {
      expect(
        AbsensiSetupService.isLikelyWrongShift(
          'Shift 1 (03:00 - 11:00)',
          DateTime(2026, 11, 4, 3, 30),
        ),
        isFalse,
      );
    });

    test('Shift 1 (03:00) jam 21:30 berarti datang lebih awal', () {
      expect(
        AbsensiSetupService.isLikelyWrongShift(
          'Shift 1 (03:00 - 11:00)',
          DateTime(2026, 11, 4, 21, 30),
        ),
        isFalse,
      );
    });

    test('Shift 2 (10:00) jam 12:01 telat lebih dari 2 jam', () {
      expect(
        AbsensiSetupService.isLikelyWrongShift(
          'Shift 2 (10:00 - 18:00)',
          DateTime(2026, 11, 4, 12, 1),
        ),
        isTrue,
      );
    });

    test('Shift 2 (10:00) jam 12:00 masih di batas 120 menit', () {
      expect(
        AbsensiSetupService.isLikelyWrongShift(
          'Shift 2 (10:00 - 18:00)',
          DateTime(2026, 11, 4, 12, 0),
        ),
        isFalse,
      );
    });

    test('label shift tanpa jam tidak pernah dianggap salah', () {
      expect(
        AbsensiSetupService.isLikelyWrongShift('Shift Teknisi', now),
        isFalse,
      );
    });

    test('Shift 3 (24.00) jam 00:30 masih wajar', () {
      expect(
        AbsensiSetupService.isLikelyWrongShift(
          'Shift 3 (24.00 - 08.00)',
          DateTime(2026, 11, 4, 0, 30),
        ),
        isFalse,
      );
    });

    test('format titik Bali Shift 1 (06.00) jam 08:30 telat', () {
      expect(
        AbsensiSetupService.isLikelyWrongShift(
          'Shift 1 (06.00 - 14.00)',
          DateTime(2026, 11, 4, 8, 30),
        ),
        isTrue,
      );
    });
  });
}
