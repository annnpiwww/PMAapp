import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bssparking_timemark/core/constants/app_theme.dart';
import 'package:bssparking_timemark/core/widgets/tiket/tiket_pill.dart';
import 'package:bssparking_timemark/data/models/daily_task_model.dart';
import 'package:bssparking_timemark/data/models/user_model.dart';
import 'package:bssparking_timemark/data/repositories/auth_repository.dart';
import 'package:bssparking_timemark/data/services/branch_service.dart';
import 'package:bssparking_timemark/data/services/daily_task_service.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';
import 'package:bssparking_timemark/features/daily_tasks/screens/spv_task_dispatcher_screen.dart';
import 'package:bssparking_timemark/features/daily_tasks/widgets/spv_task_card.dart';

import 'visual/visual_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime.now();
  final todayStr =
      '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

  final spvUser = UserModel(
    id: 'spv-001',
    nama: 'Farhan Lakoro',
    npp: 'BSS-001',
    email: 'farhan@bss.id',
    role: UserRole.supervisor,
    posId: 'POS-01',
    posName: 'Pos Gate Utama',
    cabangName: 'KC Manado',
  );

  List<DailyTaskModel> createSampleTasks() {
    final names = [
      'Ryan Lumasuge',
      'Raldy Sangkop',
      'Junifer Manua',
      'Alessandro Sulistyo',
      'Ryan Lumasuge',
      'Raldy Sangkop',
    ];
    return List.generate(
      names.length,
      (i) => DailyTaskModel(
        id: 'task-spv-$i',
        tanggal: todayStr,
        teknisiId: 'u-tech-$i',
        teknisiNama: names[i],
        posName: 'Pos Pasar Bersehati',
        posTag: 'PBM',
        judul: 'Pemasangan barrier gate unit ${i + 1} pos barat daya',
        deskripsi: 'Pengecekan rutin kabel optik dan power supply jalur ${i + 1}',
        kategori: 'maintenance',
        status: TaskStatus.pending,
      ),
    );
  }

  Future<void> savePng(
    WidgetTester tester,
    GlobalKey boundaryKey,
    String path,
  ) async {
    final boundary = boundaryKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) throw Exception('Boundary not found for $path');

    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File(path);
      file.parent.createSync(recursive: true);
      await file.writeAsBytes(byteData!.buffer.asUint8List());
    });
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    await AuthRepository.instance.login(spvUser);
    await BranchService.instance.setBranch(AppBranch.manado);
    await loadAppFonts();

    final tasks = createSampleTasks();
    await StorageService.setString(
      DailyTaskService.localCacheKey,
      jsonEncode(tasks.map((t) => t.toJson()).toList()),
    );
  });

  group('SPV Dispatcher Balance Sweep Fixes B', () {
    testWidgets(
      'last card bottom >= list visible bottom minus FAB area when scrolled to end (bottom padding >= 72)',
      (tester) async {
        const size = Size(360, 800);
        tester.view.physicalSize = Size(size.width * 2.0, size.height * 2.0);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final boundaryKey = GlobalKey();

        await tester.pumpWidget(
          RepaintBoundary(
            key: boundaryKey,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme,
              home: MediaQuery(
                data: const MediaQueryData(
                  size: size,
                  devicePixelRatio: 2.0,
                  platformBrightness: Brightness.light,
                  padding: EdgeInsets.zero,
                ),
                child: SizedBox(
                  width: size.width,
                  height: size.height,
                  child: const Scaffold(
                    body: SpvTaskDispatcherScreen(),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Verify bottom padding on task list is >= 72
        final sliverPaddingFinders = find.byType(SliverPadding);
        expect(sliverPaddingFinders, findsWidgets);
        final taskSliverPadding = tester.widget<SliverPadding>(sliverPaddingFinders.last);
        final padding = taskSliverPadding.padding as EdgeInsets;
        expect(padding.bottom, greaterThanOrEqualTo(72.0));

        // 2. Scroll to end
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -2000));
        await tester.pumpAndSettle();

        // 3. Verify last card bottom is at or above FAB area (800 - 72 = 728)
        final lastCardFinder = find.byType(SpvTaskCard).last;
        final lastCardBottom = tester.getBottomRight(lastCardFinder).dy;
        expect(
          lastCardBottom <= (size.height - 72.0 + 1.0),
          isTrue,
          reason: 'Last card bottom ($lastCardBottom) must be <= 728 so FAB does not cover it',
        );

        // 4. Capture screenshot
        await savePng(
          tester,
          boundaryKey,
          'docs/screenshots/balance-sweep/fix-b/dispatcher-scrolled-end-light-360.png',
        );
      },
    );

    testWidgets(
      'delete dialog has sentence case title, one-row actions with equal dy, and Hapus fill color danger',
      (tester) async {
        const size = Size(360, 800);
        tester.view.physicalSize = Size(size.width * 2.0, size.height * 2.0);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        for (final mode in [ThemeMode.light, ThemeMode.dark]) {
          final isDark = mode == ThemeMode.dark;
          final boundaryKey = GlobalKey();

          await tester.pumpWidget(
            RepaintBoundary(
              key: boundaryKey,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: isDark ? AppTheme.darkTheme : AppTheme.lightTheme,
                home: MediaQuery(
                  data: MediaQueryData(
                    size: size,
                    devicePixelRatio: 2.0,
                    platformBrightness: isDark ? Brightness.dark : Brightness.light,
                  ),
                  child: SizedBox(
                    width: size.width,
                    height: size.height,
                    child: const Scaffold(
                      body: SpvTaskDispatcherScreen(),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Open delete dialog via SpvTaskCard popup menu
          final popupFinder = find.byType(PopupMenuButton<String>).first;
          await tester.tap(popupFinder);
          await tester.pumpAndSettle();

          final hapusMenuFinder = find.text('Hapus Tugas');
          expect(hapusMenuFinder, findsOneWidget);
          await tester.tap(hapusMenuFinder);
          await tester.pumpAndSettle();

          // Assert title sentence case
          expect(find.text('Hapus tugas?'), findsOneWidget);

          // Assert actions in ONE row with equal dy
          final batalFinder = find.widgetWithText(TiketPill, 'Batal');
          final hapusFinder = find.widgetWithText(TiketPill, 'Hapus');
          expect(batalFinder, findsOneWidget);
          expect(hapusFinder, findsOneWidget);

          final batalDy = tester.getTopLeft(batalFinder).dy;
          final hapusDy = tester.getTopLeft(hapusFinder).dy;
          expect(
            (batalDy - hapusDy).abs() <= 1.0,
            isTrue,
            reason: 'Batal dy ($batalDy) and Hapus dy ($hapusDy) must be equal (one row)',
          );

          // Assert Hapus fill color is danger #C81E1E
          final hapusMaterial = tester.widget<Material>(
            find.descendant(of: hapusFinder, matching: find.byType(Material)).first,
          );
          expect(hapusMaterial.color, const Color(0xFFC81E1E));

          // Capture screenshot
          final themeStr = isDark ? 'dark' : 'light';
          await savePng(
            tester,
            boundaryKey,
            'docs/screenshots/balance-sweep/fix-b/dialog-hapus-$themeStr-360.png',
          );

          // Dismiss dialog
          await tester.tap(batalFinder);
          await tester.pumpAndSettle();
        }
      },
    );
  });
}
