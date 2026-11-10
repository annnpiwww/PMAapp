import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bssparking_timemark/core/constants/app_theme.dart';
import 'package:bssparking_timemark/core/constants/tiket_colors.dart';
import 'package:bssparking_timemark/core/widgets/tiket/tiket.dart';
import 'package:bssparking_timemark/data/models/daily_task_model.dart';
import 'package:bssparking_timemark/data/models/maintenance_submission.dart';
import 'package:bssparking_timemark/data/models/user_model.dart';
import 'package:bssparking_timemark/data/repositories/auth_repository.dart';
import 'package:bssparking_timemark/data/services/branch_service.dart';
import 'package:bssparking_timemark/data/services/daily_task_service.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';
import 'package:bssparking_timemark/features/daily_tasks/screens/teknisi_daily_tasks_screen.dart';
import 'package:bssparking_timemark/features/daily_tasks/widgets/completed_daily_task_modal.dart';
import 'package:bssparking_timemark/features/daily_tasks/widgets/task_handover_dialog.dart';

Future<void> loadAppFonts() async {
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
    // ignore: avoid_print
    print('Generated screenshot: $path (${file.lengthSync()} bytes)');
  });
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadAppFonts();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    BranchService.instance.resetForTesting();
    await AuthRepository.instance.login(
      UserModel(
        id: 'usr_test_ryan',
        nama: 'Ryan',
        npp: '12345',
        email: 'ryan@bss.id',
        role: UserRole.petugas,
        posId: 'pos_1',
        posName: 'PBM',
        cabangName: 'KC Manado',
      ),
    );
  });

  tearDown(() {
    DailyTaskService.clientOverride = null;
    BranchService.instance.resetForTesting();
  });

  final now = DateTime.now();
  final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

  final sampleRows = [
    {
      'id': 'dt_1',
      'tanggal': todayStr,
      'teknisi_id': 'usr_test_ryan',
      'teknisi_nama': 'Ryan',
      'pos_name': 'Pos Pasar Bersehati',
      'pos_tag': 'PBM',
      'judul': 'Cek barrier gate masuk 1',
      'status': 'completed',
      'jam_selesai': '09:30 WITA',
      'foto_bukti': ['foto1.jpg', 'foto2.jpg'],
    },
    {
      'id': 'dt_2',
      'tanggal': todayStr,
      'teknisi_id': 'usr_test_ryan',
      'teknisi_nama': 'Ryan',
      'pos_name': 'Gate 1 PBM',
      'pos_tag': 'PBM',
      'judul': 'Bersihkan sensor gate dan kalibrasi palang',
      'template_id': 'tpl_gate',
      'status': 'pending',
      'peserta': 'Alessandro',
    },
    {
      'id': 'dt_3',
      'tanggal': todayStr,
      'teknisi_id': 'usr_test_ryan',
      'teknisi_nama': 'Ryan',
      'pos_name': 'Server PBM',
      'pos_tag': 'PBM',
      'judul': 'Periksa PC server dan switch',
      'kategori': 'khusus',
      'status': 'pending',
    },
  ];

  final sampleOpenRows = [
    {
      'id': 'dt_open_1',
      'tanggal': todayStr,
      'teknisi_id': 'usr_other',
      'teknisi_nama': 'Farhan',
      'pos_name': 'Pos Pasar Bersehati',
      'pos_tag': 'PBM',
      'judul': 'Kabel LAN kasir 2 putus',
      'status': 'pending',
      'serah_terima': 'Farhan||kemarin 17:00|08 Nov 17:00',
    },
  ];

  final sampleOngoing = MaintenanceSubmission(
    id: 'sub_2',
    templateId: 'tpl_gate',
    templateName: 'SOP Maintenance Gate',
    userId: 'usr_test_ryan',
    userName: 'Ryan',
    userNpp: '12345',
    posId: 'pos_1',
    posName: 'Gate 1 PBM',
    cabangName: 'KC Manado',
    taskId: 'dt_2',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    points: const [
      MaintenancePointResult(pointId: 'p1', label: 'Point 1', status: PointStatus.sesuai, imagePath: 'p1.jpg'),
      MaintenancePointResult(pointId: 'p2', label: 'Point 2', status: PointStatus.sesuai, imagePath: 'p2.jpg'),
      MaintenancePointResult(pointId: 'p3', label: 'Point 3', status: PointStatus.sesuai, imagePath: 'p3.jpg'),
      MaintenancePointResult(pointId: 'p4', label: 'Point 4', status: PointStatus.belumFoto),
      MaintenancePointResult(pointId: 'p5', label: 'Point 5', status: PointStatus.belumFoto),
      MaintenancePointResult(pointId: 'p6', label: 'Point 6', status: PointStatus.belumFoto),
    ],
  );

  final sampleCompletedTask = DailyTaskModel(
    id: 'dt_1',
    tanggal: todayStr,
    teknisiId: 'usr_test_ryan',
    teknisiNama: 'Ryan',
    posName: 'Pos Pasar Bersehati',
    posTag: 'PBM',
    judul: 'Cek barrier gate masuk 1',
    status: TaskStatus.completed,
    jamSelesai: '09:30 WITA',
    fotoBuktiUrls: const ['foto1.jpg', 'foto2.jpg'],
    deskripsi: 'Cek fungsi palang, sensor loop, dan tombol tiket di gate masuk 1.',
    catatanTeknisi: 'Palang normal, sensor loop sudah dibersihkan.',
  );

  void setupClientMock({bool empty = false}) {
    DailyTaskService.clientOverride = MockClient((req) async {
      if (empty) {
        return http.Response(jsonEncode([]), 200, headers: {'content-type': 'application/json'});
      }
      if (req.url.queryParameters['status'] == 'eq.pending') {
        return http.Response(jsonEncode(sampleOpenRows), 200, headers: {'content-type': 'application/json'});
      }
      return http.Response(jsonEncode(sampleRows), 200, headers: {'content-type': 'application/json'});
    });
  }

  group('TeknisiDailyTasksScreen Tests', () {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      final modeName = brightness == Brightness.light ? 'Light' : 'Dark';
      final theme = brightness == Brightness.dark ? AppTheme.darkTheme : AppTheme.lightTheme;

      for (final dim in [(360.0, 800.0), (390.0, 844.0)]) {
        final w = dim.$1;
        final h = dim.$2;

        testWidgets('TeknisiDailyTasksScreen $modeName ${w.toInt()}x${h.toInt()} renders without overflow', (tester) async {
          tester.view.physicalSize = Size(w, h);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          setupClientMock();
          await StorageService.saveMaintenanceSubmissions([sampleOngoing]);

          await tester.pumpWidget(
            MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: theme,
              home: const MediaQuery(
                data: MediaQueryData(
                  size: Size(390.0, 844.0),
                  padding: EdgeInsets.only(top: 24.0, bottom: 24.0),
                ),
                child: TeknisiDailyTasksScreen(),
              ),
            ),
          );

          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(find.text('tugas selesai'), findsWidgets);
          expect(find.text('Lihat Bukti'), findsOneWidget);
          expect(find.text('Lanjutkan'), findsOneWidget);
          expect(find.text('Belum Selesai'), findsWidgets);
        });
      }
    }

    testWidgets('TeknisiDailyTasksScreen handles textScaler 1.3 at 360 without overflow', (tester) async {
      tester.view.physicalSize = const Size(360.0, 800.0);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      setupClientMock();
      await StorageService.saveMaintenanceSubmissions([sampleOngoing]);

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          home: const MediaQuery(
            data: MediaQueryData(
              size: Size(360.0, 800.0),
              textScaler: TextScaler.linear(1.3),
              padding: EdgeInsets.only(top: 24.0, bottom: 24.0),
            ),
            child: TeknisiDailyTasksScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('CompletedDailyTaskModal Tests', () {
    testWidgets('CompletedDailyTaskModal renders Read-Only, Tutup, and Unduh Semua', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: CompletedDailyTaskModal(task: sampleCompletedTask),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Read-Only'), findsOneWidget);
      expect(find.text('Unduh Semua'), findsOneWidget);
      expect(find.text('Cek barrier gate masuk 1'), findsOneWidget);
      expect(find.byTooltip('Tutup'), findsOneWidget);
    });
  });

  group('TaskHandoverDialog Tests', () {
    testWidgets('TaskHandoverDialog validates empty submit, casing, and Batal pill', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: TaskHandoverDialog(
              judul: 'Bersihkan sensor gate dan kalibrasi palang',
              lokasi: 'Gate 1 PBM',
              pemilik: 'Ryan',
              teknisiOptions: ['Raldy', 'Alessandro'],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Serahkan Tugas'), findsOneWidget);
      expect(find.text('Lanjut ke Teknisi'), findsOneWidget);
      expect(find.text('Alasan Serah Terima'), findsOneWidget);
      expect(find.text('Batal'), findsOneWidget);

      await tester.tap(find.text('Serahkan Tugas'));
      await tester.pumpAndSettle();

      expect(find.text('Alasan wajib diisi'), findsOneWidget);
    });
  });

  group('Generate 20 Showcase Screenshots', () {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      final mode = brightness == Brightness.light ? 'light' : 'dark';
      final theme = brightness == Brightness.dark ? AppTheme.darkTheme : AppTheme.lightTheme;

      for (final dim in [(360.0, 800.0), (390.0, 844.0)]) {
        final w = dim.$1;
        final h = dim.$2;
        final sizeTag = '${w.toInt()}';

        testWidgets('Capture $mode-$sizeTag-daily-task', (tester) async {
          final key = GlobalKey();
          tester.view.physicalSize = Size(w, h);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          setupClientMock();
          await StorageService.saveMaintenanceSubmissions([sampleOngoing]);

          await tester.pumpWidget(
            RepaintBoundary(
              key: key,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: theme,
                home: MediaQuery(
                  data: MediaQueryData(
                    size: Size(w, h),
                    padding: const EdgeInsets.only(top: 24.0, bottom: 24.0),
                  ),
                  child: const TeknisiDailyTasksScreen(),
                ),
              ),
            ),
          );

          await tester.pumpAndSettle();
          await _saveBoundaryAsPng(
            tester,
            key,
            'docs/screenshots/tiket-daily-task/$mode-$sizeTag-daily-task.png',
          );
        });

        testWidgets('Capture $mode-$sizeTag-empty', (tester) async {
          final key = GlobalKey();
          tester.view.physicalSize = Size(w, h);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          setupClientMock(empty: true);
          await StorageService.saveMaintenanceSubmissions([]);

          await tester.pumpWidget(
            RepaintBoundary(
              key: key,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: theme,
                home: MediaQuery(
                  data: MediaQueryData(
                    size: Size(w, h),
                    padding: const EdgeInsets.only(top: 24.0, bottom: 24.0),
                  ),
                  child: const TeknisiDailyTasksScreen(),
                ),
              ),
            ),
          );

          await tester.pumpAndSettle();
          await _saveBoundaryAsPng(
            tester,
            key,
            'docs/screenshots/tiket-daily-task/$mode-$sizeTag-empty.png',
          );
        });

        testWidgets('Capture $mode-$sizeTag-offline', (tester) async {
          final key = GlobalKey();
          tester.view.physicalSize = Size(w, h);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          final colors = brightness == Brightness.dark ? TiketColors.dark : TiketColors.light;

          await tester.pumpWidget(
            RepaintBoundary(
              key: key,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: theme,
                home: MediaQuery(
                  data: MediaQueryData(
                    size: Size(w, h),
                    padding: const EdgeInsets.only(top: 24.0, bottom: 24.0),
                  ),
                  child: Scaffold(
                    backgroundColor: colors.canvas,
                    bottomNavigationBar: TiketBottomBar(
                      primary: TiketPill(
                        label: 'Catat Kerjaan baru',
                        icon: Icons.add_rounded,
                        kind: TiketPillKind.primary,
                        height: 48,
                        expand: true,
                        onPressed: () {},
                      ),
                    ),
                    body: CustomScrollView(
                      slivers: [
                        TiketSliverBand(
                          expandedHeight: 220.0,
                          compactTitle: 'Daily Task · 1/3 selesai',
                          leading: const TiketIconButton(
                            icon: Icons.arrow_back_rounded,
                            semanticLabel: 'Kembali',
                          ),
                          actions: const [
                            TiketIconButton(
                              icon: Icons.refresh_rounded,
                              semanticLabel: 'Muat Ulang',
                            ),
                          ],
                          caption: 'Daily Task · Ryan',
                          hero: Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                '1/3',
                                style: TextStyle(
                                  fontFamily: TiketType.fontFamily,
                                  fontSize: 36,
                                  fontWeight: FontWeight.w800,
                                  color: colors.white,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'tugas selesai',
                                style: TextStyle(
                                  fontFamily: TiketType.fontFamily,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: colors.white,
                                ),
                              ),
                            ],
                          ),
                          footer: Text(
                            'Data terakhir 08:15',
                            style: TextStyle(
                              fontFamily: TiketType.fontFamily,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: colors.bandCaption,
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: colors.soft,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: colors.hairline),
                                  ),
                                  child: Row(
                                    children: [
                                      const StatusMarker(status: TiketStatus.attention),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          'Offline. Ini data terakhir yang tersimpan di HP (08:15).',
                                          style: TextStyle(
                                            fontFamily: TiketType.fontFamily,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: colors.ink,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        'Coba Lagi',
                                        style: TextStyle(
                                          fontFamily: TiketType.fontFamily,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: colors.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Text(
                                      'Hari ini',
                                      style: TextStyle(
                                        fontFamily: TiketType.fontFamily,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: colors.ink,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '3 tugas',
                                      style: TextStyle(
                                        fontFamily: TiketType.fontFamily,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: colors.body,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        SliverList(
                          delegate: SliverChildListDelegate([
                            TiketRow(
                              leading: const StatusMarker(status: TiketStatus.ok),
                              title: 'Cek barrier gate masuk 1',
                              meta: const ['Pos Pasar Bersehati', 'Maintenance'],
                              status: ('Selesai 09:30 WITA', colors.okText),
                              trailing: const TiketPill(
                                label: 'Lihat Bukti',
                                kind: TiketPillKind.secondary,
                                height: 44,
                              ),
                            ),
                            TiketRow(
                              leading: const StatusMarker(status: TiketStatus.attention),
                              title: 'Bersihkan sensor gate dan kalibrasi palang',
                              meta: const ['Gate 1 PBM', 'bersama Alessandro'],
                              status: ('Proses 3/6 poin', colors.signalText),
                              trailing: const TiketPill(
                                label: 'Lanjutkan',
                                kind: TiketPillKind.primary,
                                height: 44,
                              ),
                            ),
                          ]),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );

          await tester.pumpAndSettle();
          await _saveBoundaryAsPng(
            tester,
            key,
            'docs/screenshots/tiket-daily-task/$mode-$sizeTag-offline.png',
          );
        });

        testWidgets('Capture $mode-$sizeTag-lihat-bukti', (tester) async {
          final key = GlobalKey();
          tester.view.physicalSize = Size(w, h);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await tester.pumpWidget(
            RepaintBoundary(
              key: key,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: theme,
                home: MediaQuery(
                  data: MediaQueryData(
                    size: Size(w, h),
                    padding: const EdgeInsets.only(top: 24.0, bottom: 24.0),
                  ),
                  child: Scaffold(
                    backgroundColor: Colors.black45,
                    body: Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                        ),
                        constraints: BoxConstraints(maxHeight: h * 0.90),
                        child: CompletedDailyTaskModal(task: sampleCompletedTask),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );

          await tester.pumpAndSettle();
          await _saveBoundaryAsPng(
            tester,
            key,
            'docs/screenshots/tiket-daily-task/$mode-$sizeTag-lihat-bukti.png',
          );
        });

        testWidgets('Capture $mode-$sizeTag-serah-terima', (tester) async {
          final key = GlobalKey();
          tester.view.physicalSize = Size(w, h);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await tester.pumpWidget(
            RepaintBoundary(
              key: key,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: theme,
                home: MediaQuery(
                  data: MediaQueryData(
                    size: Size(w, h),
                    padding: const EdgeInsets.only(top: 24.0, bottom: 24.0),
                  ),
                  child: const Scaffold(
                    backgroundColor: Colors.black45,
                    body: Align(
                      alignment: Alignment.bottomCenter,
                      child: TaskHandoverDialog(
                        judul: 'Bersihkan sensor gate dan kalibrasi palang',
                        lokasi: 'Gate 1 PBM',
                        pemilik: 'Ryan',
                        teknisiOptions: ['Raldy', 'Alessandro'],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );

          await tester.pumpAndSettle();
          await _saveBoundaryAsPng(
            tester,
            key,
            'docs/screenshots/tiket-daily-task/$mode-$sizeTag-serah-terima.png',
          );
        });
      }
    }
  });
}
