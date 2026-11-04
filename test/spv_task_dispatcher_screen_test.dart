import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bssparking_timemark/core/constants/app_colors.dart';
import 'package:bssparking_timemark/core/services/theme_service.dart';
import 'package:bssparking_timemark/data/models/daily_task_model.dart';
import 'package:bssparking_timemark/data/models/user_model.dart';
import 'package:bssparking_timemark/data/repositories/auth_repository.dart';
import 'package:bssparking_timemark/data/services/branch_service.dart';
import 'package:bssparking_timemark/data/services/daily_task_service.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';
import 'package:bssparking_timemark/features/daily_tasks/screens/spv_task_dispatcher_screen.dart';
import 'package:bssparking_timemark/features/daily_tasks/widgets/spv_progress_ring_card.dart';
import 'package:bssparking_timemark/features/daily_tasks/widgets/spv_status_segment_bar.dart';
import 'package:bssparking_timemark/features/daily_tasks/widgets/spv_task_card.dart';
import 'package:bssparking_timemark/features/daily_tasks/widgets/spv_tech_filter_strip.dart';

bool _fontsLoaded = false;

Future<void> _loadAppFonts(WidgetTester tester) async {
  if (_fontsLoaded) return;
  await tester.runAsync(() async {
    final pjsLoader = FontLoader('PlusJakartaSans');
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
      final file = File('assets/fonts/PlusJakartaSans-$weight.ttf');
      if (file.existsSync()) {
        pjsLoader.addFont(Future.value(ByteData.view(file.readAsBytesSync().buffer)));
      }
    }
    await pjsLoader.load();

    const robotoDir = '/home/annnpii/flutter/bin/cache/artifacts/material_fonts';
    final robotoLoader = FontLoader('Roboto');
    for (final name in ['Regular', 'Medium', 'Bold']) {
      final file = File('$robotoDir/Roboto-$name.ttf');
      if (file.existsSync()) {
        robotoLoader.addFont(Future.value(ByteData.view(file.readAsBytesSync().buffer)));
      }
    }
    await robotoLoader.load();

    final iconFile = File('$robotoDir/MaterialIcons-Regular.otf');
    if (iconFile.existsSync()) {
      final iconLoader = FontLoader('MaterialIcons');
      iconLoader.addFont(Future.value(ByteData.view(iconFile.readAsBytesSync().buffer)));
      await iconLoader.load();
    }
    _fontsLoaded = true;
  });
}

String _todayKey() => DateTime.now().toIso8601String().substring(0, 10);

DailyTaskModel _task({
  required String id,
  required String teknisi,
  required String judul,
  String posTag = 'PKM',
  String posName = 'Pos Kasir Masuk',
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
        judul: 'Pemasangan lampu pos',
        peserta: 'Raldy Sangkop',
      ),
      _task(
        id: 't2',
        teknisi: 'Ryan Lumasuge',
        judul: 'Maintenance thermal printer',
        status: TaskStatus.completed,
        jamSelesai: '09:49',
        kategori: 'maintenance',
        fotoBuktiUrls: const ['https://example.com/b1.jpg', 'https://example.com/b2.jpg'],
      ),
      _task(
        id: 't3',
        teknisi: 'Raldy Sangkop',
        judul: 'Cek sensor loop gate',
        posTag: 'MTC',
        posName: 'Gate Keluar',
      ),
      _task(
        id: 't4',
        teknisi: 'Junifer Manua',
        judul: 'Perbaikan barrier gate',
        posTag: 'PBM',
        status: TaskStatus.completed,
        jamSelesai: '11:00',
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

Widget _app({
  bool dark = false,
  double textScale = 1.0,
  double height = 640,
  GlobalKey? boundaryKey,
}) {
  final builder = boundaryKey == null
      ? null
      : (BuildContext context, Widget? child) => RepaintBoundary(key: boundaryKey, child: child!);
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    builder: builder,
    theme: ThemeData.light().copyWith(
      textTheme: ThemeData.light().textTheme.apply(fontFamily: 'PlusJakartaSans'),
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        surface: AppColors.surface,
      ),
    ),
    darkTheme: ThemeData.dark().copyWith(
      textTheme: ThemeData.dark().textTheme.apply(fontFamily: 'PlusJakartaSans'),
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primaryLight,
        surface: AppColors.darkSurface,
      ),
    ),
    themeMode: dark ? ThemeMode.dark : ThemeMode.light,
    home: MediaQuery(
      data: MediaQueryData(
        size: Size(360, height),
        textScaler: TextScaler.linear(textScale),
      ),
      child: const SpvTaskDispatcherScreen(),
    ),
  );
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  bool dark = false,
  double textScale = 1.0,
  double height = 1100,
  bool captureShadows = false,
  GlobalKey? boundaryKey,
}) async {
  debugDisableShadows = !captureShadows;
  tester.view.physicalSize = Size(360 * 2, height * 2);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(_app(dark: dark, textScale: textScale, height: height, boundaryKey: boundaryKey));
  await tester.pumpAndSettle();
}

