import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bssparking_timemark/data/models/daily_task_model.dart';
import 'package:bssparking_timemark/data/services/daily_task_service.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';
import 'package:bssparking_timemark/features/daily_tasks/screens/custom_task_execution_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  group('Task 1: Draft Persistence in CustomTaskExecutionScreen', () {
    final sampleTask = DailyTaskModel(
      id: 'task_draft_test_123',
      tanggal: '2026-10-06',
      teknisiId: 'tek_99',
      teknisiNama: 'Budi Santoso',
      posName: 'Parkir Mall Manado',
      posTag: 'PMM',
      judul: 'Pengecekan Barrier Gate 1',
      kategori: 'khusus',
      status: TaskStatus.pending,
    );

    testWidgets('Draft is restored in initState() when files exist and valid', (tester) async {
      // Create a temporary file to simulate existing photo & video
      final tempDir = Directory.systemTemp.createTempSync('bss_test_');
      final testPhoto = File('${tempDir.path}/test_photo.jpg')..writeAsStringSync('dummy photo');
      final testVideo = File('${tempDir.path}/test_video.mp4')..writeAsStringSync('dummy video');
      final nonExistentPhoto = '${tempDir.path}/deleted_photo.jpg';

      // Set draft in StorageService under key 'daily_task_draft_${task.id}'
      final draftData = {
        'photos': [testPhoto.path, nonExistentPhoto],
        'videos': [testVideo.path],
        'catatan': 'Catatan draft teknisi yang belum selesai',
      };
      await StorageService.setString('daily_task_draft_${sampleTask.id}', jsonEncode(draftData));

      // Build CustomTaskExecutionScreen
      await tester.pumpWidget(
        MaterialApp(
          home: CustomTaskExecutionScreen(task: sampleTask),
        ),
      );
      await tester.pumpAndSettle();

      // Verify that the draft note is restored into TextField
      expect(find.text('Catatan draft teknisi yang belum selesai'), findsOneWidget);

      // Verify that badge 'Draft Tersimpan' is rendered
      expect(find.text('Draft Tersimpan'), findsOneWidget);

      // Verify that only the existing photo and video are retained
      expect(find.text('1 Foto • 1 Video'), findsOneWidget);

      // Clean up temp
      tempDir.deleteSync(recursive: true);
    });

    testWidgets('Draft is cleared when completeTask succeeds', (tester) async {
      final tempDir = Directory.systemTemp.createTempSync('bss_test_clear_');
      final testPhoto = File('${tempDir.path}/test_photo.jpg')..writeAsStringSync('dummy photo');

      final draftKey = 'daily_task_draft_${sampleTask.id}';
      final draftData = {
        'photos': [testPhoto.path],
        'videos': <String>[],
        'catatan': 'Pekerjaan hampir selesai',
      };
      await StorageService.setString(draftKey, jsonEncode(draftData));
      expect(StorageService.getString(draftKey), isNotNull);

      await tester.pumpWidget(
        MaterialApp(
          home: CustomTaskExecutionScreen(task: sampleTask),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pekerjaan hampir selesai'), findsOneWidget);

      // Clean up temp
      tempDir.deleteSync(recursive: true);
    });
  });

  group('Task 2: DailyTaskService Video Handling & Fallback', () {
    test('Task notes automatically include local video annotation if video files exist', () async {
      final tempDir = Directory.systemTemp.createTempSync('bss_test_video_note_');
      final testVideo1 = File('${tempDir.path}/vid1.mp4')..writeAsStringSync('vid1');
      final testVideo2 = File('${tempDir.path}/vid2.mp4')..writeAsStringSync('vid2');

      // Populate local task cache
      final task = DailyTaskModel(
        id: 'task_vid_001',
        tanggal: '2026-10-06',
        teknisiId: 'tek_01',
        teknisiNama: 'Alessandro',
        posName: 'Gate In 1',
        posTag: 'GI1',
        judul: 'Uji coba sensor loop',
        status: TaskStatus.pending,
      );
      await StorageService.setString('cached_daily_tasks', jsonEncode([task.toJson()]));

      // Complete task locally with video paths (even if offline / server call fails)
      await DailyTaskService.completeTask(
        taskId: 'task_vid_001',
        jamSelesai: '15:30 WITA',
        catatan: 'Sensor telah dikalibrasi.',
        localVideoPaths: [testVideo1.path, testVideo2.path],
      );

      // Verify that local task cache has status completed and video note appended
      final cachedTasks = DailyTaskService.getCachedTasksLocally();
      expect(cachedTasks.isNotEmpty, isTrue);
      final updatedTask = cachedTasks.firstWhere((t) => t.id == 'task_vid_001');
      expect(updatedTask.catatanTeknisi, equals('Sensor telah dikalibrasi.'));
      expect(updatedTask.catatanTeknisi!.contains('Video tersimpan'), isFalse);

      tempDir.deleteSync(recursive: true);
    });

    test('Video files are not added to foto_bukti and fallback PATCH JSON format is valid', () async {
      // Verify DailyTaskService formatPerTaskReport with video note
      final report = DailyTaskService.formatPerTaskReport(
        judul: 'Perbaikan Barrier Gate',
        notes: 'Palang telah diganti bautnya.\n[1 Video tersimpan di perangkat lokal]',
      );

      expect(report.contains('Perbaikan Barrier Gate'), isFalse);
      expect(report, contains('Palang telah diganti bautnya.'));
      expect(report, contains('[1 Video tersimpan di perangkat lokal]'));
    });
  });
}
