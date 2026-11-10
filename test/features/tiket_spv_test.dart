import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bssparking_timemark/core/constants/app_theme.dart';
import 'package:bssparking_timemark/core/widgets/tiket/tiket.dart';
import 'package:bssparking_timemark/data/models/daily_task_model.dart';
import 'package:bssparking_timemark/data/models/user_model.dart';
import 'package:bssparking_timemark/data/repositories/auth_repository.dart';
import 'package:bssparking_timemark/data/services/branch_service.dart';
import 'package:bssparking_timemark/data/services/daily_task_service.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';
import 'package:bssparking_timemark/features/daily_tasks/screens/spv_task_dispatcher_screen.dart';
import 'package:bssparking_timemark/features/daily_tasks/widgets/spv_task_card.dart';

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
  final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  if (boundary == null) throw Exception('RenderRepaintBoundary not found for $path');

  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) throw Exception('Failed to get png byteData for $path');

    final file = File(path);
    file.parent.createSync(recursive: true);
    await file.writeAsBytes(byteData.buffer.asUint8List());
  });
}

String _todayKey() => DateTime.now().toIso8601String().substring(0, 10);

DailyTaskModel _task({
  required String id,
  required String teknisi,
  required String judul,
  String posTag = 'PKM',
  String posName = 'Pos Pasar Bersehati',
  String deskripsi = 'Pengecekan rutin perangkat pos',
  String kategori = 'khusus',
  TaskStatus status = TaskStatus.pending,
  String? jamSelesai,
  String peserta = '',
  List<String> fotoBuktiUrls = const [],
}) {
  return DailyTaskModel(
    id: id,
    tanggal: _todayKey(),
    teknisiId: 'u-$teknisi',
    teknisiNama: teknisi,
    posName: posName,
    posTag: posTag,
    judul: judul,
    deskripsi: deskripsi,
    kategori: kategori,
    status: status,
    jamSelesai: jamSelesai,
    peserta: peserta,
    fotoBuktiUrls: fotoBuktiUrls,
  );
}

List<DailyTaskModel> _sampleTasks() => [
      _task(
        id: 't1',
        teknisi: 'Ryan Lumasuge',
        posTag: 'PBM',
        posName: 'Pos Pasar Bersehati',
        judul: 'Bersihkan sensor gate dan kalibrasi palang',
        peserta: 'Alessandro Sulistyo',
        kategori: 'maintenance',
      ),
      _task(
        id: 't2',
        teknisi: 'Raldy Sangkop',
        posTag: 'MTC',
        posName: 'Mega Mall',
        judul: 'Ganti kertas thermal printer gate 2',
        kategori: 'maintenance',
      ),
      _task(
        id: 't3',
        teknisi: 'Raldy Sangkop',
        posTag: 'MTC',
        posName: 'Mega Mall',
        judul: 'Ganti switch hub 8 port kasir 2',
        kategori: 'khusus',
        peserta: '',
      ),
      _task(
        id: 't4',
        teknisi: 'Junifer Manua',
        posTag: 'PBM',
        posName: 'Pos Barrier 2',
        judul: 'Perbaikan barrier gate motor arm servo',
        status: TaskStatus.completed,
        jamSelesai: '11:00',
        fotoBuktiUrls: const ['https://example.com/b1.jpg'],
      ),
      _task(
        id: 't5',
        teknisi: 'Alessandro Sulistyo',
        posTag: 'PKM',
        posName: 'Pos Kasir Masuk',
        judul: 'Maintenance PC Server kasir',
        status: TaskStatus.completed,
        jamSelesai: '09:49',
        kategori: 'maintenance',
        fotoBuktiUrls: const ['https://example.com/b2.jpg'],
      ),
    ];

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

