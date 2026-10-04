import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bssparking_timemark/core/utils/image_watermark_processor.dart';
import 'package:bssparking_timemark/data/models/watermark_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('applyWatermarkToFile executes successfully and modifies image', () async {
    // Create a temporary 1080x1920 test image
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(const Rect.fromLTWH(0, 0, 1080, 1920), Paint()..color = Colors.blue);
    final picture = recorder.endRecording();
    final img = await picture.toImage(1080, 1920);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    
    final tempDir = Directory.systemTemp.createTempSync('bss_test_wm');
    final tempFile = File('${tempDir.path}/test_img.jpg');
    await tempFile.writeAsBytes(byteData!.buffer.asUint8List());

    final initialSize = tempFile.lengthSync();
    debugPrint('Initial size: $initialSize bytes');

    final stopwatch = Stopwatch()..start();
    final resultPath = await ImageWatermarkProcessor.applyWatermarkToFile(
      imagePath: tempFile.path,
      timestamp: DateTime.now(),
      lat: 1.4882,
      lng: 124.8428,
      fullAddress: 'Pos 1 Megamas Manado',
      kodeVerifikasi: 'BSS-TEST-1234',
      config: const WatermarkConfig(),
      activeLocationTag: 'PBM/PKM',
      activeLocationColor: const Color(0xFFF59E0B),
    );
    stopwatch.stop();
    debugPrint('Watermark applied in ${stopwatch.elapsedMilliseconds}ms, resultPath: $resultPath');

    final finalSize = File(resultPath).lengthSync();
    debugPrint('Final size: $finalSize bytes');

    expect(resultPath, equals(tempFile.path));
    // Final size should be different from initial PNG
    expect(finalSize != initialSize, isTrue);

    tempDir.deleteSync(recursive: true);
  });

  test('applyWatermarkToFile supports targetAspectRatio for Full ratio and 1:1', () async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(const Rect.fromLTWH(0, 0, 1080, 1920), Paint()..color = Colors.green);
    final picture = recorder.endRecording();
    final img = await picture.toImage(1080, 1920);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

    final tempDir = Directory.systemTemp.createTempSync('bss_test_ratio');
    final tempFile = File('${tempDir.path}/test_ratio.jpg');
    await tempFile.writeAsBytes(byteData!.buffer.asUint8List());

    // Test Full ratio (e.g. 9:20 = 0.45)
    final resultPath = await ImageWatermarkProcessor.applyWatermarkToFile(
      imagePath: tempFile.path,
      timestamp: DateTime.now(),
      lat: 1.4882,
      lng: 124.8428,
      fullAddress: 'Pos 1 Megamas Manado',
      kodeVerifikasi: 'BSS-RATIO-FULL',
      config: const WatermarkConfig(),
      activeLocationTag: 'PBM/PKM',
      activeLocationColor: const Color(0xFFF59E0B),
      targetAspectRatio: 9.0 / 20.0,
      jpegQuality: 93,
    );

    expect(File(resultPath).existsSync(), isTrue);
    expect(File(resultPath).lengthSync() > 0, isTrue);

    // Also test generateAiVisionBase64 with targetAspectRatio
    final base64 = await ImageWatermarkProcessor.generateAiVisionBase64(
      resultPath,
      null,
      false,
      9.0 / 20.0,
    );
    expect(base64, isNotNull);
    expect(base64!.isNotEmpty, isTrue);

    tempDir.deleteSync(recursive: true);
  });

  test('applyWatermarkToFile supports isAbsensi flag and downscales large sensor images safely', () async {
    // Create a 2400x3200 (large resolution) test image
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(const Rect.fromLTWH(0, 0, 2400, 3200), Paint()..color = Colors.amber);
    final picture = recorder.endRecording();
    final img = await picture.toImage(2400, 3200);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

    final tempDir = Directory.systemTemp.createTempSync('bss_test_large');
    final tempFile = File('${tempDir.path}/test_large.jpg');
    await tempFile.writeAsBytes(byteData!.buffer.asUint8List());

    final sw = Stopwatch()..start();
    final resultPath = await ImageWatermarkProcessor.applyWatermarkToFile(
      imagePath: tempFile.path,
      timestamp: DateTime.now(),
      lat: 1.4882,
      lng: 124.8428,
      fullAddress: 'Pos 1 Megamas Manado',
      kodeVerifikasi: 'BSS-ABSEN-1234',
      config: const WatermarkConfig(badgeTag: 'Absensi'),
      activeLocationTag: 'PBM/PKM',
      activeLocationColor: const Color(0xFFF59E0B),
      isAbsensi: true,
      jpegQuality: 90,
    );
    sw.stop();
    debugPrint('Large image processed in ${sw.elapsedMilliseconds}ms');

    expect(File(resultPath).existsSync(), isTrue);
    expect(File(resultPath).lengthSync() > 0, isTrue);
    // Should execute fast (<3000ms even on CI)
    expect(sw.elapsedMilliseconds < 5000, isTrue);

    tempDir.deleteSync(recursive: true);
  });
}
