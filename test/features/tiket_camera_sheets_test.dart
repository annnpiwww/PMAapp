import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bssparking_timemark/core/constants/app_theme.dart';
import 'package:bssparking_timemark/data/repositories/template_repository.dart';
import 'package:bssparking_timemark/data/services/absensi_setup_service.dart';
import 'package:bssparking_timemark/data/services/branch_service.dart';
import 'package:bssparking_timemark/data/services/location_service.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';
import 'package:bssparking_timemark/features/camera/widgets/daily_pulang_bottom_sheet.dart';
import 'package:bssparking_timemark/features/camera/widgets/template_quick_picker_modal.dart';
import 'package:bssparking_timemark/features/locations/widgets/location_picker_modal.dart';
import 'package:bssparking_timemark/features/templates/widgets/absensi_kategori_dialog.dart';

Future<void> loadAppFonts() async {
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
}

Future<void> _captureSheet({
  required WidgetTester tester,
  required Widget sheet,
  required Brightness brightness,
  required double width,
  required double height,
  String? outputPath,
  TextScaler? textScaler,
}) async {
  final boundaryKey = GlobalKey();
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    RepaintBoundary(
      key: boundaryKey,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: brightness == Brightness.dark ? AppTheme.darkTheme : AppTheme.lightTheme,
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, height),
            padding: const EdgeInsets.only(top: 24.0, bottom: 24.0),
            textScaler: textScaler ?? TextScaler.noScaling,
          ),
          child: Scaffold(
            backgroundColor: Colors.black,
            body: Align(
              alignment: Alignment.bottomCenter,
              child: sheet,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  if (outputPath != null) {
    final boundary = boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) throw Exception('RenderRepaintBoundary not found');

    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('Failed to get png byteData');

      final file = File(outputPath);
      file.parent.createSync(recursive: true);
      await file.writeAsBytes(byteData.buffer.asUint8List());
    });
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadAppFonts();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'bss_last_technician_name_v1': 'Ryan',
      'absensi_lokasi_standby_v1': 'PBM',
      'absensi_jadwal_shift_v1': 'Shift 1 (03:00 - 11:00)',
      'absensi_tipe_laporan_v1': 'Masuk',
    });
    await StorageService.init();
    await StorageService.saveLastTechnicianName('Ryan');

    BranchService.clientOverride = null;
    BranchService.instance.resetForTesting();
    await BranchService.instance.setBranch(AppBranch.manado);

    await TemplateRepository.instance.resetToDefaults();

    LocationService.testLocationOverride = () async => LocationResult(
      lat: 1.4921,
      lng: 124.8412,
      accuracyMeter: 5.0,
      isGpsEnabled: true,
      isMockLocation: false,
      isFallback: false,
      isDefaultFallback: false,
      posName: 'Pos Pasar Bersehati',
      cabangName: 'KC Manado',
      fullAddress: 'Jl. Sam Ratulangi No. 1, Manado',
      locationTag: 'PBM',
      tagColor: const Color(0xFF10B981),
    );
  });

  tearDown(() {
    BranchService.clientOverride = null;
    BranchService.instance.resetForTesting();
    LocationService.testLocationOverride = null;
  });

  group('Tiket Camera Sheets Screenshots & Verifications', () {
    const outputDir = 'docs/screenshots/tiket-camera-sheets';

    testWidgets('Template SOP sheet captures & asserts', (tester) async {
      final template = TemplateRepository.instance.templates.first;
      Widget buildSheet() => TemplateQuickPickerModal(
            selectedTemplate: template,
            onTemplateSelected: (_) {},
          );

      // light-360
      await _captureSheet(
        tester: tester,
        sheet: buildSheet(),
        brightness: Brightness.light,
        width: 360.0,
        height: 800.0,
        outputPath: '$outputDir/light-360-template.png',
      );
      expect(find.text('Pilih Template SOP'), findsOneWidget);
      expect(File('$outputDir/light-360-template.png').existsSync(), isTrue);

      // light-390
      await _captureSheet(
        tester: tester,
        sheet: buildSheet(),
        brightness: Brightness.light,
        width: 390.0,
        height: 844.0,
        outputPath: '$outputDir/light-390-template.png',
      );
      expect(File('$outputDir/light-390-template.png').existsSync(), isTrue);

      // dark-360
      await _captureSheet(
        tester: tester,
        sheet: buildSheet(),
        brightness: Brightness.dark,
        width: 360.0,
        height: 800.0,
        outputPath: '$outputDir/dark-360-template.png',
      );
      expect(File('$outputDir/dark-360-template.png').existsSync(), isTrue);

      // dark-390
      await _captureSheet(
        tester: tester,
        sheet: buildSheet(),
        brightness: Brightness.dark,
        width: 390.0,
        height: 844.0,
        outputPath: '$outputDir/dark-390-template.png',
      );
      expect(File('$outputDir/dark-390-template.png').existsSync(), isTrue);

      // 360 with textScaler 1.3
      await _captureSheet(
        tester: tester,
        sheet: buildSheet(),
        brightness: Brightness.light,
        width: 360.0,
        height: 800.0,
        textScaler: const TextScaler.linear(1.3),
      );
      expect(find.text('Pilih Template SOP'), findsOneWidget);
    });

    testWidgets('Atur Shift & Absensi sheet captures & asserts', (tester) async {
      Widget buildSheet() => const AbsensiKategoriDialog();

      // light-360
      await _captureSheet(
        tester: tester,
        sheet: buildSheet(),
        brightness: Brightness.light,
        width: 360.0,
        height: 800.0,
        outputPath: '$outputDir/light-360-atur-shift.png',
      );
      expect(find.text('Atur Shift & Absensi'), findsOneWidget);
      expect(find.text('Simpan Shift'), findsOneWidget);
      expect(File('$outputDir/light-360-atur-shift.png').existsSync(), isTrue);

      // light-390
      await _captureSheet(
        tester: tester,
        sheet: buildSheet(),
        brightness: Brightness.light,
        width: 390.0,
        height: 844.0,
        outputPath: '$outputDir/light-390-atur-shift.png',
      );
      expect(File('$outputDir/light-390-atur-shift.png').existsSync(), isTrue);

      // dark-360
      await _captureSheet(
        tester: tester,
        sheet: buildSheet(),
        brightness: Brightness.dark,
        width: 360.0,
        height: 800.0,
        outputPath: '$outputDir/dark-360-atur-shift.png',
      );
      expect(File('$outputDir/dark-360-atur-shift.png').existsSync(), isTrue);

      // dark-390
      await _captureSheet(
        tester: tester,
        sheet: buildSheet(),
        brightness: Brightness.dark,
        width: 390.0,
        height: 844.0,
        outputPath: '$outputDir/dark-390-atur-shift.png',
      );
      expect(File('$outputDir/dark-390-atur-shift.png').existsSync(), isTrue);

      // 360 with textScaler 1.3
      await _captureSheet(
        tester: tester,
        sheet: buildSheet(),
        brightness: Brightness.light,
        width: 360.0,
        height: 800.0,
        textScaler: const TextScaler.linear(1.3),
      );
      expect(find.text('Atur Shift & Absensi'), findsOneWidget);
      expect(find.text('Simpan Shift'), findsOneWidget);
    });

    testWidgets('Handover & Laporan Pulang sheet captures & asserts', (tester) async {
      AbsensiSetupService.instance.updateDailyHandover(
        nextShift: 'Raldy Sangkop',
        selesai: '1. Cek barrier gate masuk 1 (PBM)\n2. Ganti kertas thermal printer gate 2 (Mega Mall)',
        belum: '1. Kabel LAN kasir 2 putus (PBM)\nAlasan: tunggu kabel baru dari gudang',
      );

      Widget buildSheet() => const DailyPulangBottomSheet();

      // light-360
      await _captureSheet(
        tester: tester,
        sheet: buildSheet(),
        brightness: Brightness.light,
        width: 360.0,
        height: 800.0,
        outputPath: '$outputDir/light-360-pulang.png',
      );
      expect(find.text('Handover & Laporan Pulang'), findsOneWidget);
      expect(find.text('Simpan & Lanjut Foto Pulang'), findsOneWidget);
      expect(File('$outputDir/light-360-pulang.png').existsSync(), isTrue);

      // light-390
      await _captureSheet(
        tester: tester,
        sheet: buildSheet(),
        brightness: Brightness.light,
        width: 390.0,
        height: 844.0,
        outputPath: '$outputDir/light-390-pulang.png',
      );
      expect(File('$outputDir/light-390-pulang.png').existsSync(), isTrue);

      // dark-360
      await _captureSheet(
        tester: tester,
        sheet: buildSheet(),
        brightness: Brightness.dark,
        width: 360.0,
        height: 800.0,
        outputPath: '$outputDir/dark-360-pulang.png',
      );
      expect(File('$outputDir/dark-360-pulang.png').existsSync(), isTrue);

      // dark-390
      await _captureSheet(
        tester: tester,
        sheet: buildSheet(),
        brightness: Brightness.dark,
        width: 390.0,
        height: 844.0,
        outputPath: '$outputDir/dark-390-pulang.png',
      );
      expect(File('$outputDir/dark-390-pulang.png').existsSync(), isTrue);

      // 360 with textScaler 1.3
      await _captureSheet(
        tester: tester,
        sheet: buildSheet(),
        brightness: Brightness.light,
        width: 360.0,
        height: 800.0,
        textScaler: const TextScaler.linear(1.3),
      );
      expect(find.text('Handover & Laporan Pulang'), findsOneWidget);
    });

    testWidgets('Pilih Lokasi sheet captures & asserts', (tester) async {
      Widget buildSheet() => LocationPickerModal(
            activePos: LocationService.currentPos,
            onLocationSelected: (_) {},
          );

      // light-360
      await _captureSheet(
        tester: tester,
        sheet: buildSheet(),
        brightness: Brightness.light,
        width: 360.0,
        height: 800.0,
        outputPath: '$outputDir/light-360-lokasi.png',
      );
      expect(find.text('Pilih Lokasi'), findsOneWidget);
      expect(find.text('Simpan Lokasi'), findsOneWidget);
      expect(File('$outputDir/light-360-lokasi.png').existsSync(), isTrue);

      // light-390
      await _captureSheet(
        tester: tester,
        sheet: buildSheet(),
        brightness: Brightness.light,
        width: 390.0,
        height: 844.0,
        outputPath: '$outputDir/light-390-lokasi.png',
      );
      expect(File('$outputDir/light-390-lokasi.png').existsSync(), isTrue);

      // dark-360
      await _captureSheet(
        tester: tester,
        sheet: buildSheet(),
        brightness: Brightness.dark,
        width: 360.0,
        height: 800.0,
        outputPath: '$outputDir/dark-360-lokasi.png',
      );
      expect(File('$outputDir/dark-360-lokasi.png').existsSync(), isTrue);

      // dark-390
      await _captureSheet(
        tester: tester,
        sheet: buildSheet(),
        brightness: Brightness.dark,
        width: 390.0,
        height: 844.0,
        outputPath: '$outputDir/dark-390-lokasi.png',
      );
      expect(File('$outputDir/dark-390-lokasi.png').existsSync(), isTrue);

      // 360 with textScaler 1.3
      await _captureSheet(
        tester: tester,
        sheet: buildSheet(),
        brightness: Brightness.light,
        width: 360.0,
        height: 800.0,
        textScaler: const TextScaler.linear(1.3),
      );
      expect(find.text('Pilih Lokasi'), findsOneWidget);
      expect(find.text('Simpan Lokasi'), findsOneWidget);
    });
  });
}
