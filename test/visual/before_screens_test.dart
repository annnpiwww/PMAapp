import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bssparking_timemark/data/models/attendance_record.dart';
import 'package:bssparking_timemark/data/models/daily_task_model.dart';
import 'package:bssparking_timemark/data/models/user_model.dart';
import 'package:bssparking_timemark/data/repositories/auth_repository.dart';
import 'package:bssparking_timemark/data/repositories/template_repository.dart';
import 'package:bssparking_timemark/data/services/branch_service.dart';
import 'package:bssparking_timemark/data/services/daily_task_service.dart';
import 'package:bssparking_timemark/data/services/location_service.dart';
import 'package:bssparking_timemark/data/services/maintenance_log_service.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';

import 'package:bssparking_timemark/features/daily_tasks/screens/spv_task_dispatcher_screen.dart';
import 'package:bssparking_timemark/features/daily_tasks/screens/teknisi_daily_tasks_screen.dart';
import 'package:bssparking_timemark/features/history/screens/attendance_archive_screen.dart';
import 'package:bssparking_timemark/features/maintenance/screens/maintenance_checklist_screen.dart';
import 'package:bssparking_timemark/features/maintenance/screens/maintenance_location_detail_screen.dart';
import 'package:bssparking_timemark/features/maintenance/screens/maintenance_map_screen.dart';

