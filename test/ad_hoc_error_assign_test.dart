import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bssparking_timemark/data/models/daily_task_model.dart';
import 'package:bssparking_timemark/data/models/error_report.dart';
import 'package:bssparking_timemark/data/services/error_ticket_service.dart';
import 'package:bssparking_timemark/data/services/location_service.dart';
import 'package:bssparking_timemark/features/daily_tasks/widgets/ad_hoc_task_dialog.dart';

bool _fontsLoaded = false;
Future<void> _loadAppFonts() async {
  if (_fontsLoaded) return;
  final FontLoader fontLoader = FontLoader('Figtree');
  for (final String weight in <String>[
    'Regular',
    'Medium',
    'SemiBold',
    'Bold',
    'ExtraBold',
  ]) {
    final File file = File('assets/fonts/Figtree-$weight.ttf');
    if (file.existsSync()) {
      final Uint8List bytes = file.readAsBytesSync();
      fontLoader.addFont(Future<ByteData>.value(ByteData.view(bytes.buffer)));
    }
  }
  await fontLoader.load();

  final File iconFile = File(
    '/home/annnpii/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (iconFile.existsSync()) {
    final FontLoader iconLoader = FontLoader('MaterialIcons');
    final Uint8List iconBytes = iconFile.readAsBytesSync();
    iconLoader.addFont(Future<ByteData>.value(ByteData.view(iconBytes.buffer)));
    await iconLoader.load();
  }
  _fontsLoaded = true;
}

const PosLocation _samplePos = PosLocation(
  posId: 'pos_masuk',
  posName: 'Pos Masuk Utama',
  cabangName: 'KC Manado',
  fullAddress: 'Jl. Sam Ratulangi',
  locationTag: 'GATE IN',
  tagColor: Color(0xFF1E3A8A),
  lat: 1.4870,
  lng: 124.8456,
);

