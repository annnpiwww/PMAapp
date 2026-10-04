import 'package:flutter_test/flutter_test.dart';
import 'package:bssparking_timemark/data/services/secure_time_service.dart';
import 'package:bssparking_timemark/data/services/location_service.dart';
import 'package:bssparking_timemark/data/repositories/template_repository.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    SecureTimeService.reset();
  });

  group('Security & Anti-Fraud Tests', () {
    test('Detects manipulated device time when offset exceeds 5 minutes (300s)', () {
      // 1. Device jam normal (offset 0s)
      SecureTimeService.setMockOffset(0);
      var result = SecureTimeService.getVerifiedTime();
      expect(result.isDeviceTimeManipulated, isFalse);

      // 2. Device jam dimundurkan 2 jam (-7200s) -> Fake Time Fraud
      SecureTimeService.setMockOffset(-7200);
      result = SecureTimeService.getVerifiedTime();
      expect(result.isDeviceTimeManipulated, isTrue);
      expect(result.source, equals('NTP_HTTP'));

      // 3. Device jam dimajukan 1 jam (+3600s) -> Fake Time Fraud
      SecureTimeService.setMockOffset(3600);
      result = SecureTimeService.getVerifiedTime();
      expect(result.isDeviceTimeManipulated, isTrue);

      // 4. Waktu dalam batas toleransi wajar (10 detik) -> Lolos
      SecureTimeService.setMockOffset(10);
      result = SecureTimeService.getVerifiedTime();
      expect(result.isDeviceTimeManipulated, isFalse);
    });

    test('LocationResult tracks isMockLocation accurately', () {
      final realLoc = LocationResult(
        lat: 1.497558,
        lng: 124.841501,
        accuracyMeter: 3.5,
        isGpsEnabled: true,
        isMockLocation: false,
        posName: 'Pos Gate Utama',
        cabangName: 'BSS Manado',
        fullAddress: 'Jl. Piere Tendean',
        locationTag: 'GATE 1',
      );
      expect(realLoc.isMockLocation, isFalse);

      final fakeLoc = LocationResult(
        lat: 1.497558,
        lng: 124.841501,
        accuracyMeter: 10.0,
        isGpsEnabled: true,
        isMockLocation: true,
        posName: 'Pos Gate Utama',
        cabangName: 'BSS Manado',
        fullAddress: 'Jl. Piere Tendean',
        locationTag: 'GATE 1',
      );
      expect(fakeLoc.isMockLocation, isTrue);
    });

    test('LocationService.isLastLocationMocked accurately reflects cached location state', () {
      LocationService.setCachedLocationForTesting(LocationResult(
        lat: 1.497558,
        lng: 124.841501,
        accuracyMeter: 5.0,
        isGpsEnabled: true,
        isMockLocation: true,
        posName: 'Pos Gate Utama',
        cabangName: 'BSS Manado',
        fullAddress: 'Jl. Piere Tendean',
        locationTag: 'GATE 1',
      ));
      expect(LocationService.isLastLocationMocked, isTrue);

      LocationService.setCachedLocationForTesting(LocationResult(
        lat: 1.497558,
        lng: 124.841501,
        accuracyMeter: 3.0,
        isGpsEnabled: true,
        isMockLocation: false,
        posName: 'Pos Gate Utama',
        cabangName: 'BSS Manado',
        fullAddress: 'Jl. Piere Tendean',
        locationTag: 'GATE 1',
      ));
      expect(LocationService.isLastLocationMocked, isFalse);

      LocationService.setCachedLocationForTesting(null);
    });
  });

  group('Template Models & Role Classification Smoke Tests', () {
    test('All standard BSS templates are seeded with complete points', () async {
      await TemplateRepository.instance.init();
      final templates = TemplateRepository.instance.templates;

      expect(templates.length, greaterThanOrEqualTo(5));

      // Absensi check: kriteria ringkas 7 item
      final absensi = templates.firstWhere((t) => t.id == 'tpl_absensi_01');
      expect(absensi.nama, equals('Absensi'));
      expect(absensi.sopCriteria.length, equals(7));
      expect(absensi.sopCriteria.any((c) => c.contains('dimasukkan dalam celana')), isTrue);
      expect(absensi.sopCriteria.any((c) => c.contains('Pin smile')), isTrue);

      // Maintenance templates checks (technician per-point ringkas representatif)
      final maintPos = templates.firstWhere((t) => t.id == 'tpl_maint_pos');
      expect(maintPos.isPerPoint, isTrue);
      expect(maintPos.sopPoints.length, equals(9));

      final maintBarrier = templates.firstWhere((t) => t.id == 'tpl_maint_barrier');
      expect(maintBarrier.sopPoints.length, equals(9));

      final maintManless = templates.firstWhere((t) => t.id == 'tpl_maint_manless');
      expect(maintManless.sopPoints.length, equals(8));

      final maintServer = templates.firstWhere((t) => t.id == 'tpl_maint_server');
      expect(maintServer.sopPoints.length, equals(6));
    });
  });
}
