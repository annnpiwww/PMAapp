import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bssparking_timemark/data/models/submission_model.dart';
import 'package:bssparking_timemark/data/models/template_model.dart';
import 'package:bssparking_timemark/data/services/ai_vision_service.dart';
import 'package:bssparking_timemark/features/camera/widgets/sop_verification_modal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final template = TemplateModel(
    id: 'tpl_retry_01',
    nama: 'Teknisi',
    deskripsi: 'Verifikasi seragam resmi BSS Parking',
    jenis: TemplateCategory.absensi,
    sopCriteria: ['Seragam resmi BSS Parking bersih dan rapi'],
    contohFotoDescriptions: ['Foto full body tegap menghadap kamera'],
    createdBy: 'HO BSS Parking Pusat',
    updatedAt: DateTime.now(),
  );

  final fallback = AiVerificationResult(
    status: VerificationStatus.perluCekManual,
    confidenceScore: 0.0,
    alasan:
        'Koneksi ke AI gagal (HTTP 503). Foto dialihkan untuk Cek Manual oleh Supervisor.',
    poinLolos: const [],
    poinGagal: const ['Koneksi Server Vision Terganggu / Gagal'],
    providerName: 'AI Fallback Alert (Google Gemini)',
    isFallback: true,
  );

  Widget buildModal({
    required AiVerificationResult result,
    Future<AiVerificationResult> Function()? onRetryAi,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SopVerificationModal(
          template: template,
          result: result,
          kodeVerifikasi: 'VERIF-RETRY-1',
          onRetake: () {},
          onSave: () {},
          onCancel: () {},
          onRetryAi: onRetryAi,
        ),
      ),
    );
  }

  testWidgets('AI gagal -> tombol analisa ulang memakai foto yang sama',
      (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    var retryCalls = 0;
    final pending = Completer<AiVerificationResult>();
    await tester.pumpWidget(buildModal(
      result: fallback,
      onRetryAi: () {
        retryCalls++;
        return pending.future;
      },
    ));
    await tester.pumpAndSettle();

    expect(find.text('Verifikasi AI terputus'), findsOneWidget);
    expect(find.text('Analisa Ulang Foto Ini dengan AI'), findsOneWidget);

    await tester.tap(find.text('Analisa Ulang Foto Ini dengan AI'));
    await tester.pump();
    expect(find.text('Menganalisa ulang foto...'), findsOneWidget);

    pending.complete(AiVerificationResult(
      status: VerificationStatus.sesuai,
      confidenceScore: 0.93,
      alasan: 'Foto memenuhi SOP.',
      poinLolos: const ['Seragam rapi'],
      poinGagal: const [],
      providerName: 'Gemini',
    ));
    await tester.pumpAndSettle();

    expect(retryCalls, 1);
    expect(find.text('Foto lolos validasi'), findsOneWidget);
    expect(find.text('Simpan & Kirim Laporan'), findsOneWidget);
    expect(find.text('Verifikasi AI terputus'), findsNothing);
  });

  testWidgets('AI masih gagal -> hasil lama dipertahankan, tombol bisa dicoba lagi',
      (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildModal(
      result: fallback,
      onRetryAi: () async => fallback,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Analisa Ulang Foto Ini dengan AI'));
    await tester.pumpAndSettle();

    expect(find.text('Verifikasi AI terputus'), findsOneWidget);
    expect(find.text('Analisa Ulang Foto Ini dengan AI'), findsOneWidget);
  });

  testWidgets('Tanpa callback retry (mis. GPS mock) -> tombol tidak muncul',
      (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildModal(result: fallback));
    await tester.pumpAndSettle();

    expect(find.text('Verifikasi AI terputus'), findsOneWidget);
    expect(find.text('Analisa Ulang Foto Ini dengan AI'), findsNothing);
  });

  testWidgets(
      'AI tidak bisa memastikan (perluCekManual tanpa isFallback) -> tombol tetap muncul',
      (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() => tester.view.reset());

    final ambiguous = AiVerificationResult(
      status: VerificationStatus.perluCekManual,
      confidenceScore: 0.5,
      alasan: 'Foto tidak dapat diverifikasi otomatis: no identification',
      poinLolos: const [],
      poinGagal: const [],
      providerName: 'Google Gemini',
    );

    await tester.pumpWidget(buildModal(
      result: ambiguous,
      onRetryAi: () async => ambiguous,
    ));
    await tester.pumpAndSettle();

    expect(find.text('Verifikasi AI terputus'), findsOneWidget);
    expect(find.text('Analisa Ulang Foto Ini dengan AI'), findsOneWidget);
  });
}
