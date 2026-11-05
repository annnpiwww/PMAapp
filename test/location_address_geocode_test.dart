import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:bssparking_timemark/data/services/branch_service.dart';
import 'package:bssparking_timemark/data/services/location_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    LocationService.resetForTesting();
  });

  tearDown(() {
    LocationService.resetForTesting();
  });

  group('LocationService.geocodeAddress unit tests', () {
    test('returns coordinates for valid native geocoding result', () async {
      LocationService.nativeGeocodeLookupOverride = (address) async {
        return [
          geo.Location(
            latitude: -8.670458,
            longitude: 115.212629,
            timestamp: DateTime(2026, 11, 5),
          ),
        ];
      };

      final result = await LocationService.geocodeAddress(
        'Jl. Teuku Umar No. 10',
        AppBranch.bali,
      );

      expect(result, isNotNull);
      expect(result!.lat, closeTo(-8.670458, 0.000001));
      expect(result.lng, closeTo(115.212629, 0.000001));
    });

    test('appends branch region when city keyword is missing', () async {
      final capturedQueries = <String>[];
      LocationService.nativeGeocodeLookupOverride = (query) async {
        capturedQueries.add(query);
        return [
          geo.Location(
            latitude: 1.498,
            longitude: 124.841,
            timestamp: DateTime(2026, 11, 5),
          ),
        ];
      };

      // Manado branch without "manado"
      await LocationService.geocodeAddress(
        'Jl. Sam Ratulangi',
        AppBranch.manado,
      );
      expect(capturedQueries.last, 'Jl. Sam Ratulangi, Manado, Sulawesi Utara');

      // Bali branch without "bali"
      await LocationService.geocodeAddress('Jl. Diponegoro 5', AppBranch.bali);
      expect(capturedQueries.last, 'Jl. Diponegoro 5, Bali');

      // HO branch without "makassar"
      await LocationService.geocodeAddress('Jl. AP Pettarani', AppBranch.ho);
      expect(
        capturedQueries.last,
        'Jl. AP Pettarani, Makassar, Sulawesi Selatan',
      );
    });

    test(
      'does not append branch region when city keyword is already present',
      () async {
        final capturedQueries = <String>[];
        LocationService.nativeGeocodeLookupOverride = (query) async {
          capturedQueries.add(query);
          return [
            geo.Location(
              latitude: 1.498,
              longitude: 124.841,
              timestamp: DateTime(2026, 11, 5),
            ),
          ];
        };

        // Manado branch with "manado"
        await LocationService.geocodeAddress(
          'Jl. Sam Ratulangi, Manado',
          AppBranch.manado,
        );
        expect(capturedQueries.last, 'Jl. Sam Ratulangi, Manado');

        // Bali branch with "bali"
        await LocationService.geocodeAddress(
          'Jl. Sunset Road, Bali',
          AppBranch.bali,
        );
        expect(capturedQueries.last, 'Jl. Sunset Road, Bali');

        // HO branch with "makassar"
        await LocationService.geocodeAddress(
          'Jl. Veteran, Makassar',
          AppBranch.ho,
        );
        expect(capturedQueries.last, 'Jl. Veteran, Makassar');
      },
    );

    test('returns null for empty or whitespace-only address', () async {
      var called = false;
      LocationService.nativeGeocodeLookupOverride = (_) async {
        called = true;
        return [];
      };

      final emptyRes = await LocationService.geocodeAddress(
        '',
        AppBranch.manado,
      );
      final wsRes = await LocationService.geocodeAddress('   ', AppBranch.bali);

      expect(emptyRes, isNull);
      expect(wsRes, isNull);
      expect(called, isFalse);
    });

    test('returns null when geocoding returns empty list', () async {
      LocationService.nativeGeocodeLookupOverride = (_) async => [];

      final result = await LocationService.geocodeAddress(
        'Alamat Antah Berantah',
        AppBranch.manado,
      );

      expect(result, isNull);
    });

    test('returns null when geocoding returns exactly 0,0', () async {
      LocationService.nativeGeocodeLookupOverride = (_) async => [
        geo.Location(
          latitude: 0.0,
          longitude: 0.0,
          timestamp: DateTime(2026, 11, 5),
        ),
      ];

      final result = await LocationService.geocodeAddress(
        'Null Island',
        AppBranch.ho,
      );

      expect(result, isNull);
    });

    test(
      'returns null when coordinates are outside Indonesia bounds',
      () async {
        // Out of bounds north (lat > 6)
        LocationService.nativeGeocodeLookupOverride = (_) async => [
          geo.Location(
            latitude: 35.6762,
            longitude: 139.6503,
            timestamp: DateTime(2026, 11, 5),
          ),
        ];
        expect(
          await LocationService.geocodeAddress('Tokyo', AppBranch.bali),
          isNull,
        );

        // Out of bounds south (lat < -11)
        LocationService.nativeGeocodeLookupOverride = (_) async => [
          geo.Location(
            latitude: -11.5,
            longitude: 115.0,
            timestamp: DateTime(2026, 11, 5),
          ),
        ];
        expect(
          await LocationService.geocodeAddress('South of Bali', AppBranch.bali),
          isNull,
        );

        // Out of bounds west (lng < 95)
        LocationService.nativeGeocodeLookupOverride = (_) async => [
          geo.Location(
            latitude: 0.0,
            longitude: 94.0,
            timestamp: DateTime(2026, 11, 5),
          ),
        ];
        expect(
          await LocationService.geocodeAddress('West of Sumatra', AppBranch.ho),
          isNull,
        );

        // Out of bounds east (lng > 141)
        LocationService.nativeGeocodeLookupOverride = (_) async => [
          geo.Location(
            latitude: -2.0,
            longitude: 142.0,
            timestamp: DateTime(2026, 11, 5),
          ),
        ];
        expect(
          await LocationService.geocodeAddress('East of Papua', AppBranch.ho),
          isNull,
        );
      },
    );

    test(
      'returns null and does not throw when lookup throws exception',
      () async {
        LocationService.nativeGeocodeLookupOverride = (_) async {
          throw Exception('Native platform channel unavailable');
        };

        final result = await LocationService.geocodeAddress(
          'Jl. Error No. 404',
          AppBranch.manado,
        );

        expect(result, isNull);
      },
    );

    test(
      'web nominatim path handles valid and invalid HTTP responses',
      () async {
        LocationService.isWebOverride = true;

        // Valid response
        LocationService.clientOverride = MockClient((request) async {
          expect(request.url.host, 'nominatim.openstreetmap.org');
          expect(request.url.queryParameters['countrycodes'], 'id');
          return http.Response(
            jsonEncode([
              {'lat': '-5.147665', 'lon': '119.432731'},
            ]),
            200,
          );
        });

        final webResult = await LocationService.geocodeAddress(
          'Jl. Hasanuddin',
          AppBranch.ho,
        );
        expect(webResult, isNotNull);
        expect(webResult!.lat, closeTo(-5.147665, 0.000001));
        expect(webResult.lng, closeTo(119.432731, 0.000001));

        // Empty response
        LocationService.clientOverride = MockClient((request) async {
          return http.Response(jsonEncode([]), 200);
        });
        expect(
          await LocationService.geocodeAddress(
            'Alamat Tidak Ada',
            AppBranch.ho,
          ),
          isNull,
        );

        // HTTP error 500
        LocationService.clientOverride = MockClient((request) async {
          return http.Response('Server Error', 500);
        });
        expect(
          await LocationService.geocodeAddress('Jl. Error', AppBranch.ho),
          isNull,
        );
      },
    );
  });
}
