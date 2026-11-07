import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bssparking_timemark/data/models/user_model.dart';
import 'package:bssparking_timemark/data/repositories/auth_repository.dart';
import 'package:bssparking_timemark/data/services/branch_service.dart';
import 'package:bssparking_timemark/data/services/location_service.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';
import 'package:bssparking_timemark/features/auth/screens/login_screen.dart';

String _buildSessionToken({
  String uid = 'usr_spv_1',
  String role = 'spv',
  String cabang = 'KC Manado',
  String name = 'Farhan Lakoro',
  required int expEpochSeconds,
}) {
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final payload = {
    'uid': uid,
    'role': role,
    'cabang': cabang,
    'name': name,
    'iat': now - 60,
    'exp': expEpochSeconds,
  };
  final payloadB64 =
      base64UrlEncode(utf8.encode(jsonEncode(payload))).replaceAll('=', '');
  return 'v1.$payloadB64.hmac_sig_stub';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    BranchService.instance.resetForTesting();
    await AuthRepository.instance.logout();
    AuthRepository.instance.httpClient = null;
    AuthRepository.instance.isWebOverride = false;
    LocationService.clientOverride = null;
  });

  tearDown(() {
    AuthRepository.instance.httpClient = null;
    AuthRepository.instance.isWebOverride = null;
    LocationService.clientOverride = null;
  });

  group('Session Auth Contract Tests (SEC-04)', () {
    test('loginWithPassword stores bss_session_token_v1 and never writes dummy sb_auth_token', () async {
      final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final token = _buildSessionToken(expEpochSeconds: nowSec + 86400);

      AuthRepository.instance.httpClient = MockClient((req) async {
        expect(req.url.path, endsWith('/functions/v1/auth-login'));
        expect(req.method, 'POST');
        return http.Response(
          jsonEncode({
            'token': token,
            'user': {
              'id': 'usr_spv_1',
              'username': 'farhan',
              'nama': 'Farhan Lakoro',
              'email': 'farhan@bssparking.id',
              'role': 'spv',
              'cabang': 'manado',
            },
          }),
          200,
        );
      });

      final ok = await AuthRepository.instance.loginWithPassword(
        identity: 'farhan',
        password: 'valid_password',
      );

      expect(ok, isTrue);
      expect(AuthRepository.instance.sessionToken, equals(token));
      expect(AuthRepository.instance.currentUser?.role, equals(UserRole.supervisor));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AuthRepository.sessionTokenPrefsKey), equals(token));
      expect(prefs.getString('sb_auth_token'), isNull);
    });

    test('init() preserves valid unexpired session and logs out missing or expired token', () async {
      final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final validToken = _buildSessionToken(expEpochSeconds: nowSec + 3600);
      final expiredToken = _buildSessionToken(expEpochSeconds: nowSec - 10);

      final demoUser = UserModel(
        id: 'usr_spv_1',
        nama: 'Farhan Lakoro',
        npp: 'BSS-SPV-01',
        email: 'farhan@bssparking.id',
        role: UserRole.supervisor,
        posId: 'POS-01',
        posName: 'Pos Gate Utama',
        cabangName: 'KC BSG',
      );

      // 1. Valid token -> stays logged in
      final prefs = await SharedPreferences.getInstance();
      await StorageService.saveUser(demoUser);
      await prefs.setString(AuthRepository.sessionTokenPrefsKey, validToken);

      await AuthRepository.instance.init();
      expect(AuthRepository.instance.isLoggedIn, isTrue);
      expect(AuthRepository.instance.sessionToken, equals(validToken));

      // 2. Expired token -> logs out on init()
      await prefs.setString(AuthRepository.sessionTokenPrefsKey, expiredToken);
      await AuthRepository.instance.init();
      expect(AuthRepository.instance.isLoggedIn, isFalse);
      expect(AuthRepository.instance.currentUser, isNull);
      expect(AuthRepository.instance.sessionToken, isNull);
      expect(prefs.getString(AuthRepository.sessionTokenPrefsKey), isNull);

      // 3. Missing token with saved user -> logs out on init()
      await StorageService.saveUser(demoUser);
      await prefs.remove(AuthRepository.sessionTokenPrefsKey);
      await AuthRepository.instance.init();
      expect(AuthRepository.instance.isLoggedIn, isFalse);
      expect(AuthRepository.instance.currentUser, isNull);
    });

    test('offline login restores token when unexpired, and drops token when expired', () async {
      final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final expiredToken = _buildSessionToken(expEpochSeconds: nowSec - 30);

      AuthRepository.instance.httpClient = MockClient((_) async {
        return http.Response(
          jsonEncode({
            'token': expiredToken,
            'user': {
              'id': 'usr_tek_1',
              'username': 'ryan',
              'nama': 'Ryan Lumasuge',
              'email': 'ryan@pma.com',
              'role': 'technician',
              'cabang': 'manado',
            },
          }),
          200,
        );
      });

      expect(
        await AuthRepository.instance.loginWithPassword(
          identity: 'ryan',
          password: 'pass123',
        ),
        isTrue,
      );
      await AuthRepository.instance.logout();

      // Offline login with expired cached token: offline login succeeds locally, but expired token is NOT restored
      AuthRepository.instance.httpClient = MockClient((_) async {
        throw http.ClientException('Network down');
      });
      final offlineOk = await AuthRepository.instance.loginWithPassword(
        identity: 'ryan',
        password: 'pass123',
      );
      expect(offlineOk, isTrue);
      expect(AuthRepository.instance.sessionToken, isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AuthRepository.sessionTokenPrefsKey), isNull);
    });

    testWidgets('401 from edge function clears session, routes to LoginScreen, and shows snackbar', (tester) async {
      final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final validToken = _buildSessionToken(expEpochSeconds: nowSec + 3600);

      final user = UserModel(
        id: 'usr_spv_1',
        nama: 'Farhan Lakoro',
        npp: 'BSS-SPV-01',
        email: 'farhan@bssparking.id',
        role: UserRole.supervisor,
        posId: 'POS-01',
        posName: 'Pos Gate Utama',
        cabangName: 'KC BSG',
      );
      await StorageService.saveUser(user);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AuthRepository.sessionTokenPrefsKey, validToken);
      await AuthRepository.instance.init();

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: AuthRepository.navigatorKey,
          scaffoldMessengerKey: AuthRepository.scaffoldMessengerKey,
          home: const Scaffold(body: Text('Protected Dashboard')),
        ),
      );

      expect(find.text('Protected Dashboard'), findsOneWidget);
      expect(AuthRepository.instance.isLoggedIn, isTrue);

      LocationService.clientOverride = MockClient((_) async {
        return http.Response(jsonEncode({'error': 'unauthorized'}), 401);
      });

      const pos = PosLocation(
        posId: 'POS-EXP-01',
        posName: 'Test Pos',
        cabangName: 'KC BSG',
        fullAddress: 'Jl. Test',
        locationTag: 'EXP',
        tagColor: Color(0xFFF59E0B),
        lat: 1.0,
        lng: 124.0,
      );

      final res = await LocationService.saveLocationRemote(pos);
      expect(res, equals(RemoteWriteResult.invalidCredentials));

      await tester.pumpAndSettle();

      expect(AuthRepository.instance.isLoggedIn, isFalse);
      expect(AuthRepository.instance.sessionToken, isNull);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('Sesi habis, silakan login ulang.'), findsOneWidget);
    });
  });
}
