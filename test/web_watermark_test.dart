@TestOn('browser')
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bssparking_timemark/core/utils/image_watermark_processor.dart';
import 'package:bssparking_timemark/data/models/watermark_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('applyWatermarkToBytes menghasilkan JPEG ber-watermark di browser', () async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 720, 960),
      Paint()..color = Colors.blue,
    );
    final picture = recorder.endRecording();
    final img = await picture.toImage(720, 960);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

    final result = await ImageWatermarkProcessor.applyWatermarkToBytes(
      imageBytes: byteData!.buffer.asUint8List(),
      timestamp: DateTime(2026, 10, 20, 8, 30),
      lat: 1.4882,
      lng: 124.8428,
      fullAddress: 'Pos 1 Megamas Manado',
      kodeVerifikasi: 'BSS-WEB-1234',
      config: const WatermarkConfig(),
      activeLocationTag: 'PBM/PKM',
      activeLocationColor: const Color(0xFFF59E0B),
      isAbsensi: true,
      targetAspectRatio: 3 / 4,
      jpegQuality: 90,
    );

    expect(result, isNotNull);
    expect(result!.length, greaterThan(0));
    expect(result[0], 0xFF);
    expect(result[1], 0xD8);

    final codec = await ui.instantiateImageCodec(result);
    final frame = await codec.getNextFrame();
    expect(frame.image.width, 720);
    expect(frame.image.height, 960);
  });
}
