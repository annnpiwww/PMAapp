import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bssparking_timemark/data/models/daily_task_model.dart';
import 'package:bssparking_timemark/data/repositories/auth_repository.dart';
import 'package:bssparking_timemark/data/services/branch_service.dart';
import 'package:bssparking_timemark/data/services/daily_task_service.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const spvToken = 'v1.eyJ1aWQiOiJ1c3Jfc3B2Iiwicm9sZSI6InNwdiIsImV4cCI6NDEwMjQ0NDgwMH0.sig';

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    BranchService.instance.resetForTesting();
    DailyTaskService.clientOverride = null;
    AuthRepository.instance.setSessionTokenForTesting(spvToken);
  });

  tearDown(() {
    DailyTaskService.clientOverride = null;
    AuthRepository.instance.setSessionTokenForTesting(null);
  });

  group('DailyTaskService Server Mutation & SEC-09 Tests', () {
    test('createTask, transferTask, and deleteTask call /functions/v1/daily-tasks with x-app-session', () async {
      final calls = <({String path, String? session, Map<String, dynamic> body})>[];

      DailyTaskService.clientOverride = MockClient((req) async {
        final decoded = jsonDecode(req.body) as Map<String, dynamic>;
        calls.add((
          path: req.url.path,
          session: req.headers['x-app-session'],
          body: decoded,
        ));

        final action = decoded['action'];
        if (action == 'create') {
          final taskMap = Map<String, dynamic>.from(decoded['task'] as Map);
          return http.Response(jsonEncode(taskMap), 201);
        }
        if (action == 'transfer') {
          return http.Response(jsonEncode({'ok': true}), 200);
        }
        if (action == 'delete') {
          return http.Response(jsonEncode({'ok': true}), 200);
        }
        return http.Response('{}', 400);
      });

      final created = await DailyTaskService.createTask(
        tanggal: '2026-11-07',
        teknisiNama: 'Ryan Lumasuge',
        posName: 'Pasar Bersehati Manado',
        posTag: 'PBM',
        judul: 'Cek printer gate 1',
        peserta: 'Andi',
      );

      expect(created, isNotNull);
      expect(created!.id.startsWith('task_'), isTrue);
      expect(calls.length, equals(1));
      expect(calls[0].path, endsWith('/functions/v1/daily-tasks'));
      expect(calls[0].session, equals(spvToken));
      expect(calls[0].body['action'], equals('create'));

      final transferred = await DailyTaskService.transferTask(
        task: created,
        keTeknisi: 'Budi',
        alasan: 'Pergantian shift',
        olehSiapa: 'Farhan Lakoro',
      );
      expect(transferred, isTrue);
      expect(calls.length, equals(2));
      expect(calls[1].path, endsWith('/functions/v1/daily-tasks'));
      expect(calls[1].session, equals(spvToken));
      expect(calls[1].body['action'], equals('transfer'));
      expect(calls[1].body['teknisi_nama'], equals('Budi'));
      expect((calls[1].body['serah_terima'] as String), contains('Pergantian shift'));

      final deleted = await DailyTaskService.deleteTask(created);
      expect(deleted, isTrue);
      expect(calls.length, equals(3));
      expect(calls[2].path, endsWith('/functions/v1/daily-tasks'));
      expect(calls[2].session, equals(spvToken));
      expect(calls[2].body['action'], equals('delete'));
      expect(calls[2].body['id'], equals(created.id));
    });

    test('deleteTask returns false when server refuses completed task with 409', () async {
      DailyTaskService.clientOverride = MockClient((_) async {
        return http.Response(jsonEncode({'error': 'completed'}), 409);
      });

      final task = DailyTaskModel(
        id: 'task_server_completed_1',
        tanggal: '2026-11-07',
        teknisiId: 'tek_1',
        teknisiNama: 'Ryan Lumasuge',
        posName: 'PBM',
        posTag: 'PBM',
        judul: 'Cek kamera LPR',
        status: TaskStatus.pending,
      );

      final ok = await DailyTaskService.deleteTask(task);
      expect(ok, isFalse);
    });

    test('SEC-09: _uploadBuktiFoto rejects "../x" and non-allowlisted taskId without HTTP upload', () async {
      var httpCalls = 0;
      DailyTaskService.clientOverride = MockClient((_) async {
        httpCalls++;
        return http.Response('ok', 200);
      });

      final badIds = <String>[
        '../x',
        '../../etc/passwd',
        'task/evil',
        'task..1',
        'task with space',
        '',
        'a' * 81,
      ];

      for (final badId in badIds) {
        final uploaded = await DailyTaskService.uploadBuktiFotoForTesting(
          '/nonexistent/photo.jpg',
          taskId: badId,
        );
        expect(uploaded, isNull, reason: 'taskId "$badId" must be rejected');
      }

      expect(httpCalls, equals(0));
    });

    test('SEC-09: _assignedOrGroup strips "%" and PostgREST metacharacters', () {
      final filter = DailyTaskService.assignedOrGroupForTesting('Ryan%Admin,(*):\\Test');
      expect(filter.contains('%'), isFalse);
      expect(filter.contains('('), isFalse);
      expect(filter.contains(')'), isFalse);
      expect(filter, contains('teknisi_nama.ilike.*Ryan*'));
    });
  });
}
