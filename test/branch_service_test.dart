import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';
import 'package:bssparking_timemark/data/services/branch_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    BranchService.instance.resetForTesting();
  });

  group('BranchService Tests', () {
    test('Default branch is Manado', () {
      expect(BranchService.instance.currentBranch, equals(AppBranch.manado));
      expect(BranchService.instance.currentBranch.name, equals('KC Manado'));
      expect(BranchService.instance.currentBranch.recapHeader, equals('REKAP DAILY TEAM PMA KC BSG'));
      expect(BranchService.instance.currentBranch.defaultSpv, equals('Farhan Lakoro'));
      expect(BranchService.instance.currentBranch.defaultLocationTag, equals('PBM'));
    });

    test('Switching branch to Bali loads Bali technicians, shifts, and 15 locations', () async {
      await BranchService.instance.setBranch(AppBranch.bali);

      expect(BranchService.instance.currentBranch, equals(AppBranch.bali));
      expect(BranchService.instance.currentBranch.name, equals('KC Bali'));
      expect(BranchService.instance.currentBranch.recapHeader, equals('REKAP DAILY TEAM PMA KC BALI'));
      expect(BranchService.instance.currentBranch.defaultSpv, equals('Indra Yohana'));
      expect(BranchService.instance.currentBranch.defaultLocationTag, equals('PBKD'));

      // Technicians
      final techs = BranchService.instance.getTechnicians();
      expect(techs.length, equals(6));
      expect(techs, contains('Putu Hyan Parta Wijaya'));
      expect(techs, contains('Alif Candra Triantoro'));
      expect(techs, contains('I Putu Indra Yohana'));
      expect(techs, contains('I PUTU GEDE SUARDANA PUTRA'));
      expect(techs, contains('ADITYA CAESAR BAGASKARA'));
      expect(techs, contains('ANAK AGUNG GEDE AGUNG YUSTIKAWANGSA'));

      // Shifts
      final shifts = BranchService.instance.getShifts();
      expect(shifts.length, equals(6));
      expect(shifts, contains('Shift 1 (06.00 - 14.00)'));
      expect(shifts, contains('Shift 2 (14.00 - 22.00)'));
      expect(shifts, contains('Shift 3 (22.00 - 06.00)'));
      expect(shifts, contains('Shift 4 (08.30 - 16.30)'));
      expect(shifts, contains('Shift 2.2 (18.00 - 22.00)'));
      expect(shifts, contains('Shift 4.1 (08.00 - 12.00)'));

      // 15 Locations
      final locations = BranchService.instance.getLocationTags();
      expect(locations.length, equals(15));
      final expectedTags = [
        'PBKD', 'PCD', 'PKRD', 'PAS', 'PSD',
        'PGA', 'TBB', 'TBG', 'KIH', 'BMS',
        'BMK', 'SPD', 'GYS', 'PBB', 'RSPM'
      ];
      for (final tag in expectedTags) {
        expect(locations, contains(tag));
      }
    });

    test('Branch persistence in StorageService works across instances', () async {
      await BranchService.instance.setBranch(AppBranch.bali);
      expect(StorageService.getString('active_branch_code'), equals('DPS'));

      // Simulate re-init
      final reloadedBranch = BranchService.parseBranchFromCode(StorageService.getString('active_branch_code'));
      expect(reloadedBranch, equals(AppBranch.bali));
    });

    test('parseBranchFromName matches both formal and short names', () {
      expect(BranchService.parseBranchFromName('KC Bali'), equals(AppBranch.bali));
      expect(BranchService.parseBranchFromName('bali'), equals(AppBranch.bali));
      expect(BranchService.parseBranchFromName('KC Manado'), equals(AppBranch.manado));
      expect(BranchService.parseBranchFromName('manado'), equals(AppBranch.manado));
      expect(BranchService.parseBranchFromName('KC BSG'), equals(AppBranch.manado));
      expect(BranchService.parseBranchFromName('unknown'), equals(AppBranch.manado));
    });
  });
}
