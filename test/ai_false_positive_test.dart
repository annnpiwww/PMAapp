import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as imglib;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bssparking_timemark/core/utils/image_watermark_processor.dart';
import 'package:bssparking_timemark/data/models/ai_vision_config.dart';
import 'package:bssparking_timemark/data/models/maintenance_submission.dart';
import 'package:bssparking_timemark/data/models/submission_model.dart';
import 'package:bssparking_timemark/data/models/template_model.dart';
import 'package:bssparking_timemark/data/services/ai_vision_service.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';
import 'package:bssparking_timemark/data/services/whatsapp_report_service.dart';
import 'package:bssparking_timemark/features/maintenance/screens/maintenance_checklist_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  group('Audit 2026-11-07 AI False-Positive Repro Cases (RC-01..RC-12)', () {
    test('RC-01: Negated poinGagal on passing photo stays sesuai with empty poinGagal', () {
      const rawJson =
          '{"status": "sesuai", "alasan": "Mesin barrier gate bersih.", "poinLolos": ["Mesin bersih"], "poinGagal": ["Tidak ada debu atau kotor"]}';

      final result = AiVisionService.parseAiJsonResponseForTest(
        rawJson,
        const ['Dudukan mesin bersih dan kokoh'],
        AiVisionConfig.defaultConfig(),
      );

      expect(result, isNotNull);
      expect(result!.status, equals(VerificationStatus.sesuai));
      expect(result.poinGagal, isEmpty);
    });

    test('RC-02: Placeholder "Tidak ada" / "-" / "none" / "n/a" in poinGagal is dropped', () {
      for (final placeholder in ['Tidak ada', '-', 'none', 'n/a', 'Bebas debu', 'No issue']) {
        final rawJson = jsonEncode({
          'status': 'sesuai',
          'alasan': 'Semua kriteria terpenuhi.',
          'poinLolos': ['Seragam rapi'],
          'poinGagal': [placeholder],
        });

        final result = AiVisionService.parseAiJsonResponseForTest(
          rawJson,
          const ['Seragam rapi'],
          AiVisionConfig.defaultConfig(),
        );

        expect(result, isNotNull, reason: 'placeholder=$placeholder');
        expect(
          result!.status,
          equals(VerificationStatus.sesuai),
          reason: 'placeholder=$placeholder should not force tidakSesuai',
        );
        expect(result.poinGagal, isEmpty, reason: 'placeholder=$placeholder');
      }
    });

    test('RC-03: poinGagal does not override perlu_cek_manual on glare/dark photo', () {
      const rawJson =
          '{"status": "perlu_cek_manual", "alasan": "Foto silau terkena lampu di sisi kiri.", "poinLolos": [], "poinGagal": ["Pencahayaan silau"]}';

      final result = AiVisionService.parseAiJsonResponseForTest(
        rawJson,
        const ['Dudukan mesin & baut dynabolt'],
        AiVisionConfig.defaultConfig(),
      );

      expect(result, isNotNull);
      expect(result!.status, equals(VerificationStatus.perluCekManual));
    });

    test('RC-04: rawStatus containing "tidak" inside passing status resolves to sesuai', () {
      const rawJson =
          '{"status": "sesuai (tidak ada masalah)", "alasan": "Kondisi palang normal.", "poinLolos": ["Palang normal"], "poinGagal": []}';

      final result = AiVisionService.parseAiJsonResponseForTest(
        rawJson,
        const ['Fisik palang tertutup lurus'],
        AiVisionConfig.defaultConfig(),
      );

      expect(result, isNotNull);
      expect(result!.status, equals(VerificationStatus.sesuai));
      expect(result.poinGagal, isEmpty);
    });

    test('RC-05: Free-text fallback with negated English quality keywords returns sesuai', () {
      const rawText =
          'The technician uniform is neat and visible. The photo is clear, not blurry, and not tilted.';

      final result = AiVisionService.parseAiJsonResponseForTest(
        rawText,
        const [
          'Seragam resmi BSS Parking rapi',
          'ID card terlihat jelas',
          'Sepatu kerja hitam',
        ],
        AiVisionConfig.defaultConfig(),
      );

      expect(result, isNotNull);
      expect(result!.status, equals(VerificationStatus.sesuai));
      expect(result.poinGagal, isEmpty);
    });

    test('RC-06: Free-text fallback on blurry Maintenance photo returns perluCekManual (not tidakSesuai)', () {
      const rawText =
          'Foto agak blur dan gelap pada area sudut kanan bawah CPU.';

      final result = AiVisionService.parseAiJsonResponseForTest(
        rawText,
        const ['Pembersihan debu CPU & heatsink'],
        AiVisionConfig.defaultConfig(),
        extraContext: 'Maintenance Server & Kasir',
      );

      expect(result, isNotNull);
      expect(result!.status, equals(VerificationStatus.perluCekManual));
    });

    test('RC-07: Truncated JSON (finish_reason: length) on passing response recovers sesuai', () {
      const truncatedJson =
          '{"status": "sesuai", "alasan": "Kondisi dudukan mesin barrier gate kokoh dan bersih", "poinLolos": ["Dudukan mesin kokoh';

      final result = AiVisionService.parseAiJsonResponseForTest(
        truncatedJson,
        const ['Dudukan mesin & baut dynabolt'],
        AiVisionConfig.defaultConfig(),
      );

      expect(result, isNotNull);
      expect(result!.status, equals(VerificationStatus.sesuai));
      expect(
        result.alasan,
        equals('Dudukan mesin barrier gate kokoh dan bersih'),
      );
    });

    test('RC-08: cleanTechnicianReason keeps short first sentence (>= 4 chars) like "Aman." or "Sesuai."', () {
      expect(
        AiVisionService.cleanTechnicianReason(
          'Aman. Namun bagian luar casing agak basah.',
        ),
        equals('Aman'),
      );
      expect(
        AiVisionService.cleanTechnicianReason(
          'Sesuai. Kabel tertata rapi.',
        ),
        equals('Sesuai'),
      );
    });

    test('RC-09: AI timeout/system error perluCekManual does not print as WA report ⚠️ finding', () {
      final submission = MaintenanceSubmission(
        id: 'sub_rc09',
        templateId: 'tpl_maint_barrier',
        templateName: 'Maintenance: Barrier Gate',
        userId: 'u1',
        userName: 'Ryan Lumasuge',
        userNpp: '12345',
        posId: 'pos_nbm',
        posName: 'NBM',
        cabangName: 'Manado',
        points: const [
          MaintenancePointResult(
            pointId: 'bar_1_01',
            label: 'Barrier Gate 1 - Dudukan Mesin & Baut Dynabolt',
            status: PointStatus.perluCekManual,
            alasan:
                'Koneksi ke AI gagal (timeout). Foto dialihkan untuk Cek Manual oleh Supervisor.',
          ),
        ],
        createdAt: DateTime(2026, 11, 7, 9, 0),
        updatedAt: DateTime(2026, 11, 7, 9, 10),
      );

      final report = WhatsAppReportService.generateReportText(
        submission: submission,
        category: TemplateCategory.maintBarrier,
        unitCount: 1,
      );

      expect(report, isNot(contains('Koneksi ke AI gagal')));
      expect(
        report,
        contains(
          '1. *dudukan mesin & baut dynabolt* :\n   ✅ dudukan mesin kokoh & baut dynabolt kencang',
        ),
      );
    });

    test('RC-10: Checklist bottom sheet detectAiIssues skips negated defects within 3 words', () {
      final issues = MaintenanceChecklistScreen.detectAiIssues(
        'Tidak ada karat atau bagian rusak, namun pencahayaan agak gelap di sudut kiri',
      );
      final labels = issues.map((e) => e.label).toList();

      expect(labels, equals(['Pencahayaan Kurang']));
    });

    test('RC-11: Manless printer label maps to Manless observation text, not Booth Parkir', () {
      final cleaned = WhatsAppReportService.cleanItemLabel(
        'Manless 1 - Pembersihan Total Printer Tiket',
      );
      final obs = WhatsAppReportService.defaultObservationForTheme(cleaned);

      expect(cleaned, equals('Pembersihan printer tiket'));
      expect(obs, equals('printer tiket manless bersih, mekanik lancar'));
      expect(obs, isNot(contains('printer booth')));
    });

    test('RC-12: generateAiVisionBase64 outputs 864px width from a 1080px input', () async {
      final srcImage = imglib.Image(width: 1080, height: 1440);
      imglib.fill(srcImage, color: imglib.ColorRgb8(40, 120, 200));
      final inputJpeg = Uint8List.fromList(
        imglib.encodeJpg(srcImage, quality: 90),
      );

      final b64 = await ImageWatermarkProcessor.generateAiVisionBase64(
        '',
        inputJpeg,
      );

      expect(b64, isNotNull);
      final decodedBytes = base64Decode(b64!);
      final outImage = imglib.decodeImage(decodedBytes);
      expect(outImage, isNotNull);
      expect(outImage!.width, equals(864));
      expect(outImage.height, equals(1152));
    });
  });
}
