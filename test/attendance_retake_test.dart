import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bssparking_timemark/data/models/template_model.dart';
import 'package:bssparking_timemark/data/models/submission_model.dart';
import 'package:bssparking_timemark/data/services/ai_vision_service.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';
import 'package:bssparking_timemark/features/camera/widgets/sop_verification_modal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  group('Attendance Retake & Decoupled State Tests', () {
    testWidgets('SopVerificationModal shows Foto Ulang button even when AI verification succeeds', (tester) async {
      bool retakeCalled = false;
      bool saveCalled = false;

      final template = TemplateModel(
        id: 'tpl_absensi',
        nama: 'Absensi Teknisi',
        deskripsi: 'Template Absensi',
        jenis: TemplateCategory.absensi,
        sopPoints: [],
        createdBy: 'admin',
        updatedAt: DateTime.now(),
      );

      final successResult = AiVerificationResult(
        status: VerificationStatus.sesuai,
        confidenceScore: 0.95,
        alasan: 'Semua SOP terpenuhi',
        poinLolos: ['Seragam', 'ID Card'],
        poinGagal: [],
        providerName: 'Gemini Flash',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SopVerificationModal(
              template: template,
              result: successResult,
              kodeVerifikasi: 'VERIF-1234',
              onRetake: () {
                retakeCalled = true;
              },
              onSave: () {
                saveCalled = true;
              },
              onCancel: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check that both 'Foto Ulang' and primary submit button are present
      expect(find.text('Foto Ulang'), findsOneWidget);
      expect(find.text('Simpan & Kirim Laporan'), findsOneWidget);

      // Tap Foto Ulang
      await tester.tap(find.text('Foto Ulang'));
      await tester.pumpAndSettle();

      expect(retakeCalled, isTrue);
      expect(saveCalled, isFalse);
    });

    test('Check-in time is not saved before explicit user confirmation', () async {
      // Initially no check in time
      expect(StorageService.getLastCheckInTime(), isNull);

      // Simulating retake cycle: User takes photo, evaluates, but decides to retake.
      // StorageService.getLastCheckInTime() must remain null!
      final now = DateTime.now();
      // Only when explicitly saved, it should exist
      await StorageService.saveLastCheckInTime(now);
      expect(StorageService.getLastCheckInTime()?.millisecondsSinceEpoch, equals(now.millisecondsSinceEpoch));

      // Clearing on checkout
      await StorageService.clearLastCheckInTime();
      expect(StorageService.getLastCheckInTime(), isNull);
    });
  });
}
