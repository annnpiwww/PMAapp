import 'package:flutter_test/flutter_test.dart';
import 'package:bssparking_timemark/data/services/notification_service.dart';
import 'package:bssparking_timemark/data/services/absensi_setup_service.dart';
import 'package:bssparking_timemark/data/models/daily_task_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NotificationService & Shift Notification Logic', () {
    test('NotificationService singleton instance is not null', () {
      final service = NotificationService.instance;
      expect(service, isNotNull);
    });

    test('Shift duration calculation for notifications: Shift 2.2 is 4 hours', () {
      final dur = AbsensiSetupService.getMinimumWorkDuration('Shift 2.2 (10:00 - 14:00)');
      expect(dur.inHours, equals(4));
    });

    test('Shift duration calculation for notifications: Shift 2 is 8 hours', () {
      final dur = AbsensiSetupService.getMinimumWorkDuration('Shift 2 (10:00 - 18:00)');
      expect(dur.inHours, equals(8));
    });

    test('Shift duration calculation for notifications: Shift 3 is 8 hours', () {
      final dur = AbsensiSetupService.getMinimumWorkDuration('Shift 3 (14:00 - 22:00)');
      expect(dur.inHours, equals(8));
    });

    test('Remaining work time is zero or positive appropriately', () {
      final checkIn = DateTime(2026, 9, 13, 10, 0);
      final current = DateTime(2026, 9, 13, 12, 0);
      final remaining = AbsensiSetupService.getRemainingWorkTime(
        shift: 'Shift 2.2 (10:00 - 14:00)',
        checkInTime: checkIn,
        currentTime: current,
      );
      expect(remaining, isNotNull);
      expect(remaining!.inHours, equals(2));
    });

    test('Daily Tasks notification signature deduplicates identical pending tasks and prevents spam', () async {
      final service = NotificationService.instance;
      service.resetDailyTasksSignatureForTesting();

      final tasks = [
        DailyTaskModel(
          id: 'task_1',
          judul: 'Cek Barrier Gate',
          posName: 'Pos 1',
          posTag: 'P1',
          tanggal: '2026-10-05',
          teknisiId: 'tek_1',
          teknisiNama: 'Ryan',
        ),
        DailyTaskModel(
          id: 'task_2',
          judul: 'Bersihkan Scanner',
          posName: 'Pos 1',
          posTag: 'P1',
          tanggal: '2026-10-05',
          teknisiId: 'tek_1',
          teknisiNama: 'Ryan',
        ),
      ];

      await service.showDailyTasksNotification(tasks: tasks);
      expect(service.lastDailyTasksSignature, equals('2_task_1,task_2'));

      // Panggilan kedua dengan list tugas yang identik tidak mengubah signature (deduplicated)
      await service.showDailyTasksNotification(tasks: tasks);
      expect(service.lastDailyTasksSignature, equals('2_task_1,task_2'));

      // Saat salah satu tugas selesai, signature berubah
      final updatedTasks = [
        tasks[0].copyWith(status: TaskStatus.completed),
        tasks[1],
      ];
      await service.showDailyTasksNotification(tasks: updatedTasks, force: true);
      expect(service.lastDailyTasksSignature, equals('1_task_2'));

      // Saat semua tugas selesai, notifikasi dibatalkan dan signature dibersihkan
      final allCompleted = [
        tasks[0].copyWith(status: TaskStatus.completed),
        tasks[1].copyWith(status: TaskStatus.completed),
      ];
      await service.showDailyTasksNotification(tasks: allCompleted);
      expect(service.lastDailyTasksSignature, isNull);
    });
  });
}
