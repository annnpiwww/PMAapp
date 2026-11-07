import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bssparking_timemark/data/models/ai_vision_config.dart';
import 'package:bssparking_timemark/data/models/submission_model.dart';
import 'package:bssparking_timemark/data/models/template_model.dart';
import 'package:bssparking_timemark/data/models/user_model.dart';
import 'package:bssparking_timemark/data/repositories/auth_repository.dart';
import 'package:bssparking_timemark/data/services/ai_vision_service.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final template = TemplateModel(
    id: 'tpl_absen_1',
    nama: 'Grooming Pagi',
    deskripsi: 'Inspeksi grooming pagi',
    jenis: TemplateCategory.absensi,
    wajibLokasi: true,
    sopCriteria: const ['Seragam resmi BSS Parking rapi'],
    contohFotoDescriptions: const [],
    createdBy: 'Tester',
    updatedAt: DateTime(2026, 11, 7),
  );

  const validSessionToken =
      'v1.eyJ1aWQiOiJ1c3JfdGVrXzEiLCJyb2xlIjoidGVjaG5pY2lhbiIsImV4cCI6NDEwMjQ0NDgwMH0.sig';

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    await AuthRepository.instance.logout();
    AiVisionService.resetProxyState();
  });

  tearDown(() {
    AiVisionService.clientFactory = http.Client.new;
    AuthRepository.instance.setSessionTokenForTesting(null);
  });

  group('AiVisionService Proxy Session Client Tests (SEC-03)', () {
    test('sends x-app-session header to proxy and never calls direct Gemini URL even if proxy fails', () async {
      AuthRepository.instance.setSessionTokenForTesting(validSessionToken);

      final calledUrls = <String>[];
      final sessionHeaders = <String?>[];

      AiVisionService.clientFactory = () => MockClient((req) async {
            calledUrls.add(req.url.toString());
            sessionHeaders.add(req.headers['x-app-session']);
            return http.Response('{"error":"ai unavailable"}', 502);
          });

      final res = await AiVisionService.verifySubmissionWithAI(
        template: template,
        imageBase64: 'data:image/jpeg;base64,AAAA',
        customConfig: const AiVisionConfig(
          provider: AiProviderType.customEndpoint,
          apiKey: 'even-if-a-key-is-passed-never-call-direct',
        ),
      );

      expect(res.status, equals(VerificationStatus.perluCekManual));
      expect(res.isFallback, isTrue);
      expect(calledUrls, isNotEmpty);
      expect(calledUrls.every((u) => u.contains('/functions/v1/ai-vision')), isTrue);
      expect(calledUrls.any((u) => u.contains('generativelanguage.googleapis.com')), isFalse);
      expect(sessionHeaders.every((h) => h == validSessionToken), isTrue);
    });

    testWidgets('401 from ai-vision proxy logs out immediately without retrying and shows session expired snackbar', (tester) async {
      final user = UserModel(
        id: 'usr_tek_1',
        nama: 'Ryan Lumasuge',
        npp: 'BSS-TEK-01',
        email: 'ryan@pma.com',
        role: UserRole.petugas,
        posId: 'POS-01',
        posName: 'Pos Gate Utama',
        cabangName: 'KC BSG',
      );
      await StorageService.saveUser(user);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AuthRepository.sessionTokenPrefsKey, validSessionToken);
      await AuthRepository.instance.init();

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: AuthRepository.navigatorKey,
          scaffoldMessengerKey: AuthRepository.scaffoldMessengerKey,
          home: const Scaffold(body: Text('Camera Screen')),
        ),
      );

      var attempts = 0;
      AiVisionService.clientFactory = () => MockClient((_) async {
            attempts++;
            return http.Response('{"error":"unauthorized"}', 401);
          });

      final res = await AiVisionService.verifySubmissionWithAI(
        template: template,
        imageBase64: 'data:image/jpeg;base64,AAAA',
      );

      await tester.pumpAndSettle();

      expect(attempts, equals(1));
      expect(res.status, equals(VerificationStatus.perluCekManual));
      expect(AuthRepository.instance.isLoggedIn, isFalse);
      expect(AuthRepository.instance.sessionToken, isNull);
      expect(find.text('Sesi habis, silakan login ulang.'), findsOneWidget);
    });
  });
}
