import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bssparking_timemark/data/models/ai_vision_config.dart';
import 'package:bssparking_timemark/data/models/template_model.dart';
import 'package:bssparking_timemark/data/models/submission_model.dart';
import 'package:bssparking_timemark/data/services/ai_vision_service.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';
import 'package:bssparking_timemark/features/settings/screens/ai_vision_settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  group('AiVisionConfig Model Serialization Tests', () {
    test('Default configuration values', () {
      final config = AiVisionConfig.defaultConfig();
      expect(config.provider, equals(AiProviderType.customEndpoint));
      expect(config.confidenceThreshold, equals(0.85));
      expect(config.fallbackBehavior, equals(FallbackBehavior.fallbackToOnDevice));
      expect(config.enableGroomingCheck, isTrue);
      expect(config.enableIdCardDetection, isTrue);
      expect(config.enableFormationCheck, isTrue);
      expect(config.enableCleanlinessCheck, isTrue);
      expect(config.modelName, equals('gemini-3.1-flash-lite'));
      expect(config.baseUrl,
          equals('https://generativelanguage.googleapis.com/v1beta/openai'));
      // API key tidak boleh hardcoded di source: default = compile-time env
      // (kosong saat test tanpa --dart-define, terisi saat build release).
      expect(
        config.apiKey,
        equals(AiVisionConfig.defaultApiKey),
      );
    });

    test('Serialization and Deserialization', () {
      const config = AiVisionConfig(
        provider: AiProviderType.geminiVision,
        apiKey: 'test-api-key-123',
        baseUrl: 'https://custom-proxy.bss.co.id/v1',
        modelName: 'gemini-1.5-flash',
        confidenceThreshold: 0.90,
        timeoutSeconds: 15,
        fallbackBehavior: FallbackBehavior.bypassToManualReview,
        enableGroomingCheck: true,
        enableIdCardDetection: false,
        enableFormationCheck: false,
        enableCleanlinessCheck: true,
      );

      final jsonStr = config.serialize();
      final restored = AiVisionConfig.deserialize(jsonStr);

      expect(restored.provider, equals(AiProviderType.geminiVision));
      expect(restored.apiKey, equals('test-api-key-123'));
      expect(restored.baseUrl, equals('https://custom-proxy.bss.co.id/v1'));
      expect(restored.modelName, equals('gemini-1.5-flash'));
      expect(restored.confidenceThreshold, equals(0.90));
      expect(restored.timeoutSeconds, equals(15));
      expect(restored.fallbackBehavior, equals(FallbackBehavior.bypassToManualReview));
      expect(restored.enableGroomingCheck, isTrue);
      expect(restored.enableIdCardDetection, isFalse);
      expect(restored.enableFormationCheck, isFalse);
      expect(restored.enableCleanlinessCheck, isTrue);
    });
  });

  group('AiVisionService Tests', () {
    test('Config persistence in StorageService', () async {
      const newConfig = AiVisionConfig(
        provider: AiProviderType.customEndpoint,
        apiKey: 'sk-test-bss-proxmox',
        baseUrl: 'https://generativelanguage.googleapis.com/v1beta/openai',
        modelName: 'gemini-3.1-flash-lite',
        confidenceThreshold: 0.88,
      );

      await AiVisionService.updateConfig(newConfig);
      final retrieved = AiVisionService.getConfig();

      expect(retrieved.confidenceThreshold, equals(0.88));
      expect(retrieved.apiKey, equals('sk-test-bss-proxmox'));
      expect(retrieved.modelName, equals('gemini-3.1-flash-lite'));
      expect(retrieved.baseUrl,
          equals('https://generativelanguage.googleapis.com/v1beta/openai'));
    });

    test('Auto-migration from legacy endpoints to Google Gemini Cloud AI', () async {
      // Simulate old saved config
      SharedPreferences.setMockInitialValues({});
      await StorageService.init();
      const legacyConfig = AiVisionConfig(
        provider: AiProviderType.customEndpoint,
        apiKey: 'sk-old-tunnel',
        baseUrl: 'https://pizza-namespace-brings-desert.trycloudflare.com/v1',
        modelName: 'gemini-3.7-flash-high',
        timeoutSeconds: 15,
        maxTokens: 400,
      );
      await StorageService.saveAiVisionConfig(legacyConfig);

      // Re-read should trigger migration
      AiVisionService.clearConfigCache();
      final migrated = AiVisionService.getConfig();

      expect(migrated.baseUrl,
          equals('https://generativelanguage.googleapis.com/v1beta/openai'));
      expect(migrated.modelName, equals('gemini-3.1-flash-lite'));
      expect(migrated.apiKey, equals(AiVisionConfig.defaultApiKey));
    });

    test('Valid Google AI Studio custom key is preserved during migration', () async {
      SharedPreferences.setMockInitialValues({});
      await StorageService.init();
      const customGaiConfig = AiVisionConfig(
        provider: AiProviderType.customEndpoint,
        apiKey: 'AQ.custom-valid-key-999',
        baseUrl: 'https://pizza-namespace-brings-desert.trycloudflare.com/v1',
        modelName: 'gemini-3.7-flash-high',
      );
      await StorageService.saveAiVisionConfig(customGaiConfig);

      AiVisionService.clearConfigCache();
      final migrated = AiVisionService.getConfig();

      expect(migrated.baseUrl,
          equals('https://generativelanguage.googleapis.com/v1beta/openai'));
      expect(migrated.apiKey, equals('AQ.custom-valid-key-999'));
    });

    test('Criteria filtering based on active toggles', () {
      final rawCriteria = [
        'Seragam resmi BSS Parking bersih dan rapi',
        'ID Card / Name Tag terpasang jelas di saku',
        'Personel shift berbaris rapi dan berbanjar',
        'Area pos / booth bersih bebas sampah',
      ];

      // Disable grooming check
      final configWithoutGrooming = AiVisionConfig.defaultConfig().copyWith(
        enableGroomingCheck: false,
      );
      final filtered = AiVisionService.filterCriteriaByConfig(
          rawCriteria, configWithoutGrooming);
      expect(filtered.length, equals(3));
      expect(filtered.any((c) => c.contains('Seragam')), isFalse);
      expect(filtered.any((c) => c.contains('ID Card')), isTrue);
    });

    test('Verification test for template', () async {
      final template = TemplateModel(
        id: 't1',
        nama: 'Grooming Pagi',
        deskripsi: 'Inspeksi grooming pagi',
        jenis: TemplateCategory.absensi,
        wajibLokasi: true,
        sopCriteria: [
          'Seragam resmi BSS Parking rapi',
          'ID Card terpasang di saku',
        ],
        contohFotoDescriptions: [],
        createdBy: 'Tester',
        updatedAt: DateTime.now(),
      );

      final result = await AiVisionService.verifySubmissionWithAI(
        template: template,
        imageBase64: '',
        customConfig: const AiVisionConfig(
          provider: AiProviderType.onDeviceMock,
        ),
      );

      // Dark/empty image must fail on device mock
      expect(result.status, equals(VerificationStatus.tidakSesuai));
      expect(result.isSesuai, isFalse);
      expect(result.poinGagal.isNotEmpty, isTrue);
    });

    test('Absensi pulang teknisi accepts half-body and lanyard without shoes', () async {
      const mockRawResponse = '''
{
  "status": "sesuai",
  "confidenceScore": 95,
  "alasan": "Foto setengah badan rapi, seragam dinas teknisi sesuai dan tali lanyard ID Card terpasang jelas di dada.",
  "poinLolos": ["Seragam dinas teknisi rapi", "Tali lanyard ID Card terpasang"],
  "poinGagal": []
}
''';

      final parsed = AiVisionService.parseAiJsonResponseForTest(
        mockRawResponse,
        [
          'seragam dinas teknisi rapi',
          'id card / name tag terpasang jelas',
        ],
        AiVisionConfig.defaultConfig(),
      );

      expect(parsed, isNotNull);
      expect(parsed!.status, equals(VerificationStatus.sesuai));
      expect(parsed.isSesuai, isTrue);
      expect(parsed.poinGagal, isEmpty);
      expect(parsed.alasan, contains('setengah badan'));
    });

    test('Gemini LLM failure JSON parsing test', () {
      const mockRawLlmResponse = '''
```json
{
  "status": "tidak_sesuai",
  "confidenceScore": 92,
  "alasan": "Petugas tidak mengenakan seragam BSS dan ID Card tidak terpasang.",
  "poinLolos": ["Sepatu dinas pantofel hitam bersih"],
  "poinGagal": [
    "seragam resmi bss parking bersih, rapi dan terkancing",
    "id card / name tag terpasang jelas di saku kiri"
  ]
}
```
''';

      final parsed = AiVisionService.parseAiJsonResponseForTest(
        mockRawLlmResponse,
        [
          'seragam resmi bss parking bersih, rapi dan terkancing',
          'id card / name tag terpasang jelas di saku kiri',
          'sepatu dinas pantofel / pdl hitam bersih',
        ],
        AiVisionConfig.defaultConfig(),
      );

      expect(parsed, isNotNull);
      expect(parsed!.status, equals(VerificationStatus.tidakSesuai));
      expect(parsed.isSesuai, isFalse);
      expect(parsed.confidenceScore, equals(0.92));
      expect(parsed.poinGagal.length, equals(2));
      expect(
          parsed.poinGagal.first,
          equals(
              'Tidak menggunakan seragam resmi BSS Parking / seragam tidak rapi dan tidak terkancing'));
      expect(parsed.poinLolos.length, equals(1));
    });

    test('Free-text fallback: motion-blur -> perlu_cek_manual', () {
      // Simulates a model that ignored response_format: json_object and
      // returned a free-text description instead of JSON.
      const freeText = '''
The image is severely motion-blurred and out of focus, showing only an
indistinct outline of a person's head and face against a green wall and
a dark ceiling. The heavy blur and vertical light streaks completely
obscure all details, leaving no visible uniform, identification badge,
equipment, or readable text.''';

      final parsed = AiVisionService.parseAiJsonResponseForTest(
        freeText,
        [
          'seragam resmi bss parking bersih, rapi dan terkancing',
          'id card / name tag terpasang jelas di saku kiri',
          'sepatu dinas pantofel / pdl hitam bersih',
        ],
        AiVisionConfig.defaultConfig(),
      );

      expect(parsed, isNotNull);
      expect(parsed!.status, equals(VerificationStatus.perluCekManual));
      expect(parsed.isFallback, isTrue);
      expect(parsed.poinGagal, isEmpty);
      expect(parsed.poinLolos, isEmpty);
      // Reason should include the original text
      expect(parsed.alasan, contains('tidak dapat diverifikasi'));
    });

    test('Free-text fallback: full body + uniform detected -> sesuai', () {
      const freeText = '''
The image shows a full body view of a BSS Parking officer wearing a
clean official uniform, complete with name tag and black shoes.
The officer is standing upright in proper posture.''';

      final parsed = AiVisionService.parseAiJsonResponseForTest(
        freeText,
        [
          'seragam resmi bss parking bersih, rapi dan terkancing',
          'id card / name tag terpasang jelas di saku kiri',
          'sepatu dinas pantofel / pdl hitam bersih',
        ],
        AiVisionConfig.defaultConfig(),
      );

      expect(parsed, isNotNull);
      expect(parsed!.status, equals(VerificationStatus.sesuai));
      expect(parsed.isFallback, isTrue);
      expect(parsed.poinLolos.length, greaterThan(0));
    });

    test('Free-text fallback: ambiguous -> conservatively perlu_cek_manual', () {
      const freeText = 'There is a person in the image but details unclear.';

      final parsed = AiVisionService.parseAiJsonResponseForTest(
        freeText,
        [
          'seragam resmi bss parking bersih, rapi dan terkancing',
        ],
        AiVisionConfig.defaultConfig(),
      );

      expect(parsed, isNotNull);
      // Ambiguous + no unverifiable keyword + no positive match -> fallback
      expect(parsed!.status, equals(VerificationStatus.perluCekManual));
      expect(parsed.isFallback, isTrue);
    });
  });

  group('AiVisionSettingsScreen Widget Tests', () {
    testWidgets('Renders all sections correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AiVisionSettingsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pengaturan AI Vision'), findsOneWidget);
      expect(find.text('Provider & Endpoint AI Vision'), findsOneWidget);
      expect(find.text('Uji Latensi & Konektivitas'), findsOneWidget);
      expect(find.text('Fitur Pemeriksaan SOP AI'), findsOneWidget);
      expect(find.text('Deteksi Kerapian Seragam & Grooming'), findsOneWidget);
      expect(find.text('Deteksi ID Card / Name Tag'), findsOneWidget);
      expect(find.text('Uji Koneksi AI'), findsOneWidget);
      expect(find.text('Gemini 3.1 Flash Lite'), findsOneWidget);
    });
  });
}
