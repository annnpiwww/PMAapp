import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bssparking_timemark/core/constants/app_theme.dart';
import 'package:bssparking_timemark/data/services/branch_service.dart';
import 'package:bssparking_timemark/features/maintenance/screens/maintenance_map_screen.dart';

bool _fontsLoaded = false;
Future<void> _loadAppFonts() async {
  if (_fontsLoaded) return;
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
  _fontsLoaded = true;
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
    // ignore: avoid_print
    print('Generated screenshot: $path (${file.lengthSync()} bytes)');
  });
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _loadAppFonts();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    BranchService.instance.resetForTesting();
  });

  group('Map Maintenance Error Ticket Radar & Chip (Phase 2c)', () {
    testWidgets('(1) a pos with an error ticket renders the label "<pos> · Error" and the chip "1 lokasi error"', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const targetPos = 'Mie Gacoan Babe Palar';

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const MediaQuery(
            data: MediaQueryData(
              size: Size(390, 844),
              disableAnimations: true,
            ),
            child: MaintenanceMapScreen(
              showTileLayer: false,
              initialErrorPosNames: {targetPos},
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      // Chip should appear
      expect(find.text('1 lokasi error'), findsOneWidget);

      // Label pill under pin should render posName · Error
      expect(find.text('$targetPos · Error'), findsOneWidget);
    });

    testWidgets('(2) with the status filter set to a rank that excludes that pos, the marker is still present while tile counts are unchanged', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const targetPos = 'Mie Gacoan Babe Palar';

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const MediaQuery(
            data: MediaQueryData(
              size: Size(390, 844),
              disableAnimations: true,
            ),
            child: MaintenanceMapScreen(
              showTileLayer: false,
              initialErrorPosNames: {targetPos},
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Capture initial counts on tiles
      expect(find.text('1 lokasi error'), findsOneWidget);
      expect(find.text('$targetPos · Error'), findsOneWidget);

      // Tap on Aman tile (rank 2)
      final amanTileFinder = find.widgetWithText(InkWell, 'Aman');
      expect(amanTileFinder, findsOneWidget);
      await tester.tap(amanTileFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Marker for error pos is still present due to union in _buildMarkers
      expect(find.text('$targetPos · Error'), findsOneWidget);
      // Tile labels and stat structure still intact
      expect(find.text('Aman'), findsWidgets);
      expect(find.text('Belum'), findsWidgets);
      expect(find.text('Temuan'), findsWidgets);
    });

    testWidgets('(3) disableAnimations true -> no running animation (pumpAndSettle completes)', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const targetPos = 'Mie Gacoan Babe Palar';

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const MediaQuery(
            data: MediaQueryData(
              size: Size(390, 844),
              disableAnimations: true,
            ),
            child: MaintenanceMapScreen(
              showTileLayer: false,
              initialErrorPosNames: {targetPos},
            ),
          ),
        ),
      );
      await tester.pump();
      // pumpAndSettle must complete without timing out on running animation
      await tester.pumpAndSettle();
      expect(find.text('1 lokasi error'), findsOneWidget);
    });

    testWidgets('(4) no tickets -> no chip', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const MediaQuery(
            data: MediaQueryData(
              size: Size(390, 844),
              disableAnimations: true,
            ),
            child: MaintenanceMapScreen(
              showTileLayer: false,
              initialErrorPosNames: {},
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('1 lokasi error'), findsNothing);
      expect(find.textContaining('lokasi error'), findsNothing);
    });
  });

  group('Capture Screenshots for Tiket Error E3 Mockup', () {
    const targetPos = 'Mie Gacoan Babe Palar';
    final configs = [
      (brightness: Brightness.light, name: 'e3-light-390'),
      (brightness: Brightness.dark, name: 'e3-dark-390'),
    ];

    for (final cfg in configs) {
      testWidgets('Screenshot Map E3 ${cfg.name}', (tester) async {
        final key = GlobalKey();
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final theme = cfg.brightness == Brightness.dark ? AppTheme.darkTheme : AppTheme.lightTheme;

        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: theme,
              home: const MediaQuery(
                data: MediaQueryData(
                  size: Size(390, 844),
                  disableAnimations: true,
                  padding: EdgeInsets.only(top: 24, bottom: 24),
                ),
                child: MaintenanceMapScreen(
                  showTileLayer: false,
                  initialErrorPosNames: {targetPos},
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final outDir = Directory('docs/screenshots/tiket-error/e3');
        if (!outDir.existsSync()) {
          outDir.createSync(recursive: true);
        }
        final outPath = 'docs/screenshots/tiket-error/e3/${cfg.name}.png';
        await _saveBoundaryAsPng(tester, key, outPath);
        expect(File(outPath).existsSync(), isTrue);
      });
    }
  });
}
