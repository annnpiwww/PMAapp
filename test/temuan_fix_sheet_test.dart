import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bssparking_timemark/data/models/maintenance_temuan_fix.dart';
import 'package:bssparking_timemark/data/services/location_service.dart';
import 'package:bssparking_timemark/data/services/maintenance_fix_service.dart';
import 'package:bssparking_timemark/data/services/maintenance_log_service.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';
import 'package:bssparking_timemark/features/maintenance/screens/maintenance_location_detail_screen.dart';
import 'package:bssparking_timemark/features/maintenance/screens/maintenance_map_screen.dart';
import 'package:bssparking_timemark/features/maintenance/widgets/temuan_fix_sheet.dart';

bool _fontsLoaded = false;
Future<void> _loadAppFonts() async {
  if (_fontsLoaded) return;
  final fontLoader = FontLoader('Figtree');
  for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
    final file = File('assets/fonts/Figtree-$weight.ttf');
    if (file.existsSync()) {
      fontLoader.addFont(Future.value(ByteData.view(file.readAsBytesSync().buffer)));
    }
  }
  await fontLoader.load();

  final iconFile = File('/home/annnpii/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (iconFile.existsSync()) {
    final iconLoader = FontLoader('MaterialIcons');
    iconLoader.addFont(Future.value(ByteData.view(iconFile.readAsBytesSync().buffer)));
    await iconLoader.load();
  }
  _fontsLoaded = true;
}

