import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bssparking_timemark/features/auth/screens/login_screen.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Capture Login Screen', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();

    final boundaryKey = GlobalKey();
    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          fontFamily: 'PlusJakartaSans',
        ),
        home: RepaintBoundary(
          key: boundaryKey,
          child: const LoginScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final boundary = boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary != null) {
      await tester.runAsync(() async {
        final ui.Image image = await boundary.toImage(pixelRatio: 1.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData != null) {
          final buffer = byteData.buffer.asUint8List();
          final dir = Directory('docs/screenshots');
          if (!dir.existsSync()) {
            dir.createSync(recursive: true);
          }
          final file = File('docs/screenshots/login_screen.png');
          await file.writeAsBytes(buffer);
          debugPrint('Saved login screenshot: ${file.path}');
        }
      });
    }
  });
}
