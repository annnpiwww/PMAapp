import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bssparking_timemark/data/models/submission_model.dart';
import 'package:bssparking_timemark/data/repositories/submission_repository.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';
import 'package:bssparking_timemark/features/history/screens/gallery_screen.dart';
import 'package:bssparking_timemark/features/maintenance/widgets/photo_preview_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late File testFile1;
  late File testFile2;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();

    tempDir = await Directory.systemTemp.createTemp('gallery_test_');
    testFile1 = File('${tempDir.path}/photo1.jpg');
    await testFile1.writeAsBytes([1, 2, 3]);
    testFile2 = File('${tempDir.path}/photo2.jpg');
    await testFile2.writeAsBytes([4, 5, 6]);

    await SubmissionRepository.instance.clearAll();
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Gallery Multi-Select & Download Tests', () {
    testWidgets('GalleryScreen shows empty state when no photos exist', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: GalleryScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Belum Ada Foto Tersimpan'), findsOneWidget);
      expect(find.text('Pilih'), findsNothing);
    });

    testWidgets('GalleryScreen enters multi-select mode and toggles selection', (tester) async {
      // Add mock submissions with photos
      final sub1 = SubmissionModel(
        id: 'sub_1',
        templateId: 'tpl_absensi',
        templateName: 'Absensi Masuk',
        userId: 'u1',
        userName: 'Farhan',
        userNpp: 'BSS-001',
        posId: 'pos_1',
        posName: 'Pos 1 Megamas',
        cabangName: 'Megamas',
        imagePath: testFile1.path,
        timestampCapture: DateTime.now(),
        lat: 1.0,
        lng: 1.0,
        akurasiMeter: 2.0,
        kodeVerifikasi: 'V1',
        status: VerificationStatus.sesuai,
        alasanAI: 'OK',
        poinGagal: [],
        poinLolos: [],
        createdAt: DateTime.now(),
      );

      final sub2 = SubmissionModel(
        id: 'sub_2',
        templateId: 'tpl_absensi',
        templateName: 'Absensi Pulang',
        userId: 'u1',
        userName: 'Farhan',
        userNpp: 'BSS-001',
        posId: 'pos_1',
        posName: 'Pos 1 Megamas',
        cabangName: 'Megamas',
        imagePath: testFile2.path,
        timestampCapture: DateTime.now().add(const Duration(hours: 4)),
        lat: 1.0,
        lng: 1.0,
        akurasiMeter: 2.0,
        kodeVerifikasi: 'V2',
        status: VerificationStatus.sesuai,
        alasanAI: 'OK',
        poinGagal: [],
        poinLolos: [],
        createdAt: DateTime.now().add(const Duration(hours: 4)),
      );

      await SubmissionRepository.instance.addSubmission(sub1);
      await SubmissionRepository.instance.addSubmission(sub2);

      await tester.pumpWidget(
        const MaterialApp(
          home: GalleryScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Pilih button should be visible
      expect(find.text('Pilih'), findsOneWidget);

      // Tap Pilih button
      await tester.tap(find.text('Pilih'));
      await tester.pumpAndSettle();

      // Multi-select mode activated
      expect(find.text('0 Terpilih'), findsOneWidget);
      expect(find.text('Pilih Semua'), findsOneWidget);
      expect(find.text('Batal'), findsOneWidget);
      expect(find.text('Download (0 Foto)'), findsOneWidget);

      // Tap Pilih Semua
      await tester.tap(find.text('Pilih Semua'));
      await tester.pumpAndSettle();

      expect(find.text('2 Terpilih'), findsOneWidget);
      expect(find.text('Batal Semua'), findsOneWidget);
      expect(find.text('Download (2 Foto)'), findsOneWidget);

      // Tap Batal
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();

      // Should exit multi-select mode
      expect(find.text('0 Terpilih'), findsNothing);
      expect(find.text('Pilih'), findsOneWidget);
    });

    testWidgets('PhotoPreviewDialog contains download icon button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PhotoPreviewDialog(
              imagePath: testFile1.path,
              title: 'Foto Barrier Gate',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check download icon exists
      expect(find.byIcon(Icons.download_rounded), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    });
  });
}
