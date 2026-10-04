import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Technician PIN & Storage Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await StorageService.init();
    });

    test('Default technician PIN is default (no plaintext stored)', () {
      expect(StorageService.isTechnicianPinDefault(), isTrue);
    });

    test('Save and verify custom technician PIN (hashed)', () async {
      await StorageService.saveTechnicianPin('998877');
      expect(StorageService.isTechnicianPinDefault(), isFalse);
      final ok = await StorageService.verifyTechnicianPin('998877');
      expect(ok.ok, isTrue);
      final wrong = await StorageService.verifyTechnicianPin('000000');
      expect(wrong.ok, isFalse);
    });

    test('Default PIN 123321 cannot be saved', () async {
      expect(
        () => StorageService.saveTechnicianPin('123321'),
        throwsArgumentError,
      );
    });

    test('Brute force locks after 5 wrong attempts', () async {
      await StorageService.saveTechnicianPin('112233');
      for (int i = 0; i < 5; i++) {
        await StorageService.verifyTechnicianPin('000000');
      }
      final locked = await StorageService.verifyTechnicianPin('112233');
      expect(locked.ok, isFalse);
      expect(locked.locked, isTrue);
    });

    test('Save and retrieve last technician name', () async {
      expect(StorageService.getLastTechnicianName(), '');
      await StorageService.saveLastTechnicianName('Ryan Lumasuge');
      expect(StorageService.getLastTechnicianName(), 'Ryan Lumasuge');
    });
  });
}
