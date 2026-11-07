import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bssparking_timemark/data/models/user_model.dart';
import 'package:bssparking_timemark/data/repositories/auth_repository.dart';
import 'package:bssparking_timemark/data/services/branch_service.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';

String _makeTestSessionToken({
  required String uid,
  required String role,
  required String cabang,
  required String name,
  int? expSeconds,
}) {
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final payload = {
    'uid': uid,
    'role': role,
    'cabang': cabang,
    'name': name,
    'iat': now,
    'exp': expSeconds ?? (now + 30 * 86400),
  };
  final payloadB64 =
      base64UrlEncode(utf8.encode(jsonEncode(payload))).replaceAll('=', '');
  return 'v1.$payloadB64.test_signature_bytes';
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
  });

  tearDown(() {
    AuthRepository.instance.httpClient = null;
    AuthRepository.instance.isWebOverride = null;
  });

  group('AuthRepository Online (auth-login) & Salted Offline Credential Cache Tests', () {
    test('Online success writes salted hash record + token (never plaintext password) and allows subsequent offline login', () async {
      const testPass = 's3cr3t_online_pass_99';
      final issuedToken = _makeTestSessionToken(
        uid: 'usr_bali_spv',
        role: 'spv',
        cabang: 'KC Bali',
        name: 'Indra Yohana',
      );
      AuthRepository.instance.httpClient = MockClient((request) async {
        expect(request.url.path, endsWith('/functions/v1/auth-login'));
        expect(request.method, equals('POST'));
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        if (body['password'] != testPass) {
          return http.Response(jsonEncode({'error': 'invalid credentials'}), 401);
        }
        return http.Response(
          jsonEncode({
            'token': issuedToken,
            'user': {
              'id': 'usr_bali_spv',
              'username': 'indra',
              'email': 'indra@pma.com',
              'nama': 'Indra Yohana',
              'role': 'spv',
              'cabang': 'KC Bali',
            },
          }),
          200,
        );
      });

      final onlineOk = await AuthRepository.instance.loginWithPassword(
        identity: '  Indra@PMA.com ',
        password: testPass,
      );
      expect(onlineOk, isTrue);
      expect(AuthRepository.instance.currentUser?.role, equals(UserRole.supervisor));
      expect(AuthRepository.instance.currentUser?.cabangName, equals('KC Bali'));
      expect(AuthRepository.instance.sessionToken, equals(issuedToken));
      expect(BranchService.instance.currentBranch, equals(AppBranch.bali));

      final prefs = await SharedPreferences.getInstance();
      for (final key in prefs.getKeys()) {
        final val = prefs.get(key)?.toString() ?? '';
        expect(val.contains(testPass), isFalse, reason: 'Prefs key $key must not contain plaintext password');
      }

      final rawCache = prefs.getString(AuthRepository.offlineCredentialsPrefsKey);
      expect(rawCache, isNotNull);
      final decodedCache = jsonDecode(rawCache!) as Map<String, dynamic>;
      expect(decodedCache.containsKey('indra@pma.com'), isTrue);
      final record = decodedCache['indra@pma.com'] as Map<String, dynamic>;
      final saltBytes = base64Decode(record['salt'] as String);
      expect(saltBytes.length, equals(16));
      expect((record['hash'] as String).length, equals(64));
      expect(record['token'], equals(issuedToken));

      // Simulate device going offline (network exception) after logout/restart
      await AuthRepository.instance.logout();
      BranchService.instance.resetForTesting();
      AuthRepository.instance.httpClient = MockClient((_) async {
        throw http.ClientException('Network unreachable');
      });

      final offlineOk = await AuthRepository.instance.loginWithPassword(
        identity: 'indra@pma.com',
        password: testPass,
      );
      expect(offlineOk, isTrue);
      expect(AuthRepository.instance.currentUser?.id, equals('usr_bali_spv'));
      expect(AuthRepository.instance.currentUser?.nama, equals('Indra Yohana'));
      expect(AuthRepository.instance.currentUser?.role, equals(UserRole.supervisor));
      expect(AuthRepository.instance.sessionToken, equals(issuedToken));
      expect(BranchService.instance.currentBranch, equals(AppBranch.bali));
      expect(AuthRepository.instance.lastErrorMessage, isNull);
    });

    test('Offline login with cached record but wrong password fails', () async {
      const rightPass = 'valid_tech_pass_42';
      AuthRepository.instance.httpClient = MockClient((_) async {
        return http.Response(
          jsonEncode({
            'token': _makeTestSessionToken(
              uid: 'usr_mnd_1',
              role: 'technician',
              cabang: 'KC Manado',
              name: 'Ryan Lumasuge',
            ),
            'user': {
              'id': 'usr_mnd_1',
              'username': 'ryan',
              'email': 'ryan@pma.com',
              'nama': 'Ryan Lumasuge',
              'role': 'technician',
              'cabang': 'KC Manado',
            },
          }),
          200,
        );
      });

      expect(
        await AuthRepository.instance.loginWithPassword(
          identity: 'ryan@pma.com',
          password: rightPass,
        ),
        isTrue,
      );

      await AuthRepository.instance.logout();
      AuthRepository.instance.httpClient = MockClient((_) async {
        throw http.ClientException('Offline');
      });

      final wrongOffline = await AuthRepository.instance.loginWithPassword(
        identity: 'ryan@pma.com',
        password: 'wrong_password_attempt',
      );
      expect(wrongOffline, isFalse);
      expect(AuthRepository.instance.currentUser, isNull);
    });

    test('Server wrong-password response (401) does NOT fall back to cached offline credentials', () async {
      const oldPass = 'old_online_pass_1';

      AuthRepository.instance.httpClient = MockClient((_) async {
        return http.Response(
          jsonEncode({
            'token': _makeTestSessionToken(
              uid: 'usr_mnd_1',
              role: 'technician',
              cabang: 'KC Manado',
              name: 'Ryan Lumasuge',
            ),
            'user': {
              'id': 'usr_mnd_1',
              'username': 'ryan',
              'email': 'ryan@pma.com',
              'nama': 'Ryan Lumasuge',
              'role': 'technician',
              'cabang': 'KC Manado',
            },
          }),
          200,
        );
      });

      expect(
        await AuthRepository.instance.loginWithPassword(
          identity: 'ryan@pma.com',
          password: oldPass,
        ),
        isTrue,
      );
      await AuthRepository.instance.logout();

      // Server is online and rejects old password with 401
      AuthRepository.instance.httpClient = MockClient((_) async {
        return http.Response(jsonEncode({'error': 'invalid credentials'}), 401);
      });

      final failOnlineWrongPass = await AuthRepository.instance.loginWithPassword(
        identity: 'ryan@pma.com',
        password: oldPass,
      );
      expect(failOnlineWrongPass, isFalse);
      expect(AuthRepository.instance.currentUser, isNull);
    });

    test('Offline login with no prior online record fails with explicit message', () async {
      AuthRepository.instance.httpClient = MockClient((_) async {
        throw http.ClientException('No internet');
      });

      final ok = await AuthRepository.instance.loginWithPassword(
        identity: 'toro@pma.com',
        password: 'any_password',
      );
      expect(ok, isFalse);
      expect(
        AuthRepository.instance.lastErrorMessage,
        equals('Login offline hanya untuk akun yang pernah login online di HP ini.'),
      );
    });

    test('Web seam never caches offline credentials and never logs in offline', () async {
      const webPass = 'web_only_pass_77';
      AuthRepository.instance.isWebOverride = false;
      AuthRepository.instance.httpClient = MockClient((_) async {
        return http.Response(
          jsonEncode({
            'token': _makeTestSessionToken(
              uid: 'usr_ho_1',
              role: 'spv',
              cabang: 'HO Makassar',
              name: 'ADI SUPRIADI',
            ),
            'user': {
              'id': 'usr_ho_1',
              'username': 'adi',
              'email': 'adi@pma.com',
              'nama': 'ADI SUPRIADI',
              'role': 'spv',
              'cabang': 'HO Makassar',
            },
          }),
          200,
        );
      });
      expect(
        await AuthRepository.instance.loginWithPassword(
          identity: 'adi@pma.com',
          password: webPass,
        ),
        isTrue,
      );
      await AuthRepository.instance.logout();

      AuthRepository.instance.isWebOverride = true;
      AuthRepository.instance.httpClient = MockClient((_) async {
        throw http.ClientException('Offline on web');
      });

      final webOfflineOk = await AuthRepository.instance.loginWithPassword(
        identity: 'adi@pma.com',
        password: webPass,
      );
      expect(webOfflineOk, isFalse);
      expect(AuthRepository.instance.currentUser, isNull);
    });

    test('SEC-01: rejects wildcard and PostgREST filter-injection identifiers without network call', () async {
      var networkCalls = 0;
      AuthRepository.instance.httpClient = MockClient((_) async {
        networkCalls++;
        return http.Response(jsonEncode({'error': 'invalid credentials'}), 401);
      });

      final maliciousIdentifiers = <String>[
        '*',
        'a%',
        'x,role.eq.spv',
        'admin)',
        '(username.eq.indra)',
        "indra' OR '1'='1",
        '"indra"',
        'a' * 65,
      ];

      for (final rawId in maliciousIdentifiers) {
        final ok = await AuthRepository.instance.loginWithPassword(
          identity: rawId,
          password: 'any_test_password',
        );
        expect(ok, isFalse, reason: 'Identifier "$rawId" must be rejected');
      }

      expect(networkCalls, equals(0));
    });

    test('SEC-04: normal username and email login via auth-login POST (zero /rest/v1/app_users queries)', () async {
      final capturedPaths = <String>[];
      final capturedIdentities = <String>[];
      AuthRepository.instance.httpClient = MockClient((request) async {
        capturedPaths.add(request.url.path);
        final payload = jsonDecode(request.body) as Map<String, dynamic>;
        capturedIdentities.add(payload['identity'] as String);
        return http.Response(
          jsonEncode({
            'token': _makeTestSessionToken(
              uid: 'usr_online_1',
              role: 'technician',
              cabang: 'KC Manado',
              name: 'Ryan Lumasuge',
            ),
            'user': {
              'id': 'usr_online_1',
              'username': 'ryan',
              'email': 'ryan@pma.com',
              'nama': 'Ryan Lumasuge',
              'role': 'technician',
              'cabang': 'KC Manado',
            },
          }),
          200,
        );
      });

      final okUsername = await AuthRepository.instance.loginWithPassword(
        identity: 'ryan',
        password: 'mock_online_pass',
      );
      expect(okUsername, isTrue);
      expect(AuthRepository.instance.currentUser?.id, equals('usr_online_1'));
      expect(capturedPaths.first, endsWith('/functions/v1/auth-login'));
      expect(capturedIdentities.first, equals('ryan'));

      final okEmail = await AuthRepository.instance.loginWithPassword(
        identity: 'ryan@pma.com',
        password: 'mock_online_pass',
      );
      expect(okEmail, isTrue);
      expect(capturedPaths.last, endsWith('/functions/v1/auth-login'));
      expect(capturedIdentities.last, equals('ryan@pma.com'));
    });
  });
}
