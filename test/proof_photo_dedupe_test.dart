import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bssparking_timemark/data/services/branch_service.dart';
import 'package:bssparking_timemark/data/services/daily_task_service.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    BranchService.instance.resetForTesting();
    tempDir = Directory.systemTemp.createTempSync('proof_dedupe_test_');
  });

  tearDown(() {
    DailyTaskService.clientOverride = null;
    BranchService.instance.resetForTesting();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('Proof Photo Deduplication & Single-Flight Flush (Task t20261108-141604-4b5c)', () {
    test('(a) first completeTask uploads OK, PATCH 500 -> queued; flush with PATCH 200 -> zero new storage POSTs, PATCH body contains URLs from 1st upload', () async {
      int storageUploads = 0;
      final photo = File('${tempDir.path}/photo_1.jpg')..writeAsBytesSync(Uint8List.fromList([10, 20, 30]));

      bool patchShouldFail = true;
      String? lastPatchBody;

      DailyTaskService.clientOverride = MockClient((req) async {
        if (req.url.path.contains('/storage/v1/object/task-proofs/')) {
          storageUploads++;
          return http.Response('', 200);
        }
        if (req.method == 'PATCH') {
          lastPatchBody = req.body;
          if (patchShouldFail) {
            return http.Response('Server Error', 500);
          }
          return http.Response('[{"id":"task_dedupe_1"}]', 200, headers: {'content-type': 'application/json'});
        }
        return http.Response('', 404);
      });

      // 1. First completeTask: photo uploads OK, but PATCH fails with 500
      final ok1 = await DailyTaskService.completeTask(
        taskId: 'task_dedupe_1',
        jamSelesai: '14:00',
        localPhotoPaths: [photo.path],
      );
      expect(ok1, isFalse);
      expect(storageUploads, equals(1));
      expect(lastPatchBody, isNotNull);
      final firstUrls = (jsonDecode(lastPatchBody!)['foto_bukti'] as List).cast<String>();
      expect(firstUrls, hasLength(1));
      expect(firstUrls[0], startsWith('https://'));

      // Check that the outbox has stored the remote URL instead of the local path
      final rawQueue = StorageService.getString('pending_task_completions') ?? '';
      expect(rawQueue, contains(firstUrls[0]));
      expect(rawQueue.contains(photo.path), isFalse);

      // 2. Flush with PATCH succeeding -> zero new storage uploads!
      patchShouldFail = false;
      final flushed = await DailyTaskService.flushPendingCompletions();
      expect(flushed, equals(1));
      expect(storageUploads, equals(1)); // ZERO new storage POSTs!

      final retryUrls = (jsonDecode(lastPatchBody!)['foto_bukti'] as List).cast<String>();
      expect(retryUrls, equals(firstUrls));
    });

    test('(b) two concurrent flushPendingCompletions calls -> each photo uploaded at most once', () async {
      int storageUploads = 0;
      final photo = File('${tempDir.path}/photo_concurrent.jpg')..writeAsBytesSync(Uint8List.fromList([40, 50, 60]));

      String? lastPatchBody;
      DailyTaskService.clientOverride = MockClient((req) async {
        if (req.url.path.contains('/storage/v1/object/task-proofs/')) {
          storageUploads++;
          // Simulate async network latency
          await Future<void>.delayed(const Duration(milliseconds: 30));
          return http.Response('', 200);
        }
        if (req.method == 'PATCH') {
          lastPatchBody = req.body;
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return http.Response('[{"id":"task_concurrent_1"}]', 200, headers: {'content-type': 'application/json'});
        }
        return http.Response('', 404);
      });

      // Queue a pending completion with local photo path
      await StorageService.setString(
        'pending_task_completions',
        jsonEncode([
          {
            'taskId': 'task_concurrent_1',
            'jamSelesai': '14:10',
            'catatan': 'concurrent test',
            'photos': [photo.path],
          }
        ]),
      );

      // Trigger two concurrent flushes
      final results = await Future.wait([
        DailyTaskService.flushPendingCompletions(),
        DailyTaskService.flushPendingCompletions(),
      ]);

      // Both resolve to the same single-flight operation
      expect(storageUploads, equals(1));
      expect(results[0], equals(1));
      expect(results[1], equals(1));
      expect(lastPatchBody, isNotNull);
    });

    test('(c) partial: 1 of 2 uploads failed first time -> retry uploads only the missing one', () async {
      int uploadPhoto0Count = 0;
      int uploadPhoto1Count = 0;
      final photo0 = File('${tempDir.path}/photo_p0.jpg')..writeAsBytesSync(Uint8List.fromList([1, 2, 3]));
      final photo1 = File('${tempDir.path}/photo_p1.jpg')..writeAsBytesSync(Uint8List.fromList([4, 5, 6]));

      bool failPhoto1 = true;
      bool patchShouldFail = true;
      String? lastPatchBody;

      DailyTaskService.clientOverride = MockClient((req) async {
        if (req.url.path.contains('/storage/v1/object/task-proofs/')) {
          if (RegExp(r'_1_\d+\.jpg$').hasMatch(req.url.path)) {
            uploadPhoto0Count++;
            return http.Response('', 200);
          }
          if (RegExp(r'_2_\d+\.jpg$').hasMatch(req.url.path)) {
            uploadPhoto1Count++;
            if (failPhoto1) {
              return http.Response('Upload 1 Failed', 500);
            }
            return http.Response('', 200);
          }
        }
        if (req.method == 'PATCH') {
          lastPatchBody = req.body;
          if (patchShouldFail) {
            return http.Response('Patch Failed', 500);
          }
          return http.Response('[{"id":"task_partial_1"}]', 200, headers: {'content-type': 'application/json'});
        }
        return http.Response('', 404);
      });

      // First run: photo 0 uploads, photo 1 fails, patch fails
      final ok1 = await DailyTaskService.completeTask(
        taskId: 'task_partial_1',
        jamSelesai: '14:20',
        localPhotoPaths: [photo0.path, photo1.path],
      );
      expect(ok1, isFalse);
      expect(uploadPhoto0Count, equals(1));
      expect(uploadPhoto1Count, equals(1));

      // Retry: photo 1 is retried, photo 0 is NOT uploaded again!
      failPhoto1 = false;
      patchShouldFail = false;
      final flushed = await DailyTaskService.flushPendingCompletions();
      expect(flushed, equals(1));

      expect(uploadPhoto0Count, equals(1)); // Skipped on retry!
      expect(uploadPhoto1Count, equals(2)); // Retried!

      final finalUrls = (jsonDecode(lastPatchBody!)['foto_bukti'] as List).cast<String>();
      expect(finalUrls, hasLength(2));
      expect(finalUrls[0], startsWith('https://'));
      expect(finalUrls[1], startsWith('https://'));
    });
  });
}
