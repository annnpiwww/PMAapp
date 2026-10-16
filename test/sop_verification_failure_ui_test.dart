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

  final template = TemplateModel(
    id: 'tpl_absensi_01',
    nama: 'Teknisi',
    deskripsi: 'Verifikasi seragam resmi BSS Parking',
    jenis: TemplateCategory.absensi,
    sopCriteria: [
      'Wajah terlihat jelas tanpa masker / kacamata',
      'Seragam resmi BSS Parking bersih, rapi & dimasukkan dalam celana',
    ],
    contohFotoDescriptions: ['Foto full body tegap menghadap kamera'],
    createdBy: 'HO BSS Parking Pusat',
    updatedAt: DateTime.now(),
  );

  testWidgets('State gagal menampilkan banner, daftar perbaikan, tips, dan 2 CTA',
      (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() => tester.view.reset());

    bool retakeCalled = false;
    final result = AiVerificationResult(
      status: VerificationStatus.tidakSesuai,
      confidenceScore: 0.35,
      alasan: 'Foto belum menampilkan teknisi, atribut grooming tidak bisa diverifikasi.',
      poinLolos: [],
      poinGagal: ['Wajah dan tubuh teknisi tidak terlihat'],
      providerName: 'Gemini Flash',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SopVerificationModal(
            template: template,
            result: result,
            kodeVerifikasi: 'VERIF-FAIL-1',
            onRetake: () => retakeCalled = true,
            onSave: () {},
            onCancel: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Header + banner status.
    expect(find.text('Validasi Grooming'), findsOneWidget);
    expect(find.text('Foto 1 dari 1'), findsOneWidget);
    expect(find.text('Foto belum lolos validasi'), findsOneWidget);
    expect(find.text('1 hal perlu diperbaiki'), findsOneWidget);

    // Kartu alasan AI + daftar kriteria gagal + tips dari template.
    expect(find.text('Alasan AI menolak foto'), findsOneWidget);
    expect(find.text('YANG PERLU DIPERBAIKI'), findsOneWidget);
    expect(find.text('Tips agar lolos'), findsOneWidget);
    expect(find.text('Foto full body tegap menghadap kamera'), findsOneWidget);

    // Confidence AI tidak lagi ditampilkan sebagai status kelulusan.
    expect(find.textContaining('Tingkat Keyakinan'), findsNothing);

    // Opsi buka penjelasan: standar SOP asli dari template.
    await tester.tap(find.text('Wajah dan tubuh teknisi tidak terlihat'));
    await tester.pumpAndSettle();
    expect(
      find.text('Standar SOP: Wajah terlihat jelas tanpa masker / kacamata'),
      findsOneWidget,
    );

    // CTA utama oranye + sekunder outline, keduanya berfungsi.
    await tester.ensureVisible(find.text('Lihat contoh foto'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lihat contoh foto'));
    await tester.pumpAndSettle();
    expect(find.text('Contoh Foto yang Benar'), findsOneWidget);
    await tester.tap(find.text('Tutup'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Foto Ulang'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Foto Ulang'));
    await tester.pumpAndSettle();
    expect(retakeCalled, isTrue);
  });
}
