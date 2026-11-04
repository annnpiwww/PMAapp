import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';
import 'package:bssparking_timemark/data/services/branch_service.dart';
import 'package:bssparking_timemark/data/services/absensi_setup_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    BranchService.instance.resetForTesting();
  });

  group('Custom Shift Capture & Handling Tests', () {
    test('isCustomShift identifies custom shift vs predefined vs empty', () {
      expect(BranchService.instance.currentBranch, equals(AppBranch.manado));
      expect(
        AbsensiSetupService.isCustomShift('Jaga Pagi (14:00 - 18:00)'),
        isTrue,
      );
      expect(
        AbsensiSetupService.isCustomShift('Shift 3 (14:00 - 22:00)'),
        isFalse,
      );
      expect(AbsensiSetupService.isCustomShift(''), isFalse);
      expect(AbsensiSetupService.isCustomShift('   '), isFalse);
      expect(
        AbsensiSetupService.isCustomShift('Shift 1 (06.00 - 14.00)'),
        isFalse,
      );
    });

    test(
      'autoDetectJamPulang returns 18:00 for custom colon and dot formats',
      () {
        expect(
          AbsensiSetupService.autoDetectJamPulang(
            shift: 'Jaga Pagi (14:00 - 18:00)',
          ),
          equals('18:00'),
        );
        expect(
          AbsensiSetupService.autoDetectJamPulang(
            shift: 'Jaga Pagi (14.00 - 18.00)',
          ),
          equals('18:00'),
        );
      },
    );

    test(
      'pulangAllowedFrom with checkIn 13:55 returns 18:00 same day for custom 14:00-18:00',
      () {
        final checkIn = DateTime(2026, 11, 4, 13, 55);
        final gate = AbsensiSetupService.pulangAllowedFrom(
          shift: 'Jaga Pagi (14:00 - 18:00)',
          checkInTime: checkIn,
        );
        expect(gate, equals(DateTime(2026, 11, 4, 18, 0)));
      },
    );

    test(
      'updateShift keeps custom shift value in jadwalShift and effectiveJadwalShift',
      () {
        final setup = AbsensiSetupService.instance;
        const customShift = 'Jaga Pagi (14:00 - 18:00)';
        setup.updateShift(customShift);
        expect(setup.jadwalShift, equals(customShift));
        expect(setup.effectiveJadwalShift, equals(customShift));
      },
    );
  });
}
