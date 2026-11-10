import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bssparking_timemark/core/constants/app_theme.dart';
import 'package:bssparking_timemark/core/widgets/tiket/tiket_pill.dart';
import 'package:bssparking_timemark/data/services/location_service.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';
import 'package:bssparking_timemark/features/daily_tasks/widgets/ad_hoc_task_dialog.dart';

const String _adminSampleText = '''
Selamat pagi, izin melaporkan, telah terjadi kendala dengan kronologi sebagai berikut:

Tanggal : 07-11-2026
Waktu : 05.35

Lokasi : PBM

Kendala : Pos 1 Palang Tidak bisa terangkat 

Penyebab : Tidak diketahui 

Solusi sementara : Pos 1 ditutup Smntra

Durasi Error : 

Berikut kami lampirkan dokumentasi kerusakan.

Terima kasih.
''';

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

  final flutterRoot = Platform.environment['FLUTTER_ROOT'] ?? '/home/annnpii/flutter';
  final iconFontFile = File(
    '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (iconFontFile.existsSync()) {
    final iconLoader = FontLoader('MaterialIcons');
    final bytes = iconFontFile.readAsBytesSync();
    iconLoader.addFont(Future.value(ByteData.view(bytes.buffer)));
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
    debugPrint('Generated screenshot: $path (${file.lengthSync()} bytes)');
  });
}

Widget _buildWrapper({
  required Widget child,
  required GlobalKey boundaryKey,
  required ThemeData theme,
  required double width,
  required double height,
  double textScale = 1.0,
}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: theme,
    home: MediaQuery(
      data: MediaQueryData(
        size: Size(width, height),
        padding: const EdgeInsets.only(top: 24, bottom: 24),
        textScaler: TextScaler.linear(textScale),
      ),
      child: Scaffold(
        backgroundColor: Colors.black54,
        body: Align(
          alignment: Alignment.bottomCenter,
          child: RepaintBoundary(
            key: boundaryKey,
            child: child,
          ),
        ),
      ),
    ),
  );
}

