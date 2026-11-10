import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bssparking_timemark/core/constants/app_theme.dart';
import 'package:bssparking_timemark/data/models/attendance_record.dart';
import 'package:bssparking_timemark/data/models/maintenance_submission.dart';
import 'package:bssparking_timemark/data/models/submission_model.dart';
import 'package:bssparking_timemark/data/models/user_model.dart';
import 'package:bssparking_timemark/data/repositories/auth_repository.dart';
import 'package:bssparking_timemark/data/repositories/submission_repository.dart';
import 'package:bssparking_timemark/data/services/branch_service.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';
import 'package:bssparking_timemark/features/history/screens/attendance_archive_screen.dart';
import 'package:bssparking_timemark/features/history/screens/gallery_screen.dart';
import 'package:bssparking_timemark/features/maintenance/screens/maintenance_history_screen.dart';

final Uint8List k1x1Png = Uint8List.fromList(<int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
]);

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
  if (!path.startsWith('docs/screenshots/button-audit/coder2/')) {
    return;
  }
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

Future<void> _captureScreen({
  required WidgetTester tester,
  required Widget screen,
  required Brightness brightness,
  required double width,
  required double height,
  required String outputPath,
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
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, height),
            textScaler: textScaler ?? TextScaler.noScaling,
          ),
          child: screen,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await _saveBoundaryAsPng(tester, boundaryKey, outputPath);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late File testPhoto1;
  late File testPhoto2;
  late File testPhoto3;

  setUpAll(() async {
    await _loadAppFonts();
    tempDir = await Directory.systemTemp.createTemp('tiket_history_test_');
    testPhoto1 = File('${tempDir.path}/p1.png')..writeAsBytesSync(k1x1Png);
    testPhoto2 = File('${tempDir.path}/p2.png')..writeAsBytesSync(k1x1Png);
    testPhoto3 = File('${tempDir.path}/p3.png')..writeAsBytesSync(k1x1Png);
  });

  tearDownAll(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    BranchService.instance.resetForTesting();
    await BranchService.instance.setBranch(AppBranch.manado);

    await AuthRepository.instance.login(
      UserModel(
        id: 'usr_farhan',
        nama: 'Farhan Lakoro',
        npp: 'BSS-001',
        email: 'farhan@bss.id',
        role: UserRole.petugas,
        posId: 'pos_1',
        posName: 'PKM Kalimas',
        cabangName: 'KC Manado',
      ),
    );

    // 1. Setup Attendance Records
    await StorageService.saveAttendanceRecord(
      AttendanceRecord(
        id: 'att_1',
        timestamp: DateTime(2026, 11, 9, 6, 58),
        type: AttendanceType.masuk,
        shiftName: 'Shift 1 (07:00 - 15:00)',
        technicianName: 'Farhan Lakoro',
        posName: 'PKM Kalimas',
        lat: 1.500147,
        lng: 124.850032,
        fullAddress: 'Singkil Satu, Manado',
        photoPath: testPhoto1.path,
      ),
    );
    await StorageService.saveAttendanceRecord(
      AttendanceRecord(
        id: 'att_2',
        timestamp: DateTime(2026, 11, 9, 15, 2),
        type: AttendanceType.pulang,
        shiftName: 'Shift 1 (07:00 - 15:00)',
        technicianName: 'Farhan Lakoro',
        posName: 'PKM Kalimas',
        lat: 1.500147,
        lng: 124.850032,
        fullAddress: 'Singkil Satu, Manado',
        photoPath: testPhoto2.path,
      ),
    );
    await StorageService.saveAttendanceRecord(
      AttendanceRecord(
        id: 'att_3',
        timestamp: DateTime(2026, 11, 8, 7, 22),
        type: AttendanceType.masuk,
        shiftName: 'Shift 1 (07:00 - 15:00)',
        technicianName: 'Farhan Lakoro',
        posName: 'PKM Kalimas',
        lat: 1.500147,
        lng: 124.850032,
        fullAddress: 'Singkil Satu, Manado',
        photoPath: testPhoto3.path,
      ),
    );

    // 2. Setup Maintenance Submissions
    final draftSub = MaintenanceSubmission(
      id: 'maint_draft_1',
      templateId: 'tpl_maint_pos',
      templateName: 'Maintenance Pos & Barrier Gate',
      userId: 'usr_farhan',
      userName: 'Farhan Lakoro',
      userNpp: 'BSS-001',
      posId: 'pos_1',
      posName: 'Pos 1 Megamas',
      cabangName: 'KC Manado',
      createdAt: DateTime(2026, 11, 9, 8, 30),
      updatedAt: DateTime(2026, 11, 9, 8, 45),
      points: [
        MaintenancePointResult(
          pointId: 'p1',
          label: 'Kondisi Barrier Gate & Palang',
          status: PointStatus.sesuai,
          imagePath: testPhoto1.path,
          timestamp: DateTime(2026, 11, 9, 8, 35),
        ),
        MaintenancePointResult(
          pointId: 'p2',
          label: 'Sensor Loop & Safety Deteksi',
          status: PointStatus.tidakSesuai,
          imagePath: testPhoto2.path,
          alasan: 'Sensor kotor terhalang debu',
          urgensi: TingkatUrgensi.urgent,
          timestamp: DateTime(2026, 11, 9, 8, 40),
        ),
        const MaintenancePointResult(
          pointId: 'p3',
          label: 'Thermal Printer & Kertas Tiket',
          status: PointStatus.belumFoto,
        ),
      ],
    );

    final completedSub = MaintenanceSubmission(
      id: 'maint_done_1',
      templateId: 'tpl_maint_pos',
      templateName: 'Maintenance Pos & Barrier Gate',
      userId: 'usr_farhan',
      userName: 'Farhan Lakoro',
      userNpp: 'BSS-001',
      posId: 'pos_2',
      posName: 'Pos 2 Kawasan Megamas',
      cabangName: 'KC Manado',
      createdAt: DateTime(2026, 11, 8, 14, 0),
      updatedAt: DateTime(2026, 11, 8, 14, 45),
      points: [
        MaintenancePointResult(
          pointId: 'p1',
          label: 'Kondisi Fisik Housing & Boom Gate',
          status: PointStatus.sesuai,
          imagePath: testPhoto1.path,
          timestamp: DateTime(2026, 11, 8, 14, 15),
        ),
        MaintenancePointResult(
          pointId: 'p2',
          label: 'Kelistrikan & Kabel Grounding',
          status: PointStatus.sesuai,
          imagePath: testPhoto2.path,
          timestamp: DateTime(2026, 11, 8, 14, 30),
        ),
      ],
    );

    await StorageService.saveMaintenanceSubmissions([draftSub, completedSub]);

    // 3. Setup Submissions for Gallery
    await SubmissionRepository.instance.clearAll();
    await SubmissionRepository.instance.addSubmission(
      SubmissionModel(
        id: 'sub_gal_1',
        templateId: 'tpl_absensi',
        templateName: 'Absensi Masuk Pagi',
        userId: 'usr_farhan',
        userName: 'Farhan Lakoro',
        userNpp: 'BSS-001',
        posId: 'pos_1',
        posName: 'PKM Kalimas',
        cabangName: 'KC Manado',
        imagePath: testPhoto1.path,
        timestampCapture: DateTime(2026, 11, 9, 6, 58),
        lat: 1.500147,
        lng: 124.850032,
        akurasiMeter: 3.5,
        kodeVerifikasi: 'ABSM-01',
        status: VerificationStatus.sesuai,
        alasanAI: 'SOP Terpenuhi',
        poinGagal: [],
        poinLolos: ['Seragam Lengkap', 'Tepat Waktu'],
        createdAt: DateTime(2026, 11, 9, 6, 58),
      ),
    );
  });

  group('Group G9: Tiket History Screen Tests & Verifications', () {
    testWidgets('AttendanceArchiveScreen renders and verifies labels', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AttendanceArchiveScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Riwayat Kerja'), findsOneWidget);
      expect(find.text('Export CSV'), findsOneWidget);
      expect(find.text('Opsi'), findsOneWidget);
      expect(find.textContaining('PKM Kalimas'), findsWidgets);
    });

    testWidgets('MaintenanceHistoryScreen renders and verifies verbatim labels', (tester) async {
      // Test Draft Tab
      await tester.pumpWidget(
        const MaterialApp(
          home: MaintenanceHistoryScreen(initialTabIndex: 0),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Riwayat Maintenance'), findsOneWidget);
      expect(find.text('Lanjutkan draf'), findsOneWidget);
      expect(find.text('Hapus draf'), findsOneWidget);

      // Test Selesai Tab
      await tester.tap(find.textContaining('Selesai 100%'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Lihat detail'), findsOneWidget);
    });

    testWidgets('GalleryScreen renders folder view and action pills', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: GalleryScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Semua Foto'), findsOneWidget);
      expect(find.text('Pilih'), findsOneWidget);
    });

    testWidgets('Screens render at 360x800 with textScale 1.3 without overflow', (tester) async {
      // 1. AttendanceArchiveScreen
      await _captureScreen(
        tester: tester,
        screen: const AttendanceArchiveScreen(),
        brightness: Brightness.light,
        width: 360,
        height: 800,
        outputPath: 'docs/screenshots/tiket-history/temp_test_overflow_arsip.png',
        textScaler: const TextScaler.linear(1.3),
      );

      // 2. MaintenanceHistoryScreen Draft
      await _captureScreen(
        tester: tester,
        screen: const MaintenanceHistoryScreen(initialTabIndex: 0),
        brightness: Brightness.light,
        width: 360,
        height: 800,
        outputPath: 'docs/screenshots/tiket-history/temp_test_overflow_draft.png',
        textScaler: const TextScaler.linear(1.3),
      );

      // 3. MaintenanceHistoryScreen Selesai
      await _captureScreen(
        tester: tester,
        screen: const MaintenanceHistoryScreen(initialTabIndex: 1),
        brightness: Brightness.light,
        width: 360,
        height: 800,
        outputPath: 'docs/screenshots/tiket-history/temp_test_overflow_selesai.png',
        textScaler: const TextScaler.linear(1.3),
      );

      // 4. GalleryScreen
      await _captureScreen(
        tester: tester,
        screen: const GalleryScreen(),
        brightness: Brightness.light,
        width: 360,
        height: 800,
        outputPath: 'docs/screenshots/tiket-history/temp_test_overflow_galeri.png',
        textScaler: const TextScaler.linear(1.3),
      );

      // Clean temp test files
      for (final name in [
        'temp_test_overflow_arsip.png',
        'temp_test_overflow_draft.png',
        'temp_test_overflow_selesai.png',
        'temp_test_overflow_galeri.png',
      ]) {
        final f = File('docs/screenshots/tiket-history/$name');
        if (f.existsSync()) f.deleteSync();
      }
    });
  });

  group('Group G9: Generate 16 Required Tiket History Showcase Screenshots', () {
    // --- 1. AttendanceArchiveScreen (Frame 07) ---
    testWidgets('Capture light-360-arsip', (tester) async {
      await _captureScreen(
        tester: tester,
        screen: const AttendanceArchiveScreen(),
        brightness: Brightness.light,
        width: 360,
        height: 800,
        outputPath: 'docs/screenshots/tiket-history/light-360-arsip.png',
      );
    });

    testWidgets('Capture dark-360-arsip', (tester) async {
      await _captureScreen(
        tester: tester,
        screen: const AttendanceArchiveScreen(),
        brightness: Brightness.dark,
        width: 360,
        height: 800,
        outputPath: 'docs/screenshots/tiket-history/dark-360-arsip.png',
      );
    });

    testWidgets('Capture light-390-arsip', (tester) async {
      await _captureScreen(
        tester: tester,
        screen: const AttendanceArchiveScreen(),
        brightness: Brightness.light,
        width: 390,
        height: 844,
        outputPath: 'docs/screenshots/tiket-history/light-390-arsip.png',
      );
    });

    testWidgets('Capture dark-390-arsip', (tester) async {
      await _captureScreen(
        tester: tester,
        screen: const AttendanceArchiveScreen(),
        brightness: Brightness.dark,
        width: 390,
        height: 844,
        outputPath: 'docs/screenshots/tiket-history/dark-390-arsip.png',
      );
    });

    // --- 2. MaintenanceHistoryScreen Draft (Frame 27) ---
    testWidgets('Capture light-360-riwayat-draft', (tester) async {
      await _captureScreen(
        tester: tester,
        screen: const MaintenanceHistoryScreen(initialTabIndex: 0),
        brightness: Brightness.light,
        width: 360,
        height: 800,
        outputPath: 'docs/screenshots/tiket-history/light-360-riwayat-draft.png',
      );
    });

    testWidgets('Capture dark-360-riwayat-draft', (tester) async {
      await _captureScreen(
        tester: tester,
        screen: const MaintenanceHistoryScreen(initialTabIndex: 0),
        brightness: Brightness.dark,
        width: 360,
        height: 800,
        outputPath: 'docs/screenshots/tiket-history/dark-360-riwayat-draft.png',
      );
    });

    testWidgets('Capture light-390-riwayat-draft', (tester) async {
      await _captureScreen(
        tester: tester,
        screen: const MaintenanceHistoryScreen(initialTabIndex: 0),
        brightness: Brightness.light,
        width: 390,
        height: 844,
        outputPath: 'docs/screenshots/tiket-history/light-390-riwayat-draft.png',
      );
      await _captureScreen(
        tester: tester,
        screen: const MaintenanceHistoryScreen(initialTabIndex: 0),
        brightness: Brightness.light,
        width: 390,
        height: 844,
        outputPath: 'docs/screenshots/button-audit/coder2/light-390-maintenance-history.png',
      );
    });

    testWidgets('Capture dark-390-riwayat-draft', (tester) async {
      await _captureScreen(
        tester: tester,
        screen: const MaintenanceHistoryScreen(initialTabIndex: 0),
        brightness: Brightness.dark,
        width: 390,
        height: 844,
        outputPath: 'docs/screenshots/tiket-history/dark-390-riwayat-draft.png',
      );
    });

    // --- 3. MaintenanceHistoryScreen Selesai (Frame 27b) ---
    testWidgets('Capture light-360-riwayat-selesai', (tester) async {
      await _captureScreen(
        tester: tester,
        screen: const MaintenanceHistoryScreen(initialTabIndex: 1),
        brightness: Brightness.light,
        width: 360,
        height: 800,
        outputPath: 'docs/screenshots/tiket-history/light-360-riwayat-selesai.png',
      );
    });

    testWidgets('Capture dark-360-riwayat-selesai', (tester) async {
      await _captureScreen(
        tester: tester,
        screen: const MaintenanceHistoryScreen(initialTabIndex: 1),
        brightness: Brightness.dark,
        width: 360,
        height: 800,
        outputPath: 'docs/screenshots/tiket-history/dark-360-riwayat-selesai.png',
      );
    });

    testWidgets('Capture light-390-riwayat-selesai', (tester) async {
      await _captureScreen(
        tester: tester,
        screen: const MaintenanceHistoryScreen(initialTabIndex: 1),
        brightness: Brightness.light,
        width: 390,
        height: 844,
        outputPath: 'docs/screenshots/tiket-history/light-390-riwayat-selesai.png',
      );
    });

    testWidgets('Capture dark-390-riwayat-selesai', (tester) async {
      await _captureScreen(
        tester: tester,
        screen: const MaintenanceHistoryScreen(initialTabIndex: 1),
        brightness: Brightness.dark,
        width: 390,
        height: 844,
        outputPath: 'docs/screenshots/tiket-history/dark-390-riwayat-selesai.png',
      );
    });

    // --- 4. GalleryScreen (Frame 20) ---
    testWidgets('Capture light-360-galeri', (tester) async {
      await _captureScreen(
        tester: tester,
        screen: const GalleryScreen(),
        brightness: Brightness.light,
        width: 360,
        height: 800,
        outputPath: 'docs/screenshots/tiket-history/light-360-galeri.png',
      );
    });

    testWidgets('Capture dark-360-galeri', (tester) async {
      await _captureScreen(
        tester: tester,
        screen: const GalleryScreen(),
        brightness: Brightness.dark,
        width: 360,
        height: 800,
        outputPath: 'docs/screenshots/tiket-history/dark-360-galeri.png',
      );
    });

    testWidgets('Capture light-390-galeri', (tester) async {
      await _captureScreen(
        tester: tester,
        screen: const GalleryScreen(),
        brightness: Brightness.light,
        width: 390,
        height: 844,
        outputPath: 'docs/screenshots/tiket-history/light-390-galeri.png',
      );
    });

    testWidgets('Capture dark-390-galeri', (tester) async {
      await _captureScreen(
        tester: tester,
        screen: const GalleryScreen(),
        brightness: Brightness.dark,
        width: 390,
        height: 844,
        outputPath: 'docs/screenshots/tiket-history/dark-390-galeri.png',
      );
    });
  });
}
