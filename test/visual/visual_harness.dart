import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bssparking_timemark/core/constants/app_theme.dart';

bool _fontsLoaded = false;

/// Loads Figtree fonts and MaterialIcons into Flutter's FontLoader
/// to prevent fallback to the Ahem test font during screenshot captures.
Future<void> loadAppFonts() async {
  if (_fontsLoaded) return;

  final fontLoader = FontLoader(AppTheme.fontFamily);
  for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
    final file = File('assets/fonts/Figtree-$weight.ttf');
    if (file.existsSync()) {
      final bytes = file.readAsBytesSync();
      fontLoader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
  }
  await fontLoader.load();

  // Load MaterialIcons if available
  const candidateIconPaths = [
    '/home/annnpii/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    'bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  ];
  for (final p in candidateIconPaths) {
    final file = File(p);
    if (file.existsSync()) {
      final iconLoader = FontLoader('MaterialIcons');
      final bytes = file.readAsBytesSync();
      iconLoader.addFont(Future.value(ByteData.view(bytes.buffer)));
      await iconLoader.load();
      break;
    }
  }

  _fontsLoaded = true;
}

/// Helper that loads fonts, configures viewport/devicePixelRatio,
/// pumps [screen] wrapped in MaterialApp with AppTheme light/dark,
/// and writes the rendered RepaintBoundary to `docs/screenshots/<folder>/<name>-<w>-<light|dark>.png`.
Future<void> captureScreen(
  WidgetTester t, {
  required String name,
  required Widget screen,
  required Size size,
  required ThemeMode mode,
  double textScale = 1.0,
  String folder = 'before',
  double pixelRatio = 1.0,
  String? customFileName,
  Future<void> Function(WidgetTester t)? onPumped,
}) async {
  await loadAppFonts();

  t.view.physicalSize = Size(size.width * 2.0, size.height * 2.0);
  t.view.devicePixelRatio = 2.0;

  final boundaryKey = GlobalKey();
  final activeTheme = mode == ThemeMode.dark ? AppTheme.darkTheme : AppTheme.lightTheme;

  await t.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: mode,
      home: Theme(
        data: activeTheme,
        child: MediaQuery(
          data: MediaQueryData(
            size: size,
            devicePixelRatio: 2.0,
            textScaler: TextScaler.linear(textScale),
            platformBrightness: mode == ThemeMode.dark ? Brightness.dark : Brightness.light,
          ),
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: RepaintBoundary(
              key: boundaryKey,
              child: screen,
            ),
          ),
        ),
      ),
    ),
  );

  await t.pump();
  await t.pump(const Duration(milliseconds: 300));

  if (onPumped != null) {
    await onPumped(t);
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
  }

  final boundary = boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  if (boundary == null) {
    throw Exception('Failed to find RenderRepaintBoundary for $name');
  }

  await t.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw Exception('Failed to encode image to PNG for $name');
    }
    final buffer = byteData.buffer.asUint8List();
    final w = size.width.toInt();
    final themeStr = mode == ThemeMode.dark ? 'dark' : 'light';
    final dir = Directory('docs/screenshots/$folder');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    final fileName = customFileName ?? '$name-$w-$themeStr.png';
    final file = File('docs/screenshots/$folder/$fileName');
    await file.writeAsBytes(buffer);
    debugPrint('Saved screenshot: ${file.path} (${image.width}x${image.height})');
  });

  t.view.resetPhysicalSize();
  t.view.resetDevicePixelRatio();
}
