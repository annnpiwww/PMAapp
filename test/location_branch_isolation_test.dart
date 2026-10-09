import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';
import 'package:bssparking_timemark/data/services/branch_service.dart';
import 'package:bssparking_timemark/data/services/location_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    BranchService.instance.resetForTesting();
    LocationService.resetForTesting();
  });

  group('Location Branch Isolation Tests', () {
    test('KC Manado availablePosList contains only Manado locations without Bali leaks', () {
      BranchService.instance.resetForTesting();
      expect(BranchService.instance.currentBranch, equals(AppBranch.manado));

      final locations = LocationService.availablePosList;
      expect(locations.isNotEmpty, isTrue);

      final tags = locations.map((e) => e.locationTag.toUpperCase()).toList();
      // Must contain Manado default seed
      expect(tags, contains('PBM'));
      expect(tags, contains('PKM'));
      expect(tags, contains('TBM'));

      // Must NOT contain any Bali locations
      const baliTags = [
        'PBKD', 'PCD', 'PKRD', 'PAS', 'PSD',
        'PGA', 'TBB', 'TBG', 'KIH', 'BMS',
        'BMK', 'SPD', 'GYS', 'PBB', 'RSPM'
      ];
      for (final baliTag in baliTags) {
        expect(tags.contains(baliTag), isFalse, reason: 'Bali tag $baliTag leaked into Manado list');
      }

      // Default currentPos is PBM
      expect(LocationService.currentPos.locationTag, equals('PBM'));
    });

    test('KC Bali availablePosList contains only 15 Bali locations without Manado leaks', () async {
      await BranchService.instance.setBranch(AppBranch.bali);
      expect(BranchService.instance.currentBranch, equals(AppBranch.bali));

      final locations = LocationService.availablePosList;
      expect(locations.length, equals(15));

      final tags = locations.map((e) => e.locationTag.toUpperCase()).toList();
      const expectedBaliTags = [
        'PBKD', 'PCD', 'PKRD', 'PAS', 'PSD',
        'PGA', 'TBB', 'TBG', 'KIH', 'BMS',
        'BMK', 'SPD', 'GYS', 'PBB', 'RSPM'
      ];
      for (final baliTag in expectedBaliTags) {
        expect(tags, contains(baliTag));
      }

      // Must NOT contain any Manado locations
      const manadoTags = ['PBM', 'PKM', 'MPP', 'NBM', 'PPM', 'TBM', 'MGAM'];
      for (final manadoTag in manadoTags) {
        expect(tags.contains(manadoTag), isFalse, reason: 'Manado tag $manadoTag leaked into Bali list');
      }

      // Default currentPos in Bali is PBKD
      expect(LocationService.currentPos.locationTag, equals('PBKD'));
    });

    test('Distance ranking strictly filters locations by active branch', () async {
      // In Manado
      BranchService.instance.resetForTesting();
      final rankedManado = LocationService.getLocationsRankedByDistance(1.493, 124.841);
      final manadoTags = rankedManado.map((e) => (e['location'] as PosLocation).locationTag).toList();
      expect(manadoTags, contains('PBM'));
      expect(manadoTags.contains('PBKD'), isFalse);

      // In Bali
      await BranchService.instance.setBranch(AppBranch.bali);
      final rankedBali = LocationService.getLocationsRankedByDistance(-8.670, 115.212);
      final baliTags = rankedBali.map((e) => (e['location'] as PosLocation).locationTag).toList();
      expect(baliTags, contains('PBKD'));
      expect(baliTags.contains('PBM'), isFalse);
    });

    test('Active location is preserved independently between branches without cross-contamination', () async {
      // 1. In Bali, select PCD
      await BranchService.instance.setBranch(AppBranch.bali);
      final pcd = LocationService.availablePosList.firstWhere((p) => p.locationTag == 'PCD');
      LocationService.setCurrentPos(pcd);
      expect(LocationService.currentPos.locationTag, equals('PCD'));

      // 2. Switch to Manado -> currentPos must be PBM (not PCD!)
      await BranchService.instance.setBranch(AppBranch.manado);
      expect(LocationService.currentPos.locationTag, equals('PBM'));

      // In Manado, select TBM
      final tbm = LocationService.availablePosList.firstWhere((p) => p.locationTag == 'TBM');
      LocationService.setCurrentPos(tbm);
      expect(LocationService.currentPos.locationTag, equals('TBM'));

      // 3. Switch back to Bali -> currentPos must still be PCD (not TBM!)
      await BranchService.instance.setBranch(AppBranch.bali);
      expect(LocationService.currentPos.locationTag, equals('PCD'));

      // 4. Switch back to Manado -> currentPos must still be TBM
      await BranchService.instance.setBranch(AppBranch.manado);
      expect(LocationService.currentPos.locationTag, equals('TBM'));
    });

    test('resolveLocationFromTask tags correctly by branch', () async {
      // In Bali, dynamic location creation should receive KC Bali cabangName and POS-DPS- prefix
      await BranchService.instance.setBranch(AppBranch.bali);
      final locBali = LocationService.resolveLocationFromTask(posTag: 'DPS-TEST', posName: 'Pos Uji Coba Bali');
      expect(locBali, isNotNull);
      expect(locBali!.cabangName, equals('KC Bali'));
      expect(locBali.posId, startsWith('POS-DPS-'));

      // In Manado, dynamic location creation should receive KC Manado cabangName and POS- prefix
      await BranchService.instance.setBranch(AppBranch.manado);
      final locManado = LocationService.resolveLocationFromTask(posTag: 'MDO-TEST', posName: 'Pos Uji Coba Manado');
      expect(locManado, isNotNull);
      expect(locManado!.cabangName, equals('KC Manado'));
      expect(locManado.posId, startsWith('POS-'));
      expect(locManado.posId.startsWith('POS-DPS-'), isFalse);
    });
  });
}
