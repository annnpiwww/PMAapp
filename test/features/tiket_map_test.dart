import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bssparking_timemark/core/constants/app_theme.dart';
import 'package:bssparking_timemark/core/constants/tiket_colors.dart';
import 'package:bssparking_timemark/data/models/maintenance_temuan_fix.dart';
import 'package:bssparking_timemark/data/services/branch_service.dart';
import 'package:bssparking_timemark/data/services/location_service.dart';
import 'package:bssparking_timemark/data/services/maintenance_log_service.dart';
import 'package:bssparking_timemark/features/maintenance/screens/maintenance_location_detail_screen.dart';
import 'package:bssparking_timemark/features/maintenance/screens/maintenance_map_screen.dart';
import 'package:bssparking_timemark/features/maintenance/widgets/temuan_fix_sheet.dart';

bool _fontsLoaded = false;
Future<void> _loadAppFonts() async {
  if (_fontsLoaded) return;
  final fontLoader = FontLoader('PlusJakartaSans');
  for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
    final file = File('assets/fonts/PlusJakartaSans-$weight.ttf');
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

const PosLocation _sampleLocation = PosLocation(
  posId: 'POS-01',
  posName: 'Pos Pasar Bersehati',
  cabangName: 'KC Manado',
  fullAddress: 'Jl. Nusantara, Pasar Bersehati, Manado',
  locationTag: 'PBM',
  tagColor: Colors.blue,
  lat: 1.4931,
  lng: 124.8412,
);

const MaintenanceTemuan _sampleTemuan1 = MaintenanceTemuan(
  label: 'Sensor gate kotor',
  status: 'tidak_sesuai',
  alasan: 'Perlu dibersihkan segera',
  urgent: true,
);

final MaintenanceTemuanFix _sampleFix = MaintenanceTemuanFix(
  id: 'fix-01',
  posId: 'POS-01',
  logId: 'log-01',
  temuanLabel: 'Kabel sensor kendur',
  catatan: 'Ganti roller, jalur kabel dirapikan dan konektor dikencangkan.',
  photoUrls: const ['/tmp/fix1.jpg', '/tmp/fix2.jpg', '/tmp/fix3.jpg'],
  teknisiNama: 'Ryan',
  fixedAt: DateTime(2026, 11, 9, 14, 20),
);

final MaintenanceTemuan _sampleTemuan2 = MaintenanceTemuan(
  label: 'Kabel sensor kendur',
  status: 'tidak_sesuai',
  alasan: 'Periksa koneksi kabel',
  urgent: false,
  fix: _sampleFix,
);

final MaintenanceLogEntry _sampleLog = MaintenanceLogEntry(
  id: 'log-01',
  tanggal: '2026-11-09',
  jamSelesai: '09:30',
  posId: 'POS-01',
  posName: 'Pos Pasar Bersehati',
  teknisiNama: 'Ryan',
  templateId: 'tpl_maint_manless',
  totalPoin: 5,
  sesuaiPoin: 3,
  temuan: [_sampleTemuan1, _sampleTemuan2],
);

final PosMaintenanceStatus _sampleStatus = PosMaintenanceStatus(
  location: _sampleLocation,
  wilayah: 'Manado',
  logs: [_sampleLog],
);

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _loadAppFonts();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    BranchService.instance.resetForTesting();
  });

  group('Group G6: Tiket Map, Detail Lokasi, and TemuanFixSheet', () {
    testWidgets('pumps MaintenanceMapScreen and verifies stat tiles and labels', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const MaintenanceMapScreen(showTileLayer: false),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(find.text('Map Maintenance'), findsOneWidget);
      expect(find.text('Belum'), findsWidgets);
      expect(find.text('Temuan'), findsWidgets);
      expect(find.text('Aman'), findsWidgets);
    });

    testWidgets('pumps MaintenanceLocationDetailScreen and verifies labels and actions', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: MaintenanceLocationDetailScreen(
            status: _sampleStatus,
            month: DateTime(2026, 11, 1),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Pos Pasar Bersehati'), findsOneWidget);
      expect(find.text('Buka di Maps'), findsOneWidget);
      expect(find.text('Tandai Sudah Diperbaiki'), findsWidgets);
    });

    testWidgets('pumps TemuanFixSheet and verifies verbatim labels without overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: TemuanFixSheet(
                log: _sampleLog,
                temuan: _sampleTemuan1,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Tandai Sudah Diperbaiki'), findsOneWidget);
      expect(find.text('+ Ambil Foto'), findsOneWidget);
      expect(find.text('Simpan Perbaikan'), findsOneWidget);
    });

    testWidgets('asserts no overflow at 360 width with textScaler 1.3', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 800),
              textScaler: TextScaler.linear(1.3),
            ),
            child: Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: TemuanFixSheet(
                  log: _sampleLog,
                  temuan: _sampleTemuan1,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Tandai Sudah Diperbaiki'), findsOneWidget);
      expect(find.text('+ Ambil Foto'), findsOneWidget);
      expect(find.text('Simpan Perbaikan'), findsOneWidget);
    });
  });

  group('Capture 12 Screenshots for Tiket Map Group G6', () {
    final configs = [
      (brightness: Brightness.light, width: 360.0, height: 800.0, name: 'light-360'),
      (brightness: Brightness.light, width: 390.0, height: 844.0, name: 'light-390'),
      (brightness: Brightness.dark, width: 360.0, height: 800.0, name: 'dark-360'),
      (brightness: Brightness.dark, width: 390.0, height: 844.0, name: 'dark-390'),
    ];

    for (final cfg in configs) {
      testWidgets('Screenshot Map ${cfg.name}', (tester) async {
        final key = GlobalKey();
        tester.view.physicalSize = Size(cfg.width, cfg.height);
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
              home: MediaQuery(
                data: MediaQueryData(
                  size: Size(cfg.width, cfg.height),
                  padding: const EdgeInsets.only(top: 24, bottom: 24),
                ),
                child: const MaintenanceMapScreen(showTileLayer: false),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final outPath = 'docs/screenshots/tiket-map/${cfg.name}-map.png';
        await _saveBoundaryAsPng(tester, key, outPath);
        expect(File(outPath).existsSync(), isTrue);
      });

      testWidgets('Screenshot Detail ${cfg.name}', (tester) async {
        final key = GlobalKey();
        tester.view.physicalSize = Size(cfg.width, cfg.height);
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
              home: MediaQuery(
                data: MediaQueryData(
                  size: Size(cfg.width, cfg.height),
                  padding: const EdgeInsets.only(top: 24, bottom: 24),
                ),
                child: MaintenanceLocationDetailScreen(
                  status: _sampleStatus,
                  month: DateTime(2026, 11, 1),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final outPath = 'docs/screenshots/tiket-map/${cfg.name}-detail.png';
        await _saveBoundaryAsPng(tester, key, outPath);
        expect(File(outPath).existsSync(), isTrue);
      });

      testWidgets('Screenshot Fix Sheet ${cfg.name}', (tester) async {
        final key = GlobalKey();
        tester.view.physicalSize = Size(cfg.width, cfg.height);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final theme = cfg.brightness == Brightness.dark ? AppTheme.darkTheme : AppTheme.lightTheme;
        final colors = cfg.brightness == Brightness.dark ? TiketColors.dark : TiketColors.light;

        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: theme,
              home: MediaQuery(
                data: MediaQueryData(
                  size: Size(cfg.width, cfg.height),
                  padding: const EdgeInsets.only(top: 24, bottom: 24),
                ),
                child: Scaffold(
                  backgroundColor: colors.ink.withValues(alpha: 0.4),
                  body: Align(
                    alignment: Alignment.bottomCenter,
                    child: TemuanFixSheet(
                      log: _sampleLog,
                      temuan: _sampleTemuan1,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final outPath = 'docs/screenshots/tiket-map/${cfg.name}-fix.png';
        await _saveBoundaryAsPng(tester, key, outPath);
        expect(File(outPath).existsSync(), isTrue);
      });
    }
  });
}
