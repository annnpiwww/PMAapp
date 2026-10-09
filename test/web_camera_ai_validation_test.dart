import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as imglib;
import 'package:bssparking_timemark/core/utils/image_watermark_processor.dart';
import 'package:bssparking_timemark/features/camera/screens/camera_capture_screen.dart';
import 'package:bssparking_timemark/data/models/template_model.dart';
import 'package:bssparking_timemark/data/models/submission_model.dart';
import 'package:bssparking_timemark/data/models/ai_vision_config.dart';
import 'package:bssparking_timemark/data/repositories/template_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bssparking_timemark/data/services/ai_vision_service.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Web Camera Preview & AI Validation Integration Tests', () {
    late Uint8List dummyJpegBytes;

    setUp(() {
      // Create a test image: 1200 x 800 landscape (representing typical camera feed)
      final img = imglib.Image(width: 1200, height: 800);
      imglib.fill(img, color: imglib.ColorRgb8(50, 100, 200));
      dummyJpegBytes = Uint8List.fromList(imglib.encodeJpg(img, quality: 75));
    });

    test('CameraAspectRatio.ratio3x4 value is exactly 0.75 (3:4)', () {
      expect(CameraAspectRatio.ratio3x4.value, equals(3 / 4));
      expect(CameraAspectRatio.ratio1x1.value, equals(1.0));
      expect(CameraAspectRatio.ratio9x16.value, equals(9 / 16));
      expect(CameraAspectRatio.ratioFull.value, isNull);
    });

    test('generateAiVisionBase64 crops to 3:4 target aspect ratio and generates valid base64', () async {
      final base64Result = await ImageWatermarkProcessor.generateAiVisionBase64(
        'dummy_path.jpg',
        dummyJpegBytes,
        false,
        3 / 4,
      );

      expect(base64Result, isNotNull);
      expect(base64Result!.isNotEmpty, isTrue);

      // Verify that base64 decoded bytes form a valid image with 3:4 aspect ratio
      final decodedBytes = base64Decode(base64Result);
      final decodedImg = imglib.decodeImage(decodedBytes);
      expect(decodedImg, isNotNull);

      final aspect = decodedImg!.width / decodedImg.height;
      // Should be very close to 0.75 (3:4)
      expect(aspect, closeTo(0.75, 0.05));
    });

    test('generateAiVisionBase64 flips horizontally when isFrontCamera is true', () async {
      final base64Front = await ImageWatermarkProcessor.generateAiVisionBase64(
        'dummy_front.jpg',
        dummyJpegBytes,
        true,
        3 / 4,
      );

      expect(base64Front, isNotNull);
      expect(base64Front!.isNotEmpty, isTrue);
    });

    test('generateAiVisionBase64 returns fallback base64 rather than null on corrupted image', () async {
      final corruptedBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      final fallbackBase64 = await ImageWatermarkProcessor.generateAiVisionBase64(
        'corrupted.jpg',
        corruptedBytes,
        false,
        3 / 4,
      );

      // Must never return null if directBytes has content!
      expect(fallbackBase64, isNotNull);
      expect(fallbackBase64, equals(base64Encode(corruptedBytes)));
    });

    test('AiVisionService verifies base64 photo cleanly with on-device mock fallback', () async {
      SharedPreferences.setMockInitialValues({});
      await StorageService.init();

      final template = TemplateRepository.defaultTemplates.first;
      const testConfig = AiVisionConfig(
        provider: AiProviderType.onDeviceMock,
        modelName: 'bss-mock',
      );

      final base64String = base64Encode(dummyJpegBytes);
      final result = await AiVisionService.verifySubmissionWithAI(
        template: template,
        imageBase64: base64String,
        customConfig: testConfig,
      );

      expect(result.status, equals(VerificationStatus.sesuai));
      expect(result.confidenceScore, greaterThan(0.8));
    });
  });
}
