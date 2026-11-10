import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bssparking_timemark/core/constants/app_theme.dart';
import 'package:bssparking_timemark/data/models/daily_task_model.dart';
import 'package:bssparking_timemark/data/models/user_model.dart';
import 'package:bssparking_timemark/data/repositories/auth_repository.dart';
import 'package:bssparking_timemark/data/services/branch_service.dart';
import 'package:bssparking_timemark/data/services/daily_task_service.dart';
import 'package:bssparking_timemark/data/services/location_service.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';
import 'package:bssparking_timemark/features/daily_tasks/screens/spv_task_dispatcher_screen.dart';
import 'package:bssparking_timemark/features/daily_tasks/widgets/ad_hoc_task_dialog.dart';
import 'package:bssparking_timemark/features/daily_tasks/widgets/spv_task_card.dart';

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
    debugPrint('Generated screenshot: $path (${file.lengthSync()} bytes)');
  });
}

UserModel _supervisor() => UserModel(
      id: 'spv-1',
      nama: 'Farhan Lakoro',
      npp: 'BSS-001',
      email: 'farhan@bss.id',
      role: UserRole.supervisor,
      posId: 'POS-01',
      posName: 'Pos Gate Utama',
      cabangName: 'KC Manado',
    );

DailyTaskModel _sampleTask({
  required String id,
  required String judul,
  String kategori = 'error',
  TaskStatus status = TaskStatus.pending,
  String teknisi = 'Farhan Lakoro',
}) {
  return DailyTaskModel(
    id: id,
    tanggal: '2026-11-10',
    teknisiId: 'u-$teknisi',
    teknisiNama: teknisi,
    posName: 'PBM',
    posTag: 'PBM',
    judul: judul,
    deskripsi: 'Kendala: Palang macet',
    kategori: kategori,
    status: status,
  );
}

Future<void> _seed({List<DailyTaskModel> tasks = const []}) async {
  SharedPreferences.setMockInitialValues({});
  await StorageService.init();
  BranchService.instance.resetForTesting();
  await BranchService.instance.setBranch(AppBranch.manado);
  await StorageService.setString(
    DailyTaskService.localCacheKey,
    jsonEncode(tasks.map((t) => t.toJson()).toList()),
  );
  await AuthRepository.instance.login(_supervisor());
}

Widget _buildDispatcherApp({
  required GlobalKey boundaryKey,
  required double width,
  required double height,
  double textScale = 1.0,
  ThemeData? theme,
}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: theme ?? AppTheme.lightTheme,
    home: MediaQuery(
      data: MediaQueryData(
        size: Size(width, height),
        textScaler: TextScaler.linear(textScale),
        padding: const EdgeInsets.only(top: 24, bottom: 24),
      ),
      child: RepaintBoundary(
        key: boundaryKey,
        child: const SpvTaskDispatcherScreen(),
      ),
    ),
  );
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _loadAppFonts();
  });

  group('Spv Error Entry Tests', () {
    testWidgets('(1) dispatcher shows both Laporan Error and Buat Tugas at 360 width textScale 1.3 with no overflow exception', (tester) async {
      await _seed(tasks: [_sampleTask(id: 't1', judul: 'Pos 1 Palang macet')]);

      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        _buildDispatcherApp(
          boundaryKey: boundaryKey,
          width: 360.0,
          height: 800.0,
          textScale: 1.3,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.bySemanticsLabel('Laporan Error'), findsOneWidget);
      expect(find.text('Buat Tugas'), findsOneWidget);
    });

    testWidgets('(2) SpvTaskCard with onKerjakan shows Kerjakan, without it does not', (tester) async {
      bool kerjakanPressed = false;
      final task = _sampleTask(id: 't1', judul: 'Pos 1 Palang macet');

      // Test with onKerjakan
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: SpvTaskCard(
              task: task,
              isDark: false,
              isExpanded: false,
              onToggleExpand: () {},
              onKerjakan: () => kerjakanPressed = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Kerjakan'), findsOneWidget);
      await tester.tap(find.text('Kerjakan'));
      await tester.pumpAndSettle();
      expect(kerjakanPressed, isTrue);

      // Test without onKerjakan
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: SpvTaskCard(
              task: task,
              isDark: false,
              isExpanded: false,
              onToggleExpand: () {},
              onKerjakan: null,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Kerjakan'), findsNothing);
    });

    testWidgets('(3) AdHocTaskDialog with startInErrorMode true shows Tempel dari Telegram immediately', (tester) async {
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
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: AdHocTaskDialog(
              teknisiNama: 'Farhan Lakoro',
              tanggal: '2026-11-10',
              lokasiOptions: sampleOptions,
              startInErrorMode: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tempel dari Telegram'), findsOneWidget);
      expect(find.text('Kerjaan apa *'), findsNothing);
    });
  });

  group('Spv Error Entry Screenshots', () {
    const outDir = 'docs/screenshots/tiket-error/spv';

    testWidgets('Capture dispatcher-light-390.png', (tester) async {
      tester.view.physicalSize = const Size(390.0, 844.0);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final task = _sampleTask(id: 't1', judul: 'Pos 1 Palang Tidak bisa terangkat');
      await _seed(tasks: [task]);

      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        _buildDispatcherApp(
          boundaryKey: boundaryKey,
          width: 390.0,
          height: 844.0,
        ),
      );
      await tester.pumpAndSettle();

      await _saveBoundaryAsPng(tester, boundaryKey, '$outDir/dispatcher-light-390.png');
      expect(File('$outDir/dispatcher-light-390.png').existsSync(), isTrue);
    });

    testWidgets('Capture dispatcher-light-360-ts13.png', (tester) async {
      tester.view.physicalSize = const Size(360.0, 800.0);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final task = _sampleTask(id: 't1', judul: 'Pos 1 Palang Tidak bisa terangkat');
      await _seed(tasks: [task]);

      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        _buildDispatcherApp(
          boundaryKey: boundaryKey,
          width: 360.0,
          height: 800.0,
          textScale: 1.3,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await _saveBoundaryAsPng(tester, boundaryKey, '$outDir/dispatcher-light-360-ts13.png');
      expect(File('$outDir/dispatcher-light-360-ts13.png').existsSync(), isTrue);
    });

    testWidgets('Capture card-kerjakan-light-390.png', (tester) async {
      tester.view.physicalSize = const Size(390.0, 300.0);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final task = _sampleTask(id: 't1', judul: 'Pos 1 Palang Tidak bisa terangkat');
      final boundaryKey = GlobalKey();

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          home: Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: RepaintBoundary(
                key: boundaryKey,
                child: Container(
                  width: 390.0,
                  color: Colors.white,
                  padding: const EdgeInsets.all(16.0),
                  child: SpvTaskCard(
                    task: task,
                    isDark: false,
                    isExpanded: false,
                    onToggleExpand: () {},
                    onKerjakan: () {},
                    onHandover: () {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await _saveBoundaryAsPng(tester, boundaryKey, '$outDir/card-kerjakan-light-390.png');
      expect(File('$outDir/card-kerjakan-light-390.png').existsSync(), isTrue);
    });
  });
}
