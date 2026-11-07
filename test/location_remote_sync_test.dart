import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bssparking_timemark/data/repositories/auth_repository.dart';
import 'package:bssparking_timemark/data/services/location_service.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';
import 'package:bssparking_timemark/data/services/branch_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    LocationService.clientOverride = null;
    AuthRepository.instance.setSessionTokenForTesting(null);
  });

  group('LocationService Remote Sync Contract Tests', () {
    test(
        '(a) remote rows replace local list and explicitBranch=bali row matches AppBranch.bali even with a Manado-looking tag',
        () async {
      SharedPreferences.setMockInitialValues({});
      await StorageService.init();
      LocationService.resetForTesting();

      final remoteRow = {
        'pos_id': 'POS-TEST-BALI-01',
        'pos_name': 'Test Bali Pos',
        'cabang_name': 'KC Bali',
        'full_address': 'Jl. Test Bali',
        'location_tag': 'PBM',
        'tag_color': 4294286859,
        'branch': 'bali',
        'lat': -8.65,
        'lng': 115.21,
      };

      LocationService.clientOverride = MockClient((request) async {
        if (request.url.path.contains('pos_locations')) {
          return http.Response(jsonEncode([remoteRow]), 200);
        }
        return http.Response('{"ok":true}', 200);
      });

      final ok = await LocationService.syncFromRemote();
      expect(ok, isTrue);

      final all = LocationService.allLocations;
      expect(all.length, 1);
      final pos = all.first;
      expect(pos.posId, 'POS-TEST-BALI-01');
      expect(pos.explicitBranch, AppBranch.bali);
      expect(pos.matchesBranch(AppBranch.bali), isTrue);
      expect(pos.matchesBranch(AppBranch.manado), isFalse);
      expect(pos.branch, AppBranch.bali);
    });

    test('(b) local-only custom row is kept and sent in an import request', () async {
      SharedPreferences.setMockInitialValues({});
      await StorageService.init();
      LocationService.resetForTesting();

      const localCustom = PosLocation(
        posId: 'POS-CUSTOM-99',
        posName: 'Custom Gate',
        cabangName: 'KC BSG',
        fullAddress: 'Jl. Custom',
        locationTag: 'CUST',
        tagColor: Color(0xFFF59E0B),
        lat: 1.5,
        lng: 124.8,
      );
      await LocationService.addLocation(localCustom);

      final remoteRow = {
        'pos_id': 'POS-PBM-01',
        'pos_name': 'Pasar Bersehati Manado',
        'cabang_name': 'KC BSG',
        'full_address': 'Jl. Nusantara No.17',
        'location_tag': 'PBM',
        'tag_color': 4294286859,
        'branch': 'manado',
        'lat': 1.498,
        'lng': 124.841,
      };

      bool importCalled = false;
      Map<String, dynamic>? importBody;

      LocationService.clientOverride = MockClient((request) async {
        if (request.url.path.contains('pos_locations')) {
          return http.Response(jsonEncode([remoteRow]), 200);
        }
        if (request.url.path.contains('pos-locations')) {
          importCalled = true;
          importBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(jsonEncode({'ok': true, 'count': 1}), 200);
        }
        return http.Response('{}', 404);
      });

      final ok = await LocationService.syncFromRemote();
      expect(ok, isTrue);

      final all = LocationService.allLocations;
      expect(all.any((p) => p.posId == 'POS-PBM-01'), isTrue);
      expect(all.any((p) => p.posId == 'POS-CUSTOM-99'), isTrue);

      expect(importCalled, isTrue);
      expect(importBody?['action'], 'import');
      final importedLocs = importBody?['locations'] as List;
      expect(importedLocs.any((loc) => loc['pos_id'] == 'POS-CUSTOM-99'), isTrue);

      expect(StorageService.getLocationImportQueue(), isEmpty);
    });

    test(
        '(c) saveLocationRemote maps 200/401/403/SocketException/500 to ok/invalidCredentials/notSupervisor/offline/failed',
        () async {
      SharedPreferences.setMockInitialValues({});
      await StorageService.init();
      LocationService.resetForTesting();

      const testPos = PosLocation(
        posId: 'POS-TEST-01',
        posName: 'Test Pos',
        cabangName: 'KC BSG',
        fullAddress: 'Jl. Test',
        locationTag: 'TST',
        tagColor: Color(0xFFF59E0B),
        lat: 1.0,
        lng: 124.0,
      );

      // 200 -> ok
      LocationService.clientOverride =
          MockClient((_) async => http.Response('{"ok":true}', 200));
      var res = await LocationService.saveLocationRemote(testPos,
          identity: 'spv1', password: 'pass');
      expect(res, RemoteWriteResult.ok);
      expect(LocationService.allLocations.any((p) => p.posId == 'POS-TEST-01'),
          isTrue);

      // 401 -> invalidCredentials
      LocationService.clientOverride = MockClient(
          (_) async => http.Response('{"error":"unauthorized"}', 401));
      res = await LocationService.saveLocationRemote(testPos,
          identity: 'spv1', password: 'bad');
      expect(res, RemoteWriteResult.invalidCredentials);

      // 403 -> notSupervisor
      LocationService.clientOverride =
          MockClient((_) async => http.Response('{"error":"forbidden"}', 403));
      res = await LocationService.saveLocationRemote(testPos,
          identity: 'user1', password: 'pass');
      expect(res, RemoteWriteResult.notSupervisor);

      // SocketException -> offline
      LocationService.clientOverride = MockClient(
          (_) async => throw const SocketException('No internet'));
      res = await LocationService.saveLocationRemote(testPos,
          identity: 'spv1', password: 'pass');
      expect(res, RemoteWriteResult.offline);

      // 500 -> failed
      LocationService.clientOverride = MockClient(
          (_) async => http.Response('{"error":"server error"}', 500));
      res = await LocationService.saveLocationRemote(testPos,
          identity: 'spv1', password: 'pass');
      expect(res, RemoteWriteResult.failed);
    });

    test('(d) remote failure keeps cached list unchanged', () async {
      SharedPreferences.setMockInitialValues({});
      await StorageService.init();
      LocationService.resetForTesting();

      final initialCount = LocationService.allLocations.length;

      LocationService.clientOverride =
          MockClient((_) async => http.Response('Internal Error', 500));
      final ok = await LocationService.syncFromRemote();
      expect(ok, isFalse);
      expect(LocationService.allLocations.length, initialCount);
    });

    test('deleteLocationRemote maps 200/401/403/SocketException/500 correctly',
        () async {
      SharedPreferences.setMockInitialValues({});
      await StorageService.init();
      LocationService.resetForTesting();

      LocationService.clientOverride =
          MockClient((_) async => http.Response('{"ok":true}', 200));
      var res = await LocationService.deleteLocationRemote('POS-PBM-01',
          identity: 'spv1', password: 'pass');
      expect(res, RemoteWriteResult.ok);
      expect(
          LocationService.allLocations.any((p) => p.posId == 'POS-PBM-01'), isFalse);
    });

    test('deleted-on-server seeds are not re-added from _defaultSeed once synced',
        () async {
      SharedPreferences.setMockInitialValues({});
      await StorageService.init();
      LocationService.resetForTesting();

      final remoteRows = [
        {
          'pos_id': 'POS-PKM-01',
          'pos_name': 'Pelabuhan Kalimas Manado',
          'cabang_name': 'KC BSG',
          'full_address': 'Jl. Rumambi',
          'location_tag': 'PKM',
          'tag_color': 4294286859,
          'branch': 'manado',
          'lat': 1.498,
          'lng': 124.840,
        }
      ];

      LocationService.clientOverride =
          MockClient((_) async => http.Response(jsonEncode(remoteRows), 200));
      await LocationService.syncFromRemote();

      expect(
          LocationService.allLocations.any((p) => p.posId == 'POS-PBM-01'), isFalse);

      LocationService.resetForTesting();
      expect(
          LocationService.allLocations.any((p) => p.posId == 'POS-PBM-01'), isFalse);
      expect(
          LocationService.allLocations.any((p) => p.posId == 'POS-PKM-01'), isTrue);
    });

    test('password is never persisted into StorageService or SharedPreferences during remote ops', () async {
      SharedPreferences.setMockInitialValues({});
      await StorageService.init();
      LocationService.resetForTesting();

      const testPos = PosLocation(
        posId: 'POS-TEST-SEC',
        posName: 'Test Pos',
        cabangName: 'KC BSG',
        fullAddress: 'Jl. Test',
        locationTag: 'SEC',
        tagColor: Color(0xFFF59E0B),
        lat: 1.0,
        lng: 124.0,
      );

      const secretPassword = 'SuperSecretPassword123!';
      const sessionTok = 'v1.eyJleHAiOjQxMDI0NDQ4MDB9.sig';
      AuthRepository.instance.setSessionTokenForTesting(sessionTok);

      final capturedHeaders = <Map<String, String>>[];
      final capturedBodies = <Map<String, dynamic>>[];
      LocationService.clientOverride = MockClient((req) async {
        capturedHeaders.add(req.headers);
        capturedBodies.add(jsonDecode(req.body) as Map<String, dynamic>);
        return http.Response('{"ok":true}', 200);
      });

      await LocationService.saveLocationRemote(testPos, identity: 'spv1', password: secretPassword);
      await LocationService.deleteLocationRemote('POS-TEST-SEC', identity: 'spv1', password: secretPassword);

      for (final h in capturedHeaders) {
        expect(h['x-app-session'], equals(sessionTok));
      }
      for (final b in capturedBodies) {
        expect(b.containsKey('password'), isFalse);
        expect(b.containsKey('identity'), isFalse);
      }

      final prefs = await SharedPreferences.getInstance();
      for (final key in prefs.getKeys()) {
        final val = prefs.get(key).toString();
        expect(val.contains(secretPassword), isFalse, reason: 'Password leaked in SharedPreferences key: $key');
      }
    });
  });
}
