import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bssparking_timemark/data/models/daily_task_model.dart';
import 'package:bssparking_timemark/data/services/daily_task_service.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  group('DailyTaskService Offline-First Resilience Tests', () {
    test('createTask falls back to local creation when server returns error or is offline', () async {
      final task = await DailyTaskService.createTask(
        tanggal: '2026-10-16',
        teknisiNama: 'Ryan Lumasuge',
        posName: 'PBM',
        posTag: 'PBM',
        judul: 'Pengecekan Barrier Gate 1 & 2',
        deskripsi: 'Cek kondisi fisik dan sensor loop',
        kategori: 'khusus',
      );

      // Task must never be null even if network / PocketBase fails
      expect(task, isNotNull);
      expect(task!.judul, equals('Pengecekan Barrier Gate 1 & 2'));
      expect(task.teknisiNama, equals('Ryan Lumasuge'));
      expect(task.posName, equals('PBM'));
      expect(task.id, startsWith('local_'));
      expect(task.status, equals(TaskStatus.pending));

      // Must be saved in local cache
      final cached = DailyTaskService.getCachedTasksLocally();
      expect(cached.any((t) => t.id == task.id), isTrue);

      // Must be enqueued in pending creation queue
      final queue = StorageService.getStringList('pending_daily_task_creations_v1');
      expect(queue, isNotNull);
      expect(queue!.length, equals(1));
      final enqueued = jsonDecode(queue.first);
      expect(enqueued['localId'], equals(task.id));
      expect(enqueued['payload']['judul'], equals('Pengecekan Barrier Gate 1 & 2'));
    });

    test('getAllTasksToday returns cached local tasks when server fails', () async {
      // Create two local tasks
      final t1 = await DailyTaskService.createTask(
        tanggal: '2026-10-16',
        teknisiNama: 'Ryan Lumasuge',
        posName: 'PBM',
        posTag: 'PBM',
        judul: 'Tugas Rutin 1',
      );
      final t2 = await DailyTaskService.createTask(
        tanggal: '2026-10-16',
        teknisiNama: 'Raldy Sangkop',
        posName: 'PBM',
        posTag: 'PBM',
        judul: 'Tugas Rutin 2',
      );

      expect(t1, isNotNull);
      expect(t2, isNotNull);

      // Fetch for today - should return both tasks despite server 400 in test environment
      final allTasks = await DailyTaskService.getAllTasksToday('2026-10-16');
      expect(allTasks.length, greaterThanOrEqualTo(2));
      expect(allTasks.any((t) => t.id == t1!.id), isTrue);
      expect(allTasks.any((t) => t.id == t2!.id), isTrue);
    });

    test('getTasksForTeknisi filters cached local tasks by technician when offline', () async {
      await DailyTaskService.createTask(
        tanggal: '2026-10-16',
        teknisiNama: 'Ryan Lumasuge',
        posName: 'PBM',
        posTag: 'PBM',
        judul: 'Tugas Khusus Ryan',
      );
      await DailyTaskService.createTask(
        tanggal: '2026-10-16',
        teknisiNama: 'Raldy Sangkop',
        posName: 'PBM',
        posTag: 'PBM',
        judul: 'Tugas Khusus Raldy',
      );

      final ryanTasks = await DailyTaskService.getTasksForTeknisi(
        tanggal: '2026-10-16',
        teknisiNama: 'Ryan Lumasuge',
      );

      expect(ryanTasks.any((t) => t.judul == 'Tugas Khusus Ryan'), isTrue);
      expect(ryanTasks.any((t) => t.judul == 'Tugas Khusus Raldy'), isFalse);
    });

    test('completeTask on local task marks it completed locally and updates offline queue', () async {
      final task = await DailyTaskService.createTask(
        tanggal: '2026-10-16',
        teknisiNama: 'Ryan Lumasuge',
        posName: 'PBM',
        posTag: 'PBM',
        judul: 'Tugas Siap Selesai',
      );

      expect(task, isNotNull);
      expect(task!.status, equals(TaskStatus.pending));

      final success = await DailyTaskService.completeTask(
        taskId: task.id,
        jamSelesai: '10:30 WITA',
        catatan: 'Pekerjaan beres dengan lancar',
      );

      expect(success, isTrue);

      // Verify local cache updated
      final cached = DailyTaskService.getCachedTasksLocally();
      final updated = cached.firstWhere((t) => t.id == task.id);
      expect(updated.isCompleted, isTrue);
      expect(updated.jamSelesai, equals('10:30 WITA'));
      expect(updated.catatanTeknisi, equals('Pekerjaan beres dengan lancar'));

      // Verify offline queue item payload updated with completed status
      final queue = StorageService.getStringList('pending_daily_task_creations_v1')!;
      final queuedItem = jsonDecode(queue.first);
      expect(queuedItem['payload']['status'], equals('completed'));
      expect(queuedItem['payload']['jam_selesai'], equals('10:30 WITA'));
      expect(queuedItem['payload']['catatan_teknisi'], equals('Pekerjaan beres dengan lancar'));
    });
  });
}
