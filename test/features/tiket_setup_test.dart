import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bssparking_timemark/core/constants/app_theme.dart';
import 'package:bssparking_timemark/data/models/template_model.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';
import 'package:bssparking_timemark/features/maintenance/widgets/maintenance_setup_dialog.dart';

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
  final boundary =
      key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  if (boundary == null) {
    throw Exception('RenderRepaintBoundary not found for $path');
  }

  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw Exception('Failed to get png byteData for $path');
    }

    final file = File(path);
    file.parent.createSync(recursive: true);
    await file.writeAsBytes(byteData.buffer.asUint8List());
  });
}

TemplateModel _createSampleTemplate() {
  return TemplateModel(
    id: 'tpl-server',
    nama: 'Maintenance: Server & Kasir',
    deskripsi: 'Pengecekan server dan kasir',
    jenis: TemplateCategory.maintServer,
    createdBy: 'admin',
    updatedAt: DateTime(2026, 11, 1),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await _loadAppFonts();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'last_technician_name': 'Ryan',
    });
    await StorageService.init();
  });

  group('MaintenanceSetupDialog Tiket Redesign Tests', () {
    testWidgets('renders labels and handles actions', (tester) async {
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.reset());

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Center(
              child: MaintenanceSetupDialog(
                initialTemplate: _createSampleTemplate(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Maintenance: Server & Kasir'), findsOneWidget);
      expect(find.text('Nama Teknisi / Support'), findsOneWidget);
      expect(find.text('Lokasi Parkir'), findsOneWidget);
      expect(find.text('Pilih Perangkat'), findsOneWidget);
      expect(find.text('Server & Kasir'), findsOneWidget);
      expect(find.text('Hanya Kasir'), findsOneWidget);
      expect(find.text('Mulai Checklist'), findsOneWidget);
      expect(find.text('Batal'), findsOneWidget);
    });

    testWidgets('360x780 textScaler 1.3 renders without overflow',
        (tester) async {
      tester.view.physicalSize = const Size(360 * 2, 780 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.reset());

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 780),
              textScaler: TextScaler.linear(1.3),
            ),
            child: Scaffold(
              body: Center(
                child: MaintenanceSetupDialog(
                  initialTemplate: _createSampleTemplate(),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('Capture light-390-21-setup-maintenance and dark-390',
        (tester) async {
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.reset());

      for (final mode in ['light', 'dark']) {
        final repaintKey = GlobalKey();
        final theme =
            mode == 'light' ? AppTheme.lightTheme : AppTheme.darkTheme;

        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              backgroundColor: const Color(0x80000000),
              body: RepaintBoundary(
                key: repaintKey,
                child: SizedBox(
                  width: 390,
                  height: 844,
                  child: Center(
                    child: MaintenanceSetupDialog(
                      initialTemplate: _createSampleTemplate(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap '+' on Jumlah PC Kasir to increment from 1 to 2 to match mockup 21
        final addIcons = find.byIcon(Icons.add);
        if (addIcons.evaluate().isNotEmpty) {
          await tester.tap(addIcons.first);
          await tester.pumpAndSettle();
        }

        final pathFrame =
            'docs/screenshots/tiket-setup/$mode-390-21-setup-maintenance.png';
        final pathShort = 'docs/screenshots/tiket-setup/$mode-390-setup.png';
        await _saveBoundaryAsPng(tester, repaintKey, pathFrame);
        await _saveBoundaryAsPng(tester, repaintKey, pathShort);

        expect(File(pathFrame).existsSync(), isTrue);
        expect(File(pathShort).existsSync(), isTrue);
      }
    });
  });
}
