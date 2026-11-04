import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bssparking_timemark/data/models/daily_task_model.dart';
import 'package:bssparking_timemark/data/repositories/auth_repository.dart';
import 'package:bssparking_timemark/data/services/absensi_setup_service.dart';
import 'package:bssparking_timemark/data/services/branch_service.dart';
import 'package:bssparking_timemark/data/services/daily_task_service.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';
import 'package:bssparking_timemark/features/daily_tasks/screens/spv_task_dispatcher_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    await BranchService.instance.setBranch(AppBranch.manado);
    await AuthRepository.instance.loginWithPassword(
      identity: 'farhan lakoro',
      password: 'flakoro05',
    );
  });

  group('Shift 1 KC Manado Routine & Target Date Tests', () {
    test('DailyTaskService formats Telegram alert with target date properly', () {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final tomorrowStr = '${tomorrow.year}-${tomorrow.month.toString().padLeft(2, '0')}-${tomorrow.day.toString().padLeft(2, '0')}';
      final msgTomorrow = DailyTaskService.formatTelegramTaskMessage(
        teknisiNama: 'Ryan Lumasuge',
        judul: 'Pengecekan Sistem Gate out 1-6 PBM (bukti dokumentasi layar aplikasi kasir)',
        posName: 'PBM',
        tanggal: tomorrowStr,
      );

      expect(msgTomorrow, contains('[JADWAL: $tomorrowStr]'));
      expect(msgTomorrow, contains('Target Tanggal:</b> $tomorrowStr'));
      expect(msgTomorrow, contains('Ryan Lumasuge'));
      expect(msgTomorrow, contains('PBM'));
    });

    testWidgets('SpvTaskDispatcherScreen renders Shift 1 Manado 2 routine tasks and date toggle', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SpvTaskDispatcherScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Buka bottom sheet via FAB Buat Tugas
      await tester.tap(find.text('Buat Tugas'));
      await tester.pumpAndSettle();

      // Tab kategori paling atas: Rutin / Maintenance / Tugas Khusus
      expect(find.text('Rutin'), findsOneWidget);
      expect(find.text('Maintenance'), findsOneWidget);
      expect(find.text('Tugas Khusus'), findsOneWidget);

      // Buka tab Rutin, isinya 2 tugas rutin shift 1
      await tester.tap(find.text('Rutin'));
      await tester.pumpAndSettle();

      expect(find.text('TUGAS RUTIN SHIFT 1 KC MANADO'), findsOneWidget);
      expect(
        find.textContaining('Pengecekan Sistem Gate out 1-6 PBM (bukti dokumentasi layar aplikasi kasir)'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Pengecekan Sistem Gate ojek'),
        findsOneWidget,
      );
      expect(find.text('Tugaskan 2 Rutin Shift 1'), findsOneWidget);

      // Target tanggal berupa baris field
      expect(find.text('TANGGAL PENUGASAN'), findsOneWidget);
    });
  });

  group('Shift 1.1 KC Manado (06:00 - 14:00)', () {
    const shift11 = 'Shift 1.1 (06:00 - 14:00)';

    test('Shift 1.1 hanya ada di cabang Manado, bukan Bali', () async {
      expect(BranchService.instance.getShifts(branch: AppBranch.manado), contains(shift11));
      expect(BranchService.instance.getShifts(branch: AppBranch.bali), isNot(contains(shift11)));
    });

    test('Shift 1.1 dihitung shift penuh dengan jam pulang 14:00', () {
      expect(
        AbsensiSetupService.getMinimumWorkDuration(shift11),
        const Duration(hours: 8),
      );
      expect(AbsensiSetupService.autoDetectJamPulang(shift: shift11), '14:00');
    });

    test('Format briefing tim menampilkan grup Shift 1.1', () {
      final tasks = [
        DailyTaskModel(
          id: 't1',
          tanggal: '2026-10-17',
          teknisiId: 'ryan',
          teknisiNama: 'Ryan Lumasuge',
          posName: 'PBM',
          posTag: 'PBM',
          judul: 'Pengecekan gate in/out PBM',
        ),
      ];

      final briefing = DailyTaskService.formatMorningDispatchReport(
        tasks: tasks,
        techShiftMap: const {'Ryan Lumasuge': shift11},
        branch: AppBranch.manado,
      );

      expect(briefing, contains('$shift11 : Ryan Lumasuge'));
      expect(briefing, contains('1. Pengecekan gate in/out PBM'));
    });
  });
}
