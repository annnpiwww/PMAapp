import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bssparking_timemark/data/models/daily_task_model.dart';
import 'package:bssparking_timemark/data/services/branch_service.dart';
import 'package:bssparking_timemark/data/services/daily_task_service.dart';
import 'package:bssparking_timemark/data/services/notification_service.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';
import 'package:bssparking_timemark/features/daily_tasks/error_ticket_launcher.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  DailyTaskModel makeTask({
    String id = 'task_err_1',
    String kategori = 'error',
    String teknisiNama = 'fatma',
    TaskStatus status = TaskStatus.pending,
    String serahTerima = 'fatma||Daftar terbuka|13 Nov 05:52',
    String peserta = '',
  }) {
    return DailyTaskModel(
      id: id,
      tanggal: '2026-11-13',
      teknisiId: '',
      teknisiNama: teknisiNama,
      posName: 'Pasar Bersehati',
      posTag: 'PBM',
      judul: 'Gate masuk error',
      kategori: kategori,
      status: status,
      serahTerima: serahTerima,
      peserta: peserta,
    );
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    BranchService.instance.resetForTesting();
    DailyTaskService.resetKnownPendingTaskIdsForTesting();
    NotificationService.instance.clearSentAlarmNotificationsForTesting();
    ErrorTicketLauncher.pendingTaskId = null;
  });

  tearDown(() {
    DailyTaskService.clientOverride = null;
    BranchService.instance.resetForTesting();
    ErrorTicketLauncher.pendingTaskId = null;
  });

  group('ErrorTicketLauncher.taskIdFromPayload', () {
    test('returns null for null, empty, or unrelated payloads', () {
      expect(ErrorTicketLauncher.taskIdFromPayload(null), isNull);
      expect(ErrorTicketLauncher.taskIdFromPayload(''), isNull);
      expect(ErrorTicketLauncher.taskIdFromPayload('daily_tasks'), isNull);
      expect(ErrorTicketLauncher.taskIdFromPayload('error_ticket'), isNull);
      expect(ErrorTicketLauncher.taskIdFromPayload('error_alarm_v2'), isNull);
    });

    test('returns empty string sentinel for bare or empty-id error_alarm payloads', () {
      expect(ErrorTicketLauncher.taskIdFromPayload('error_alarm'), equals(''));
      expect(ErrorTicketLauncher.taskIdFromPayload('error_alarm:'), equals(''));
      expect(ErrorTicketLauncher.taskIdFromPayload('error_alarm:   '), equals(''));
    });

    test('extracts task id from error_alarm:<taskId>', () {
      expect(ErrorTicketLauncher.taskIdFromPayload('error_alarm:task_1'), equals('task_1'));
      expect(
        ErrorTicketLauncher.taskIdFromPayload('error_alarm:task_1794522568284_1130'),
        equals('task_1794522568284_1130'),
      );
    });
  });

  group('ErrorTicketLauncher.ensureClaimed', () {
    test('returns task unchanged without calling claim for non-error, already-assigned, and completed tasks', () async {
      var httpCalls = 0;
      DailyTaskService.clientOverride = MockClient((request) async {
        httpCalls++;
        return http.Response('{}', 500);
      });

      final nonError = makeTask(kategori: 'khusus');
      final nonErrorRes = await ErrorTicketLauncher.ensureClaimed(nonError, 'Ryan Lumasuge');
      expect(nonErrorRes, same(nonError));

      final alreadyAssigned = makeTask(teknisiNama: 'Ryan Lumasuge');
      final assignedRes = await ErrorTicketLauncher.ensureClaimed(alreadyAssigned, 'Ryan Lumasuge');
      expect(assignedRes, same(alreadyAssigned));

      final asPeserta = makeTask(teknisiNama: 'fatma', peserta: 'Ryan Lumasuge');
      final pesertaRes = await ErrorTicketLauncher.ensureClaimed(asPeserta, 'Ryan Lumasuge');
      expect(pesertaRes, same(asPeserta));

      final completed = makeTask(status: TaskStatus.completed);
      final completedRes = await ErrorTicketLauncher.ensureClaimed(completed, 'Ryan Lumasuge');
      expect(completedRes, same(completed));

      expect(httpCalls, equals(0));
    });

    test('claims open error ticket and returns updated task owned by technician', () async {
      final openTask = makeTask(id: 'task_1794522568284_1130');
      var claimCalled = false;

      DailyTaskService.clientOverride = MockClient((request) async {
        if (request.url.path.endsWith('/functions/v1/daily-tasks')) {
          claimCalled = true;
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['action'], equals('claim'));
          expect(body['id'], equals(openTask.id));
          final updated = openTask.copyWith(
            teknisiNama: 'Ryan Lumasuge',
            serahTerima: '${openTask.serahTerima}\nfatma|Ryan Lumasuge|Ambil tugas terbuka|13 Nov 06:00',
          );
          return http.Response(jsonEncode({'task': updated.toJson()}), 200);
        }
        return http.Response('{}', 404);
      });

      String? capturedMsg;
      final res = await ErrorTicketLauncher.ensureClaimed(
        openTask,
        'Ryan Lumasuge',
        onMessage: (pesan, _) => capturedMsg = pesan,
      );

      expect(claimCalled, isTrue);
      expect(capturedMsg, isNull);
      expect(res, isNotNull);
      expect(res!.teknisiNama, equals('Ryan Lumasuge'));
      expect(res.isOpenHandover, isFalse);
    });

    test('returns null and invokes onMessage when ticket is already taken (409)', () async {
      final openTask = makeTask();

      DailyTaskService.clientOverride = MockClient((request) async {
        if (request.url.path.endsWith('/functions/v1/daily-tasks')) {
          return http.Response(jsonEncode({'claimed_by': 'Junifer Manua'}), 409);
        }
        return http.Response('{}', 500);
      });

      String? capturedMsg;
      bool? capturedSukses;
      final res = await ErrorTicketLauncher.ensureClaimed(
        openTask,
        'Ryan Lumasuge',
        onMessage: (pesan, sukses) {
          capturedMsg = pesan;
          capturedSukses = sukses;
        },
      );

      expect(res, isNull);
      expect(capturedSukses, isFalse);
      expect(capturedMsg, contains('Junifer Manua'));
    });

    test('returns null and invokes failure message when claim fails', () async {
      final openTask = makeTask();

      DailyTaskService.clientOverride = MockClient((request) async {
        return http.Response('error', 500);
      });

      String? capturedMsg;
      bool? capturedSukses;
      final res = await ErrorTicketLauncher.ensureClaimed(
        openTask,
        'Ryan Lumasuge',
        onMessage: (pesan, sukses) {
          capturedMsg = pesan;
          capturedSukses = sukses;
        },
      );

      expect(res, isNull);
      expect(capturedSukses, isFalse);
      expect(capturedMsg, equals('Gagal mengambil tiket, cek sinyal lalu coba lagi.'));
    });
  });

  group('ErrorTicketLauncher pending sentinel & NotificationService payload', () {
    test('openById stores sentinel empty string for newest and exact id when not ready', () async {
      await ErrorTicketLauncher.openById(null);
      expect(ErrorTicketLauncher.pendingTaskId, equals(''));

      await ErrorTicketLauncher.openById('task_99');
      expect(ErrorTicketLauncher.pendingTaskId, equals('task_99'));
    });

    test('NotificationService alarm notifications embed task id in payload', () async {
      final service = NotificationService.instance;
      await service.showDirectErrorAlarmNotification(
        title: 'Lokasi error: PBM',
        body: 'Gate mati',
        taskId: 'task_direct_1',
      );
      await service.showErrorAlarmNotification(
        openTickets: [makeTask(id: 'task_open_1')],
      );

      final sent = service.sentAlarmNotificationsForTesting;
      expect(sent.length, equals(2));
      expect(sent[0]['payload'], equals('error_alarm:task_direct_1'));
      expect(sent[1]['payload'], equals('error_alarm:task_open_1'));
    });
  });
}
