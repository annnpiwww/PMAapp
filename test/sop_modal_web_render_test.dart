import 'dart:typed_data';
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

  testWidgets('SopVerificationModal renders cleanly inside showModalBottomSheet', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() => tester.view.reset());

    final template = TemplateModel(
      id: 'tpl_absensi',
      nama: 'Absensi Teknisi',
      deskripsi: 'Template Absensi',
      jenis: TemplateCategory.absensi,
      sopPoints: [],
      createdBy: 'admin',
      updatedAt: DateTime.now(),
    );

    final result = AiVerificationResult(
      status: VerificationStatus.sesuai,
      confidenceScore: 0.95,
      alasan: 'Semua SOP terpenuhi dengan baik dan rapi.',
      poinLolos: ['Seragam Rapi', 'ID Card Terpasang'],
      poinGagal: [],
      providerName: 'Gemini Flash',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () {
                showModalBottomSheet(
                  context: ctx,
                  isScrollControlled: true,
                  isDismissible: false,
                  enableDrag: false,
                  backgroundColor: Colors.transparent,
                  builder: (modalCtx) => SopVerificationModal(
                    template: template,
                    result: result,
                    kodeVerifikasi: 'VERIF-TEST-1234',
                    imagePath: 'blob:https://bssparking.trakingduit.my.id/test-blob-123',
                    onRetake: () {},
                    onSave: () {},
                    onCancel: () {},
                  ),
                );
              },
              child: const Text('Open Modal'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Modal'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(SopVerificationModal), findsOneWidget);
    expect(find.text('SELESAI VERIFIKASI'), findsOneWidget);
    expect(find.text('VERIF-TEST-1234'), findsOneWidget);
  });

  testWidgets('SopVerificationModal renders cleanly with imageBytes on Web/Mobile', (tester) async {
    final template = TemplateModel(
      id: 'tpl_absensi',
      nama: 'Absensi Teknisi',
      deskripsi: 'Template Absensi',
      jenis: TemplateCategory.absensi,
      sopPoints: [],
      createdBy: 'admin',
      updatedAt: DateTime.now(),
    );

    final result = AiVerificationResult(
      status: VerificationStatus.sesuai,
      confidenceScore: 0.90,
      alasan: 'Semua SOP terpenuhi.',
      poinLolos: ['Seragam'],
      poinGagal: [],
      providerName: 'Gemini',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SopVerificationModal(
            template: template,
            result: result,
            kodeVerifikasi: 'BYTES-1234',
            imageBytes: Uint8List.fromList([1, 2, 3]),
            onRetake: () {},
            onSave: () {},
            onCancel: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(SopVerificationModal), findsOneWidget);
    expect(find.text('BYTES-1234'), findsOneWidget);
    expect(find.text('Cek Kejernihan Foto'), findsOneWidget);
  });
}
