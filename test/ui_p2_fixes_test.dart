import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bssparking_timemark/core/constants/app_theme.dart';
import 'package:bssparking_timemark/core/utils/spreadsheet_escape.dart';
import 'package:bssparking_timemark/data/models/attendance_record.dart';
import 'package:bssparking_timemark/data/models/daily_task_model.dart';
import 'package:bssparking_timemark/data/models/submission_model.dart';
import 'package:bssparking_timemark/data/models/template_model.dart';
import 'package:bssparking_timemark/data/repositories/submission_repository.dart';
import 'package:bssparking_timemark/data/services/branch_service.dart';
import 'package:bssparking_timemark/data/services/location_service.dart';
import 'package:bssparking_timemark/data/services/maintenance_log_service.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';
import 'package:bssparking_timemark/features/camera/screens/camera_capture_screen.dart';
import 'package:bssparking_timemark/features/daily_tasks/screens/custom_task_execution_screen.dart';
import 'package:bssparking_timemark/features/history/screens/attendance_archive_screen.dart';
import 'package:bssparking_timemark/features/history/screens/gallery_screen.dart';
import 'package:bssparking_timemark/features/maintenance/screens/maintenance_checklist_screen.dart';
import 'package:bssparking_timemark/features/maintenance/screens/maintenance_location_detail_screen.dart';
import 'package:bssparking_timemark/features/maintenance/screens/maintenance_map_screen.dart';
import 'package:bssparking_timemark/features/maintenance/screens/point_camera_view.dart';

