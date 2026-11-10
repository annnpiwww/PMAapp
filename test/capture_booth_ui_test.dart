import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bssparking_timemark/core/constants/app_theme.dart';
import 'package:bssparking_timemark/data/repositories/template_repository.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';
import 'package:bssparking_timemark/features/maintenance/screens/maintenance_checklist_screen.dart';
import 'package:bssparking_timemark/features/maintenance/widgets/maintenance_setup_dialog.dart';

/// Screenshot preview fitur Maintenance Booth Parkir (mode Booth).
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
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    await _loadAppFonts();
  });

  testWidgets('capture setup dialog Pos Parkir & Booth (mode Booth)', (
    tester,
  ) async {
    final tpl = TemplateRepository.defaultTemplates.firstWhere(
      (t) => t.id == 'tpl_maint_pos',
    );
    tester.view.physicalSize = const Size(1100, 2100);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          home: Builder(
            builder: (ctx) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showDialog(
                    context: ctx,
                    builder: (_) => MaintenanceSetupDialog(initialTemplate: tpl),
                  ),
                  child: const Text('buka'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Booth'));
    await tester.tap(find.text('Booth'));
    await tester.pumpAndSettle();

    await _save(tester, key, 'docs/screenshots/maintenance_booth_setup.png');
  });

  testWidgets('capture checklist Booth Parkir (5 poin)', (tester) async {
    final tpl = TemplateRepository.defaultTemplates.firstWhere(
      (t) => t.id == 'tpl_maint_pos',
    );
    tester.view.physicalSize = const Size(1100, 2100);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          home: MaintenanceChecklistScreen(
            template: tpl,
            unitCount: 1,
            unitNumbers: const [1],
            posMode: 'booth',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _save(tester, key, 'docs/screenshots/maintenance_booth_checklist.png');
  });
}
