import 'package:flutter_test/flutter_test.dart';
import 'package:bssparking_timemark/data/models/watermark_config.dart';

void main() {
  group('WatermarkConfig Scale & Defaults', () {
    test('WatermarkConfig defaults to 1.0 scale (100% size)', () {
      const config = WatermarkConfig();
      expect(config.scale, equals(1.0));
    });

    test('WatermarkConfig.fromJson defaults scale to 1.0 when omitted or null', () {
      final config = WatermarkConfig.fromJson({});
      expect(config.scale, equals(1.0));

      final configNullScale = WatermarkConfig.fromJson({'scale': null});
      expect(configNullScale.scale, equals(1.0));
    });

    test('WatermarkConfig.fromJson preserves custom scale if provided', () {
      final config = WatermarkConfig.fromJson({'scale': 0.75});
      expect(config.scale, equals(0.75));
    });
  });
}
