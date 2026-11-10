import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bssparking_timemark/core/constants/app_theme.dart';
import 'package:bssparking_timemark/data/models/maintenance_submission.dart';
import 'package:bssparking_timemark/data/models/submission_model.dart';
import 'package:bssparking_timemark/data/services/ai_vision_service.dart';
import 'package:bssparking_timemark/features/maintenance/widgets/ai_result_dialog.dart';
import 'package:bssparking_timemark/features/maintenance/widgets/photo_preview_dialog.dart';

Future<void> _loadAppFonts() async {
  final fontLoader = FontLoader('Figtree');
  for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
    final file = File('assets/fonts/Figtree-$weight.ttf');
    if (file.existsSync()) {
      final bytes = file.readAsBytesSync();
      fontLoader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
  }
  await fontLoader.load();

  final iconFile = File(
    '/home/annnpii/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (iconFile.existsSync()) {
    final iconLoader = FontLoader('MaterialIcons');
    final iconBytes = iconFile.readAsBytesSync();
    iconLoader.addFont(Future.value(ByteData.view(iconBytes.buffer)));
    await iconLoader.load();
  }
}

Future<void> _saveBoundaryAsPng(
  WidgetTester tester,
  GlobalKey key,
  String path,
) async {
  final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  if (boundary == null) throw Exception('RenderRepaintBoundary not found for $path');

  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) throw Exception('Failed to get png byteData for $path');

    final file = File(path);
    file.parent.createSync(recursive: true);
    await file.writeAsBytes(byteData.buffer.asUint8List());
  });
}

