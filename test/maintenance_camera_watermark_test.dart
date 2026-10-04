import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bssparking_timemark/core/utils/image_watermark_processor.dart';
import 'package:bssparking_timemark/data/models/maintenance_submission.dart';
import 'package:bssparking_timemark/data/models/template_model.dart';
import 'package:bssparking_timemark/data/models/watermark_config.dart';
import 'package:bssparking_timemark/data/services/whatsapp_report_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Maintenance Camera & Watermark Integration Tests', () {
    late Directory tempDir;
    late File dummyImageFile;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('bss_maint_test_');
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawRect(const Rect.fromLTWH(0, 0, 1080, 1920), Paint()..color = Colors.teal);
      final picture = recorder.endRecording();
      final img = await picture.toImage(1080, 1920);
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

      dummyImageFile = File('${tempDir.path}/maint_point_dummy.jpg');
      await dummyImageFile.writeAsBytes(byteData!.buffer.asUint8List());
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('applyWatermarkToFile burns watermark on maintenance image with isFrontCamera false & true', () async {
      final initialSize = dummyImageFile.lengthSync();

      // Test Rear Camera Watermarking
      final rearPath = await ImageWatermarkProcessor.applyWatermarkToFile(
        imagePath: dummyImageFile.path,
        timestamp: DateTime(2026, 9, 12, 14, 30),
        lat: -6.2088,
        lng: 106.8456,
        fullAddress: 'Pos 1 Megamas Manado',
        kodeVerifikasi: 'MAINT-REAR-001',
        config: const WatermarkConfig(),
        activeLocationTag: 'POS 1',
        activeLocationColor: const Color(0xFFF59E0B),
        isFrontCamera: false,
      );

      expect(rearPath, equals(dummyImageFile.path));
      final rearSize = File(rearPath).lengthSync();
      expect(rearSize != initialSize, isTrue);

      // Test Front Camera Watermarking (with horizontal flip)
      final frontPath = await ImageWatermarkProcessor.applyWatermarkToFile(
        imagePath: dummyImageFile.path,
        timestamp: DateTime(2026, 9, 12, 14, 35),
        lat: -6.2088,
        lng: 106.8456,
        fullAddress: 'Pos 1 Megamas Manado',
        kodeVerifikasi: 'MAINT-FRONT-002',
        config: const WatermarkConfig(),
        activeLocationTag: 'POS 1',
        activeLocationColor: const Color(0xFFF59E0B),
        isFrontCamera: true,
      );

      expect(frontPath, equals(dummyImageFile.path));
      expect(File(frontPath).existsSync(), isTrue);
    });

    test('MaintenanceSubmission handles watermarked point results correctly', () {
      final pointResult1 = MaintenancePointResult(
        pointId: 'pos_1_pc',
        label: 'Kebersihan & Kondisi PC Kasir',
        imagePath: dummyImageFile.path,
        timestamp: DateTime(2026, 9, 12, 14, 30),
        status: PointStatus.sesuai,
        alasan: 'PC bersih, kipas normal.',
        confidence: 0.98,
        providerName: 'Gemini Vision',
      );

      final pointResult2 = MaintenancePointResult(
        pointId: 'pos_1_printer',
        label: 'Printer Thermal Struk',
        imagePath: dummyImageFile.path,
        timestamp: DateTime(2026, 9, 12, 14, 32),
        status: PointStatus.sesuai,
        alasan: 'Hasil cetak struk tajam.',
        confidence: 0.95,
        providerName: 'Gemini Vision',
      );

      final submission = MaintenanceSubmission(
        id: 'sub_test_001',
        templateId: 'tpl_pos',
        templateName: 'Maintenance Pos Kasir',
        userId: 'tech_01',
        userName: 'Teknisi BSS',
        userNpp: 'BSS-889',
        posId: 'pos_1',
        posName: 'Pos 1',
        cabangName: 'Kawasan Megamas Manado',
        points: [pointResult1, pointResult2],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(submission.isComplete, isTrue);
      expect(submission.isAllSesuai, isTrue);
      expect(submission.doneCount, equals(2));
      expect(submission.totalPoints, equals(2));

      // Report generation should format properly with point labels
      final reportText = WhatsAppReportService.generateReportText(
        submission: submission,
        category: TemplateCategory.maintPos,
        unitCount: 1,
      );

      expect(reportText, contains('Izin melaporkan hasil maintenance POS'));
      expect(reportText, contains('Farhan Lakoro'));
      expect(reportText, contains('Lokasi : Pos 1'));
    });
  });
}
