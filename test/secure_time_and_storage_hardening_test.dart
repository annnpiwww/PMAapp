import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bssparking_timemark/data/services/secure_time_service.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';
import 'package:bssparking_timemark/data/services/google_sheets_service.dart';
import 'package:bssparking_timemark/data/models/maintenance_submission.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    SecureTimeService.reset();
  });

  group('SecureTimeService Hardening & Clock Skew Detection', () {
    test('Normal time flow does not trigger clock skew or tampered flag', () {
      final result = SecureTimeService.getVerifiedTime();
      expect(result.isTimeSkewDetected, isFalse);
      expect(result.isDeviceTimeManipulated, isFalse);
      expect(result.isTampered, isFalse);
      expect(result.warningTag, isNull);
      expect(SecureTimeService.isTampered, isFalse);
      expect(SecureTimeService.warningTag, isNull);
    });

    test('Backward clock skew jump (> 60s) triggers isTimeSkewDetected & isTampered', () {
      // Simulasi lompatan mundur 120 detik (> 60 detik)
      SecureTimeService.simulateClockSkew(skewSeconds: -120);
      final result = SecureTimeService.getVerifiedTime();

      expect(result.isTimeSkewDetected, isTrue);
      expect(result.isTampered, isTrue);
      expect(result.warningTag, equals('[JAM DIUBAH MANUAL]'));
      expect(SecureTimeService.isTimeSkewDetected, isTrue);
      expect(SecureTimeService.isTampered, isTrue);
      expect(SecureTimeService.warningTag, equals('[JAM DIUBAH MANUAL]'));
    });

    test('Extreme forward clock skew jump (> 300s) triggers isTimeSkewDetected & isTampered', () {
      // Simulasi lompatan maju 600 detik (> 300 detik)
      SecureTimeService.simulateClockSkew(skewSeconds: 600);
      final result = SecureTimeService.getVerifiedTime();

      expect(result.isTimeSkewDetected, isTrue);
      expect(result.isTampered, isTrue);
      expect(result.warningTag, equals('[JAM DIUBAH MANUAL]'));
      expect(SecureTimeService.isTimeSkewDetected, isTrue);
      expect(SecureTimeService.isTampered, isTrue);
      expect(SecureTimeService.warningTag, equals('[JAM DIUBAH MANUAL]'));
    });

    test('Server sync offset (> 300s) sets isTampered and warningTag', () {
      SecureTimeService.setMockOffset(1800); // 30 menit ke depan
      final result = SecureTimeService.getVerifiedTime();

      expect(result.isDeviceTimeManipulated, isTrue);
      expect(result.isTampered, isTrue);
      expect(result.warningTag, equals('[JAM DIUBAH MANUAL]'));
      expect(result.source, equals('NTP_HTTP'));
    });
  });

  group('StorageService PIN Hardening & Maintenance Sorting', () {
    test('hashPin generates multi-round SHA-256 hash', () {
      const pin = '887766';
      final hash1 = StorageService.hashPin(pin);
      final hash2 = StorageService.hashPin(pin);

      expect(hash1.length, equals(64)); // 64 hex characters (SHA-256)
      expect(hash1, equals(hash2));
    });

    test('Fallback compatibility: legacy single-round PIN is verified and auto-upgraded', () async {
      final prefs = await SharedPreferences.getInstance();
      const legacyPin = '654321';
      const salt = 'testsalt1234567890';
      // Simpan salt dan hash legacy single-round (sha256(salt::pin))
      await prefs.setString('bss_technician_pin_salt_v1', salt);
      final legacyHash = sha256.convert(utf8.encode('$salt::$legacyPin')).toString();
      await prefs.setString('bss_technician_pin_v1', legacyHash);

      // Verifikasi harus berhasil lewat fallback legacy
      final verifyRes = await StorageService.verifyTechnicianPin(legacyPin);
      expect(verifyRes.ok, isTrue);
      expect(verifyRes.message, equals('PIN sesuai.'));

      // Setelah verifikasi, hash harus otomatis di-upgrade ke multi-round hash
      final upgradedHash = prefs.getString('bss_technician_pin_v1');
      expect(upgradedHash, isNotNull);
      expect(upgradedHash, isNot(equals(legacyHash)));

      // Verifikasi ulang dengan hash baru yang sudah ter-upgrade
      final verifyAgain = await StorageService.verifyTechnicianPin(legacyPin);
      expect(verifyAgain.ok, isTrue);
    });

    test('saveMaintenanceSubmissions sorts properly by createdAt descending', () async {
      final sub1 = MaintenanceSubmission(
        id: 'sub_1',
        templateId: 't1',
        templateName: 'Barrier Gate',
        userId: 'u1',
        userName: 'Aan',
        userNpp: '12345',
        posId: 'p1',
        posName: 'Pos 1',
        cabangName: 'Manado',
        points: [],
        createdAt: DateTime(2026, 9, 1, 10, 0),
        updatedAt: DateTime(2026, 9, 1, 10, 0),
      );

      final sub2 = MaintenanceSubmission(
        id: 'sub_2',
        templateId: 't1',
        templateName: 'Barrier Gate',
        userId: 'u1',
        userName: 'Aan',
        userNpp: '12345',
        posId: 'p1',
        posName: 'Pos 1',
        cabangName: 'Manado',
        points: [],
        createdAt: DateTime(2026, 9, 11, 14, 0),
        updatedAt: DateTime(2026, 9, 11, 14, 0),
      );

      await StorageService.saveMaintenanceSubmissions([sub1, sub2]);
      final loaded = StorageService.getMaintenanceSubmissions();

      expect(loaded, isNotNull);
      expect(loaded!.length, equals(2));
      // Urutan descending: sub_2 (terbaru) duluan
      expect(loaded.first.id, equals('sub_2'));
      expect(loaded.last.id, equals('sub_1'));
      expect(loaded.first.timestamp, equals(sub2.createdAt));
    });
  });

  group('GoogleSheetsService Auth & Secret Token Hardening', () {
    test('Default secret token matches BSS_TIMEMARK_SECURE_TOKEN_2026', () async {
      expect(GoogleSheetsService.defaultSecretToken, equals('BSS_TIMEMARK_SECURE_TOKEN_2026'));
      final token = await GoogleSheetsService.getSecretToken();
      expect(token, equals('BSS_TIMEMARK_SECURE_TOKEN_2026'));
    });

    test('Custom secret token can be saved and retrieved', () async {
      await GoogleSheetsService.saveSecretToken('CUSTOM_SECURE_TOKEN_999');
      final token = await GoogleSheetsService.getSecretToken();
      expect(token, equals('CUSTOM_SECURE_TOKEN_999'));
    });
  });
}
