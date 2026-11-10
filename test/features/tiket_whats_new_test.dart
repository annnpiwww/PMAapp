import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bssparking_timemark/core/constants/app_theme.dart';
import 'package:bssparking_timemark/data/services/whats_new_service.dart';
import 'package:bssparking_timemark/features/whats_new/widgets/whats_new_sheet.dart';

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

Future<void> _captureSheet({
  required WidgetTester tester,
  required Widget sheet,
  required Brightness brightness,
  required double width,
  required double height,
  String? outputPath,
  TextScaler? textScaler,
}) async {
  final boundaryKey = GlobalKey();
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    RepaintBoundary(
      key: boundaryKey,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: brightness == Brightness.dark ? AppTheme.darkTheme : AppTheme.lightTheme,
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, height),
            padding: const EdgeInsets.only(top: 24.0, bottom: 24.0),
            textScaler: textScaler ?? TextScaler.noScaling,
          ),
          child: Scaffold(
            backgroundColor: const Color(0x99000000),
            body: Align(
              alignment: Alignment.bottomCenter,
              child: sheet,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));

  if (outputPath != null) {
    final boundary = boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) throw Exception('RenderRepaintBoundary not found for $outputPath');

    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('Failed to get png byteData for $outputPath');

      final file = File(outputPath);
      file.parent.createSync(recursive: true);
      await file.writeAsBytes(byteData.buffer.asUint8List());
      // ignore: avoid_print
      print('Generated screenshot: $outputPath (${file.lengthSync()} bytes)');
    });
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await _loadAppFonts();
  });

  const testRelease = WhatsNewService.current;

  group('WhatsNewSheet Tiket Redesign Tests', () {
    testWidgets('WhatsNewSheet renders labels and can be closed', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: WhatsNewSheet(release: testRelease),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Apa yang baru'), findsOneWidget);
      expect(find.text('Fitur baru'), findsOneWidget);
      expect(find.text('Mengerti'), findsOneWidget);
      expect(find.text('Muncul sekali tiap ada versi baru'), findsOneWidget);
    });

    testWidgets('WhatsNewSheet 360x780 textScaler 1.3 renders without overflow', (tester) async {
      await _captureSheet(
        tester: tester,
        sheet: const WhatsNewSheet(release: testRelease),
        brightness: Brightness.light,
        width: 360,
        height: 780,
        textScaler: const TextScaler.linear(1.3),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('Capture light-390-28-apa-yang-baru', (tester) async {
      await _captureSheet(
        tester: tester,
        sheet: const WhatsNewSheet(release: testRelease),
        brightness: Brightness.light,
        width: 390,
        height: 844,
        outputPath: 'docs/screenshots/tiket-whats-new/light-390-apa-yang-baru.png',
      );

      final copy = File('docs/screenshots/tiket-whats-new/light-390-apa-yang-baru.png');
      if (copy.existsSync()) {
        copy.copySync('docs/screenshots/tiket-whats-new/light-390-28-apa-yang-baru.png');
      }
    });

    testWidgets('Capture dark-390-28-apa-yang-baru', (tester) async {
      await _captureSheet(
        tester: tester,
        sheet: const WhatsNewSheet(release: testRelease),
        brightness: Brightness.dark,
        width: 390,
        height: 844,
        outputPath: 'docs/screenshots/tiket-whats-new/dark-390-apa-yang-baru.png',
      );

      final copy = File('docs/screenshots/tiket-whats-new/dark-390-apa-yang-baru.png');
      if (copy.existsSync()) {
        copy.copySync('docs/screenshots/tiket-whats-new/dark-390-28-apa-yang-baru.png');
      }
    });
  });
}
