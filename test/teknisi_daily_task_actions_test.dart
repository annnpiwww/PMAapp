import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bssparking_timemark/core/constants/app_theme.dart';
import 'package:bssparking_timemark/data/models/daily_task_model.dart';
import 'package:bssparking_timemark/data/models/user_model.dart';
import 'package:bssparking_timemark/data/repositories/auth_repository.dart';
import 'package:bssparking_timemark/data/services/branch_service.dart';
import 'package:bssparking_timemark/data/services/daily_task_service.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';
import 'package:bssparking_timemark/features/daily_tasks/screens/teknisi_daily_tasks_screen.dart';
import 'package:bssparking_timemark/features/daily_tasks/widgets/daily_task_action_pill.dart';
import 'package:bssparking_timemark/features/daily_tasks/widgets/spv_task_card.dart';

import 'visual/visual_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final user = UserModel(
    id: 'u-teknisi-1',
    nama: 'Ryan Lumasuge',
    npp: 'T-01',
    email: 'ryan@bss.com',
    role: UserRole.petugas,
    posId: 'PBM-01',
    posName: 'Pos Pasar Bersehati',
    cabangName: 'KC Manado',
  );

  final now = DateTime.now();
  final todayStr =
      '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

  final taskRows = [
    {
      'id': 'task-1',
      'tanggal': todayStr,
      'teknisi_id': 'u-teknisi-1',
      'teknisi_nama': 'Ryan Lumasuge',
      'pos_name': 'Pos Pasar Bersehati',
      'pos_tag': 'PBM',
      'judul': 'Pengecekan Barrier Gate Keluar',
      'deskripsi': 'Periksa sensor loop dan motor penggerak',
      'kategori': 'maintenance',
      'status': 'pending',
      'foto_bukti': <String>[],
    },
    {
      'id': 'task-2',
      'tanggal': todayStr,
      'teknisi_id': 'u-teknisi-1',
      'teknisi_nama': 'Ryan Lumasuge',
      'pos_name': 'Pos Pasar Bersehati',
      'pos_tag': 'PBM',
      'judul': 'Ganti Roll Struk POS Masuk',
      'deskripsi': 'Pasang thermal paper roll baru',
      'kategori': 'operasional',
      'status': 'completed',
      'jam_selesai': '09:30',
      'foto_bukti': ['https://example.com/bukti.jpg'],
    },
  ];

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    BranchService.instance.resetForTesting();
    await AuthRepository.instance.login(user);
    DailyTaskService.clientOverride = MockClient((req) async {
      return http.Response(
        jsonEncode(taskRows),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
  });

  tearDown(() {
    DailyTaskService.clientOverride = null;
    BranchService.instance.resetForTesting();
  });

  Future<void> saveScreenshot(
    WidgetTester tester, {
    required Widget screen,
    required Size size,
    required ThemeMode mode,
    required String fileName,
    String folder = 'docs/screenshots/balance-sweep/fix-a',
    double textScale = 1.0,
  }) async {
    await loadAppFonts();

    tester.view.physicalSize = Size(size.width * 2.0, size.height * 2.0);
    tester.view.devicePixelRatio = 2.0;

    final boundaryKey = GlobalKey();
    final activeTheme = mode == ThemeMode.dark ? AppTheme.darkTheme : AppTheme.lightTheme;

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: mode,
        home: Theme(
          data: activeTheme,
          child: MediaQuery(
            data: MediaQueryData(
              size: size,
              devicePixelRatio: 2.0,
              textScaler: TextScaler.linear(textScale),
              platformBrightness: mode == ThemeMode.dark ? Brightness.dark : Brightness.light,
            ),
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: RepaintBoundary(
                key: boundaryKey,
                child: screen,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    try {
      await tester.pumpAndSettle(const Duration(milliseconds: 100)).timeout(const Duration(seconds: 2));
    } catch (_) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    final boundary = boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) {
      throw Exception('Failed to find RenderRepaintBoundary for $fileName');
    }

    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('Failed to encode image to PNG for $fileName');
      }
      final buffer = byteData.buffer.asUint8List();
      final dir = Directory(folder);
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      final file = File('$folder/$fileName');
      await file.writeAsBytes(buffer);
      debugPrint('Saved screenshot: ${file.path}');
    });

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  }

  group('Teknisi Daily Task Actions Layout Tests', () {
    testWidgets('assert button alignment, same dy, and matching right edge', (tester) async {
      await loadAppFonts();
      tester.view.physicalSize = const Size(390 * 2.0, 844 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.darkTheme,
          home: const Scaffold(
            body: TeknisiDailyTasksScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final belumTextFinder = find.text('Belum selesai');
      final kerjakanTextFinder = find.text('Kerjakan');
      final titleFinder = find.text('Pengecekan Barrier Gate Keluar');
      final buktiTextFinder = find.text('Lihat bukti');

      expect(belumTextFinder, findsOneWidget);
      expect(kerjakanTextFinder, findsOneWidget);
      expect(titleFinder, findsOneWidget);
      expect(buktiTextFinder, findsOneWidget);

      // 1. assert 'Belum selesai' and 'Kerjakan' centers have the same dy (within 1.0)
      final belumCenterDy = tester.getCenter(belumTextFinder).dy;
      final kerjakanCenterDy = tester.getCenter(kerjakanTextFinder).dy;
      expect(
        (belumCenterDy - kerjakanCenterDy).abs() <= 1.0,
        isTrue,
        reason: 'Centers vertical alignment: Belum selesai dy=$belumCenterDy vs Kerjakan dy=$kerjakanCenterDy',
      );

      // 2. assert 'Belum selesai' left edge aligns with title text left edge (within 1.0)
      final belumPillFinder = find.ancestor(of: belumTextFinder, matching: find.byType(DailyTaskActionPill)).first;
      final belumPillLeft = tester.getTopLeft(belumPillFinder).dx;
      final titleLeft = tester.getTopLeft(titleFinder).dx;
      expect(
        (belumPillLeft - titleLeft).abs() <= 1.0,
        isTrue,
        reason: 'Left alignment: Belum selesai pill dx=$belumPillLeft vs Title dx=$titleLeft',
      );

      // 3. assert 'Lihat bukti' right edge == 'Kerjakan' right edge of another row within 1
      final kerjakanPillFinder = find.ancestor(of: kerjakanTextFinder, matching: find.byType(DailyTaskActionPill)).first;
      final kerjakanPillRight = tester.getTopRight(kerjakanPillFinder).dx;
      final buktiPillFinder = find.ancestor(of: buktiTextFinder, matching: find.byType(DailyTaskActionPill)).first;
      final buktiPillRight = tester.getTopRight(buktiPillFinder).dx;
      expect(
        (kerjakanPillRight - buktiPillRight).abs() <= 1.0,
        isTrue,
        reason: 'Right alignment: Kerjakan pill right=$kerjakanPillRight vs Lihat bukti right=$buktiPillRight',
      );
    });

    testWidgets('assert on a 360-wide screen with textScaler 1.3 does not throw RenderFlex overflow', (tester) async {
      await loadAppFonts();
      tester.view.physicalSize = const Size(360 * 2.0, 800 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.darkTheme,
          home: const MediaQuery(
            data: MediaQueryData(
              size: Size(360, 800),
              devicePixelRatio: 2.0,
              textScaler: TextScaler.linear(1.3),
            ),
            child: Scaffold(
              body: TeknisiDailyTasksScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('capture screenshots in docs/screenshots/balance-sweep/fix-a/', (tester) async {
      // 1. spv-card-light-360.png (SPV Daily Task card in light mode, 360 width)
      final spvTaskPending = DailyTaskModel(
        id: 'spv-1',
        tanggal: todayStr,
        teknisiId: 'u-teknisi-1',
        teknisiNama: 'Ryan Lumasuge',
        posName: 'Pos Pasar Bersehati',
        posTag: 'PBM',
        judul: 'Pemasangan barrier gate baru di pos barat daya Megamas Manado',
        deskripsi: 'Pengecekan rutin kabel optik dan power supply unit 1 sampai 6',
        kategori: 'maintenance',
        status: TaskStatus.pending,
      );

      final spvTaskDone = DailyTaskModel(
        id: 'spv-2',
        tanggal: todayStr,
        teknisiId: 'u-teknisi-1',
        teknisiNama: 'Ryan Lumasuge',
        posName: 'Pos Pasar Bersehati',
        posTag: 'PBM',
        judul: 'Ganti sensor loop terminal 1',
        deskripsi: 'Selesai perbaikan kabel grounding',
        kategori: 'maintenance',
        status: TaskStatus.completed,
        jamSelesai: '09:45',
        fotoBuktiUrls: const ['https://example.com/bukti.jpg'],
      );

      await saveScreenshot(
        tester,
        screen: Scaffold(
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: SpvTaskCard(
                      task: spvTaskPending,
                      isDark: false,
                      isExpanded: false,
                      onToggleExpand: () {},
                      onHandover: () {},
                      onDelete: () {},
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: SpvTaskCard(
                      task: spvTaskDone,
                      isDark: false,
                      isExpanded: false,
                      onToggleExpand: () {},
                      onDelete: () {},
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        size: const Size(360, 800),
        mode: ThemeMode.light,
        fileName: 'spv-card-light-360.png',
      );

      // 2. teknisi-light-360.png (Teknisi row in light mode, 360 width)
      await saveScreenshot(
        tester,
        screen: const Scaffold(
          body: TeknisiDailyTasksScreen(),
        ),
        size: const Size(360, 800),
        mode: ThemeMode.light,
        fileName: 'teknisi-light-360.png',
      );

      // 3. teknisi-dark-360.png (Teknisi row in dark mode, 360 width)
      await saveScreenshot(
        tester,
        screen: const Scaffold(
          body: TeknisiDailyTasksScreen(),
        ),
        size: const Size(360, 800),
        mode: ThemeMode.dark,
        fileName: 'teknisi-dark-360.png',
      );

      expect(File('docs/screenshots/balance-sweep/fix-a/spv-card-light-360.png').existsSync(), isTrue);
      expect(File('docs/screenshots/balance-sweep/fix-a/teknisi-light-360.png').existsSync(), isTrue);
      expect(File('docs/screenshots/balance-sweep/fix-a/teknisi-dark-360.png').existsSync(), isTrue);
    });
  });
}
