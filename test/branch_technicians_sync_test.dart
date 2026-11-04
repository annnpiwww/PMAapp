import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bssparking_timemark/data/services/branch_service.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    BranchService.clientOverride = null;
    BranchService.instance.resetForTesting();
  });

  tearDown(() {
    BranchService.clientOverride = null;
    BranchService.instance.resetForTesting();
  });

  group('BranchService Technician Remote Sync Contract Tests', () {
    test('(a) remote rows replace the fallback for bali and ho', () async {
      final remoteRows = [
        {'nama': 'Bali Remote Tech 1', 'branch': 'bali', 'sort_order': 0},
        {'nama': 'Bali Remote Tech 2', 'branch': 'bali', 'sort_order': 1},
        {'nama': 'HO Remote Specialist', 'branch': 'ho', 'sort_order': 0},
        {'nama': 'Ryan Lumasuge', 'branch': 'manado', 'sort_order': 0},
      ];

      BranchService.clientOverride = MockClient((request) async {
        if (request.url.path.contains('technicians')) {
          return http.Response(jsonEncode(remoteRows), 200);
        }
        return http.Response('Not Found', 404);
      });

      final synced = await BranchService.syncTechniciansFromRemote();
      expect(synced, isTrue);

      final baliTechs = BranchService.instance.getTechnicians(branch: AppBranch.bali);
      expect(baliTechs, equals(['Bali Remote Tech 1', 'Bali Remote Tech 2']));

      final hoTechs = BranchService.instance.getTechnicians(branch: AppBranch.ho);
      expect(hoTechs, equals(['HO Remote Specialist']));
    });

    test('(b) manado list unchanged when remote mirrors seed', () async {
      final seedManado = [
        {'nama': 'Ryan Lumasuge', 'branch': 'manado', 'sort_order': 0},
        {'nama': 'Raldy Sangkop', 'branch': 'manado', 'sort_order': 1},
        {'nama': 'Junifer Manua', 'branch': 'manado', 'sort_order': 2},
        {'nama': 'Alessandro Sulistyo', 'branch': 'manado', 'sort_order': 3},
      ];

      BranchService.clientOverride = MockClient((request) async {
        if (request.url.path.contains('technicians')) {
          return http.Response(jsonEncode(seedManado), 200);
        }
        return http.Response('Not Found', 404);
      });

      final synced = await BranchService.syncTechniciansFromRemote();
      expect(synced, isTrue);

      final manadoTechs = BranchService.instance.getTechnicians(branch: AppBranch.manado);
      expect(
        manadoTechs,
        equals([
          'Ryan Lumasuge',
          'Raldy Sangkop',
          'Junifer Manua',
          'Alessandro Sulistyo',
        ]),
      );
    });

    test('(c) remote failure keeps last cache', () async {
      final initialRows = [
        {'nama': 'Custom Bali Guy', 'branch': 'bali', 'sort_order': 0},
      ];

      BranchService.clientOverride = MockClient((request) async {
        return http.Response(jsonEncode(initialRows), 200);
      });

      final ok = await BranchService.syncTechniciansFromRemote();
      expect(ok, isTrue);
      expect(
        BranchService.instance.getTechnicians(branch: AppBranch.bali),
        equals(['Custom Bali Guy']),
      );

      // Now simulate network failure
      BranchService.clientOverride = MockClient((request) async {
        return http.Response('Internal Server Error', 500);
      });

      final failed = await BranchService.syncTechniciansFromRemote();
      expect(failed, isFalse);

      // Cache should be retained
      expect(
        BranchService.instance.getTechnicians(branch: AppBranch.bali),
        equals(['Custom Bali Guy']),
      );
    });

    test('(d) before any sync the fallback const list is returned', () {
      expect(StorageService.hasTechniciansSyncedRemote(), isFalse);

      final bali = BranchService.instance.getTechnicians(branch: AppBranch.bali);
      expect(bali.length, 6);
      expect(bali, contains('Putu Hyan Parta Wijaya'));
      expect(bali, contains('ANAK AGUNG GEDE AGUNG YUSTIKAWANGSA'));

      final ho = BranchService.instance.getTechnicians(branch: AppBranch.ho);
      expect(ho.length, 10);
      expect(ho, contains('AHMAD KHAELANI'));
      expect(ho, contains('RIYAN ADNAN'));

      final manado = BranchService.instance.getTechnicians(branch: AppBranch.manado);
      expect(manado.length, 4);
      expect(manado, contains('Ryan Lumasuge'));
      expect(manado, contains('Alessandro Sulistyo'));
    });

    test('(e) getTechnicians(branch: AppBranch.ho) never contains a Manado name after sync', () async {
      final remoteRows = [
        {'nama': 'Ryan Lumasuge', 'branch': 'manado', 'sort_order': 0},
        {'nama': 'Raldy Sangkop', 'branch': 'manado', 'sort_order': 1},
        {'nama': 'Junifer Manua', 'branch': 'manado', 'sort_order': 2},
        {'nama': 'Alessandro Sulistyo', 'branch': 'manado', 'sort_order': 3},
        {'nama': 'AHMAD KHAELANI', 'branch': 'ho', 'sort_order': 0},
        {'nama': 'HASRUL HAQ', 'branch': 'ho', 'sort_order': 1},
      ];

      BranchService.clientOverride = MockClient((request) async {
        return http.Response(jsonEncode(remoteRows), 200);
      });

      final ok = await BranchService.syncTechniciansFromRemote();
      expect(ok, isTrue);

      final hoTechs = BranchService.instance.getTechnicians(branch: AppBranch.ho);
      expect(hoTechs, equals(['AHMAD KHAELANI', 'HASRUL HAQ']));

      const manadoNames = [
        'Ryan Lumasuge',
        'Raldy Sangkop',
        'Junifer Manua',
        'Alessandro Sulistyo',
      ];
      for (final m in manadoNames) {
        expect(hoTechs.contains(m), isFalse);
      }
    });

    test('branch with zero active rows returns empty list after sync', () async {
      // Remote has rows for manado and bali, but 0 rows for ho
      final remoteRows = [
        {'nama': 'Ryan Lumasuge', 'branch': 'manado', 'sort_order': 0},
        {'nama': 'Putu Hyan Parta Wijaya', 'branch': 'bali', 'sort_order': 0},
      ];

      BranchService.clientOverride = MockClient((request) async {
        return http.Response(jsonEncode(remoteRows), 200);
      });

      final ok = await BranchService.syncTechniciansFromRemote();
      expect(ok, isTrue);

      final hoTechs = BranchService.instance.getTechnicians(branch: AppBranch.ho);
      expect(hoTechs, isEmpty);
    });
  });
}