void main() {
  String? mockClipboardText;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _loadAppFonts();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.getData') {
        if (mockClipboardText == null) return null;
        return <String, dynamic>{'text': mockClipboardText};
      }
      return null;
    });
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    mockClipboardText = null;
  });

  final sampleOptions = [
    const PosLocation(
      posId: 'pos_1',
      posName: 'PBM',
      locationTag: 'PBM',
      cabangName: 'KC Manado',
      fullAddress: 'Jl. Sam Ratulangi No. 1, Manado',
      tagColor: Colors.blue,
      lat: 1.48,
      lng: 124.84,
    ),
    const PosLocation(
      posId: 'pos_2',
      posName: 'Pos Kasir 2',
      locationTag: 'KASIR2',
      cabangName: 'KC Manado',
      fullAddress: 'Jl. Piere Tendean, Manado',
      tagColor: Colors.green,
      lat: 1.49,
      lng: 124.85,
    ),
  ];

  group('AdHocTaskDialog Error Sheet Tests', () {
    testWidgets('(1) switching to Laporan error shows Tempel button and disabled submit', (tester) async {
      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        _buildWrapper(
          child: AdHocTaskDialog(
            teknisiNama: 'Farhan Lakoro',
            tanggal: '2026-11-10',
            lokasiOptions: sampleOptions,
          ),
          boundaryKey: boundaryKey,
          theme: AppTheme.lightTheme,
          width: 390.0,
          height: 844.0,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Kerjaan apa *'), findsOneWidget);
      expect(find.text('Laporan error'), findsOneWidget);

      // Switch to Laporan error
      await tester.tap(find.text('Laporan error'));
      await tester.pumpAndSettle();

      expect(find.text('Tempel dari Telegram'), findsOneWidget);
      expect(find.text('Kirim Laporan Error'), findsOneWidget);
      expect(find.text('Tempel pesan dan pilih lokasi dulu.'), findsOneWidget);

      final submitBtn = tester.widget<TiketPill>(find.widgetWithText(TiketPill, 'Kirim Laporan Error'));
      expect(submitBtn.kind, equals(TiketPillKind.disabled));
      expect(submitBtn.onPressed, isNull);
    });

    testWidgets('(2) empty clipboard shows the Clipboard kosong error', (tester) async {
      mockClipboardText = null;
      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        _buildWrapper(
          child: AdHocTaskDialog(
            teknisiNama: 'Farhan Lakoro',
            tanggal: '2026-11-10',
            lokasiOptions: sampleOptions,
          ),
          boundaryKey: boundaryKey,
          theme: AppTheme.lightTheme,
          width: 390.0,
          height: 844.0,
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Laporan error
      await tester.tap(find.text('Laporan error'));
      await tester.pumpAndSettle();

      // Tap Tempel dari Telegram
      await tester.tap(find.text('Tempel dari Telegram'));
      await tester.pumpAndSettle();

      expect(find.text('Clipboard kosong. Salin pesan admin dulu.'), findsOneWidget);
    });

    testWidgets('(3) pasting the contract admin sample shows Waktu lapor, Kendala, and preselects PBM', (tester) async {
      mockClipboardText = _adminSampleText;
      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        _buildWrapper(
          child: AdHocTaskDialog(
            teknisiNama: 'Farhan Lakoro',
            tanggal: '2026-11-10',
            lokasiOptions: sampleOptions,
          ),
          boundaryKey: boundaryKey,
          theme: AppTheme.lightTheme,
          width: 390.0,
          height: 844.0,
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Laporan error
      await tester.tap(find.text('Laporan error'));
      await tester.pumpAndSettle();

      // Tap Tempel dari Telegram
      await tester.tap(find.text('Tempel dari Telegram'));
      await tester.pumpAndSettle();

      expect(find.text('Isi laporan admin'), findsOneWidget);
      expect(find.text('Sab, 07 Nov 2026 · 05.35'), findsOneWidget);
      expect(find.text('Pos 1 Palang Tidak bisa terangkat'), findsOneWidget);
      expect(find.text('Tidak diketahui'), findsOneWidget);
      expect(find.text('Pos 1 ditutup Smntra'), findsOneWidget);
      expect(find.text('PBM'), findsOneWidget);
      expect(find.text('Dari kolom Lokasi di pesan. Ketuk kalau salah.'), findsOneWidget);

      final submitBtn = tester.widget<TiketPill>(find.widgetWithText(TiketPill, 'Kirim Laporan Error'));
      expect(submitBtn.kind, equals(TiketPillKind.primary));
      expect(submitBtn.onPressed, isNotNull);
    });

    testWidgets('(4) message without Kendala shows the tidak berisi Kendala error', (tester) async {
      mockClipboardText = 'Selamat pagi, izin melaporkan test pesan kosong tanpa kendala';
      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        _buildWrapper(
          child: AdHocTaskDialog(
            teknisiNama: 'Farhan Lakoro',
            tanggal: '2026-11-10',
            lokasiOptions: sampleOptions,
          ),
          boundaryKey: boundaryKey,
          theme: AppTheme.lightTheme,
          width: 390.0,
          height: 844.0,
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Laporan error
      await tester.tap(find.text('Laporan error'));
      await tester.pumpAndSettle();

      // Tap Tempel dari Telegram
      await tester.tap(find.text('Tempel dari Telegram'));
      await tester.pumpAndSettle();

      expect(find.text('Pesan ini tidak berisi Kendala. Cek lagi pesan yang disalin.'), findsOneWidget);
    });

    testWidgets('(5) Kerjaan mode still validates empty Kerjaan apa', (tester) async {
      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        _buildWrapper(
          child: AdHocTaskDialog(
            teknisiNama: 'Farhan Lakoro',
            tanggal: '2026-11-10',
            lokasiOptions: sampleOptions,
          ),
          boundaryKey: boundaryKey,
          theme: AppTheme.lightTheme,
          width: 390.0,
          height: 844.0,
        ),
      );
      await tester.pumpAndSettle();

      // Tap Simpan directly without typing anything
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();

      expect(find.text('Wajib diisi'), findsOneWidget);
    });
  });

  group('AdHocTaskDialog Screenshot Captures E1 and E2', () {
    const outDir = 'docs/screenshots/tiket-error/e1e2';

    testWidgets('Capture E1 light 390', (tester) async {
      tester.view.physicalSize = const Size(390.0, 844.0);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        _buildWrapper(
          child: AdHocTaskDialog(
            teknisiNama: 'Farhan Lakoro',
            tanggal: '2026-11-10',
            lokasiOptions: sampleOptions,
          ),
          boundaryKey: boundaryKey,
          theme: AppTheme.lightTheme,
          width: 390.0,
          height: 844.0,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Laporan error'));
      await tester.pumpAndSettle();

      await _saveBoundaryAsPng(tester, boundaryKey, '$outDir/e1-light-390.png');
      expect(File('$outDir/e1-light-390.png').existsSync(), isTrue);
    });

    testWidgets('Capture E2 light 390', (tester) async {
      mockClipboardText = _adminSampleText;
      tester.view.physicalSize = const Size(390.0, 844.0);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        _buildWrapper(
          child: AdHocTaskDialog(
            teknisiNama: 'Farhan Lakoro',
            tanggal: '2026-11-10',
            lokasiOptions: sampleOptions,
          ),
          boundaryKey: boundaryKey,
          theme: AppTheme.lightTheme,
          width: 390.0,
          height: 844.0,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Laporan error'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tempel dari Telegram'));
      await tester.pumpAndSettle();

      await _saveBoundaryAsPng(tester, boundaryKey, '$outDir/e2-light-390.png');
      expect(File('$outDir/e2-light-390.png').existsSync(), isTrue);
    });

    testWidgets('Capture E2 light 360 textScale 1.3', (tester) async {
      mockClipboardText = _adminSampleText;
      tester.view.physicalSize = const Size(360.0, 780.0);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        _buildWrapper(
          child: AdHocTaskDialog(
            teknisiNama: 'Farhan Lakoro',
            tanggal: '2026-11-10',
            lokasiOptions: sampleOptions,
          ),
          boundaryKey: boundaryKey,
          theme: AppTheme.lightTheme,
          width: 360.0,
          height: 780.0,
          textScale: 1.3,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Laporan error'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tempel dari Telegram'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await _saveBoundaryAsPng(tester, boundaryKey, '$outDir/e2-light-360-ts13.png');
      expect(File('$outDir/e2-light-360-ts13.png').existsSync(), isTrue);
    });

    testWidgets('Capture E2 dark 390', (tester) async {
      mockClipboardText = _adminSampleText;
      tester.view.physicalSize = const Size(390.0, 844.0);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        _buildWrapper(
          child: AdHocTaskDialog(
            teknisiNama: 'Farhan Lakoro',
            tanggal: '2026-11-10',
            lokasiOptions: sampleOptions,
          ),
          boundaryKey: boundaryKey,
          theme: AppTheme.darkTheme,
          width: 390.0,
          height: 844.0,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Laporan error'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tempel dari Telegram'));
      await tester.pumpAndSettle();

      await _saveBoundaryAsPng(tester, boundaryKey, '$outDir/e2-dark-390.png');
      expect(File('$outDir/e2-dark-390.png').existsSync(), isTrue);
    });
  });
}