Future<void> _seed(List<DailyTaskModel> tasks) async {
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

Widget _buildApp({
  required ThemeData theme,
  required double width,
  required double height,
  required GlobalKey boundaryKey,
  Widget? child,
}) {
  return RepaintBoundary(
    key: boundaryKey,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme,
      initialRoute: '/dispatcher',
      routes: {
        '/': (_) => const Scaffold(body: SizedBox.shrink()),
        '/dispatcher': (_) => MediaQuery(
          data: MediaQueryData(
            size: Size(width, height),
            padding: const EdgeInsets.only(top: 24, bottom: 24),
          ),
          child: child ?? const SpvTaskDispatcherScreen(),
        ),
      },
    ),
  );
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _loadAppFonts();
  });

  group('SpvTaskDispatcherScreen — Tiket Spec Assertions & Screenshots', () {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      final isDark = brightness == Brightness.dark;
      final modeTag = isDark ? 'dark' : 'light';
      final theme = isDark ? AppTheme.darkTheme : AppTheme.lightTheme;

      for (final dim in [(360.0, 800.0), (390.0, 844.0)]) {
        final w = dim.$1;
        final h = dim.$2;
        final sizeTag = '${w.toInt()}';

        testWidgets('Dispatcher screen $modeTag $sizeTag assertions and screenshot', (tester) async {
          tester.view.physicalSize = Size(w, h);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await _seed(_sampleTasks());
          final key = GlobalKey();

          await tester.pumpWidget(_buildApp(
            theme: theme,
            width: w,
            height: h,
            boundaryKey: key,
          ));
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          if (w >= 375) {
            expect(find.text('Briefing'), findsOneWidget);
            expect(find.text('Rekap'), findsOneWidget);
            final briefingPill = find.widgetWithText(TiketPill, 'Briefing');
            final rekapPill = find.widgetWithText(TiketPill, 'Rekap');
            final briefingMaterial = find.descendant(of: briefingPill, matching: find.byType(Material)).first;
            final rekapMaterial = find.descendant(of: rekapPill, matching: find.byType(Material)).first;
            expect(tester.getSize(briefingMaterial).height, equals(44.0));
            expect(tester.getSize(rekapMaterial).height, equals(44.0));
          } else {
            expect(find.byTooltip('Briefing'), findsOneWidget);
            expect(find.byTooltip('Rekap'), findsOneWidget);
            final briefingBtn = find.byTooltip('Briefing');
            final rekapBtn = find.byTooltip('Rekap');
            final briefingMaterial = find.descendant(of: briefingBtn, matching: find.byType(Material)).first;
            final rekapMaterial = find.descendant(of: rekapBtn, matching: find.byType(Material)).first;
            expect(tester.getSize(briefingMaterial).height, equals(44.0));
            expect(tester.getSize(rekapMaterial).height, equals(44.0));
            expect(tester.getSize(briefingBtn).height, greaterThanOrEqualTo(48.0));
            expect(tester.getSize(rekapBtn).height, greaterThanOrEqualTo(48.0));
          }
          expect(find.text('Buat Tugas'), findsOneWidget);
          expect(find.text('Teknisi'), findsOneWidget);
          expect(find.text('Semua teknisi'), findsOneWidget);
          expect(find.text('Daily Task'), findsOneWidget);
          expect(find.textContaining('selesai · '), findsOneWidget);
          expect(find.byType(SpvTaskCard), findsWidgets);

          // Assert title to meta line gap is ~4px (t5 is top card)
          final titleRect = tester.getRect(find.text('Maintenance PC Server kasir'));
          final metaRect = tester.getRect(find.text('Pos Kasir Masuk · maintenance'));
          expect(metaRect.top - titleRect.bottom, closeTo(4.0, 1.0));

          await _saveBoundaryAsPng(tester, key, 'docs/screenshots/tiket-spv/$modeTag-$sizeTag-dispatcher.png');
          DailyTaskService.stopRealtimeListener();
        });

        testWidgets('Dialog teknisi $modeTag $sizeTag screenshot', (tester) async {
          tester.view.physicalSize = Size(w, h);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await _seed(_sampleTasks());
          final key = GlobalKey();

          await tester.pumpWidget(_buildApp(
            theme: theme,
            width: w,
            height: h,
            boundaryKey: key,
          ));
          await tester.pumpAndSettle();

          // Open teknisi picker dialog
          final dropdown = find.byType(TiketDropdownField).first;
          await tester.tap(dropdown);
          await tester.pumpAndSettle();

          expect(find.text('Pilih teknisi'), findsOneWidget);
          expect(find.text('Tutup'), findsOneWidget);

          await _saveBoundaryAsPng(tester, key, 'docs/screenshots/tiket-spv/$modeTag-$sizeTag-dialog-teknisi.png');
          DailyTaskService.stopRealtimeListener();
        });

        testWidgets('Buat tugas sheet $modeTag $sizeTag screenshot', (tester) async {
          tester.view.physicalSize = Size(w, h);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await _seed(_sampleTasks());
          final key = GlobalKey();

          await tester.pumpWidget(_buildApp(
            theme: theme,
            width: w,
            height: h,
            boundaryKey: key,
          ));
          await tester.pumpAndSettle();

          // Tap Buat Tugas FAB
          await tester.tap(find.text('Buat Tugas'));
          await tester.pumpAndSettle();

          expect(find.text('Buat Tugas Baru'), findsOneWidget);
          expect(find.text('Simpan Tugas'), findsOneWidget);

          await _saveBoundaryAsPng(tester, key, 'docs/screenshots/tiket-spv/$modeTag-$sizeTag-buat-tugas.png');
          DailyTaskService.stopRealtimeListener();
        });
      }
    }

    testWidgets('Dispatcher screen 360x780 textScaler 1.3 renders without overflow', (tester) async {
      tester.view.physicalSize = const Size(360.0, 780.0);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _seed(_sampleTasks());
      final key = GlobalKey();

      await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(360.0, 780.0),
            padding: EdgeInsets.only(top: 24, bottom: 24),
            textScaler: TextScaler.linear(1.3),
          ),
          child: RepaintBoundary(
            key: key,
            child: const SpvTaskDispatcherScreen(),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(SpvTaskCard), findsWidgets);
      DailyTaskService.stopRealtimeListener();
    });
  });
}
