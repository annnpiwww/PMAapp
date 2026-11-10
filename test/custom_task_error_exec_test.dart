import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bssparking_timemark/core/constants/app_theme.dart';
import 'package:bssparking_timemark/data/models/daily_task_model.dart';
import 'package:bssparking_timemark/data/models/error_report.dart';
import 'package:bssparking_timemark/data/services/error_ticket_service.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';
import 'package:bssparking_timemark/features/daily_tasks/screens/custom_task_execution_screen.dart';

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
  final iconFile = File('$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (iconFile.existsSync()) {
    final iconLoader = FontLoader('MaterialIcons');
    final iconBytes = iconFile.readAsBytesSync();
    iconLoader.addFont(Future.value(ByteData.view(iconBytes.buffer)));
    await iconLoader.load();
  }
}

Future<void> _savePng(
  WidgetTester tester,
  GlobalKey boundaryKey,
  String relativePath, {
  double pixelRatio = 1.0,
}) async {
  await tester.runAsync(() async {
    final boundary = boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final file = File(relativePath);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(byteData!.buffer.asUint8List());
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const rawAdminSample = '''
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

  final errorDeskripsi = ErrorReport.parse(rawAdminSample).toDeskripsi(rawAdminSample);

  final errorTask = DailyTaskModel(
    id: 'task_err_test_1',
    tanggal: '2026-11-07',
    teknisiId: 'tek_01',
    teknisiNama: 'Farhan Lakoro',
    posName: 'PBM',
    posTag: 'PBM',
    judul: 'Pos 1 Palang Tidak bisa terangkat',
    deskripsi: errorDeskripsi,
    kategori: ErrorTicketService.kategori,
  );

  final nonErrorTask = DailyTaskModel(
    id: 'task_normal_test_1',
    tanggal: '2026-11-07',
    teknisiId: 'tek_01',
    teknisiNama: 'Farhan Lakoro',
    posName: 'PBM',
    posTag: 'PBM',
    judul: 'Pemeriksaan Rutin Gate 1',
    deskripsi: 'Cek barrier gate berkala',
    kategori: 'khusus',
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  group('CustomTaskExecutionScreen - Error Ticket Phase 2b', () {
    testWidgets('(1) error task shows Penyebab prefilled "Tidak diketahui", Solusi perbaikan, Catatan, three icon buttons with semantics labels', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: CustomTaskExecutionScreen(task: errorTask),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Selesaikan tugas'), findsOneWidget);
      expect(find.text('PBM · Pos 1 Palang Tidak bisa terangkat'), findsOneWidget);

      expect(find.text('Penyebab'), findsOneWidget);
      expect(find.text('Tidak diketahui'), findsOneWidget);
      expect(find.text('Isi awal dari admin. Ganti kalau sudah ketemu.'), findsOneWidget);

      expect(find.text('Solusi perbaikan'), findsOneWidget);
      expect(find.text('Tulis yang kamu perbaiki'), findsOneWidget);

      expect(find.text('Catatan (opsional)'), findsOneWidget);
      expect(find.text('Hal lain yang perlu disampaikan'), findsOneWidget);

      expect(find.text('Dokumentasi (foto atau video)'), findsOneWidget);
      expect(find.text('Minimal 1 foto atau 1 video.'), findsOneWidget);

      expect(find.bySemanticsLabel('Ambil foto'), findsOneWidget);
      expect(find.bySemanticsLabel('Rekam video'), findsOneWidget);
      expect(find.bySemanticsLabel('Pilih dari galeri'), findsOneWidget);

      expect(find.text('Simpan & Buat Laporan'), findsOneWidget);
      expect(find.text('Laporan balasan dibuat otomatis setelah disimpan.'), findsOneWidget);
    });

    testWidgets('(2) submit with media but empty Solusi shows "Solusi perbaikan wajib diisi."', (tester) async {
      final tempDir = Directory.systemTemp.createTempSync('bss_test_err_');
      final testPhoto = File('${tempDir.path}/photo.jpg')..writeAsStringSync('dummy');

      final draftKey = 'daily_task_draft_${errorTask.id}';
      await StorageService.setString(draftKey, '{"photos":["${testPhoto.path}"],"videos":[],"catatan":""}');

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: CustomTaskExecutionScreen(task: errorTask),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.ensureVisible(find.text('Simpan & Buat Laporan'));
      await tester.tap(find.text('Simpan & Buat Laporan'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Solusi perbaikan wajib diisi.'), findsOneWidget);

      tempDir.deleteSync(recursive: true);
    });

    testWidgets('(3) non-error task shows only Catatan and "Simpan"', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: CustomTaskExecutionScreen(task: nonErrorTask),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Catatan Laporan'), findsOneWidget);
      expect(find.text('Penyebab'), findsNothing);
      expect(find.text('Solusi perbaikan'), findsNothing);
      expect(find.text('Simpan'), findsOneWidget);
      expect(find.text('Simpan & Buat Laporan'), findsNothing);
    });

    test('(4) pure check that the catatan built for completeTask equals errorCatatanTeknisi(...)', () {
      final res = CustomTaskExecutionScreen.buildCompleteCatatan(
        isError: true,
        penyebab: 'sensor kotor',
        solusi: 'dibersihkan',
        catatan: 'lancar',
      );

      final expected = errorCatatanTeknisi(
        penyebab: 'sensor kotor',
        solusiPerbaikan: 'dibersihkan',
        catatan: 'lancar',
      );

      expect(res, equals(expected));

      final nonErrRes = CustomTaskExecutionScreen.buildCompleteCatatan(
        isError: false,
        penyebab: 'sensor',
        solusi: 'solusi',
        catatan: 'pekerjaan rutin beres',
      );
      expect(nonErrRes, equals('pekerjaan rutin beres'));
    });
  });

  group('CustomTaskExecutionScreen - Screenshots E5 & E6', () {
    setUpAll(() async {
      await _loadAppFonts();
    });

    testWidgets('e5-light-390.png', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundaryKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            home: CustomTaskExecutionScreen(task: errorTask),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      await _savePng(tester, boundaryKey, 'docs/screenshots/tiket-error/e5e6/e5-light-390.png');
    });

    testWidgets('e5-light-360-ts13.png', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundaryKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(1.3),
              ),
              child: child!,
            ),
            home: CustomTaskExecutionScreen(task: errorTask),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      await _savePng(tester, boundaryKey, 'docs/screenshots/tiket-error/e5e6/e5-light-360-ts13.png');
    });

    testWidgets('e5-dark-390.png', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundaryKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.darkTheme,
            home: CustomTaskExecutionScreen(task: errorTask),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      await _savePng(tester, boundaryKey, 'docs/screenshots/tiket-error/e5e6/e5-dark-390.png');
    });

    testWidgets('e6-light-390.png (dialog with reply text)', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundaryKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            home: CustomTaskExecutionScreen(task: errorTask),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Invoke post save dialog directly
      final dynamic state = tester.state(find.byType(CustomTaskExecutionScreen));
      state.showPostSaveDialogForTesting();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Laporan siap dikirim'), findsOneWidget);
      expect(find.text('Bagikan ke Grup'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await _savePng(tester, boundaryKey, 'docs/screenshots/tiket-error/e5e6/e6-light-390.png');
    });
  });
}
