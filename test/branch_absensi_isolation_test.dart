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

  group('AbsensiSetupService Branch Isolation & Reactivity Tests', () {
    test('Default branch is Manado: shift is Manado shift and location is PBM', () {
      final setup = AbsensiSetupService.instance;
      expect(BranchService.instance.currentBranch, equals(AppBranch.manado));
      expect(setup.effectiveLokasiStandby, equals('PBM'));
      expect(BranchService.instance.getShifts(branch: AppBranch.manado), contains(setup.effectiveJadwalShift));
    });

    test('Switching branch to Bali automatically updates shifts and standby location', () async {
      final setup = AbsensiSetupService.instance;
      expect(setup.effectiveLokasiStandby, equals('PBM'));

      // Switch to Bali
      await BranchService.instance.setBranch(AppBranch.bali);

      expect(BranchService.instance.currentBranch, equals(AppBranch.bali));
      expect(setup.effectiveLokasiStandby, equals('PBKD'));
      expect(BranchService.instance.getShifts(branch: AppBranch.bali), contains(setup.effectiveJadwalShift));

      // Bali shifts must not contain Manado Shift 1 (03:00 - 11:00)
      expect(setup.effectiveJadwalShift.contains('03:00'), isFalse);
    });

    test('Manual shift selection is scoped per branch and does not bleed', () async {
      final setup = AbsensiSetupService.instance;

      // 1. In Manado, pick Shift 3 (14:00 - 22:00) and location TBM
      await BranchService.instance.setBranch(AppBranch.manado);
      setup.updateShift('Shift 3 (14:00 - 22:00)');
      setup.updateLokasi('TBM');
      expect(setup.effectiveJadwalShift, equals('Shift 3 (14:00 - 22:00)'));
      expect(setup.effectiveLokasiStandby, equals('TBM'));

      // 2. Switch to Bali, pick Shift 4 (08.30 - 16.30) and location PCD
      await BranchService.instance.setBranch(AppBranch.bali);
      setup.updateShift('Shift 4 (08.30 - 16.30)');
      setup.updateLokasi('PCD');
      expect(setup.effectiveJadwalShift, equals('Shift 4 (08.30 - 16.30)'));
      expect(setup.effectiveLokasiStandby, equals('PCD'));

      // 3. Switch back to Manado -> Shift must return to Manado Shift 3 and location TBM
      await BranchService.instance.setBranch(AppBranch.manado);
      expect(setup.effectiveJadwalShift, equals('Shift 3 (14:00 - 22:00)'));
      expect(setup.effectiveLokasiStandby, equals('TBM'));

      // 4. Switch back to Bali -> Shift must return to Bali Shift 4 and location PCD
      await BranchService.instance.setBranch(AppBranch.bali);
      expect(setup.effectiveJadwalShift, equals('Shift 4 (08.30 - 16.30)'));
      expect(setup.effectiveLokasiStandby, equals('PCD'));
    });
  });
}
