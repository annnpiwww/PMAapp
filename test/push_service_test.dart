import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bssparking_timemark/data/services/notification_service.dart';
import 'package:bssparking_timemark/data/services/push_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    PushService.instance.resetForTesting();
    NotificationService.instance.clearSentAlarmNotificationsForTesting();
  });

  tearDown(() {
    PushService.instance.resetForTesting();
  });

  group('PushService unit tests', () {
    test('1. ensureRegistered sends POST to push-register with session header and payload', () async {
      int requestCount = 0;
      http.Request? capturedRequest;

      PushService.instance.httpClient = MockClient((request) async {
        requestCount++;
        capturedRequest = request;
        return http.Response(jsonEncode({'ok': true, 'registered': true}), 200);
      });

      PushService.instance.tokenFetcherOverride = () async => 'test_device_token_1234567890';

      await PushService.instance.ensureRegisteredInternal(
        name: 'Ryan Lumasuge',
        cabang: 'KC Manado',
        role: 'petugas',
      );

      expect(requestCount, equals(1));
      expect(capturedRequest, isNotNull);
      expect(capturedRequest!.method, equals('POST'));
      expect(capturedRequest!.url.path, contains('push-register'));

      final body = jsonDecode(capturedRequest!.body) as Map<String, dynamic>;
      expect(body['token'], equals('test_device_token_1234567890'));
      expect(body['platform'], equals('android'));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(PushService.prefsKeyLastToken), equals('test_device_token_1234567890'));
      expect(prefs.getString(PushService.prefsKeyLastName), equals('Ryan Lumasuge'));
    });

    test('2. ensureRegistered is idempotent when token and name are unchanged', () async {
      int requestCount = 0;

      PushService.instance.httpClient = MockClient((request) async {
        requestCount++;
        return http.Response(jsonEncode({'ok': true, 'registered': true}), 200);
      });

      PushService.instance.tokenFetcherOverride = () async => 'test_device_token_1234567890';

      // First call
      await PushService.instance.ensureRegisteredInternal(
        name: 'Ryan Lumasuge',
        cabang: 'KC Manado',
        role: 'petugas',
      );
      expect(requestCount, equals(1));

      // Second call with identical token and name
      await PushService.instance.ensureRegisteredInternal(
        name: 'Ryan Lumasuge',
        cabang: 'KC Manado',
        role: 'petugas',
      );
      // No additional HTTP request made
      expect(requestCount, equals(1));
    });

    test('3. ensureRegistered re-registers when token changes', () async {
      int requestCount = 0;
      String currentToken = 'token_version_1';

      PushService.instance.httpClient = MockClient((request) async {
        requestCount++;
        return http.Response(jsonEncode({'ok': true, 'registered': true}), 200);
      });

      PushService.instance.tokenFetcherOverride = () async => currentToken;

      await PushService.instance.ensureRegisteredInternal(
        name: 'Ryan Lumasuge',
        cabang: 'KC Manado',
        role: 'petugas',
      );
      expect(requestCount, equals(1));

      // Token refreshes
      currentToken = 'token_version_2';
      PushService.instance.setTokenForTesting(null);

      await PushService.instance.ensureRegisteredInternal(
        name: 'Ryan Lumasuge',
        cabang: 'KC Manado',
        role: 'petugas',
      );
      expect(requestCount, equals(2));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(PushService.prefsKeyLastToken), equals('token_version_2'));
    });

    test('4. unregister sends DELETE to push-register and clears shared preferences', () async {
      int deleteCount = 0;
      http.Request? capturedDelete;

      PushService.instance.httpClient = MockClient((request) async {
        if (request.method == 'DELETE') {
          deleteCount++;
          capturedDelete = request;
          return http.Response(jsonEncode({'ok': true, 'unregistered': true}), 200);
        }
        return http.Response(jsonEncode({'ok': true}), 200);
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(PushService.prefsKeyLastToken, 'stored_token_to_remove');
      await prefs.setString(PushService.prefsKeyLastName, 'Ryan Lumasuge');

      await PushService.instance.unregisterInternal();

      expect(deleteCount, equals(1));
      expect(capturedDelete!.method, equals('DELETE'));
      final body = jsonDecode(capturedDelete!.body) as Map<String, dynamic>;
      expect(body['token'], equals('stored_token_to_remove'));

      expect(prefs.getString(PushService.prefsKeyLastToken), isNull);
      expect(prefs.getString(PushService.prefsKeyLastName), isNull);
    });

    test('5. background message handler triggers NotificationService with sound and insistent flag', () async {
      const message = RemoteMessage(
        data: {
          'type': 'error_alarm',
          'task_id': 'task_err_99',
          'pos_name': 'Pos Timur Manado',
          'judul': 'Palang barrier macet',
        },
      );

      await firebaseMessagingBackgroundHandler(message);

      final sentList = NotificationService.instance.sentAlarmNotificationsForTesting;
      expect(sentList.length, equals(1));
      expect(sentList.first['title'], equals('Lokasi error: Pos Timur Manado'));
      expect(sentList.first['body'], equals('Palang barrier macet'));
    });

    test('6. foreground message of type error_alarm triggers custom handler or alarm tick', () async {
      bool handlerCalled = false;
      PushService.instance.foregroundMessageHandlerOverride = (msg) {
        if (msg.data['type'] == 'error_alarm') {
          handlerCalled = true;
        }
      };

      const msg = RemoteMessage(
        data: {
          'type': 'error_alarm',
          'task_id': 'task_err_100',
        },
      );

      PushService.instance.foregroundMessageHandlerOverride!(msg);
      expect(handlerCalled, isTrue);
    });
  });
}
