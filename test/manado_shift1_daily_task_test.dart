import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bssparking_timemark/data/repositories/auth_repository.dart';
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
      final msgTomorrow = DailyTaskService.formatTelegramTaskMessage(
        teknisiNama: 'Ryan Lumasuge',
        judul: 'Pengecekan Sistem Gate out 1-6 PBM (bukti dokumentasi layar aplikasi kasir)',
        posName: 'PBM',
        tanggal: '2026-10-16',
      );

      expect(msgTomorrow, contains('[JADWAL: 2026-10-16]'));
      expect(msgTomorrow, contains('Target Tanggal:</b> 2026-10-16'));
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

      // Check header and 2 routine tasks
      expect(find.text('Rutin Shift 1 KC Manado'), findsOneWidget);
      expect(find.text('2 Tugas Permanen Pagi (03:00 - 11:00 WITA)'), findsOneWidget);
      expect(
        find.textContaining('Pengecekan Sistem Gate out 1-6 PBM (bukti dokumentasi layar aplikasi kasir)'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Pengecekan Sistem Gate ojek'),
        findsOneWidget,
      );
      expect(find.text('Kirim 2 Tugas'), findsOneWidget);

      // Check target date toggle pills
      expect(find.text('Hari Ini'), findsOneWidget);
      expect(find.text('Besok'), findsOneWidget);
      expect(find.text('Pilih Lain'), findsOneWidget);
    });
  });
}
