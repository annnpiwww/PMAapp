import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bssparking_timemark/core/widgets/tiket/error_alarm_overlay.dart';
import 'package:bssparking_timemark/data/models/daily_task_model.dart';

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

DailyTaskModel _createDummyTicket({
  required String id,
  required String posName,
  required String judul,
}) {
  return DailyTaskModel(
    id: id,
    tanggal: '2026-11-10',
    teknisiId: 'tek-01',
    teknisiNama: 'Teknisi Alfa',
    posName: posName,
    posTag: 'TAG-01',
    judul: judul,
    kategori: 'error',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await _loadAppFonts();
  });

  testWidgets('(1) empty list -> finds child, no LOKASI ERROR',
      (WidgetTester tester) async {
    final ValueNotifier<List<DailyTaskModel>> openErrors =
        ValueNotifier<List<DailyTaskModel>>(<DailyTaskModel>[]);
    final ValueNotifier<bool> ringing = ValueNotifier<bool>(false);

    await tester.pumpWidget(
      MaterialApp(
        home: ErrorAlarmOverlay(
          openErrors: openErrors,
          ringing: ringing,
          onLihat: () {},
          child: const Scaffold(
            body: Text('Original Content'),
          ),
        ),
      ),
    );

    expect(find.text('Original Content'), findsOneWidget);
    expect(find.text('LOKASI ERROR'), findsNothing);
  });

  testWidgets(
      '(2) one ticket -> banner text <pos> · <judul>, tap Lihat calls onLihat once',
      (WidgetTester tester) async {
    int lihatCount = 0;
    final DailyTaskModel ticket = _createDummyTicket(
      id: 't-1',
      posName: 'Pos Barat',
      judul: 'Boomgate macet',
    );
    final ValueNotifier<List<DailyTaskModel>> openErrors =
        ValueNotifier<List<DailyTaskModel>>(<DailyTaskModel>[ticket]);
    final ValueNotifier<bool> ringing = ValueNotifier<bool>(false);

    await tester.pumpWidget(
      MaterialApp(
        home: ErrorAlarmOverlay(
          openErrors: openErrors,
          ringing: ringing,
          onLihat: () => lihatCount++,
          child: const Scaffold(
            body: Text('Child View'),
          ),
        ),
      ),
    );

    expect(find.text('LOKASI ERROR'), findsOneWidget);
    expect(find.text('Pos Barat · Boomgate macet'), findsOneWidget);
    expect(find.textContaining('lokasi lain'), findsNothing);

    await tester.tap(find.text('Lihat'));
    expect(lihatCount, 1);
  });

  testWidgets('(3) three tickets -> +2 lokasi lain',
      (WidgetTester tester) async {
    final DailyTaskModel t1 = _createDummyTicket(
      id: 't-1',
      posName: 'Pos Barat',
      judul: 'Boomgate macet',
    );
    final DailyTaskModel t2 = _createDummyTicket(
      id: 't-2',
      posName: 'Pos Timur',
      judul: 'Dispenser tiket habis',
    );
    final DailyTaskModel t3 = _createDummyTicket(
      id: 't-3',
      posName: 'Pos Utara',
      judul: 'Printer struk offline',
    );

    final ValueNotifier<List<DailyTaskModel>> openErrors =
        ValueNotifier<List<DailyTaskModel>>(<DailyTaskModel>[t1, t2, t3]);
    final ValueNotifier<bool> ringing = ValueNotifier<bool>(false);

    await tester.pumpWidget(
      MaterialApp(
        home: ErrorAlarmOverlay(
          openErrors: openErrors,
          ringing: ringing,
          onLihat: () {},
          child: const Scaffold(
            body: Text('Child View'),
          ),
        ),
      ),
    );

    expect(find.text('+2 lokasi lain'), findsOneWidget);
    expect(find.text('Pos Barat · Boomgate macet'), findsOneWidget);
  });

  testWidgets(
      '(4) ringing true -> speaker icon present; set ringing false -> icon gone and animation stopped',
      (WidgetTester tester) async {
    final DailyTaskModel ticket = _createDummyTicket(
      id: 't-1',
      posName: 'Pos 1',
      judul: 'Error sensor',
    );
    final ValueNotifier<List<DailyTaskModel>> openErrors =
        ValueNotifier<List<DailyTaskModel>>(<DailyTaskModel>[ticket]);
    final ValueNotifier<bool> ringing = ValueNotifier<bool>(true);

    await tester.pumpWidget(
      MaterialApp(
        home: ErrorAlarmOverlay(
          openErrors: openErrors,
          ringing: ringing,
          onLihat: () {},
          child: const Scaffold(
            body: Text('Child View'),
          ),
        ),
      ),
    );

    // Initial pump
    await tester.pump();
    expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);

    // Stop ringing
    ringing.value = false;
    await tester.pump();

    expect(find.byIcon(Icons.volume_up_rounded), findsNothing);
    // When ringing stops, animation stops, pumpAndSettle must complete
    await tester.pumpAndSettle();
  });

  testWidgets(
      '(5) disableAnimations -> pumpAndSettle completes with ringing true',
      (WidgetTester tester) async {
    final DailyTaskModel ticket = _createDummyTicket(
      id: 't-1',
      posName: 'Pos 1',
      judul: 'Error sensor',
    );
    final ValueNotifier<List<DailyTaskModel>> openErrors =
        ValueNotifier<List<DailyTaskModel>>(<DailyTaskModel>[ticket]);
    final ValueNotifier<bool> ringing = ValueNotifier<bool>(true);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: ErrorAlarmOverlay(
            openErrors: openErrors,
            ringing: ringing,
            onLihat: () {},
            child: const Scaffold(
              body: Text('Child View'),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
    // pumpAndSettle completes since animations are disabled
    await tester.pumpAndSettle();
  });

  testWidgets(
      '(6) 360 width textScaler 1.3 no overflow. Child under the banner: Scaffold with AppBar title visible',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final DailyTaskModel t1 = _createDummyTicket(
      id: 't-1',
      posName: 'Pos Masuk Utama',
      judul: 'Palang Parkir Macet Total',
    );
    final DailyTaskModel t2 = _createDummyTicket(
      id: 't-2',
      posName: 'Pos Keluar Barat',
      judul: 'Kamera ANPR Error',
    );

    final ValueNotifier<List<DailyTaskModel>> openErrors =
        ValueNotifier<List<DailyTaskModel>>(<DailyTaskModel>[t1, t2]);
    final ValueNotifier<bool> ringing = ValueNotifier<bool>(true);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 800),
            padding: EdgeInsets.only(top: 24),
            textScaler: TextScaler.linear(1.3),
            disableAnimations: true,
          ),
          child: ErrorAlarmOverlay(
            openErrors: openErrors,
            ringing: ringing,
            onLihat: () {},
            child: Scaffold(
              appBar: AppBar(
                title: const Text('Daily Task'),
              ),
              body: const Center(
                child: Text('Body Content'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final Finder titleFinder = find.text('Daily Task');
    expect(titleFinder, findsOneWidget);

    final Finder bannerFinder = find.text('LOKASI ERROR');
    final double bannerBottom = tester.getBottomLeft(bannerFinder).dy;
    final double titleTop = tester.getTopLeft(titleFinder).dy;

    // Title must be below banner (not covered)
    expect(titleTop, greaterThan(bannerBottom));
  });

  testWidgets('Generate screenshot alarm-light-390 and alarm-dark-390',
      (WidgetTester tester) async {
    final Directory dir = Directory('docs/screenshots/tiket-error/alarm');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final DailyTaskModel t1 = _createDummyTicket(
      id: 't-1',
      posName: 'Pos Masuk Timur',
      judul: 'Palang Pintu Rusak',
    );
    final DailyTaskModel t2 = _createDummyTicket(
      id: 't-2',
      posName: 'Pos Keluar Barat',
      judul: 'Dispenser Tiket Macet',
    );

    Widget buildTestApp({
      required Brightness brightness,
      required ValueNotifier<List<DailyTaskModel>> errors,
      required ValueNotifier<bool> ringing,
      required GlobalKey key,
    }) {
      return RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            brightness: brightness,
            fontFamily: 'Figtree',
            useMaterial3: true,
          ),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(390, 844),
              padding: EdgeInsets.only(top: 44, bottom: 34),
            ),
            child: ErrorAlarmOverlay(
              openErrors: errors,
              ringing: ringing,
              onLihat: () {},
              child: Scaffold(
                appBar: AppBar(
                  title: const Text('Daily Task'),
                ),
                body: ListView(
                  padding: const EdgeInsets.all(16),
                  children: const <Widget>[
                    Card(
                      child: ListTile(
                        title: Text('Inspeksi Palang Pintu'),
                        subtitle: Text('Shift 1 · 07:00 - 15:00'),
                      ),
                    ),
                    Card(
                      child: ListTile(
                        title: Text('Pemeriksaan Dispenser'),
                        subtitle: Text('Shift 1 · 07:00 - 15:00'),
                      ),
                    ),
                    Card(
                      child: ListTile(
                        title: Text('Cek Konektivitas Loop'),
                        subtitle: Text('Shift 1 · 07:00 - 15:00'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Light screenshot at pulse peak frame (1100ms)
    final GlobalKey lightKey = GlobalKey();
    final ValueNotifier<List<DailyTaskModel>> lightErrors =
        ValueNotifier<List<DailyTaskModel>>(<DailyTaskModel>[t1, t2]);
    final ValueNotifier<bool> lightRinging = ValueNotifier<bool>(true);

    await tester.pumpWidget(buildTestApp(
      brightness: Brightness.light,
      errors: lightErrors,
      ringing: lightRinging,
      key: lightKey,
    ));
    await tester.pump(const Duration(milliseconds: 1100)); // peak of pulse

    await tester.runAsync(() async {
      final RenderRepaintBoundary boundary =
          lightKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 1.0);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      File('docs/screenshots/tiket-error/alarm/alarm-light-390.png')
          .writeAsBytesSync(byteData!.buffer.asUint8List());
    });

    // Clean up light widget to stop controller
    lightRinging.value = false;
    await tester.pumpWidget(const SizedBox());

    // Dark screenshot at pulse peak frame (1100ms)
    final GlobalKey darkKey = GlobalKey();
    final ValueNotifier<List<DailyTaskModel>> darkErrors =
        ValueNotifier<List<DailyTaskModel>>(<DailyTaskModel>[t1, t2]);
    final ValueNotifier<bool> darkRinging = ValueNotifier<bool>(true);

    await tester.pumpWidget(buildTestApp(
      brightness: Brightness.dark,
      errors: darkErrors,
      ringing: darkRinging,
      key: darkKey,
    ));
    await tester.pump(const Duration(milliseconds: 1100)); // peak of pulse

    await tester.runAsync(() async {
      final RenderRepaintBoundary boundary =
          darkKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 1.0);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      File('docs/screenshots/tiket-error/alarm/alarm-dark-390.png')
          .writeAsBytesSync(byteData!.buffer.asUint8List());
    });

    // Clean up dark widget to stop controller
    darkRinging.value = false;
    await tester.pumpWidget(const SizedBox());
  });
}
