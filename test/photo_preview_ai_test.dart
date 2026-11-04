import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as imglib;
import 'package:flutter_test/flutter_test.dart';
import 'package:bssparking_timemark/data/models/maintenance_submission.dart';
import 'package:bssparking_timemark/data/models/submission_model.dart';
import 'package:bssparking_timemark/data/services/ai_vision_service.dart';
import 'package:bssparking_timemark/features/maintenance/widgets/photo_preview_dialog.dart';

void main() {
  late Directory tmpDir;
  late String photoPath;

  setUpAll(() {
    tmpDir = Directory.systemTemp.createTempSync('preview_ai_test');
    final img = imglib.Image(width: 64, height: 64);
    imglib.fill(img, color: imglib.ColorRgb8(200, 120, 60));
    photoPath = '${tmpDir.path}/foto.png';
    File(photoPath).writeAsBytesSync(imglib.encodePng(img));
  });

  tearDownAll(() => tmpDir.deleteSync(recursive: true));

  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  AiVerificationResult result(VerificationStatus status) => AiVerificationResult(
        status: status,
        alasan: 'Hasil analisa uji',
        poinGagal: const [],
        poinLolos: const [],
        confidenceScore: 0.9,
        providerName: 'Google Gemini',
      );

  testWidgets('Tanpa callback onAnalyze -> tombol otak AI tetap muncul',
      (tester) async {
    await tester.pumpWidget(wrap(
      const PhotoPreviewDialog(imagePath: '', title: 'Point Uji'),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('analyze-photo-button')), findsOneWidget);
    expect(find.byIcon(Icons.download_rounded), findsOneWidget);
  });

  testWidgets('Dengan callback onAnalyze -> tombol otak AI muncul di samping download',
      (tester) async {
    await tester.pumpWidget(wrap(
      PhotoPreviewDialog(
        imagePath: photoPath,
        title: 'Point Uji',
        onAnalyze: (base64) async => result(VerificationStatus.sesuai),
      ),
    ));
    await tester.pump();

    expect(find.byKey(const Key('analyze-photo-button')), findsOneWidget);
    expect(find.byIcon(Icons.download_rounded), findsOneWidget);
  });

  testWidgets('base64 tersimpan di memori dipakai tanpa baca file',
      (tester) async {
    String? received;
    await tester.pumpWidget(wrap(
      PhotoPreviewDialog(
        imagePath: '',
        title: 'Point Uji',
        pointResult: const MaintenancePointResult(
          pointId: 'p1',
          label: 'Point Uji',
          imageBase64: 'stored-b64',
        ),
        onAnalyze: (base64) async {
          received = base64;
          return result(VerificationStatus.tidakSesuai);
        },
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.psychology_rounded));
    await tester.pumpAndSettle();

    expect(received, 'stored-b64');
    // Hasil analisa ulang tampil sebagai modal, bukan cuma SnackBar.
    expect(find.text('Hasil Analisa AI'), findsOneWidget);
    expect(find.text('TIDAK SESUAI'), findsWidgets);
    expect(find.text('Hasil analisa uji'), findsOneWidget);
  });

  testWidgets('Foto gagal dibaca -> SnackBar jujur, callback tidak dipanggil',
      (tester) async {
    var called = false;
    await tester.pumpWidget(wrap(
      PhotoPreviewDialog(
        imagePath: '',
        title: 'Point Uji',
        onAnalyze: (base64) async {
          called = true;
          return result(VerificationStatus.sesuai);
        },
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.psychology_rounded));
    await tester.pumpAndSettle();

    expect(called, isFalse);
    expect(
      find.text('Foto tidak bisa dibaca ulang dari perangkat ini.'),
      findsOneWidget,
    );
  });

  testWidgets('Modal loading menampilkan langkah lalu hasil analisa',
      (tester) async {
    final completer = Completer<AiVerificationResult>();
    await tester.pumpWidget(wrap(
      PhotoPreviewDialog(
        imagePath: '',
        title: 'Point Uji',
        pointResult: const MaintenancePointResult(
          pointId: 'p1',
          label: 'Point Uji',
          imageBase64: 'stored-b64',
        ),
        onAnalyze: (_) => completer.future,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('analyze-photo-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Analisa AI'), findsOneWidget);
    expect(find.text('Foto disiapkan'), findsOneWidget);
    expect(find.text('Mengirim foto ke server AI'), findsOneWidget);
    expect(find.textContaining('Jangan tutup halaman ini'), findsOneWidget);

    completer.complete(result(VerificationStatus.sesuai));
    await tester.pumpAndSettle();

    expect(find.text('Hasil Analisa AI'), findsOneWidget);
    expect(find.text('SESUAI SOP'), findsWidgets);
  });

  testWidgets('Server gagal (fallback) -> modal error + Coba Lagi, bukan hasil',
      (tester) async {
    await tester.pumpWidget(wrap(
      PhotoPreviewDialog(
        imagePath: '',
        title: 'Point Uji',
        pointResult: const MaintenancePointResult(
          pointId: 'p1',
          label: 'Point Uji',
          imageBase64: 'stored-b64',
        ),
        onAnalyze: (_) async => AiVerificationResult(
          status: VerificationStatus.perluCekManual,
          alasan:
              'Koneksi ke AI gagal (HTTP 503). Foto dialihkan untuk Cek Manual oleh Supervisor.',
          poinGagal: const ['Koneksi Server Vision Terganggu / Gagal'],
          poinLolos: const [],
          confidenceScore: 0.0,
          providerName: 'AI Fallback Alert',
          isFallback: true,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('analyze-photo-button')));
    await tester.pumpAndSettle();

    expect(find.text('Koneksi ke server AI gagal'), findsOneWidget);
    expect(find.text('Coba Lagi'), findsOneWidget);
    expect(find.text('Hasil Analisa AI'), findsNothing);
  });
}
