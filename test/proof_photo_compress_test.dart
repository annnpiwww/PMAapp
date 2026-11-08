import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bssparking_timemark/data/services/branch_service.dart';
import 'package:bssparking_timemark/data/services/daily_task_service.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    BranchService.instance.resetForTesting();
    tempDir = Directory.systemTemp.createTempSync('proof_compress_test_');
  });

  tearDown(() {
    DailyTaskService.clientOverride = null;
    BranchService.instance.resetForTesting();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('DailyTaskService Proof Photo Compression Tests (Task t20261108-140658-4a2c)', () {
    test('(a) generated 4000x3000 JPEG is uploaded with longest side 1280 and bytes smaller than input', () async {
      // Create a 4000x3000 test image with pattern
      final canvas = img.Image(width: 4000, height: 3000);
      for (int y = 0; y < 3000; y += 50) {
        for (int x = 0; x < 4000; x += 50) {
          canvas.setPixelRgb(x, y, (x * 255) ~/ 4000, (y * 255) ~/ 3000, 128);
        }
      }
      final rawJpeg = Uint8List.fromList(img.encodeJpg(canvas, quality: 90));
      final testFile = File('${tempDir.path}/large_4000x3000.jpg')..writeAsBytesSync(rawJpeg);

      Uint8List? capturedBytes;
      DailyTaskService.clientOverride = MockClient((req) async {
        if (req.url.path.contains('/storage/v1/object/task-proofs/')) {
          capturedBytes = req.bodyBytes;
          return http.Response('', 200);
        }
        return http.Response('', 404);
      });

      final url = await DailyTaskService.uploadProofPhoto(
        testFile.path,
        keyPrefix: 'task_large_1',
        index: 0,
      );

      expect(url, isNotNull);
      expect(capturedBytes, isNotNull);
      expect(capturedBytes!.length, lessThan(rawJpeg.length));

      final decoded = img.decodeImage(capturedBytes!);
      expect(decoded, isNotNull);
      expect(decoded!.width, equals(1280));
      expect(decoded.height, equals(960));
    });

    test('(b) 800x600 image is not upscaled', () async {
      final canvas = img.Image(width: 800, height: 600);
      for (int y = 0; y < 600; y += 20) {
        for (int x = 0; x < 800; x += 20) {
          canvas.setPixelRgb(x, y, 200, 100, 50);
        }
      }
      final rawJpeg = Uint8List.fromList(img.encodeJpg(canvas, quality: 85));
      final testFile = File('${tempDir.path}/small_800x600.jpg')..writeAsBytesSync(rawJpeg);

      Uint8List? capturedBytes;
      DailyTaskService.clientOverride = MockClient((req) async {
        if (req.url.path.contains('/storage/v1/object/task-proofs/')) {
          capturedBytes = req.bodyBytes;
          return http.Response('', 200);
        }
        return http.Response('', 404);
      });

      final url = await DailyTaskService.uploadProofPhoto(
        testFile.path,
        keyPrefix: 'task_small_1',
        index: 0,
      );

      expect(url, isNotNull);
      expect(capturedBytes, isNotNull);

      final decoded = img.decodeImage(capturedBytes!);
      expect(decoded, isNotNull);
      expect(decoded!.width, equals(800));
      expect(decoded.height, equals(600));
    });

    test('(c) undecodable bytes are uploaded unchanged', () async {
      final rawCorruptedBytes = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
      final testFile = File('${tempDir.path}/corrupt.jpg')..writeAsBytesSync(rawCorruptedBytes);

      Uint8List? capturedBytes;
      DailyTaskService.clientOverride = MockClient((req) async {
        if (req.url.path.contains('/storage/v1/object/task-proofs/')) {
          capturedBytes = req.bodyBytes;
          return http.Response('', 200);
        }
        return http.Response('', 404);
      });

      final url = await DailyTaskService.uploadProofPhoto(
        testFile.path,
        keyPrefix: 'task_corrupt_1',
        index: 0,
      );

      expect(url, isNotNull);
      expect(capturedBytes, isNotNull);
      expect(capturedBytes, equals(rawCorruptedBytes));
    });
  });
}
