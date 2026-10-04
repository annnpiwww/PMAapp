import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bssparking_timemark/data/models/watermark_config.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  group('WatermarkConfig Persistence & Serialization Tests', () {
    test('Saves and restores WatermarkConfig with custom logo & location toggles', () async {
      const config = WatermarkConfig(
        logoImagePath: '/path/to/custom_logo.jpg',
        badgeTag: 'GATE-01',
        badgeColor: Color(0xFF1E489C),
        timeZone: 'WITA',
        showLocationOnCamera: false,
        showLocationOnResult: true,
      );

      await StorageService.saveWatermarkConfig(config);

      final restored = StorageService.getWatermarkConfig();
      expect(restored.logoImagePath, equals('/path/to/custom_logo.jpg'));
      expect(restored.badgeTag, equals('GATE-01'));
      expect(restored.badgeColor.toARGB32(), equals(const Color(0xFF1E489C).toARGB32()));
      expect(restored.showLocationOnCamera, isFalse);
      expect(restored.showLocationOnResult, isTrue);
    });

    test('Default fallback values when uninitialized', () {
      SharedPreferences.setMockInitialValues({});
      final config = StorageService.getWatermarkConfig();
      expect(config.badgeTag, equals('Absensi'));
      expect(config.scale, equals(1.0));
      expect(config.positionX, equals(0.0));
      expect(config.positionY, equals(1.0));
      expect(config.showLocationOnCamera, isTrue);
      expect(config.showLocationOnResult, isTrue);
      expect(config.logoImagePath, isNull);
    });

    test('Migrates legacy PBM/PKM watermark config to Absensi with 50% scale', () async {
      SharedPreferences.setMockInitialValues({
        'bss_watermark_config': '{"badgeTag":"PBM/PKM","scale":1.0,"positionX":0.04,"positionY":0.78}',
      });
      await StorageService.init();
      final config = StorageService.getWatermarkConfig();
      expect(config.badgeTag, equals('Absensi'));
      expect(config.scale, equals(0.5));
      expect(config.positionX, equals(0.0));
      expect(config.positionY, equals(1.0));
    });

    test('First install tutorial state defaults to false and persists true', () async {
      SharedPreferences.setMockInitialValues({});
      expect(StorageService.hasSeenTutorial(), isFalse);

      await StorageService.setHasSeenTutorial(true);
      expect(StorageService.hasSeenTutorial(), isTrue);
    });
  });
}