import 'visual_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        return Directory.systemTemp.path;
      },
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dexterous.com/flutter/local_notifications'),
      (MethodCall methodCall) async {
        return true;
      },
    );
  });

  const sizes = [
    Size(360, 800),
    Size(390, 844),
  ];

  const modes = [
    ThemeMode.light,
    ThemeMode.dark,
  ];

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    BranchService.instance.resetForTesting();
    await BranchService.instance.setBranch(AppBranch.manado);

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
    await AuthRepository.instance.login(ryan);

    // 4 sample tasks for Ryan similar to mockups (Pos Pasar Bersehati)
    final tasks = [
      DailyTaskModel(
        id: 't_01',
        tanggal: todayStr,
        teknisiId: 'usr_ryan',
        teknisiNama: 'Ryan Lumasuge',
        posName: 'Pos Pasar Bersehati',
        posTag: 'PBM',
        judul: 'Maintenance Rutin Barrier Gate In',
        kategori: 'maintenance',
        templateId: 'tpl_maint_barrier',
        status: TaskStatus.inProgress,
      ),
      DailyTaskModel(
        id: 't_02',
        tanggal: todayStr,
        teknisiId: 'usr_ryan',
        teknisiNama: 'Ryan Lumasuge',
        posName: 'Pos Pasar Bersehati',
        posTag: 'PBM',
        judul: 'Pembersihan Sensor & Dispenser Tiket',
        kategori: 'maintenance',
        templateId: 'tpl_maint_pos',
        status: TaskStatus.pending,
      ),
      DailyTaskModel(
        id: 't_03',
        tanggal: todayStr,
        teknisiId: 'usr_ryan',
        teknisiNama: 'Ryan Lumasuge',
        posName: 'Pos Pasar Bersehati',
        posTag: 'PBM',
        judul: 'Pemeriksaan Loop Detector Gate Out',
        kategori: 'maintenance',
        templateId: 'tpl_maint_manless',
        status: TaskStatus.pending,
      ),
      DailyTaskModel(
        id: 't_04',
        tanggal: todayStr,
        teknisiId: 'usr_ryan',
        teknisiNama: 'Ryan Lumasuge',
        posName: 'Pos Pasar Bersehati',
        posTag: 'PBM',
        judul: 'Cek Jalur Komunikasi & LAN Server',
        kategori: 'khusus',
        status: TaskStatus.completed,
        jamSelesai: '08:45',
      ),
    ];

    // Seed local cache for offline/test fallback
    await StorageService.setString(
      DailyTaskService.localCacheKey,
      jsonEncode(tasks.map((e) => e.toJson()).toList()),
    );

    // Seed AttendanceRecord
    await StorageService.saveAttendanceRecord(
      AttendanceRecord(
        id: 'att_01',
        timestamp: DateTime.now().subtract(const Duration(hours: 3)),
        type: AttendanceType.masuk,
        shiftName: 'Shift 1 (03:00 - 11:00)',
        technicianName: 'Ryan Lumasuge',
        posName: 'Pos Pasar Bersehati',
        lat: 1.49,
        lng: 124.84,
        fullAddress: 'Jl. Nusantara, Manado',
      ),
    );
  });

  group('BeforeScreens - TeknisiDailyTasksScreen', () {
    for (final size in sizes) {
      for (final mode in modes) {
        testWidgets(
          'capture ${size.width.toInt()} ${mode.name}',
          (tester) async {
            await captureScreen(
              tester,
              name: 'teknisi_daily_tasks',
              screen: const TeknisiDailyTasksScreen(),
              size: size,
              mode: mode,
            );
          },
        );
      }
    }
  });

  group('BeforeScreens - SpvTaskDispatcherScreen', () {
    for (final size in sizes) {
      for (final mode in modes) {
        testWidgets(
          'capture ${size.width.toInt()} ${mode.name}',
          (tester) async {
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
            await AuthRepository.instance.login(spv);

            await captureScreen(
              tester,
              name: 'spv_task_dispatcher',
              screen: const SpvTaskDispatcherScreen(),
              size: size,
              mode: mode,
            );
          },
        );
      }
    }
  });

  group('BeforeScreens - MaintenanceMapScreen', () {
    for (final size in sizes) {
      for (final mode in modes) {
        testWidgets(
          'capture ${size.width.toInt()} ${mode.name}',
          (tester) async {
            await captureScreen(
              tester,
              name: 'maintenance_map',
              screen: const MaintenanceMapScreen(),
              size: size,
              mode: mode,
            );
          },
        );
      }
    }
  });

  group('BeforeScreens - MaintenanceLocationDetailScreen', () {
    for (final size in sizes) {
      for (final mode in modes) {
        testWidgets(
          'capture ${size.width.toInt()} ${mode.name}',
          (tester) async {
            const loc = PosLocation(
              posId: 'POS-01',
              posName: 'Pos Pasar Bersehati',
              cabangName: 'KC Manado',
              fullAddress: 'Jl. Nusantara, Manado',
              locationTag: 'PBM',
              tagColor: Colors.blue,
              lat: 1.49,
              lng: 124.84,
            );

            const temuan1 = MaintenanceTemuan(
              label: 'Sensor gate kotor',
              status: 'tidak_sesuai',
              alasan: 'Perlu dibersihkan segera',
              urgent: true,
            );
            const temuan2 = MaintenanceTemuan(
              label: 'Kabel sensor kendur',
              status: 'perlu_cek_manual',
              alasan: 'Periksa koneksi kabel',
              urgent: false,
            );

            final log1 = const MaintenanceLogEntry(
              id: 'log-01',
              tanggal: '2026-11-09',
              jamSelesai: '09:30',
              posId: 'POS-01',
              posName: 'Pos Pasar Bersehati',
              teknisiNama: 'Ryan Lumasuge',
              templateId: 'tpl_maint_pos',
              totalPoin: 5,
              sesuaiPoin: 3,
              temuan: [temuan1, temuan2],
            );

            final status = PosMaintenanceStatus(
              location: loc,
              wilayah: 'Manado',
              logs: [log1],
            );

            await captureScreen(
              tester,
              name: 'maintenance_location_detail',
              screen: MaintenanceLocationDetailScreen(
                status: status,
                month: DateTime.now(),
              ),
              size: size,
              mode: mode,
            );
          },
        );
      }
    }
  });

  group('BeforeScreens - MaintenanceChecklistScreen', () {
    for (final size in sizes) {
      for (final mode in modes) {
        testWidgets(
          'capture ${size.width.toInt()} ${mode.name}',
          (tester) async {
            final template = TemplateRepository.defaultTemplates.firstWhere(
              (t) => t.id == 'tpl_maint_pos',
              orElse: () => TemplateRepository.defaultTemplates.first,
            );

            await captureScreen(
              tester,
              name: 'maintenance_checklist',
              screen: MaintenanceChecklistScreen(
                template: template,
                unitNumbers: const [1, 2],
                unitRoles: const {1: 'IN', 2: 'OUT'},
                location: const PosLocation(
                  posId: 'POS-01',
                  posName: 'Pos Pasar Bersehati',
                  cabangName: 'KC Manado',
                  fullAddress: 'Jl. Nusantara, Manado',
                  locationTag: 'PBM',
                  tagColor: Colors.blue,
                  lat: 1.49,
                  lng: 124.84,
                ),
              ),
              size: size,
              mode: mode,
            );
          },
        );
      }
    }
  });

  group('BeforeScreens - AttendanceArchiveScreen', () {
    for (final size in sizes) {
      for (final mode in modes) {
        testWidgets(
          'capture ${size.width.toInt()} ${mode.name}',
          (tester) async {
            await captureScreen(
              tester,
              name: 'attendance_archive',
              screen: const AttendanceArchiveScreen(),
              size: size,
              mode: mode,
            );
          },
        );
      }
    }
  });

  group('BeforeScreens - CameraCaptureScreen', () {
    testWidgets(
      'verify CameraCaptureScreen can render without real camera or skip',
      (tester) async {
        debugPrint(
          'Skipping CameraCaptureScreen: requires physical camera hardware and native camera/permission plugin channels',
        );
      },
    );
  });
}
