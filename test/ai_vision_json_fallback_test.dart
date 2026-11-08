import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bssparking_timemark/data/models/ai_vision_config.dart';
import 'package:bssparking_timemark/data/models/submission_model.dart';
import 'package:bssparking_timemark/data/models/template_model.dart';
import 'package:bssparking_timemark/data/services/ai_vision_service.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final template = TemplateModel(
    id: 'tpl_absen_test',
    nama: 'Absensi Masuk SOP',
    deskripsi: 'Inspeksi seragam',
    jenis: TemplateCategory.absensi,
    wajibLokasi: true,
    sopCriteria: const ['Seragam rapi', 'ID Card terpasang'],
    contohFotoDescriptions: const [],
    createdBy: 'Tester',
    updatedAt: DateTime(2026, 11, 8),
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    AiVisionService.clearConfigCache();
    AiVisionService.resetProxyState();
  });

  tearDown(() {
    AiVisionService.clientFactory = http.Client.new;
    AiVisionService.clearConfigCache();
  });

  group('AI Vision JSON Fallback and Failover Tests (Task t20261108-131933-5dd6)', () {
    test('(a) first response finish_reason length fails over to second model returning valid JSON', () async {
      int requestCount = 0;
      final requestedModels = <String>[];

      AiVisionService.clientFactory = () => MockClient((req) async {
            requestCount++;
            final body = jsonDecode(req.body) as Map<String, dynamic>;
            requestedModels.add(body['model'] as String);

            if (requestCount == 1) {
              // 1st attempt: finish_reason length with truncated JSON
              return http.Response(
                jsonEncode({
                  'choices': [
                    {
                      'finish_reason': 'length',
                      'message': {
                        'content': '```json\n{\n  "status": "ses',
                      },
                    }
                  ]
                }),
                200,
                headers: {'content-type': 'application/json'},
              );
            } else {
              // 2nd attempt: valid JSON from next model
              return http.Response(
                jsonEncode({
                  'choices': [
                    {
                      'finish_reason': 'stop',
                      'message': {
                        'content': jsonEncode({
                          'status': 'sesuai',
                          'alasan': 'Seragam rapi dan lengkap.',
                          'confidenceScore': 95,
                        }),
                      },
                    }
                  ]
                }),
                200,
                headers: {'content-type': 'application/json'},
              );
            }
          });

      final res = await AiVisionService.verifyPhoto(
        template: template,
        imageBase64: 'AAAA',
      );

      expect(requestCount, equals(2));
      expect(res.status, equals(VerificationStatus.sesuai));
      expect(res.alasan, equals('Seragam rapi dan lengkap'));
      expect(requestedModels.length, equals(2));
      expect(requestedModels[0], isNot(equals(requestedModels[1])));
    });

    test('(b) content with opening fence without closing fence parses as sesuai with alasan Rapi', () {
      const raw = '```json{"status":"sesuai","alasan":"Rapi"}';
      final res = AiVisionService.parseAiJsonResponseForTest(
        raw,
        const ['Seragam rapi'],
        const AiVisionConfig(),
      );

      expect(res, isNotNull);
      expect(res!.status, equals(VerificationStatus.sesuai));
      expect(res.alasan, equals('Rapi'));
    });

    test('(c) all attempts return unparseable text -> perluCekManual and alasan never leaks raw JSON', () async {
      int requestCount = 0;

      AiVisionService.clientFactory = () => MockClient((req) async {
            requestCount++;
            return http.Response(
              jsonEncode({
                'choices': [
                  {
                    'finish_reason': 'stop',
                    'message': {
                      'content': '```json{ status',
                    },
                  }
                ]
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          });

      final res = await AiVisionService.verifyPhoto(
        template: template,
        imageBase64: 'AAAA',
      );

      expect(requestCount, equals(3));
      expect(res.status, equals(VerificationStatus.perluCekManual));
      expect(res.alasan.contains('```'), isFalse);
      expect(res.alasan.contains('{'), isFalse);
      expect(res.alasan.contains('json'), isFalse);
      expect(res.alasan.contains('Respons:'), isFalse);
      expect(
        res.alasan.startsWith(AiVisionService.kErrorUnverifiablePhoto),
        isTrue,
      );
    });

    test('(d) AiVisionConfig default and fromJson({}) maxTokens == 800', () {
      const cfgDefault = AiVisionConfig();
      expect(cfgDefault.maxTokens, equals(800));

      final cfgFactory = AiVisionConfig.defaultConfig();
      expect(cfgFactory.maxTokens, equals(800));

      final cfgFromJson = AiVisionConfig.fromJson({});
      expect(cfgFromJson.maxTokens, equals(800));
    });

    test('StorageService migrates persisted config with maxTokens < 800 to 800', () async {
      // Save raw config with maxTokens = 350
      final oldConfig = const AiVisionConfig(
        baseUrl: AiVisionConfig.defaultCustomUrl,
        apiKey: 'custom_key_xyz',
        modelName: AiVisionConfig.defaultCustomModel,
        timeoutSeconds: 25,
      ).copyWith(maxTokens: 350);

      await StorageService.saveAiVisionConfig(oldConfig);

      AiVisionService.clearConfigCache();
      final loaded = StorageService.getAiVisionConfig();
      expect(loaded.maxTokens, equals(800));
      expect(loaded.baseUrl, equals(AiVisionConfig.defaultCustomUrl));
      expect(loaded.apiKey, equals('custom_key_xyz'));
    });
  });
}
