import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bssparking_timemark/core/constants/tiket_colors.dart';
import 'package:bssparking_timemark/core/widgets/tiket/tiket.dart';
import 'package:bssparking_timemark/data/models/daily_task_model.dart';
import 'package:bssparking_timemark/data/models/maintenance_submission.dart';
import 'package:bssparking_timemark/data/models/user_model.dart';
import 'package:bssparking_timemark/data/repositories/auth_repository.dart';
import 'package:bssparking_timemark/data/repositories/template_repository.dart';
import 'package:bssparking_timemark/data/services/branch_service.dart';
import 'package:bssparking_timemark/data/services/daily_task_service.dart';
import 'package:bssparking_timemark/data/services/location_service.dart';
import 'package:bssparking_timemark/data/services/maintenance_log_service.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';

import 'package:bssparking_timemark/features/auth/screens/login_screen.dart';
import 'package:bssparking_timemark/features/camera/widgets/camera_drawer.dart';
import 'package:bssparking_timemark/features/daily_tasks/screens/spv_task_dispatcher_screen.dart';
import 'package:bssparking_timemark/features/daily_tasks/screens/teknisi_daily_tasks_screen.dart';
import 'package:bssparking_timemark/features/daily_tasks/widgets/ad_hoc_task_dialog.dart';
import 'package:bssparking_timemark/features/maintenance/screens/maintenance_checklist_screen.dart';
import 'package:bssparking_timemark/features/maintenance/screens/maintenance_history_screen.dart';
import 'package:bssparking_timemark/features/maintenance/screens/maintenance_location_detail_screen.dart';
import 'package:bssparking_timemark/features/maintenance/screens/maintenance_map_screen.dart';

import 'visual_harness.dart';

const String _adminSampleText = '''
Selamat pagi, izin melaporkan, telah terjadi kendala dengan kronologi sebagai berikut:

Tanggal : 07-11-2026
Waktu : 05.35

Lokasi : PBM

Kendala : Pos 1 Palang Tidak bisa terangkat 

Penyebab : Tidak diketahui 

Solusi sementara : Pos 1 ditutup Smntra

Durasi Error : 

Berikut kami lampirkan dokumentasi kerusakan.

Terima kasih.
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const size = Size(360, 800);
  const modes = [ThemeMode.light, ThemeMode.dark];
  const folder = 'balance-sweep';

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async => Directory.systemTemp.path,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dexterous.com/flutter/local_notifications'),
      (MethodCall methodCall) async => true,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall methodCall) async {
        if (methodCall.method == 'Clipboard.getData') {
          return const <String, dynamic>{'text': _adminSampleText};
        }
        return null;
      },
    );
  });

  const sampleLoc = PosLocation(
    posId: 'POS-01',
    posName: 'Pos Pasar Bersehati',
    cabangName: 'KC Manado',
    fullAddress: 'Jl. Nusantara, Manado',
    locationTag: 'PBM',
    tagColor: Colors.blue,
    lat: 1.49,
    lng: 124.84,
  );

  const sampleTemuan = MaintenanceTemuan(
    label: 'Palang pintu rusak',
    status: 'tidak_sesuai',
    alasan: 'Palang tidak bisa terangkat',
    urgent: true,
  );

  final sampleLog = const MaintenanceLogEntry(
    id: 'log-01',
    tanggal: '2026-11-10',
    jamSelesai: '10:00',
    posId: 'POS-01',
    posName: 'Pos Pasar Bersehati',
    teknisiNama: 'Ryan Lumasuge',
    templateId: 'tpl_maint_pos',
    totalPoin: 10,
    sesuaiPoin: 8,
    temuan: [sampleTemuan],
  );

  final sampleStatus = PosMaintenanceStatus(
    location: sampleLoc,
    wilayah: 'Manado',
    logs: [sampleLog],
  );

  final now = DateTime.now();
  final todayStr =
      '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

  final ryan = UserModel(
    id: 'usr_ryan',
    nama: 'Ryan Lumasuge',
    npp: '10293',
    email: 'ryan@bssparking.com',
    role: UserRole.petugas,
    posId: 'POS-01',
    posName: 'Pos Pasar Bersehati',
    cabangName: 'KC Manado',
  );

  final spv = UserModel(
    id: 'usr_spv',
    nama: 'Raldy Sangkop',
    npp: '99001',
    email: 'spv@bssparking.com',
    role: UserRole.supervisor,
    posId: 'POS-01',
    posName: 'Pos Pasar Bersehati',
    cabangName: 'KC Manado',
  );

  final sampleTasks = [
    DailyTaskModel(
      id: 't_01',
      tanggal: todayStr,
      teknisiId: 'usr_ryan',
      teknisiNama: 'Ryan Lumasuge',
      posName: 'Pos Pasar Bersehati',
      posTag: 'PBM',
      judul: 'Maintenance Barrier Gate In',
      deskripsi: 'Pemeriksaan rutin motor dan sensor barrier gate masuk.',
      kategori: 'maintenance',
      templateId: 'tpl_maint_barrier',
      status: TaskStatus.pending,
    ),
    DailyTaskModel(
      id: 't_02',
      tanggal: todayStr,
      teknisiId: 'usr_ryan',
      teknisiNama: 'Ryan Lumasuge',
      posName: 'Pos Pasar Bersehati',
      posTag: 'PBM',
      judul: 'Pos 1 Palang Tidak bisa terangkat',
      deskripsi: '''