const _k1x1PngBase64 =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _loadAppFonts();
  });

  group('Tiket AI Dialogs Redesign Tests & Screenshots', () {
    testWidgets('Capture 13a preview dialog light 390x844', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repaintKey = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: repaintKey,
          child: MediaQuery(
            data: const MediaQueryData(
              size: Size(390, 844),
              padding: EdgeInsets.only(top: 47.0, bottom: 34.0),
            ),
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              debugShowCheckedModeBanner: false,
              home: PhotoPreviewDialog(
                imagePath: _k1x1PngBase64,
                title: 'Pemeriksaan Palang Barrier Gate',
                pointResult: const MaintenancePointResult(
                  pointId: 'p1',
                  label: 'Pemeriksaan Palang Barrier Gate',
                  imagePath: _k1x1PngBase64,
                  status: PointStatus.tidakSesuai,
                  alasan: 'Baut kendor dan posisi palang miring 15 derajat',
                  confidence: 0.94,
                  providerName: 'AI Vision',
                ),
                onRetake: () {},
                onAnalyze: (_) async => AiVerificationResult(
                  status: VerificationStatus.tidakSesuai,
                  alasan: 'Baut kendor',
                  confidenceScore: 0.94,
                  poinGagal: const [],
                  poinLolos: const [],
                  providerName: 'AI Vision',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Pemeriksaan Palang Barrier Gate'), findsOneWidget);
      expect(find.text('Tidak sesuai'), findsOneWidget);
      expect(find.text('Analisa ulang'), findsOneWidget);
      expect(find.text('Foto Ulang'), findsOneWidget);

      await _saveBoundaryAsPng(
        tester,
        repaintKey,
        'docs/screenshots/tiket-ai/light-390-13a-preview.png',
      );
      expect(File('docs/screenshots/tiket-ai/light-390-13a-preview.png').existsSync(), isTrue);
    });

    testWidgets('Capture 13a preview dialog dark 390x844', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repaintKey = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: repaintKey,
          child: MediaQuery(
            data: const MediaQueryData(
              size: Size(390, 844),
              padding: EdgeInsets.only(top: 47.0, bottom: 34.0),
            ),
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              debugShowCheckedModeBanner: false,
              home: PhotoPreviewDialog(
                imagePath: _k1x1PngBase64,
                title: 'Pemeriksaan Palang Barrier Gate',
                pointResult: const MaintenancePointResult(
                  pointId: 'p1',
                  label: 'Pemeriksaan Palang Barrier Gate',
                  imagePath: _k1x1PngBase64,
                  status: PointStatus.tidakSesuai,
                  alasan: 'Baut kendor dan posisi palang miring 15 derajat',
                  confidence: 0.94,
                  providerName: 'AI Vision',
                ),
                onRetake: () {},
                onAnalyze: (_) async => AiVerificationResult(
                  status: VerificationStatus.tidakSesuai,
                  alasan: 'Baut kendor',
                  confidenceScore: 0.94,
                  poinGagal: const [],
                  poinLolos: const [],
                  providerName: 'AI Vision',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Pemeriksaan Palang Barrier Gate'), findsOneWidget);
      expect(find.text('Tidak sesuai'), findsOneWidget);
      expect(find.text('Analisa ulang'), findsOneWidget);

      await _saveBoundaryAsPng(
        tester,
        repaintKey,
        'docs/screenshots/tiket-ai/dark-390-13a-preview.png',
      );
      expect(File('docs/screenshots/tiket-ai/dark-390-13a-preview.png').existsSync(), isTrue);
    });

    testWidgets('Capture 13b hasil dialog light 390x844', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repaintKey = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: repaintKey,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              backgroundColor: Colors.black.withValues(alpha: 0.75),
              body: Center(
                child: SizedBox(
                  width: 390,
                  child: AiResultDialog(
                    title: 'Pemeriksaan Palang Barrier Gate',
                    result: AiVerificationResult(
                      status: VerificationStatus.tidakSesuai,
                      alasan: 'Posisi palang miring 15 derajat dan baut pengunci kendor.',
                      confidenceScore: 0.94,
                      poinGagal: const [
                        'Baut pengunci arm servo belum kencang',
                        'Kemiringan palang melebihi batas toleransi',
                      ],
                      poinLolos: const [
                        'Karet pelindung terpasang dengan baik',
                      ],
                      providerName: 'AI Vision',
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Hasil Analisa AI'), findsOneWidget);
      expect(find.text('Tidak sesuai'), findsOneWidget);
      expect(find.text('Yang perlu diperbaiki'), findsOneWidget);
      expect(find.text('Yang sudah sesuai'), findsOneWidget);
      expect(find.text('Tutup'), findsOneWidget);

      await _saveBoundaryAsPng(
        tester,
        repaintKey,
        'docs/screenshots/tiket-ai/light-390-13b-hasil.png',
      );
      expect(File('docs/screenshots/tiket-ai/light-390-13b-hasil.png').existsSync(), isTrue);
    });

    testWidgets('Capture 13b hasil dialog dark 390x844', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repaintKey = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: repaintKey,
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              backgroundColor: Colors.black.withValues(alpha: 0.75),
              body: Center(
                child: SizedBox(
                  width: 390,
                  child: AiResultDialog(
                    title: 'Pemeriksaan Palang Barrier Gate',
                    result: AiVerificationResult(
                      status: VerificationStatus.sesuai,
                      alasan: 'Seluruh komponen dalam kondisi prima sesuai standar operasional.',
                      confidenceScore: 0.98,
                      poinGagal: const [],
                      poinLolos: const [
                        'Baut pengunci kencang dan presisi',
                        'Sensor bekerja responsif',
                      ],
                      providerName: 'AI Vision',
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Hasil Analisa AI'), findsOneWidget);
      expect(find.text('Sesuai'), findsOneWidget);
      expect(find.text('Yang sudah sesuai'), findsOneWidget);
      expect(find.text('Tutup'), findsOneWidget);

      await _saveBoundaryAsPng(
        tester,
        repaintKey,
        'docs/screenshots/tiket-ai/dark-390-13b-hasil.png',
      );
      expect(File('docs/screenshots/tiket-ai/dark-390-13b-hasil.png').existsSync(), isTrue);
    });

    testWidgets('No overflow at 360x780 with textScaler 1.3 on PhotoPreviewDialog', (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          debugShowCheckedModeBanner: false,
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 780),
              textScaler: TextScaler.linear(1.3),
            ),
            child: PhotoPreviewDialog(
              imagePath: _k1x1PngBase64,
              title: 'Pemeriksaan Palang Barrier Gate Panjang Sekali Teksnya',
              pointResult: const MaintenancePointResult(
                pointId: 'p1',
                label: 'Pemeriksaan Palang',
                imagePath: _k1x1PngBase64,
                status: PointStatus.perluCekManual,
                alasan: 'Perlu verifikasi fisik manual oleh teknisi senior',
              ),
              onRetake: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('No overflow at 360x780 with textScaler 1.3 on AiResultDialog', (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          debugShowCheckedModeBanner: false,
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 780),
              textScaler: TextScaler.linear(1.3),
            ),
            child: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 360,
                  child: AiResultDialog(
                    title: 'Pemeriksaan Palang Barrier Gate Panjang Sekali Teksnya',
                    result: AiVerificationResult(
                      status: VerificationStatus.tidakSesuai,
                      alasan: 'Alasan analisa panjang untuk menguji wrap dan scaling teks.',
                      confidenceScore: 0.91,
                      poinGagal: const [
                        'Poin temuan gagal pertama dengan penjelasan sangat detail',
                        'Poin temuan kedua yang membutuhkan perbaikan',
                      ],
                      poinLolos: const [
                        'Poin lolos standar operasional',
                      ],
                      providerName: 'AI Vision Enterprise Pro',
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
