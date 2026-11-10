import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bssparking_timemark/data/models/daily_task_model.dart';
import 'package:bssparking_timemark/data/models/user_model.dart';
import 'package:bssparking_timemark/data/services/error_alarm_service.dart';
import 'package:bssparking_timemark/data/services/notification_service.dart';
import 'package:bssparking_timemark/data/services/push_service.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final dummyUser = UserModel(
    id: 'u_1',
    nama: 'Ryan Lumasuge',
    npp: '12345',
    email: 'ryan@bss.com',
    role: UserRole.petugas,
    posId: 'pos_1',
    posName: 'PBM',
    cabangName: 'KC Manado',
  );

  DailyTaskModel makeTicket({
    required String id,
    required String judul,
    required String posName,
    String teknisiNama = 'Farhan Lakoro',
  }) {
    return DailyTaskModel(
      id: id,
      tanggal: '2026-11-10',
      teknisiId: 'tek_farhan',
      teknisiNama: teknisiNama,
      posName: posName,
      posTag: 'PBM',
      judul: judul,
      deskripsi: 'Kendala: $judul',
      kategori: 'error',
      status: TaskStatus.pending,
    );
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    ErrorAlarmService.instance.resetForTesting();
    PushService.instance.resetForTesting();
    NotificationService.instance.clearSentAlarmNotificationsForTesting();
    // Default logged in
    await StorageService.saveUser(dummyUser);
  });

  tearDown(() {
    ErrorAlarmService.instance.resetForTesting();
    PushService.instance.resetForTesting();
  });

  group('ErrorAlarmService tests', () {
    test('1. new ticket -> ringing true + exactly one notify', () async {
      final ticket1 = makeTicket(id: 'err_1', judul: 'Barrier patah', posName: 'Pos 1');
      ErrorAlarmService.instance.fetchOpenOverride = () async => [ticket1];

      await ErrorAlarmService.instance.tick();

      expect(ErrorAlarmService.instance.openErrors.value.length, equals(1));
      expect(ErrorAlarmService.instance.ringing.value, isTrue);

      final notifications = NotificationService.instance.sentAlarmNotificationsForTesting;
      expect(notifications.length, equals(1));
      expect(notifications.first['title'], equals('Lokasi error: Pos 1'));
      expect(notifications.first['body'], equals('Barrier patah'));
    });

    test('2. same ticket next tick -> no second notify', () async {
      final ticket1 = makeTicket(id: 'err_1', judul: 'Barrier patah', posName: 'Pos 1');
      ErrorAlarmService.instance.fetchOpenOverride = () async => [ticket1];

      // Tick 1
      await ErrorAlarmService.instance.tick();
      expect(NotificationService.instance.sentAlarmNotificationsForTesting.length, equals(1));

      // Tick 2 with same ticket
      await ErrorAlarmService.instance.tick();
      expect(ErrorAlarmService.instance.ringing.value, isTrue);
      // Notification count remains exactly 1 (no second notify while still ringing)
      expect(NotificationService.instance.sentAlarmNotificationsForTesting.length, equals(1));
    });

    test('3. acknowledge -> ringing false, notification cancelled, id persisted', () async {
      final ticket1 = makeTicket(id: 'err_1', judul: 'Barrier patah', posName: 'Pos 1');
      ErrorAlarmService.instance.fetchOpenOverride = () async => [ticket1];

      await ErrorAlarmService.instance.tick();
      expect(ErrorAlarmService.instance.ringing.value, isTrue);

      await ErrorAlarmService.instance.acknowledge();

      expect(ErrorAlarmService.instance.ringing.value, isFalse);
      expect(
        NotificationService.instance.cancelAlarmNotificationCallCountForTesting,
        greaterThan(0),
      );

      final prefs = await SharedPreferences.getInstance();
      final persisted = prefs.getStringList(ErrorAlarmService.prefsKeyAcknowledged);
      expect(persisted, contains('err_1'));

      // Next tick with the same ticket still open: should stay acknowledged (not ringing)
      await ErrorAlarmService.instance.tick();
      expect(ErrorAlarmService.instance.ringing.value, isFalse);
      expect(NotificationService.instance.sentAlarmNotificationsForTesting.length, equals(1));
    });

    test('4. ticket closed -> pruned, nothing open -> cancel + ringing false', () async {
      final ticket1 = makeTicket(id: 'err_1', judul: 'Barrier patah', posName: 'Pos 1');
      ErrorAlarmService.instance.fetchOpenOverride = () async => [ticket1];

      await ErrorAlarmService.instance.tick();
      expect(ErrorAlarmService.instance.ringing.value, isTrue);

      // Now ticket is closed / resolved (server returns empty list)
      ErrorAlarmService.instance.fetchOpenOverride = () async => [];

      await ErrorAlarmService.instance.tick();

      expect(ErrorAlarmService.instance.openErrors.value, isEmpty);
      expect(ErrorAlarmService.instance.ringing.value, isFalse);
      expect(
        NotificationService.instance.cancelAlarmNotificationCallCountForTesting,
        greaterThan(0),
      );

      final prefs = await SharedPreferences.getInstance();
      final persisted = prefs.getStringList(ErrorAlarmService.prefsKeyAcknowledged);
      expect(persisted, isEmpty);
    });

    test('5. second new ticket after ack -> rings again', () async {
      final ticket1 = makeTicket(id: 'err_1', judul: 'Barrier patah', posName: 'Pos 1');
      ErrorAlarmService.instance.fetchOpenOverride = () async => [ticket1];

      await ErrorAlarmService.instance.tick();
      expect(ErrorAlarmService.instance.ringing.value, isTrue);

      await ErrorAlarmService.instance.acknowledge();
      expect(ErrorAlarmService.instance.ringing.value, isFalse);

      // Now ticket 2 arrives while ticket 1 is still open
      final ticket2 = makeTicket(id: 'err_2', judul: 'Printer macet', posName: 'Pos 2');
      ErrorAlarmService.instance.fetchOpenOverride = () async => [ticket2, ticket1]; // newest first

      await ErrorAlarmService.instance.tick();

      expect(ErrorAlarmService.instance.ringing.value, isTrue);
      final notifications = NotificationService.instance.sentAlarmNotificationsForTesting;
      expect(notifications.length, equals(2));
      expect(notifications.last['title'], equals('2 lokasi error'));
      expect(notifications.last['body'], equals('Printer macet'));
    });

    test('6. logged out -> lists cleared, no fetch', () async {
      bool fetchCalled = false;
      ErrorAlarmService.instance.fetchOpenOverride = () async {
        fetchCalled = true;
        return [makeTicket(id: 'err_1', judul: 'Test', posName: 'Pos 1')];
      };

      // Set user to null
      await StorageService.clearUser();

      await ErrorAlarmService.instance.tick();

      expect(fetchCalled, isFalse, reason: 'Must not call network fetch when logged out');
      expect(ErrorAlarmService.instance.openErrors.value, isEmpty);
      expect(ErrorAlarmService.instance.ringing.value, isFalse);
      expect(
        NotificationService.instance.cancelAlarmNotificationCallCountForTesting,
        greaterThan(0),
      );
    });

    test('7. logged in tick triggers PushService.ensureRegistered', () async {
      PushService.instance.tokenFetcherOverride = () async => 'token_for_tick_test';
      PushService.instance.httpClient = MockClient((req) async {
        return http.Response('{"ok":true}', 200);
      });

      ErrorAlarmService.instance.fetchOpenOverride = () async => [];

      await ErrorAlarmService.instance.tick();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(PushService.prefsKeyLastToken), equals('token_for_tick_test'));
      expect(prefs.getString(PushService.prefsKeyLastName), equals('Ryan Lumasuge'));
    });

    test('8. logged out tick triggers PushService.unregister once', () async {
      int unregisterCalls = 0;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(PushService.prefsKeyLastToken, 'stored_token_to_unregister');
      await prefs.setString(PushService.prefsKeyLastName, 'Ryan Lumasuge');

      PushService.instance.httpClient = MockClient((req) async {
        if (req.method == 'DELETE') {
          unregisterCalls++;
        }
        return http.Response('{"ok":true}', 200);
      });

      // Clear user
      await StorageService.clearUser();

      // Tick 1: logs out -> unregisters once
      await ErrorAlarmService.instance.tick();
      expect(unregisterCalls, equals(1));
      expect(prefs.getString(PushService.prefsKeyLastToken), isNull);

      // Tick 2: still logged out -> does not call unregister again
      await ErrorAlarmService.instance.tick();
      expect(unregisterCalls, equals(1));
    });
  });
}