Future<void> _loadAppFonts() async {
  for (final family in ['PlusJakartaSans', 'monospace', 'JetBrainsMono']) {
    final fontLoader = FontLoader(family);
    for (final file in [
      'assets/fonts/PlusJakartaSans-Regular.ttf',
      'assets/fonts/PlusJakartaSans-Medium.ttf',
      'assets/fonts/PlusJakartaSans-SemiBold.ttf',
      'assets/fonts/PlusJakartaSans-Bold.ttf',
      'assets/fonts/PlusJakartaSans-ExtraBold.ttf',
    ]) {
      final bytes = await File(file).readAsBytes();
      fontLoader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await fontLoader.load();
  }

  final flutterRoot = Platform.environment['FLUTTER_ROOT'] ?? '/home/annnpii/flutter';
  final iconFontFile = File(
    '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (iconFontFile.existsSync()) {
    final iconLoader = FontLoader('MaterialIcons');
    final bytes = await iconFontFile.readAsBytes();
    iconLoader.addFont(Future.value(ByteData.sublistView(bytes)));
    await iconLoader.load();
  }
}

Future<void> _savePng(
  WidgetTester tester,
  GlobalKey boundaryKey,
  String relativePath,
) async {
  await tester.runAsync(() async {
    final boundary =
        boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final file = File(relativePath);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(byteData!.buffer.asUint8List());
  });
}

Widget _wrap320Ts13({
  required GlobalKey boundaryKey,
  required Widget child,
  ThemeData? theme,
  ThemeMode themeMode = ThemeMode.light,
}) {
  return RepaintBoundary(
    key: boundaryKey,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme ?? AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      builder: (context, inner) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(1.3),
          ),
          child: inner!,
        );
      },
      home: child,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => Directory.systemTemp.path,
    );
    await _loadAppFonts();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    await BranchService.instance.setBranch(AppBranch.manado);
    await SubmissionRepository.instance.init();
  });

  test('SEC-08 CSV formula escaping prefixes single quote on formula starters', () {
    expect(escapeSpreadsheetCell('=CMD()'), "'=CMD()");
    expect(escapeSpreadsheetCell('+SUM(A1:A2)'), "'+SUM(A1:A2)");
    expect(escapeSpreadsheetCell('-1+2'), "'-1+2");
    expect(escapeSpreadsheetCell('@A1'), "'@A1");
    expect(escapeSpreadsheetCell('\tmalicious'), "'\tmalicious");
    expect(escapeSpreadsheetCell('\rmalicious'), "'\rmalicious");
    expect(escapeSpreadsheetCell('Normal text'), 'Normal text');
    expect(escapeSpreadsheetCell(''), '');
  });

  testWidgets(
    'UI-11 CustomTaskExecutionScreen wraps long pos name and photo count at 320x640 ts1.3',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final boundaryKey = GlobalKey();
      final task = DailyTaskModel(
        id: 'task_ui11',
        tanggal: '2026-11-07',
        teknisiId: 'TEK-01',
        teknisiNama: 'Alexander M. Pratama',
        posName: 'RSUP Prof. Dr. R. D. Kandou Manado Gedung Utama',
        posTag: 'KANDOU',
        judul: 'Perbaikan Barrier Gate Jalur VIP & Kalibrasi Loop Detector',
        deskripsi: 'Cek sensor loop detector dan konektor power supply utama.',
        kategori: 'khusus',
      );

      await tester.pumpWidget(
        _wrap320Ts13(
          boundaryKey: boundaryKey,
          child: CustomTaskExecutionScreen(task: task),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      expect(tester.takeException(), isNull);
      await _savePng(
        tester,
        boundaryKey,
        'docs/screenshots/fix-2026-11-07/ui11_custom_task_execution_ts13.png',
      );
    },
  );

  testWidgets(
    'UI-12 AttendanceArchiveScreen wraps late + AI badges at 320x640 ts1.3',
    skip: true, // redesign layout, TODO post-2.0.135
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await StorageService.saveAttendanceRecord(
        AttendanceRecord(
          id: 'rec_ui12_1',
          technicianName: 'Budi Santoso',
          type: AttendanceType.masuk,
          shiftName: 'Shift 1 (06.00 - 14.00)',
          posName: 'PKM Kalimas',
          timestamp: DateTime(2026, 11, 7, 6, 25),
          lat: 1.500147,
          lng: 124.850032,
          fullAddress: 'Singkil Satu, Manado',
          workDuration: '8j 15m',
          isAiVerified: false,
          aiStatusText: 'Perlu Cek Manual SPV',
        ),
      );

      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        _wrap320Ts13(
          boundaryKey: boundaryKey,
          child: const AttendanceArchiveScreen(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      expect(tester.takeException(), isNull);
      expect(find.text('Terlambat'), findsWidgets);
      expect(find.text('Perlu Cek Manual SPV'), findsOneWidget);

      await _savePng(
        tester,
        boundaryKey,
        'docs/screenshots/fix-2026-11-07/ui12_attendance_archive_badges_ts13.png',
      );
    },
  );

  testWidgets(
    'UI-13 GalleryScreen album date text uses ellipsis and count chip never overlaps at 320x640 ts1.3',
    skip: true, // redesign layout, TODO post-2.0.135
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await SubmissionRepository.instance.addSubmission(
        SubmissionModel(
          id: 'sub_ui13',
          templateId: 'absen_masuk',
          templateName: 'Absensi Masuk Operasional Shift Pagi',
          userId: 'TEK-01',
          userName: 'Budi Santoso',
          userNpp: 'BSS-101',
          posId: 'MND-01',
          posName: 'RSUP Prof. Dr. R. D. Kandou Manado',
          cabangName: 'KC Manado',
          imagePath: 'data:image/png;base64,invalid',
          timestampCapture: DateTime(2026, 9, 30, 8, 15),
          kodeVerifikasi: 'V-UI13',
          status: VerificationStatus.sesuai,
          alasanAI: 'Sesuai SOP',
          createdAt: DateTime(2026, 9, 30, 8, 15),
        ),
      );

      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        _wrap320Ts13(
          boundaryKey: boundaryKey,
          child: const GalleryScreen(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      expect(tester.takeException(), isNull);
      expect(find.text('1 Foto ❯'), findsOneWidget);

      await _savePng(
        tester,
        boundaryKey,
        'docs/screenshots/fix-2026-11-07/ui13_gallery_album_date_ts13.png',
      );
    },
  );

  testWidgets(
    'UI-14 CameraCaptureScreen shift shortcut pill tap target >= 48x48 and label >= 12sp at 320x640 ts1.3',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        _wrap320Ts13(
          boundaryKey: boundaryKey,
          child: const CameraCaptureScreen(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(tester.takeException(), isNull);

      final pillFinder = find.byKey(const Key('attendance_shift_shortcut_pill'));
      expect(pillFinder, findsOneWidget);
      final pillSize = tester.getSize(pillFinder);
      expect(pillSize.width, greaterThanOrEqualTo(48.0));
      expect(pillSize.height, greaterThanOrEqualTo(48.0));

      final pillTexts = tester.widgetList<Text>(
        find.descendant(of: pillFinder, matching: find.byType(Text)),
      );
      expect(pillTexts, isNotEmpty);
      expect(pillTexts.first.style?.fontSize, greaterThanOrEqualTo(12.0));

      await _savePng(
        tester,
        boundaryKey,
        'docs/screenshots/fix-2026-11-07/ui14_camera_shift_pill_ts13.png',
      );
    },
  );

  testWidgets(
    'UI-15 PointCameraView back and flash buttons have >= 48x48 tap targets at 320x640 ts1.3',
    skip: true, // redesign layout, TODO post-2.0.135
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const point = SopPoint(
        id: 'p1',
        label: 'Panel Kontrol Barrier Gate & Loop Detector',
        deskripsi: 'Pastikan kabel rapi dan indikator menyala normal.',
        panduanFoto: 'Ambil foto seluruh isi box panel dari depan.',
      );
      final template = TemplateModel(
        id: 'maint_barrier',
        nama: 'Maintenance Barrier Gate',
        deskripsi: 'Inspeksi rutin barrier gate',
        jenis: TemplateCategory.maintBarrier,
        createdBy: 'System',
        updatedAt: DateTime(2026, 11, 7),
      );

      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        _wrap320Ts13(
          boundaryKey: boundaryKey,
          child: PointCameraView(point: point, template: template),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(tester.takeException(), isNull);

      final backFinder = find.byKey(const Key('point_camera_back_button'));
      final flashFinder = find.byKey(const Key('point_camera_flash_button'));
      expect(backFinder, findsOneWidget);
      expect(flashFinder, findsOneWidget);

      final backSize = tester.getSize(backFinder);
      final flashSize = tester.getSize(flashFinder);
      expect(backSize.width, greaterThanOrEqualTo(48.0));
      expect(backSize.height, greaterThanOrEqualTo(48.0));
      expect(flashSize.width, greaterThanOrEqualTo(48.0));
      expect(flashSize.height, greaterThanOrEqualTo(48.0));

      await _savePng(
        tester,
        boundaryKey,
        'docs/screenshots/fix-2026-11-07/ui15_point_camera_targets_ts13.png',
      );
    },
  );

  testWidgets(
    'UI-16 MaintenanceMapScreen and MaintenanceLocationDetailScreen use dark theme colors at 320x640 ts1.3',
    skip: true, // redesign layout, TODO post-2.0.135
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        _wrap320Ts13(
          boundaryKey: boundaryKey,
          theme: AppTheme.darkTheme,
          themeMode: ThemeMode.dark,
          child: const MaintenanceMapScreen(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(tester.takeException(), isNull);

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(scaffold.backgroundColor, isNot(equals(const Color(0xFFF8FAFC))));
      expect(scaffold.backgroundColor, isNot(equals(const Color(0xFFFFFFFF))));

      final appBar = tester.widget<AppBar>(find.byType(AppBar).first);
      expect(appBar.backgroundColor, isNot(equals(const Color(0xFFFFFFFF))));

      await _savePng(
        tester,
        boundaryKey,
        'docs/screenshots/fix-2026-11-07/ui16_maintenance_map_dark_ts13.png',
      );

      // Also verify MaintenanceLocationDetailScreen in dark mode at 320x640 ts1.3
      final loc = LocationService.getLocationsByBranch(AppBranch.manado).first;
      final status = PosMaintenanceStatus(
        location: loc,
        wilayah: 'Manado',
        logs: const [],
      );
      final detailKey = GlobalKey();
      await tester.pumpWidget(
        _wrap320Ts13(
          boundaryKey: detailKey,
          theme: AppTheme.darkTheme,
          themeMode: ThemeMode.dark,
          child: MaintenanceLocationDetailScreen(
            status: status,
            month: DateTime(2026, 11, 1),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      expect(tester.takeException(), isNull);
      final detailScaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(
        detailScaffold.backgroundColor,
        isNot(equals(const Color(0xFFF8FAFC))),
      );
    },
  );

  testWidgets(
    'UI-16b MaintenanceMapScreen date chip and Temuan stat label fit without overflow at 320 and 360 ts1.3 (light & dark)',
    (tester) async {
      for (final width in [320.0, 360.0]) {
        for (final isDark in [false, true]) {
          await tester.binding.setSurfaceSize(Size(width, 640));
          final boundaryKey = GlobalKey();
          await tester.pumpWidget(
            _wrap320Ts13(
              boundaryKey: boundaryKey,
              theme: isDark ? AppTheme.darkTheme : AppTheme.lightTheme,
              themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
              child: const MaintenanceMapScreen(),
            ),
          );
          await tester.pump(const Duration(milliseconds: 500));

          expect(tester.takeException(), isNull);
          expect(find.text('Temuan'), findsOneWidget);
          expect(find.text('Belum'), findsOneWidget);
          expect(find.text('Aman'), findsOneWidget);

          if (width == 360.0 && !isDark) {
            await _savePng(
              tester,
              boundaryKey,
              'docs/screenshots/fix-2026-11-07/ui16b_map_header_ts13.png',
            );
          }
        }
      }
      addTearDown(() => tester.binding.setSurfaceSize(null));
    },
  );

  testWidgets(
    'UI-17 MaintenanceChecklistScreen drops redundant Maintenance prefix, supports 2 lines + tooltip at 320 and 360 ts1.3',
    skip: true, // redesign layout, TODO post-2.0.135
    (tester) async {
      final loc = LocationService.getLocationsByBranch(AppBranch.manado).first;
      final template = TemplateModel(
        id: 'tpl_maint_pos',
        nama: 'Maintenance: Pos Parkir & Booth (${loc.posName})',
        deskripsi: 'Pengecekan rutin pos kasir dan booth parkir',
        jenis: TemplateCategory.maintPos,
        createdBy: 'System',
        updatedAt: DateTime(2026, 11, 7),
        sopPoints: const [
          SopPoint(
            id: 'pos_1_01',
            label: 'Kondisi Kaca & Cat Booth Kasir',
            deskripsi: 'Pastikan kaca bersih dan cat tidak mengelupas.',
            panduanFoto: 'Foto seluruh bodi pos kasir dari depan.',
          ),
        ],
      );

      for (final width in [320.0, 360.0]) {
        await tester.binding.setSurfaceSize(Size(width, 640));
        final boundaryKey = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundaryKey,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme,
              builder: (context, inner) {
                return MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: const TextScaler.linear(1.3),
                  ),
                  child: inner!,
                );
              },
              onGenerateRoute: (settings) {
                return MaterialPageRoute<void>(
                  builder: (ctx) => Scaffold(
                    body: Center(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(ctx).push(
                            MaterialPageRoute<void>(
                              builder: (_) => MaintenanceChecklistScreen(
                                template: template,
                                location: loc,
                                unitCount: 1,
                              ),
                            ),
                          );
                        },
                        child: const Text('Open'),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
        await tester.pump();
        await tester.tap(find.text('Open'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(tester.takeException(), isNull);
        expect(find.byType(BackButton), findsOneWidget);
        expect(
          find.text('Pos Parkir & Booth (${loc.posName})'),
          findsOneWidget,
        );
        expect(
          find.byTooltip('Maintenance: Pos Parkir & Booth (${loc.posName})'),
          findsOneWidget,
        );

        final titleText = tester.widget<Text>(
          find.text('Pos Parkir & Booth (${loc.posName})'),
        );
        expect(titleText.maxLines, equals(2));
        expect(titleText.overflow, equals(TextOverflow.ellipsis));

        if (width == 360.0) {
          await _savePng(
            tester,
            boundaryKey,
            'docs/screenshots/fix-2026-11-07/ui17_checklist_title_ts13.png',
          );
        }
      }
      addTearDown(() => tester.binding.setSurfaceSize(null));
    },
  );
}
