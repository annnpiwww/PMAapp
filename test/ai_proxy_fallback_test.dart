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

/// Proxy-only AI verification tests: proxy failures route to manual review and
/// never call generativelanguage.googleapis.com directly (SEC-03).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final template = TemplateModel(
    id: 't1',
    nama: 'Grooming Pagi',
    deskripsi: 'Inspeksi grooming pagi',
    jenis: TemplateCategory.absensi,
    wajibLokasi: true,
    sopCriteria: const ['Seragam resmi BSS Parking rapi'],
    contohFotoDescriptions: const [],
    createdBy: 'Tester',
    updatedAt: DateTime(2026, 10, 22),
  );

  const config = AiVisionConfig(
    provider: AiProviderType.customEndpoint,
    apiKey: '',
  );

  http.Response okResponse() => http.Response(
    jsonEncode({
      'choices': [
        {
          'message': {
            'content': jsonEncode({
              'status': 'sesuai',
              'confidenceScore': 95,
              'alasan': 'Seragam rapi dan ID card terpasang',
              'poinLolos': ['Seragam rapi'],
              'poinGagal': <String>[],
            }),
          },
        },
      ],
    }),
    200,
    headers: {'content-type': 'application/json'},
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    AiVisionService.resetProxyState();
  });

  tearDown(() {
    AiVisionService.clientFactory = http.Client.new;
    AiVisionService.resetProxyState();
  });

  test('proxy gagal (exception jaringan/CORS) -> manual review tanpa direct Gemini',
      () async {
    final urls = <String>[];
    AiVisionService.clientFactory = () => MockClient((request) async {
          urls.add(request.url.toString());
          throw http.ClientException('preflight CORS blocked');
        });

    final result = await AiVisionService.verifySubmissionWithAI(
      template: template,
      imageBase64: 'data:image/jpeg;base64,AAAA',
      customConfig: config,
    );

    expect(result.isFallback, isTrue);
    expect(result.status, VerificationStatus.perluCekManual);
    expect(urls, isNotEmpty);
    expect(
      urls.every(
        (u) =>
            u.contains('/functions/v1/ai-vision') &&
            !u.contains('generativelanguage.googleapis.com'),
      ),
      isTrue,
    );
  });

  test('proxy balas 404 -> manual review tanpa direct Gemini', () async {
    final urls = <String>[];
    AiVisionService.clientFactory = () => MockClient((request) async {
          urls.add(request.url.toString());
          return http.Response('{"code":"NOT_FOUND"}', 404);
        });

    final result = await AiVisionService.verifySubmissionWithAI(
      template: template,
      imageBase64: 'data:image/jpeg;base64,AAAA',
      customConfig: config,
    );

    expect(result.isFallback, isTrue);
    expect(result.status, VerificationStatus.perluCekManual);
    expect(result.alasan, contains('HTTP 404'));
    expect(
      urls.every(
        (u) =>
            u.contains('/functions/v1/ai-vision') &&
            !u.contains('generativelanguage.googleapis.com'),
      ),
      isTrue,
    );
  });

  test('HTTP 503 (model high demand) -> retry otomatis di proxy lalu sukses',
      () async {
    final proxyHits = <String>[];
    AiVisionService.clientFactory = () => MockClient((request) async {
          proxyHits.add(request.url.toString());
          if (proxyHits.length == 1) {
            return http.Response(
              '{"error":{"code":503,"message":"high demand"}}',
              503,
            );
          }
          return okResponse();
        });

    final result = await AiVisionService.verifySubmissionWithAI(
      template: template,
      imageBase64: 'data:image/jpeg;base64,AAAA',
      customConfig: config,
    );

    expect(result.status, VerificationStatus.sesuai);
    expect(result.isFallback, isFalse);
    expect(proxyHits.length, 2);
    expect(
      proxyHits.every(
        (u) =>
            u.contains('/functions/v1/ai-vision') &&
            !u.contains('generativelanguage.googleapis.com'),
      ),
      isTrue,
    );
  });

  test('semua attempt gagal 503 -> alasan memuat kode penyebab', () async {
    final urls = <String>[];
    AiVisionService.clientFactory = () => MockClient((request) async {
          urls.add(request.url.toString());
          return http.Response('{"error":{"code":503}}', 503);
        });

    final result = await AiVisionService.verifySubmissionWithAI(
      template: template,
      imageBase64: 'data:image/jpeg;base64,AAAA',
      customConfig: config,
    );

    expect(result.isFallback, isTrue);
    expect(result.status, VerificationStatus.perluCekManual);
    expect(result.alasan, contains('HTTP 503'));
    expect(
      urls.every(
        (u) =>
            u.contains('/functions/v1/ai-vision') &&
            !u.contains('generativelanguage.googleapis.com'),
      ),
      isTrue,
    );
  });

  test('tanpa user API key (default kosong), tetap pakai proxy dan failover antar model tanpa callDirect',
      () async {
    final requestedModels = <String>[];
    final requestedUrls = <String>[];
    AiVisionService.clientFactory = () => MockClient((request) async {
          requestedUrls.add(request.url.toString());
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          requestedModels.add(body['model'] as String);
          if (requestedModels.length == 1) {
            return http.Response('{"error":{"code":503}}', 503);
          }
          return okResponse();
        });

    final result = await AiVisionService.verifySubmissionWithAI(
      template: template,
      imageBase64: 'data:image/jpeg;base64,AAAA',
      customConfig: const AiVisionConfig(
        provider: AiProviderType.customEndpoint,
        apiKey: '',
      ),
    );

    expect(result.status, VerificationStatus.sesuai);
    expect(requestedUrls.length, 2);
    expect(
      requestedUrls.every((u) => u.contains('/functions/v1/ai-vision')),
      isTrue,
    );
    expect(requestedModels.first, equals(AiVisionConfig.defaultCustomModel));
    expect(requestedModels.last, equals('gemini-3.5-flash-lite'));
  });

  test('migrasi StorageService membersihkan key bawaan lama 53 karakter AQ. menjadi kosong',
      () async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    final oldEmbeddedLikeKey = 'AQ.${'X' * 50}';
    expect(oldEmbeddedLikeKey.length, 53);

    await StorageService.saveAiVisionConfig(
      AiVisionConfig(
        provider: AiProviderType.customEndpoint,
        apiKey: oldEmbeddedLikeKey,
      ),
    );

    AiVisionService.clearConfigCache();
    final migrated = AiVisionService.getConfig();
    expect(migrated.apiKey, isEmpty);
  });
}