Tanggal : $todayStr
Waktu : 05.35
Lokasi : PBM
Kendala : Pos 1 Palang Tidak bisa terangkat
Penyebab : Tidak diketahui
Solusi sementara : Pos 1 ditutup Smntra
''',
      kategori: 'error',
      status: TaskStatus.pending,
    ),
    DailyTaskModel(
      id: 't_03',
      tanggal: todayStr,
      teknisiId: 'usr_ryan',
      teknisiNama: 'Ryan Lumasuge',
      posName: 'Pos Pasar Bersehati',
      posTag: 'PBM',
      judul: 'Pemeriksaan Loop Detector',
      deskripsi: 'Pengecekan sensitivitas loop kabel tanam.',
      kategori: 'maintenance',
      templateId: 'tpl_maint_manless',
      status: TaskStatus.completed,
      jamSelesai: '08:30',
    ),
  ];

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    BranchService.instance.resetForTesting();
    await BranchService.instance.setBranch(AppBranch.manado);

    await StorageService.setString(
      DailyTaskService.localCacheKey,
      jsonEncode(sampleTasks.map((e) => e.toJson()).toList()),
    );
  });

  group('Balance Sweep 360', () {
    // 01. Login
    for (final mode in modes) {
      testWidgets('01-login-${mode.name}', (tester) async {
        final themeStr = mode == ThemeMode.dark ? 'dark' : 'light';
        await captureScreen(
          tester,
          name: '01-login',
          screen: const LoginScreen(),
          size: size,
          mode: mode,
          folder: folder,
          customFileName: '01-login-$themeStr.png',
        );
      });
    }

    // 02. Drawer
    for (final mode in modes) {
      testWidgets('02-drawer-${mode.name}', (tester) async {
        await AuthRepository.instance.login(ryan);
        final themeStr = mode == ThemeMode.dark ? 'dark' : 'light';
        await captureScreen(
          tester,
          name: '02-drawer',
          screen: Scaffold(
            body: Row(
              children: [
                SizedBox(
                  width: 304,
                  child: CameraDrawer(onRefreshDailyTasksBadge: () {}),
                ),
                Expanded(
                  child: Container(color: Colors.black45),
                ),
              ],
            ),
          ),
          size: size,
          mode: mode,
          folder: folder,
          customFileName: '02-drawer-$themeStr.png',
        );
      });
    }

    // 03. Teknisi Daily Task (pending row with Belum selesai + Kerjakan)
    for (final mode in modes) {
      testWidgets('03-teknisi-daily-tasks-${mode.name}', (tester) async {
        await AuthRepository.instance.login(ryan);
        final themeStr = mode == ThemeMode.dark ? 'dark' : 'light';
        await captureScreen(
          tester,
          name: '03-teknisi-daily-tasks',
          screen: const TeknisiDailyTasksScreen(),
          size: size,
          mode: mode,
          folder: folder,
          customFileName: '03-teknisi-daily-tasks-$themeStr.png',
        );
      });
    }

    // 04. SPV Dispatcher (SpvTaskCard with Alihkan)
    for (final mode in modes) {
      testWidgets('04-spv-dispatcher-${mode.name}', (tester) async {
        await AuthRepository.instance.login(spv);
        final themeStr = mode == ThemeMode.dark ? 'dark' : 'light';
        await captureScreen(
          tester,
          name: '04-spv-dispatcher',
          screen: const SpvTaskDispatcherScreen(),
          size: size,
          mode: mode,
          folder: folder,
          customFileName: '04-spv-dispatcher-$themeStr.png',
        );
      });
    }

    // 05. Laporan Error sheet SPV Tunjuk mode
    for (final mode in modes) {
      testWidgets('05-laporan-error-sheet-${mode.name}', (tester) async {
        await AuthRepository.instance.login(spv);
        final themeStr = mode == ThemeMode.dark ? 'dark' : 'light';
        await captureScreen(
          tester,
          name: '05-laporan-error-sheet',
          screen: Scaffold(
            body: AdHocTaskDialog(
              teknisiNama: 'Raldy Sangkop',
              tanggal: todayStr,
              lokasiOptions: const [sampleLoc],
              teknisiOptions: const ['Ryan Lumasuge', 'Farhan Lakoro', 'Budi Santoso'],
              startInErrorMode: true,
            ),
          ),
          size: size,
          mode: mode,
          folder: folder,
          customFileName: '05-laporan-error-sheet-$themeStr.png',
          onPumped: (t) async {
            final tempelFinder = find.text('Tempel dari Telegram');
            if (tempelFinder.evaluate().isNotEmpty) {
              await t.tap(tempelFinder);
              await t.pumpAndSettle();
            }
            final tunjukFinder = find.text('Tunjuk');
            if (tunjukFinder.evaluate().isNotEmpty) {
              await t.tap(tunjukFinder);
              await t.pumpAndSettle();
            }
          },
        );
      });
    }

    // 06. Error alarm banner over Daily Task
    for (final mode in modes) {
      testWidgets('06-error-alarm-banner-${mode.name}', (tester) async {
        await AuthRepository.instance.login(ryan);
        final themeStr = mode == ThemeMode.dark ? 'dark' : 'light';
        final errorTask = sampleTasks[1];
        final openErrors = ValueNotifier<List<DailyTaskModel>>([errorTask]);
        final ringing = ValueNotifier<bool>(true);

        await captureScreen(
          tester,
          name: '06-error-alarm-banner',
          screen: ErrorAlarmOverlay(
            openErrors: openErrors,
            ringing: ringing,
            onLihat: () {},
            child: const TeknisiDailyTasksScreen(),
          ),
          size: size,
          mode: mode,
          folder: folder,
          customFileName: '06-error-alarm-banner-$themeStr.png',
        );
      });
    }

    // 07. Map Maintenance band
    for (final mode in modes) {
      testWidgets('07-map-maintenance-${mode.name}', (tester) async {
        await AuthRepository.instance.login(ryan);
        final themeStr = mode == ThemeMode.dark ? 'dark' : 'light';
        await captureScreen(
          tester,
          name: '07-map-maintenance',
          screen: const MaintenanceMapScreen(),
          size: size,
          mode: mode,
          folder: folder,
          customFileName: '07-map-maintenance-$themeStr.png',
        );
      });
    }

    // 08. Detail Lokasi (error section + temuan card)
    for (final mode in modes) {
      testWidgets('08-detail-lokasi-${mode.name}', (tester) async {
        await AuthRepository.instance.login(ryan);
        final themeStr = mode == ThemeMode.dark ? 'dark' : 'light';
        await captureScreen(
          tester,
          name: '08-detail-lokasi',
          screen: MaintenanceLocationDetailScreen(
            status: sampleStatus,
            month: now,
          ),
          size: size,
          mode: mode,
          folder: folder,
          customFileName: '08-detail-lokasi-$themeStr.png',
        );
      });
    }

    // 09. Riwayat Maintenance (draft card)
    for (final mode in modes) {
      testWidgets('09-riwayat-maintenance-${mode.name}', (tester) async {
        await AuthRepository.instance.login(ryan);
        final draft = MaintenanceSubmission(
          id: 'draft_01',
          templateId: 'tpl_maint_pos',
          templateName: 'Pos & Dispenser Tiket',
          userId: 'usr_ryan',
          userName: 'Ryan Lumasuge',
          userNpp: '10293',
          posId: 'POS-01',
          posName: 'Pos Pasar Bersehati',
          cabangName: 'KC Manado',
          points: const [
            MaintenancePointResult(
              pointId: 'p_01',
              label: 'Sensor Barrier',
              status: PointStatus.sesuai,
            ),
            MaintenancePointResult(
              pointId: 'p_02',
              label: 'Kabel LAN',
              status: PointStatus.belumFoto,
            ),
          ],
          createdAt: now.subtract(const Duration(hours: 2)),
          updatedAt: now.subtract(const Duration(hours: 2)),
        );
        await StorageService.upsertMaintenanceSubmission(draft);

        final themeStr = mode == ThemeMode.dark ? 'dark' : 'light';
        await captureScreen(
          tester,
          name: '09-riwayat-maintenance',
          screen: const MaintenanceHistoryScreen(initialTabIndex: 0),
          size: size,
          mode: mode,
          folder: folder,
          customFileName: '09-riwayat-maintenance-$themeStr.png',
        );
      });
    }

    // 10. Checklist + Kendala sheet
    for (final mode in modes) {
      testWidgets('10-checklist-kendala-${mode.name}', (tester) async {
        await AuthRepository.instance.login(ryan);
        final template = TemplateRepository.defaultTemplates.firstWhere(
          (t) => t.id == 'tpl_maint_pos',
          orElse: () => TemplateRepository.defaultTemplates.first,
        );

        final themeStr = mode == ThemeMode.dark ? 'dark' : 'light';
        await captureScreen(
          tester,
          name: '10-checklist-kendala',
          screen: MaintenanceChecklistScreen(
            template: template,
            unitNumbers: const [1, 2],
            unitRoles: const {1: 'IN', 2: 'OUT'},
            location: sampleLoc,
          ),
          size: size,
          mode: mode,
          folder: folder,
          customFileName: '10-checklist-kendala-$themeStr.png',
          onPumped: (t) async {
            final ctx = t.element(find.byType(MaintenanceChecklistScreen));
            final colors = TiketColors.of(ctx);

            showDialog(
              context: ctx,
              builder: (dlgCtx) {
                return Dialog(
                  backgroundColor: colors.dialog,
                  surfaceTintColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Tandai Kendala Fisik',
                            style: TextStyle(
                              fontFamily: TiketType.fontFamily,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: colors.ink,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Pilih opsi ini jika alat rusak fisik atau perlu penggantian sparepart.',
                            style: TextStyle(
                              fontFamily: TiketType.fontFamily,
                              fontSize: 13,
                              color: colors.body,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Pilih jenis kendala',
                            style: TextStyle(
                              fontFamily: TiketType.fontFamily,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: colors.ink,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.radio_button_checked, size: 20, color: colors.primary),
                              const SizedBox(width: 8),
                              Text(
                                'Alat Patah / Retak / Keropos',
                                style: TextStyle(
                                  fontFamily: TiketType.fontFamily,
                                  fontSize: 13,
                                  color: colors.ink,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.radio_button_off, size: 20, color: colors.mute),
                              const SizedBox(width: 8),
                              Text(
                                'Kabel Putus / Terkelupas',
                                style: TextStyle(
                                  fontFamily: TiketType.fontFamily,
                                  fontSize: 13,
                                  color: colors.ink,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: TiketPill(
                                  label: 'Batal',
                                  kind: TiketPillKind.secondary,
                                  height: 40,
                                  expand: true,
                                  onPressed: () {},
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TiketPill(
                                  label: 'Simpan kendala',
                                  kind: TiketPillKind.primary,
                                  height: 40,
                                  expand: true,
                                  onPressed: () {},
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      });
    }

    // 11. Confirm dialog (Reset tugas)
    for (final mode in modes) {
      testWidgets('11-confirm-dialog-${mode.name}', (tester) async {
        await AuthRepository.instance.login(spv);
        final themeStr = mode == ThemeMode.dark ? 'dark' : 'light';
        await captureScreen(
          tester,
          name: '11-confirm-dialog',
          screen: const SpvTaskDispatcherScreen(),
          size: size,
          mode: mode,
          folder: folder,
          customFileName: '11-confirm-dialog-$themeStr.png',
          onPumped: (t) async {
            final ctx = t.element(find.byType(SpvTaskDispatcherScreen));
            final colors = TiketColors.of(ctx);

            showDialog(
              context: ctx,
              builder: (dlgCtx) {
                return AlertDialog(
                  backgroundColor: colors.dialog,
                  surfaceTintColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  title: Text(
                    'Hapus Tugas?',
                    style: TextStyle(
                      fontFamily: TiketType.fontFamily,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colors.ink,
                    ),
                  ),
                  content: Text(
                    'Tugas "Maintenance Barrier Gate" untuk Ryan Lumasuge akan dihapus permanen.',
                    style: TextStyle(
                      fontFamily: TiketType.fontFamily,
                      fontSize: 13,
                      color: colors.body,
                    ),
                  ),
                  actions: [
                    TiketPill(
                      label: 'Batal',
                      kind: TiketPillKind.secondary,
                      height: 40,
                      onPressed: () {},
                    ),
                    const SizedBox(width: 8),
                    TiketPill(
                      label: 'Hapus',
                      kind: TiketPillKind.primary,
                      height: 40,
                      onPressed: () {},
                    ),
                  ],
                );
              },
            );
          },
        );
      });
    }
  });
}
