import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bssparking_timemark/data/services/branch_service.dart';
import 'package:bssparking_timemark/data/services/daily_task_service.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';

/// Tugas harian dipisah per tabel cabang supaya data KC Manado dan KC Bali
/// tidak tergabung di satu tabel Supabase.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    BranchService.instance.resetForTesting();
  });

  tearDown(() {
    BranchService.instance.resetForTesting();
  });

  test('cabang Manado menulis ke daily_tasks_manado', () {
    expect(BranchService.instance.currentBranch, AppBranch.manado);
    expect(DailyTaskService.tasksTable, 'daily_tasks_manado');
  });

  test('cabang Bali menulis ke daily_tasks_bali', () async {
    await BranchService.instance.setBranch(AppBranch.bali);
    expect(DailyTaskService.tasksTable, 'daily_tasks_bali');
  });

  test('cache lokal tidak dibagi antar cabang', () async {
    expect(DailyTaskService.localCacheKey, 'cached_daily_tasks_manado');
    await BranchService.instance.setBranch(AppBranch.bali);
    expect(DailyTaskService.localCacheKey, 'cached_daily_tasks_bali');
  });

  test('ganti cabang langsung ganti tabel, tidak ada tabel bersama', () async {
    final manado = DailyTaskService.tasksTable;
    await BranchService.instance.setBranch(AppBranch.bali);
    final bali = DailyTaskService.tasksTable;
    expect(manado, isNot(bali));
    expect({manado, bali}, {'daily_tasks_manado', 'daily_tasks_bali'});
  });
}