Future<void> _saveBoundaryPng(WidgetTester tester, GlobalKey key, String filename) async {
  await tester.runAsync(() async {
    final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return;
    final image = await boundary.toImage(pixelRatio: 1.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return;
    final dir = Directory('docs/audit/2026-11-08-temuan-fix');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(byteData.buffer.asUint8List());
  });
}

MaintenanceLogEntry _createSampleLog({MaintenanceTemuanFix? fix1, MaintenanceTemuanFix? fix2}) {
  return MaintenanceLogEntry(
    id: 'log_test_001',
    tanggal: '2026-11-08',
    jamSelesai: '14:20 WITA',
    posId: 'POS-01',
    posName: 'Gate 1 PBM',
    branch: 'MDO',
    teknisiNama: 'Alessandro',
    templateId: 'tpl_maint_manless',
    templateName: 'Manless & Pulau Gate',
    totalPoin: 24,
    sesuaiPoin: 23,
    temuan: [
      MaintenanceTemuan(
        label: 'Printer tiket Gate 1',
        status: 'tidak_sesuai',
        alasan: 'Kertas macet, roller kotor',
        urgent: true,
        fix: fix1,
      ),
      MaintenanceTemuan(
        label: 'Barrier gate motor',
        status: 'perlu_cek_manual',
        alasan: 'Bunyi decit saat palang turun',
        urgent: false,
        fix: fix2,
      ),
    ],
  );
}

PosMaintenanceStatus _createSampleStatus(MaintenanceLogEntry log) {
  return PosMaintenanceStatus(
    location: const PosLocation(
      posId: 'POS-01',
      posName: 'Gate 1 PBM',
      cabangName: 'Manado',
      fullAddress: 'Jl. Sam Ratulangi No. 1',
      locationTag: 'PBM',
      tagColor: Colors.blue,
      lat: 1.485,
      lng: 124.845,
    ),
    wilayah: 'Manado',
    logs: [log],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    await _loadAppFonts();
  });

  group('TemuanFixSheet & Maintenance Location Detail UI Tests', () {
    testWidgets('(a) Simpan disabled with 0 photos or catatan < 3', (tester) async {
      final log = _createSampleLog();
      final temuan = log.temuan.first;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'Figtree'),
          home: Scaffold(
            body: TemuanFixSheet(
              log: log,
              temuan: temuan,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final buttonFinder = find.widgetWithText(ElevatedButton, 'Simpan Perbaikan');
      expect(buttonFinder, findsOneWidget);

      ElevatedButton button = tester.widget<ElevatedButton>(buttonFinder);
      expect(button.onPressed, isNull, reason: 'Disabled when 0 photos and empty text');

      // Enter text with length 2 (< 3)
      await tester.enterText(find.byType(TextField), 'AB');
      await tester.pumpAndSettle();

      button = tester.widget<ElevatedButton>(buttonFinder);
      expect(button.onPressed, isNull, reason: 'Still disabled when text < 3');

      // Enter valid text >= 3 but 0 photos
      await tester.enterText(find.byType(TextField), 'Ganti roller');
      await tester.pumpAndSettle();

      button = tester.widget<ElevatedButton>(buttonFinder);
      expect(button.onPressed, isNull, reason: 'Still disabled when 0 photos');
    });

    testWidgets('(b) enabled with 1 photo + Ganti roller', (tester) async {
      final log = _createSampleLog();
      final temuan = log.temuan.first;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'Figtree'),
          home: Scaffold(
            body: TemuanFixSheet(
              log: log,
              temuan: temuan,
              onPickPhoto: () async => '/tmp/photo_test_1.jpg',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Pick photo
      await tester.tap(find.text('+ Ambil Foto'));
      await tester.pumpAndSettle();

      // Enter text
      await tester.enterText(find.byType(TextField), 'Ganti roller');
      await tester.pumpAndSettle();

      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Simpan Perbaikan'),
      );
      expect(button.onPressed, isNotNull, reason: 'Enabled when 1 photo and text >= 3');
    });

    testWidgets('(c) after synced result the detail card shows Sudah diperbaiki and button is gone', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final log = _createSampleLog();
      final status = _createSampleStatus(log);

      final fixedItem = MaintenanceTemuanFix(
        id: 'fix_101',
        logId: log.id,
        temuanLabel: 'Printer tiket Gate 1',
        posId: 'POS-01',
        posName: 'Gate 1 PBM',
        teknisiNama: 'Alessandro',
        catatan: 'Ganti roller, bersihkan jalur kertas',
        photoUrls: ['/tmp/photo1.jpg'],
        fixedAt: DateTime(2026, 11, 8, 14, 20),
        pendingSync: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'Figtree'),
          home: MaintenanceLocationDetailScreen(
            status: status,
            month: DateTime(2026, 11, 1),
            sheetOnPickPhoto: () async => '/tmp/photo1.jpg',
            sheetOnSubmit: ({required log, required temuan, required catatan, required photoPaths}) async {
              return FixSubmitResult.synced(fixedItem);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially unfixed: shows Tandai Sudah Diperbaiki button
      expect(find.text('Tandai Sudah Diperbaiki'), findsOneWidget);
      expect(find.text('Diperbaiki'), findsNothing);

      // Tap Tandai Sudah Diperbaiki
      await tester.tap(find.text('Tandai Sudah Diperbaiki'));
      await tester.pumpAndSettle();

      // Pick photo in sheet
      await tester.tap(find.text('+ Ambil Foto'));
      await tester.pumpAndSettle();

      // Enter catatan
      await tester.enterText(find.byType(TextField), 'Ganti roller, bersihkan jalur kertas');
      await tester.pumpAndSettle();

      // Submit
      await tester.tap(find.widgetWithText(ElevatedButton, 'Simpan Perbaikan'));
      await tester.pumpAndSettle();

      // Card is updated to fixed state:
      expect(find.text('Diperbaiki'), findsOneWidget);
      expect(find.text('Ganti roller, bersihkan jalur kertas'), findsOneWidget);
      expect(find.text('Oleh Alessandro'), findsOneWidget);
      expect(find.text('8 Nov 14:20 WITA'), findsOneWidget);
      expect(find.text('Kirim ulang laporan WA'), findsOneWidget);

      // Tab updates to 1 open temuan remaining
      expect(find.text('Temuan (1)'), findsOneWidget);

      // Button is gone
      expect(find.text('Tandai Sudah Diperbaiki'), findsNothing);

      // WhatsApp share dialog appears
      expect(find.text('Kirim laporan ke WhatsApp?'), findsOneWidget);
      expect(find.text('Nanti'), findsOneWidget);
      expect(find.text('Kirim WA'), findsOneWidget);

      await tester.tap(find.text('Nanti'));
      await tester.pumpAndSettle();
    });

    testWidgets('(d) queued result shows Menunggu sinyal, dikirim otomatis', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final queuedFix = MaintenanceTemuanFix(
        id: 'fix_102',
        logId: 'log_test_001',
        temuanLabel: 'Printer tiket Gate 1',
        posId: 'POS-01',
        posName: 'Gate 1 PBM',
        teknisiNama: 'Alessandro',
        catatan: 'Ganti roller, perbaikan offline',
        photoUrls: ['/tmp/photo1.jpg'],
        fixedAt: DateTime(2026, 11, 8, 14, 20),
        pendingSync: true,
      );

      final log = _createSampleLog(fix1: queuedFix);
      final status = _createSampleStatus(log);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'Figtree'),
          home: MaintenanceLocationDetailScreen(
            status: status,
            month: DateTime(2026, 11, 1),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Diperbaiki'), findsOneWidget);
      expect(find.text('Menunggu sinyal, dikirim otomatis'), findsOneWidget);
    });

    testWidgets('(e) perlu_cek_manual temuan has no button', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final log = _createSampleLog();
      final status = _createSampleStatus(log);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'Figtree'),
          home: MaintenanceLocationDetailScreen(
            status: status,
            month: DateTime(2026, 11, 1),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Perlu Cek'), findsOneWidget);
      // There should only be 1 button for the 'tidak_sesuai' item, NOT for 'perlu_cek_manual'
      expect(find.text('Tandai Sudah Diperbaiki'), findsOneWidget);
    });

    testWidgets('(f) 360x780 at textScaler 1.3 renders sheet with 3 thumbs and error text without RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final log = _createSampleLog();
      final temuan = log.temuan.first;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'Figtree'),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 780),
              textScaler: TextScaler.linear(1.3),
            ),
            child: Scaffold(
              body: TemuanFixSheet(
                log: log,
                temuan: temuan,
                onSubmit: ({required log, required temuan, required catatan, required photoPaths}) async {
                  return FixSubmitResult.invalid('Catatan tindakan tidak valid atau foto kurang.');
                },
                onPickPhoto: () async => '/tmp/photo.jpg',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Pick 3 photos
      for (int i = 0; i < 3; i++) {
        await tester.tap(find.text('+ Ambil Foto'));
        await tester.pumpAndSettle();
      }

      // Enter text and submit to trigger error text
      await tester.enterText(find.byType(TextField), 'Test tindakan');
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Simpan Perbaikan'));
      await tester.pumpAndSettle();

      expect(find.text('Catatan tindakan tidak valid atau foto kurang.'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'No RenderFlex overflow on 360x780 at textScaler 1.3');
    });

    testWidgets('Capture Screenshots for Docs Audit', (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final log = _createSampleLog();
      final temuan = log.temuan.first;

      // 01-card-unfixed-360.png
      final key1 = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(fontFamily: 'Figtree', useMaterial3: true),
          home: Scaffold(
            backgroundColor: MaintenanceMapPalette.bg,
            body: Center(
              child: RepaintBoundary(
                key: key1,
                child: SizedBox(
                  width: 360,
                  height: 780,
                  child: MaintenanceLocationDetailScreen(
                    status: _createSampleStatus(log),
                    month: DateTime(2026, 11, 1),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _saveBoundaryPng(tester, key1, '01-card-unfixed-360.png');

      // 02-sheet-empty-360.png
      final key2 = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(fontFamily: 'Figtree', useMaterial3: true),
          home: Scaffold(
            backgroundColor: Colors.black54,
            body: Align(
              alignment: Alignment.bottomCenter,
              child: RepaintBoundary(
                key: key2,
                child: SizedBox(
                  width: 360,
                  child: TemuanFixSheet(
                    log: log,
                    temuan: temuan,
                    onPickPhoto: () async => '/tmp/proof.jpg',
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _saveBoundaryPng(tester, key2, '02-sheet-empty-360.png');

      // 03-sheet-filled-3photos-360.png
      final key3 = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(fontFamily: 'Figtree', useMaterial3: true),
          home: Scaffold(
            backgroundColor: Colors.black54,
            body: Align(
              alignment: Alignment.bottomCenter,
              child: RepaintBoundary(
                key: key3,
                child: SizedBox(
                  width: 360,
                  child: TemuanFixSheet(
                    log: log,
                    temuan: temuan,
                    onPickPhoto: () async => '/tmp/proof.jpg',
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (int i = 0; i < 3; i++) {
        await tester.tap(find.text('+ Ambil Foto'));
        await tester.pumpAndSettle();
      }
      await tester.enterText(
        find.byType(TextField),
        'Ganti roller, bersihkan jalur kertas dan sensor pembaca',
      );
      await tester.pumpAndSettle();
      await _saveBoundaryPng(tester, key3, '03-sheet-filled-3photos-360.png');

      // 04-card-fixed-360.png
      final fixedLog = _createSampleLog(
        fix1: MaintenanceTemuanFix(
          id: 'fix_1',
          logId: log.id,
          temuanLabel: 'Printer tiket Gate 1',
          posId: 'POS-01',
          posName: 'Gate 1 PBM',
          teknisiNama: 'Alessandro',
          catatan: 'Ganti roller, bersihkan jalur kertas',
          photoUrls: ['/tmp/photo1.jpg'],
          fixedAt: DateTime(2026, 11, 8, 14, 20),
          pendingSync: false,
        ),
      );
      final key4 = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(fontFamily: 'Figtree', useMaterial3: true),
          home: Scaffold(
            backgroundColor: MaintenanceMapPalette.bg,
            body: Center(
              child: RepaintBoundary(
                key: key4,
                child: SizedBox(
                  width: 360,
                  height: 780,
                  child: MaintenanceLocationDetailScreen(
                    status: _createSampleStatus(fixedLog),
                    month: DateTime(2026, 11, 1),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _saveBoundaryPng(tester, key4, '04-card-fixed-360.png');

      // 04-card-fixed-360-dark.png (Dark Mode Variant)
      final key4Dark = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            fontFamily: 'Figtree',
            useMaterial3: true,
            brightness: Brightness.dark,
          ),
          home: Scaffold(
            backgroundColor: const Color(0xFF0F172A),
            body: Center(
              child: RepaintBoundary(
                key: key4Dark,
                child: SizedBox(
                  width: 360,
                  height: 780,
                  child: MaintenanceLocationDetailScreen(
                    status: _createSampleStatus(fixedLog),
                    month: DateTime(2026, 11, 1),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _saveBoundaryPng(tester, key4Dark, '04-card-fixed-360-dark.png');

      // 05-card-pending-360.png
      final pendingLog = _createSampleLog(
        fix1: MaintenanceTemuanFix(
          id: 'fix_pending_1',
          logId: log.id,
          temuanLabel: 'Printer tiket Gate 1',
          posId: 'POS-01',
          posName: 'Gate 1 PBM',
          teknisiNama: 'Alessandro',
          catatan: 'Ganti roller, perbaikan offline',
          photoUrls: ['/tmp/photo1.jpg'],
          fixedAt: DateTime(2026, 11, 8, 14, 20),
          pendingSync: true,
        ),
      );
      final key5 = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(fontFamily: 'Figtree', useMaterial3: true),
          home: Scaffold(
            backgroundColor: MaintenanceMapPalette.bg,
            body: Center(
              child: RepaintBoundary(
                key: key5,
                child: SizedBox(
                  width: 360,
                  height: 780,
                  child: MaintenanceLocationDetailScreen(
                    status: _createSampleStatus(pendingLog),
                    month: DateTime(2026, 11, 1),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _saveBoundaryPng(tester, key5, '05-card-pending-360.png');

      // 06-sheet-ts13-360.png
      final key6 = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(fontFamily: 'Figtree', useMaterial3: true),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 780),
              textScaler: TextScaler.linear(1.3),
            ),
            child: Scaffold(
              backgroundColor: Colors.black54,
              body: Align(
                alignment: Alignment.bottomCenter,
                child: RepaintBoundary(
                  key: key6,
                  child: SizedBox(
                    width: 360,
                    child: TemuanFixSheet(
                      log: log,
                      temuan: temuan,
                      onPickPhoto: () async => '/tmp/proof.jpg',
                      onSubmit: ({required log, required temuan, required catatan, required photoPaths}) async {
                        return FixSubmitResult.invalid('Foto bukti perbaikan wajib 1-3.');
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (int i = 0; i < 3; i++) {
        await tester.tap(find.text('+ Ambil Foto'));
        await tester.pumpAndSettle();
      }
      await tester.enterText(find.byType(TextField), 'Perbaikan roller');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Simpan Perbaikan'));
      await tester.pumpAndSettle();
      await _saveBoundaryPng(tester, key6, '06-sheet-ts13-360.png');

      // 07-detail-full-412.png (412x915) for side-by-side with reference
      tester.view.physicalSize = const Size(412, 915);
      final key7 = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(fontFamily: 'Figtree', useMaterial3: true),
          home: Scaffold(
            backgroundColor: MaintenanceMapPalette.bg,
            body: Center(
              child: RepaintBoundary(
                key: key7,
                child: SizedBox(
                  width: 412,
                  height: 915,
                  child: MaintenanceLocationDetailScreen(
                    status: _createSampleStatus(fixedLog),
                    month: DateTime(2026, 11, 1),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _saveBoundaryPng(tester, key7, '07-detail-full-412.png');
    });
  });
}
