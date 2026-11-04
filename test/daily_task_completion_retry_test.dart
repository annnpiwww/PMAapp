import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bssparking_timemark/data/services/branch_service.dart';
import 'package:bssparking_timemark/data/services/daily_task_service.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';

/// Regresi kasus Junifer (19 Okt 2026): tugas tampil selesai di HP teknisi tapi
/// tetap pending di SPV karena PATCH ke Supabase gagal tanpa jejak.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    BranchService.instance.resetForTesting();
    // Alamat tidak bisa dijangkau -> semua request Supabase gagal.
    StorageService.setString('custom_supabase_url', 'https://127.0.0.1:9');
  });

  tearDown(() => BranchService.instance.resetForTesting());

  test('penyelesaian gagal sync masuk antrean dan tidak hilang saat flush gagal', () async {
    final ok = await DailyTaskService.completeTask(
      taskId: 'task_uji_retry',
      jamSelesai: '16:25',
      catatan: 'uji antrean',
    );
    expect(ok, isFalse);

    final raw = StorageService.getString('pending_task_completions') ?? '';
    expect(raw, contains('task_uji_retry'));
    expect(raw, contains('16:25'));

    // Masih offline: entri harus tetap tersimpan untuk dicoba lagi nanti.
    expect(await DailyTaskService.flushPendingCompletions(), 0);
    expect(StorageService.getString('pending_task_completions'), contains('task_uji_retry'));
  });

  test('antrean kosong atau rusak tidak membuat crash', () async {
    expect(await DailyTaskService.flushPendingCompletions(), 0);

    StorageService.setString('pending_task_completions', 'bukan json');
    expect(await DailyTaskService.flushPendingCompletions(), 0);
  });
}
