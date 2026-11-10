import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bssparking_timemark/core/constants/app_theme.dart';
import 'package:bssparking_timemark/data/services/whats_new_service.dart';
import 'package:bssparking_timemark/features/whats_new/widgets/whats_new_sheet.dart';

/// Font asli app dimuat biar screenshot kebaca (bukan kotak-kotak).
Future<void> loadAppFonts() async {
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

Future<void> _save(WidgetTester tester, GlobalKey key, String path) async {
  final boundary =
      key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  if (boundary == null) return;
  await tester.runAsync(() async {
    final img = await boundary.toImage(pixelRatio: 2.0);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    if (bytes != null) {
      final file = File(path);
      file.parent.createSync(recursive: true);
      await file.writeAsBytes(bytes.buffer.asUint8List());
      debugPrint('Saved: ${file.path}');
    }
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await loadAppFonts();
  });

  testWidgets('capture lembar Apa yang baru', (tester) async {
    tester.view.physicalSize = const Size(820, 1500);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            backgroundColor: Color(0xFF0B192C),
            body: Align(
              alignment: Alignment.bottomCenter,
              child: WhatsNewSheet(release: WhatsNewService.current),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _save(tester, key, 'docs/screenshots/whats_new_sheet.png');
  });
}
