import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bssparking_timemark/core/constants/app_theme.dart';
import 'package:bssparking_timemark/data/models/daily_task_model.dart';
import 'package:bssparking_timemark/data/models/user_model.dart';
import 'package:bssparking_timemark/data/repositories/auth_repository.dart';
import 'package:bssparking_timemark/data/services/branch_service.dart';
import 'package:bssparking_timemark/data/services/daily_task_service.dart';
import 'package:bssparking_timemark/data/services/location_service.dart';
import 'package:bssparking_timemark/data/services/maintenance_log_service.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';
import 'package:bssparking_timemark/features/daily_tasks/screens/spv_task_dispatcher_screen.dart';
import 'package:bssparking_timemark/features/maintenance/screens/maintenance_location_detail_screen.dart';

import 'visual/visual_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const loc = PosLocation(
    posId: 'POS-01',
    posName: 'Pos Pasar Bersehati',
    cabangName: 'KC Manado',
    fullAddress: 'Jl. Nusantara Manado',
    locationTag: 'PBM',
    tagColor: Colors.blue,
    lat: 1.49,
    lng: 124.84,
  );

  const temuan = MaintenanceTemuan(
    label: 'Palang pintu rusak',
    status: 'tidak_sesuai',
    alasan: 'Palang tidak terangkat',
    urgent: true,
  );

  const log = MaintenanceLogEntry(
    id: 'log-01',
    tanggal: '2026-11-10',
    jamSelesai: '10:00',
    posId: 'POS-01',
    posName: 'Pos Pasar Bersehati',
    teknisiNama: 'Budi Santoso',
    templateId: 'tpl_maint_manless',
    totalPoin: 10,
    sesuaiPoin: 8,
    temuan: [temuan],
  );

  const status = PosMaintenanceStatus(
    location: loc,
    wilayah: 'Manado',
    logs: [log],
  );

  DailyTaskModel createMatchingTicket({
    String teknisiNama = 'Budi Santoso',
    String posName = 'Pos Pasar Bersehati',
    String kendala = 'Pos 1 Palang Tidak bisa terangkat',
    String penyebab = 'Sensor loop mati',
    String solusiSementara = 'Palang dibuka manual',
    String pelapor = '',
    String peserta = '',
    String serahTerima = '',
  }) {
    final pelaporLine = pelapor.isNotEmpty ? 'Pelapor : $pelapor\n' : '';
    return DailyTaskModel(
      id: 'task-err-01',
      tanggal: '2026-11-10',
      teknisiId: 'tech-01',
      teknisiNama: teknisiNama,
      posName: posName,
      posTag: 'PBM',
      judul: kendala,
      deskripsi: '''
Tanggal : 10-11-2026
Waktu : 08.30
Lokasi : $posName
${pelaporLine}Kendala : $kendala
Penyebab : $penyebab
Solusi sementara : $solusiSementara
''',
      kategori: 'error',
      status: TaskStatus.pending,
      peserta: peserta,
      serahTerima: serahTerima,
    );
  }

  group('MaintenanceLocationDetailScreen - Laporan Error Section', () {
    testWidgets(
      '(1) matching ticket -> LAPORAN ERROR, kendala, Penyebab, Solusi sementara values visible while Temuan tab content still renders',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        SharedPreferences.setMockInitialValues({});
        await StorageService.init();
        await StorageService.saveLastTechnicianName('Budi Santoso');

        final ticket = createMatchingTicket();

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: MaintenanceLocationDetailScreen(
              status: status,
              month: DateTime.now(),
              errorTicketsLoader: () async => [ticket],
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('LAPORAN ERROR'), findsOneWidget);
        expect(find.text('Pos 1 Palang Tidak bisa terangkat'), findsOneWidget);
        expect(find.text('Penyebab'), findsOneWidget);
        expect(find.text('Sensor loop mati'), findsOneWidget);
        expect(find.text('Solusi sementara'), findsOneWidget);
        expect(find.text('Palang dibuka manual'), findsOneWidget);
        expect(find.text('Belum selesai'), findsOneWidget);

        // Temuan tab content still renders
        expect(find.text('Palang pintu rusak'), findsOneWidget);
      },
    );

    testWidgets(
      '(2) non-matching pos -> no section',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        SharedPreferences.setMockInitialValues({});
        await StorageService.init();

        final ticket = createMatchingTicket(posName: 'Pos Berbeda');

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: MaintenanceLocationDetailScreen(
              status: status,
              month: DateTime.now(),
              errorTicketsLoader: () async => [ticket],
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('LAPORAN ERROR'), findsNothing);
        expect(find.text('Palang pintu rusak'), findsOneWidget);
      },
    );

    testWidgets(
      '(3) loader throws -> screen renders without section',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        SharedPreferences.setMockInitialValues({});
        await StorageService.init();

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: MaintenanceLocationDetailScreen(
              status: status,
              month: DateTime.now(),
              errorTicketsLoader: () async => throw Exception('Network timeout'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('LAPORAN ERROR'), findsNothing);
        expect(find.text('Palang pintu rusak'), findsOneWidget);
      },
    );

    testWidgets(
      '(4) owner -> Kerjakan present, non-owner -> Ditangani <name>',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        SharedPreferences.setMockInitialValues({});
        await StorageService.init();

        // 4a: Owner view
        await StorageService.saveLastTechnicianName('Budi Santoso');
        final ticket1 = createMatchingTicket(teknisiNama: 'Budi Santoso');

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: MaintenanceLocationDetailScreen(
              status: status,
              month: DateTime.now(),
              errorTicketsLoader: () async => [ticket1],
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Kerjakan'), findsOneWidget);
        expect(find.textContaining('Ditangani'), findsNothing);

        // 4b: Non-owner view
        await StorageService.saveLastTechnicianName('Aan Admin');
        final ticket2 = createMatchingTicket(teknisiNama: 'Budi Santoso');

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: MaintenanceLocationDetailScreen(
              key: UniqueKey(),
              status: status,
              month: DateTime.now(),
              errorTicketsLoader: () async => [ticket2],
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Kerjakan'), findsNothing);
        expect(find.text('Ditangani Budi Santoso'), findsOneWidget);

        // 4c: Open-list ticket -> 'Belum diambil teknisi'
        final openTicket = createMatchingTicket(
          teknisiNama: 'Farhan Lakoro',
          serahTerima: 'Farhan Lakoro||Daftar terbuka|10 Nov 08:30',
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: MaintenanceLocationDetailScreen(
              key: UniqueKey(),
              status: status,
              month: DateTime.now(),
              errorTicketsLoader: () async => [openTicket],
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Kerjakan'), findsNothing);
        expect(find.text('Belum diambil teknisi'), findsOneWidget);

        // 4d: Peserta view -> 'Kerjakan' visible for pendamping
        await StorageService.saveLastTechnicianName('Ryan Lumasuge');
        final sharedTicket = createMatchingTicket(
          teknisiNama: 'Budi Santoso',
          peserta: 'Ryan Lumasuge, Junifer',
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: MaintenanceLocationDetailScreen(
              key: UniqueKey(),
              status: status,
              month: DateTime.now(),
              errorTicketsLoader: () async => [sharedTicket],
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Kerjakan'), findsOneWidget);

        // 4e: createdBy used in Dilaporkan meta
        final ticketWithPelapor = createMatchingTicket(
          teknisiNama: 'Budi Santoso',
          pelapor: 'Farhan SPV',
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: MaintenanceLocationDetailScreen(
              key: UniqueKey(),
              status: status,
              month: DateTime.now(),
              errorTicketsLoader: () async => [ticketWithPelapor],
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('Dilaporkan Farhan SPV'), findsOneWidget);
      },
    );

    testWidgets(
      '(5) 360 width textScaler 1.3 no overflow',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        SharedPreferences.setMockInitialValues({});
        await StorageService.init();
        await StorageService.saveLastTechnicianName('Budi Santoso');

        final ticket = createMatchingTicket();

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(360, 800),
                textScaler: TextScaler.linear(1.3),
              ),
              child: MaintenanceLocationDetailScreen(
                status: status,
                month: DateTime.now(),
                errorTicketsLoader: () async => [ticket],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('LAPORAN ERROR'), findsOneWidget);
        expect(find.text('Kerjakan'), findsOneWidget);
      },
    );

    testWidgets(
      '(6) temuan card contains the Tandai sudah diperbaiki button (find.descendant) and at 360 width textScaler 1.3 no overflow',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        SharedPreferences.setMockInitialValues({});
        await StorageService.init();
        await StorageService.saveLastTechnicianName('Budi Santoso');

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(360, 800),
                textScaler: TextScaler.linear(1.3),
              ),
              child: MaintenanceLocationDetailScreen(
                status: status,
                month: DateTime.now(),
                errorTicketsLoader: () async => [],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);

        final temuanCard = find.ancestor(
          of: find.text('Palang pintu rusak'),
          matching: find.byType(Container),
        ).first;

        expect(
          find.descendant(
            of: temuanCard,
            matching: find.text('Tandai sudah diperbaiki'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'capture screenshots docs/screenshots/tiket-error/detail/',
      skip: true,
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        await StorageService.init();
        await StorageService.saveLastTechnicianName('Budi Santoso');

        final ticket = createMatchingTicket();
        await loadAppFonts();

        for (final mode in [ThemeMode.light, ThemeMode.dark]) {
          final boundaryKey = GlobalKey();
          final activeTheme =
              mode == ThemeMode.dark ? AppTheme.darkTheme : AppTheme.lightTheme;
          const size = Size(390, 844);

          tester.view.physicalSize = Size(size.width * 2.0, size.height * 2.0);
          tester.view.devicePixelRatio = 2.0;

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
                    platformBrightness: mode == ThemeMode.dark
                        ? Brightness.dark
                        : Brightness.light,
                  ),
                  child: SizedBox(
                    width: size.width,
                    height: size.height,
                    child: RepaintBoundary(
                      key: boundaryKey,
                      child: MaintenanceLocationDetailScreen(
                        status: status,
                        month: DateTime.now(),
                        errorTicketsLoader: () async => [ticket],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          final boundary = boundaryKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
          expect(boundary, isNotNull);

          await tester.runAsync(() async {
            final image = await boundary!.toImage(pixelRatio: 1.0);
            final byteData =
                await image.toByteData(format: ui.ImageByteFormat.png);
            final buffer = byteData!.buffer.asUint8List();

            final dir = Directory('docs/screenshots/tiket-error/detail');
            if (!dir.existsSync()) {
              dir.createSync(recursive: true);
            }

            final modeStr = mode == ThemeMode.dark ? 'dark' : 'light';
            final file = File(
                'docs/screenshots/tiket-error/detail/detail-error-$modeStr-390.png');
            await file.writeAsBytes(buffer);

            // Clean up legacy duplicate file names if present
            final dupFile = File(
                'docs/screenshots/tiket-error/detail/detail-error-390-$modeStr.png');
            if (dupFile.existsSync()) {
              dupFile.deleteSync();
            }
          });

          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        }
      },
    );

    testWidgets(
      'capture coder button audit screenshots docs/screenshots/button-audit/coder/',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        await StorageService.init();
        await StorageService.saveLastTechnicianName('Budi Santoso');
        await loadAppFonts();

        final dir = Directory('docs/screenshots/button-audit/coder');
        if (!dir.existsSync()) {
          dir.createSync(recursive: true);
        }

        // 1. MaintenanceLocationDetailScreen light-390
        final ticket = createMatchingTicket();
        final boundaryKey1 = GlobalKey();
        const size = Size(390, 844);
        tester.view.physicalSize = Size(size.width * 2.0, size.height * 2.0);
        tester.view.devicePixelRatio = 2.0;

        await tester.pumpWidget(
          RepaintBoundary(
            key: boundaryKey1,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme,
              home: MediaQuery(
                data: const MediaQueryData(
                  size: size,
                  devicePixelRatio: 2.0,
                  platformBrightness: Brightness.light,
                ),
                child: SizedBox(
                  width: size.width,
                  height: size.height,
                  child: MaintenanceLocationDetailScreen(
                    status: status,
                    month: DateTime.now(),
                    errorTicketsLoader: () async => [ticket],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final boundary1 = boundaryKey1.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
        expect(boundary1, isNotNull);

        await tester.runAsync(() async {
          final image1 = await boundary1!.toImage(pixelRatio: 1.0);
          final byteData1 =
              await image1.toByteData(format: ui.ImageByteFormat.png);
          final file1 = File('docs/screenshots/button-audit/coder/detail-lokasi-light-390.png');
          await file1.writeAsBytes(byteData1!.buffer.asUint8List());
        });

        // 2. SpvTaskDispatcherScreen light-390 (with SPV logged in and tasks loaded)
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
        await AuthRepository.instance.login(spvUser);
        await BranchService.instance.setBranch(AppBranch.manado);

        final now = DateTime.now();
        final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
        final spvTask = DailyTaskModel(
          id: 'task-spv-001',
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

        await StorageService.setString(
          DailyTaskService.localCacheKey,
          jsonEncode([spvTask.toJson()]),
        );

        final boundaryKey2 = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundaryKey2,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme,
              home: MediaQuery(
                data: const MediaQueryData(
                  size: size,
                  devicePixelRatio: 2.0,
                  platformBrightness: Brightness.light,
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

        final boundary2 = boundaryKey2.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
        expect(boundary2, isNotNull);

        await tester.runAsync(() async {
          final image2 = await boundary2!.toImage(pixelRatio: 1.0);
          final byteData2 =
              await image2.toByteData(format: ui.ImageByteFormat.png);
          final file2 = File('docs/screenshots/button-audit/coder/spv-dispatcher-light-390.png');
          await file2.writeAsBytes(byteData2!.buffer.asUint8List());
        });

        // 3. Reset/Hapus task dialog screenshot
        final popupMenuFinder = find.byType(PopupMenuButton<String>);
        if (popupMenuFinder.evaluate().isNotEmpty) {
          await tester.tap(popupMenuFinder.first);
          await tester.pumpAndSettle();

          final hapusMenuFinder = find.text('Hapus Tugas');
          if (hapusMenuFinder.evaluate().isNotEmpty) {
            await tester.tap(hapusMenuFinder.first);
            await tester.pumpAndSettle();

            await tester.runAsync(() async {
              final boundaryDialog = boundaryKey2.currentContext?.findRenderObject()
                  as RenderRepaintBoundary?;
              final image3 = await boundaryDialog!.toImage(pixelRatio: 1.0);
              final byteData3 =
                  await image3.toByteData(format: ui.ImageByteFormat.png);
              final file3 = File('docs/screenshots/button-audit/coder/spv-dialog-reset-light-390.png');
              await file3.writeAsBytes(byteData3!.buffer.asUint8List());
            });

            final batalFinder = find.text('Batal');
            if (batalFinder.evaluate().isNotEmpty) {
              await tester.tap(batalFinder.first);
              await tester.pumpAndSettle();
            }
          }
        }

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      },
    );
  });
}
