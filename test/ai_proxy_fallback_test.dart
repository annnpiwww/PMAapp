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

/// Regresi: di browser, request ke proxy AI yang belum di-deploy gagal di
/// preflight CORS (exception, bukan response 404). Dulu exception itu dianggap
/// kegagalan jaringan biasa sehingga verifikasi berakhir "Koneksi ke AI gagal".
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
    apiKey: 'test-key',
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

  test('proxy gagal (exception CORS) -> fallback ke endpoint AI langsung',
      () async {
    final urls = <String>[];
    AiVisionService.clientFactory = () => MockClient((request) async {
          urls.add(request.url.toString());
          if (request.url.path.contains('/functions/v1/ai-vision')) {
            throw http.ClientException('preflight CORS blocked');
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
    expect(urls.first, contains('/functions/v1/ai-vision'));
    expect(urls.last, contains('generativelanguage.googleapis.com'));
  });

  test('proxy balas 404 -> fallback ke endpoint AI langsung', () async {
    final urls = <String>[];
    AiVisionService.clientFactory = () => MockClient((request) async {
          urls.add(request.url.toString());
          if (request.url.path.contains('/functions/v1/ai-vision')) {
            return http.Response('{"code":"NOT_FOUND"}', 404);
          }
          return okResponse();
        });

    final result = await AiVisionService.verifySubmissionWithAI(
      template: template,
      imageBase64: 'data:image/jpeg;base64,AAAA',
      customConfig: config,
    );

    expect(result.status, VerificationStatus.sesuai);
    expect(urls.last, contains('generativelanguage.googleapis.com'));
  });

  test('proxy hanya dicoba sekali per sesi (foto berikutnya langsung direct)',
      () async {
    final proxyHits = <String>[];
    AiVisionService.clientFactory = () => MockClient((request) async {
          if (request.url.path.contains('/functions/v1/ai-vision')) {
            proxyHits.add(request.url.toString());
            throw http.ClientException('preflight CORS blocked');
          }
          return okResponse();
        });

    for (var i = 0; i < 3; i++) {
      final result = await AiVisionService.verifySubmissionWithAI(
        template: template,
        imageBase64: 'data:image/jpeg;base64,AAAA',
        customConfig: config,
      );
      expect(result.status, VerificationStatus.sesuai);
    }

    expect(proxyHits.length, 1);
  });

  test('HTTP 503 (model high demand) -> retry otomatis lalu sukses', () async {
    final directHits = <String>[];
    AiVisionService.clientFactory = () => MockClient((request) async {
          if (request.url.path.contains('/functions/v1/ai-vision')) {
            return http.Response('{"code":"NOT_FOUND"}', 404);
          }
          directHits.add(request.url.toString());
          if (directHits.length == 1) {
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
    expect(directHits.length, 2);
  });

  test('semua attempt gagal 503 -> alasan memuat kode penyebab', () async {
    AiVisionService.clientFactory = () => MockClient((request) async {
          if (request.url.path.contains('/functions/v1/ai-vision')) {
            return http.Response('{"code":"NOT_FOUND"}', 404);
          }
          return http.Response('{"error":{"code":503}}', 503);
        });

    final result = await AiVisionService.verifySubmissionWithAI(
      template: template,
      imageBase64: 'data:image/jpeg;base64,AAAA',
      customConfig: config,
    );

    expect(result.isFallback, isTrue);
    expect(result.alasan, contains('HTTP 503'));
  });
}