const String _sampleTelegramText = '''
Tanggal : 11-11-2026
Waktu : 10.30
Lokasi : Pos Masuk Utama
Kendala : Barrier gate macet tidak bisa buka
Penyebab : Sensor loop error
Solusi Sementara : Buka manual
Pelapor : Budi
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await _loadAppFonts();
  });

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (MethodCall call) async {
      if (call.method == 'Clipboard.getData') {
        return const <String, dynamic>{'text': _sampleTelegramText};
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets('(1) teknisiOptions null -> no SIAPA YANG SELESAIKAN',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AdHocTaskDialog(
              teknisiNama: 'Teknisi 1',
              tanggal: '2026-11-11',
              lokasiOptions: <PosLocation>[_samplePos],
              startInErrorMode: true,
              teknisiOptions: null,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('SIAPA YANG SELESAIKAN'), findsNothing);
  });

  testWidgets(
      '(2) SPV default mode Semua teknisi -> save calls create with ErrorAssignMode.semuaTeknisi',
      (WidgetTester tester) async {
    ErrorAssignMode? capturedMode;
    String? capturedPJ;
    List<String>? capturedPendamping;

    AdHocTaskDialog.createTicketForModeSeam = ({
      required ErrorAssignMode mode,
      required ErrorReport report,
      required String original,
      required String pelapor,
      required String posName,
      required String posTag,
      String penanggungJawab = '',
      List<String> pendamping = const <String>[],
    }) async {
      capturedMode = mode;
      capturedPJ = penanggungJawab;
      capturedPendamping = pendamping;
      return DailyTaskModel(
        id: 'task_01',
        tanggal: '2026-11-11',
        teknisiId: 'tek_01',
        teknisiNama: pelapor,
        posName: posName,
        posTag: posTag,
        judul: report.judul(original),
      );
    };
    addTearDown(() => AdHocTaskDialog.createTicketForModeSeam = null);

    await tester.binding.runAsync(() async {
      await Clipboard.setData(const ClipboardData(text: _sampleTelegramText));
    });

    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AdHocTaskDialog(
              teknisiNama: 'SPV Budi',
              tanggal: '2026-11-11',
              lokasiOptions: <PosLocation>[_samplePos],
              startInErrorMode: true,
              teknisiOptions: <String>['Eko', 'Fajar', 'Gilang'],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('SIAPA YANG SELESAIKAN'), findsOneWidget);

    await tester.tap(find.text('Tempel dari Telegram'));
    await tester.pumpAndSettle();

    expect(find.text('Kirim Laporan Error'), findsOneWidget);
    await tester.tap(find.text('Kirim Laporan Error'));
    await tester.pumpAndSettle();

    expect(capturedMode, equals(ErrorAssignMode.semuaTeknisi));
    expect(capturedPJ, isEmpty);
    expect(capturedPendamping, isEmpty);
  });

  testWidgets(
      '(3) Tunjuk without PJ -> save disabled; pick PJ + 1 pendamping -> called with those names',
      (WidgetTester tester) async {
    ErrorAssignMode? capturedMode;
    String? capturedPJ;
    List<String>? capturedPendamping;

    AdHocTaskDialog.createTicketForModeSeam = ({
      required ErrorAssignMode mode,
      required ErrorReport report,
      required String original,
      required String pelapor,
      required String posName,
      required String posTag,
      String penanggungJawab = '',
      List<String> pendamping = const <String>[],
    }) async {
      capturedMode = mode;
      capturedPJ = penanggungJawab;
      capturedPendamping = pendamping;
      return DailyTaskModel(
        id: 'task_02',
        tanggal: '2026-11-11',
        teknisiId: 'tek_01',
        teknisiNama: pelapor,
        posName: posName,
        posTag: posTag,
        judul: report.judul(original),
      );
    };
    addTearDown(() => AdHocTaskDialog.createTicketForModeSeam = null);

    await tester.binding.runAsync(() async {
      await Clipboard.setData(const ClipboardData(text: _sampleTelegramText));
    });

    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AdHocTaskDialog(
              teknisiNama: 'SPV Budi',
              tanggal: '2026-11-11',
              lokasiOptions: <PosLocation>[_samplePos],
              startInErrorMode: true,
              teknisiOptions: <String>['Eko', 'Fajar', 'Gilang'],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tempel dari Telegram'));
    await tester.pumpAndSettle();

    // Select 'Tunjuk' segment
    await tester.tap(find.text('Tunjuk'));
    await tester.pumpAndSettle();

    // Helper says 'Pilih penanggung jawab dulu'
    expect(find.text('Pilih penanggung jawab dulu'), findsOneWidget);

    // Pick PJ (Eko)
    await tester.tap(find.text('Pilih penanggung jawab'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eko').last);
    await tester.pumpAndSettle();

    // Helper text is gone
    expect(find.text('Pilih penanggung jawab dulu'), findsNothing);

    // Pick 1 pendamping (Fajar)
    await tester.tap(find.text('Tambah pendamping'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fajar').last);
    await tester.pumpAndSettle();

    // Fajar is listed as selected pendamping
    expect(find.text('Fajar'), findsWidgets);

    // Tap Kirim Laporan Error
    await tester.tap(find.text('Kirim Laporan Error'));
    await tester.pumpAndSettle();

    expect(capturedMode, equals(ErrorAssignMode.tunjuk));
    expect(capturedPJ, equals('Eko'));
    expect(capturedPendamping, equals(<String>['Fajar']));
  });

  testWidgets(
      '(4) 360 width textScaler 1.3, segmented labels not clipped, no overflow',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(360, 800),
            textScaler: TextScaler.linear(1.3),
          ),
          child: Scaffold(
            body: SingleChildScrollView(
              child: AdHocTaskDialog(
                teknisiNama: 'SPV Budi',
                tanggal: '2026-11-11',
                lokasiOptions: <PosLocation>[_samplePos],
                startInErrorMode: true,
                teknisiOptions: <String>['Eko', 'Fajar', 'Gilang'],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Semua teknisi'), findsOneWidget);
    expect(find.text('Tunjuk'), findsOneWidget);
    expect(find.text('Saya'), findsOneWidget);
  });

  testWidgets('Generate screenshots assign-semua-light-390, assign-tunjuk-light-390, assign-tunjuk-dark-390',
      (WidgetTester tester) async {
    final Directory dir = Directory('docs/screenshots/tiket-error/assign');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    Widget buildSheet({
      required Brightness brightness,
      required GlobalKey boundaryKey,
    }) {
      return RepaintBoundary(
        key: boundaryKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            brightness: brightness,
            fontFamily: 'Figtree',
            useMaterial3: true,
          ),
          home: const MediaQuery(
            data: MediaQueryData(
              size: Size(390, 844),
              padding: EdgeInsets.only(top: 44, bottom: 34),
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                child: AdHocTaskDialog(
                  teknisiNama: 'SPV Budi',
                  tanggal: '2026-11-11',
                  lokasiOptions: <PosLocation>[_samplePos],
                  startInErrorMode: true,
                  teknisiOptions: <String>['Eko', 'Fajar', 'Gilang'],
                ),
              ),
            ),
          ),
        ),
      );
    }

    await tester.binding.runAsync(() async {
      await Clipboard.setData(const ClipboardData(text: _sampleTelegramText));
    });

    // 1. assign-semua-light-390.png
    final GlobalKey semuaKey = GlobalKey();

    await tester.pumpWidget(buildSheet(
      brightness: Brightness.light,
      boundaryKey: semuaKey,
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tempel dari Telegram'));
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      final RenderRepaintBoundary boundary =
          semuaKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 1.0);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      File('docs/screenshots/tiket-error/assign/assign-semua-light-390.png')
          .writeAsBytesSync(byteData!.buffer.asUint8List());
    });

    // 2. assign-tunjuk-light-390.png (with PJ + 1 pendamping)
    final GlobalKey tunjukLightKey = GlobalKey();

    await tester.pumpWidget(buildSheet(
      brightness: Brightness.light,
      boundaryKey: tunjukLightKey,
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tempel dari Telegram'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tunjuk'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pilih penanggung jawab'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eko').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tambah pendamping'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fajar').last);
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      final RenderRepaintBoundary boundary =
          tunjukLightKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 1.0);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      File('docs/screenshots/tiket-error/assign/assign-tunjuk-light-390.png')
          .writeAsBytesSync(byteData!.buffer.asUint8List());
    });

    // 3. assign-tunjuk-dark-390.png (with PJ + 1 pendamping)
    final GlobalKey tunjukDarkKey = GlobalKey();

    await tester.pumpWidget(buildSheet(
      brightness: Brightness.dark,
      boundaryKey: tunjukDarkKey,
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tempel dari Telegram'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tunjuk'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pilih penanggung jawab'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eko').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tambah pendamping'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fajar').last);
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      final RenderRepaintBoundary boundary =
          tunjukDarkKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 1.0);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      File('docs/screenshots/tiket-error/assign/assign-tunjuk-dark-390.png')
          .writeAsBytesSync(byteData!.buffer.asUint8List());
    });
  });
}