/// Chip strip is lazily built, so the target chip may need scrolling into view.
Future<void> _tapTechChip(WidgetTester tester, String label) async {
  final chip = find.text(label);
  await tester.scrollUntilVisible(
    chip,
    120,
    scrollable: find.descendant(
      of: find.byType(SpvTechFilterStrip),
      matching: find.byType(Scrollable),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(chip);
  await tester.pumpAndSettle();
}

Future<void> _capture(WidgetTester tester, GlobalKey key, String path) async {
  final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  expect(boundary, isNotNull);
  await tester.runAsync(() async {
    final image = await boundary!.toImage(pixelRatio: 3.0);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    expect(data, isNotNull);
    final file = File(path);
    file.parent.createSync(recursive: true);
    await file.writeAsBytes(data!.buffer.asUint8List());
    expect(file.existsSync(), isTrue);
  });
  debugDisableShadows = true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    ThemeService.themeModeNotifier.value = ThemeMode.system;
  });

  group('SpvTaskDispatcherScreen — tab-free layout', () {
    testWidgets('renders header, summary, segment, tech strip and task cards without TabBar', (tester) async {
      await _seed(_sampleTasks());
      await _pumpScreen(tester);

      expect(find.byType(TabBar), findsNothing);
      expect(find.byType(TabBarView), findsNothing);
      expect(find.text('Daily Task'), findsOneWidget);
      expect(find.byType(SpvProgressRingCard), findsOneWidget);
      expect(find.text('Tugas Selesai'), findsOneWidget);
      expect(find.text('2/4'), findsOneWidget);
      expect(find.byType(SpvStatusSegmentBar), findsOneWidget);
      expect(find.text('Semua (4)'), findsOneWidget);
      expect(find.text('Belum (2)'), findsOneWidget);
      expect(find.text('Selesai (2)'), findsOneWidget);
      expect(find.byType(SpvTechFilterStrip), findsOneWidget);
      expect(find.text('Semua Teknisi'), findsOneWidget);
      expect(find.byType(SpvTaskCard), findsNWidgets(4));
      expect(find.text('Buat Tugas'), findsOneWidget);
      expect(find.text('Pantau & kelola tugas teknisi dengan mudah'), findsNothing);
      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.text('Menunggu Alih'), findsNothing);
    });
  });

  group('SpvTaskDispatcherScreen — technician filter', () {
    testWidgets('chip filters by owner or participant and re-tap resets to all', (tester) async {
      await _seed(_sampleTasks());
      await _pumpScreen(tester);

      await _tapTechChip(tester, 'Raldy');

      expect(find.text('Semua (2)'), findsOneWidget);
      expect(find.text('Belum (2)'), findsOneWidget);
      expect(find.text('Selesai (0)'), findsOneWidget);
      expect(find.text('0/2'), findsOneWidget);
      expect(find.textContaining('Filter Teknisi: Raldy Sangkop'), findsOneWidget);
      expect(find.text('Pemasangan lampu pos'), findsOneWidget);
      expect(find.text('Cek sensor loop gate'), findsOneWidget);
      expect(find.text('Maintenance thermal printer'), findsNothing);

      await _tapTechChip(tester, 'Raldy');

      expect(find.text('Semua (4)'), findsOneWidget);
      expect(find.textContaining('Filter Teknisi:'), findsNothing);
      expect(find.byType(SpvTaskCard), findsNWidgets(4));
    });
  });

  group('SpvTaskDispatcherScreen — status segments', () {
    testWidgets('segment filters pending and completed tasks with live counts', (tester) async {
      await _seed(_sampleTasks());
      await _pumpScreen(tester);

      await tester.tap(find.text('Belum (2)'));
      await tester.pumpAndSettle();
      expect(find.byType(SpvTaskCard), findsNWidgets(2));
      expect(find.text('Maintenance thermal printer'), findsNothing);

      await tester.tap(find.text('Selesai (2)'));
      await tester.pumpAndSettle();
      expect(find.byType(SpvTaskCard), findsNWidgets(2));
      expect(find.text('Cek sensor loop gate'), findsNothing);
    });
  });

  group('SpvTaskDispatcherScreen — create sheet', () {
    testWidgets('FAB opens the modal sheet with category chips and submit button', (tester) async {
      await _seed(_sampleTasks());
      await _pumpScreen(tester);

      await tester.tap(find.text('Buat Tugas'));
      await tester.pumpAndSettle();

      expect(find.text('Buat Tugas Baru'), findsOneWidget);
      expect(find.text('Simpan Tugas'), findsOneWidget);
      expect(find.text('Rutin'), findsOneWidget);
      expect(find.text('Maintenance'), findsOneWidget);
      expect(find.text('Tugas Khusus'), findsOneWidget);
      expect(find.text('TEKNISI (PEMILIK TUGAS)'), findsOneWidget);
      expect(find.text('LOKASI PEKERJAAN'), findsOneWidget);

      await tester.tap(find.text('Rutin'));
      await tester.pumpAndSettle();
      expect(find.text('TUGAS RUTIN SHIFT 1 KC MANADO'), findsOneWidget);
      expect(find.text('Tugaskan 2 Rutin Shift 1'), findsOneWidget);
    });
  });

  group('SpvTaskDispatcherScreen — states', () {
    testWidgets('empty state offers creating the first task', (tester) async {
      await _seed(const []);
      await _pumpScreen(tester);

      expect(find.text('Belum Ada Tugas Tim Hari Ini'), findsOneWidget);
      expect(find.text('0/0'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Buat Tugas Baru'), findsOneWidget);
      expect(find.byType(SpvTaskCard), findsNothing);
    });

    testWidgets('all-done state shows celebration banner with recap share', (tester) async {
      await _seed([
        _task(
          id: 'd1',
          teknisi: 'Ryan Lumasuge',
          judul: 'Cek gate in',
          status: TaskStatus.completed,
          jamSelesai: '08:10',
        ),
        _task(
          id: 'd2',
          teknisi: 'Raldy Sangkop',
          judul: 'Cek gate out',
          status: TaskStatus.completed,
          jamSelesai: '08:40',
        ),
      ]);
      await _pumpScreen(tester);

      expect(find.text('Semua Tugas Selesai Hari Ini! (2/2)'), findsOneWidget);
      expect(find.text('Bagikan Rekap Tim via WA / Telegram'), findsOneWidget);
      expect(find.text('2/2'), findsOneWidget);
    });
  });

  group('SpvTaskDispatcherScreen — responsive & theme', () {
    testWidgets('textScaler 1.3 renders without overflow', (tester) async {
      await _seed(_sampleTasks());
      await _pumpScreen(tester, textScale: 1.3, height: 1500);

      expect(tester.takeException(), isNull);
      expect(find.byType(SpvProgressRingCard), findsOneWidget);
      expect(find.byType(SpvTaskCard), findsNWidgets(4));
    });

    testWidgets('dark theme renders the dispatcher with dark tokens', (tester) async {
      ThemeService.themeModeNotifier.value = ThemeMode.dark;
      await _seed(_sampleTasks());
      await _pumpScreen(tester, dark: true);

      expect(tester.takeException(), isNull);
      expect(find.text('Daily Task'), findsOneWidget);
      final context = tester.element(find.byType(SpvTaskDispatcherScreen));
      expect(ThemeService.isDarkMode(context), isTrue);
    });
  });

  group('Screenshot Capture', () {
    testWidgets('dispatcher list light', (tester) async {
      await _seed(_sampleTasks());
      await _loadAppFonts(tester);
      final key = GlobalKey();
      await _pumpScreen(tester, height: 640, captureShadows: true, boundaryKey: key);
      await _capture(tester, key, 'docs/screenshots/spv_dispatcher_redesign_list_light.png');
    });

    testWidgets('dispatcher list dark', (tester) async {
      ThemeService.themeModeNotifier.value = ThemeMode.dark;
      await _seed(_sampleTasks());
      await _loadAppFonts(tester);
      final key = GlobalKey();
      await _pumpScreen(tester, dark: true, height: 640, captureShadows: true, boundaryKey: key);
      await _capture(tester, key, 'docs/screenshots/spv_dispatcher_redesign_list_dark.png');
    });

    testWidgets('dispatcher create sheet light', (tester) async {
      await _seed(_sampleTasks());
      await _loadAppFonts(tester);
      final key = GlobalKey();
      await _pumpScreen(tester, height: 640, captureShadows: true, boundaryKey: key);
      await tester.tap(find.text('Buat Tugas'));
      await tester.pumpAndSettle();
      await _capture(tester, key, 'docs/screenshots/spv_dispatcher_redesign_sheet_light.png');
    });
  });
}
