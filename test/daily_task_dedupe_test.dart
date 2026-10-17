import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bssparking_timemark/data/services/daily_task_service.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';

/// Anti-duplikat: tugas identik (tanggal + teknisi + judul + pos) hanya boleh
/// lahir sekali, walau tombol dispatch tertekan berkali-kali atau antrean
/// offline dikirim ulang.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  group('DailyTaskService Anti-Duplikat', () {
    test('createTask dengan kunci sama mengembalikan task yang sama, bukan membuat dobel', () async {
      final first = await DailyTaskService.createTask(
        tanggal: '2026-10-17',
        teknisiNama: 'Ryan Lumasuge',
        posName: 'Pos Gate Utama',
        posTag: 'pos_1',
        judul: 'Uji Integrasi Supabase Cloud 24/7',
        deskripsi: 'Verifikasi migrasi',
        kategori: 'khusus',
      );

      final second = await DailyTaskService.createTask(
        tanggal: '2026-10-17',
        teknisiNama: 'Ryan Lumasuge',
        posName: 'Pos Gate Utama',
        posTag: 'pos_1',
        judul: 'Uji Integrasi Supabase Cloud 24/7',
        deskripsi: 'Verifikasi migrasi',
        kategori: 'khusus',
      );

      expect(first, isNotNull);
      expect(second, isNotNull);
      expect(second!.id, equals(first!.id));

      final cached = DailyTaskService.getCachedTasksLocally()
          .where((t) => t.judul == 'Uji Integrasi Supabase Cloud 24/7')
          .toList();
      expect(cached.length, equals(1));

      final queue = StorageService.getStringList('pending_daily_task_creations_v1');
      expect(queue?.length, equals(1));
    });

    test('judul atau pos berbeda tetap membuat tugas baru', () async {
      final a = await DailyTaskService.createTask(
        tanggal: '2026-10-17',
        teknisiNama: 'Ryan Lumasuge',
        posName: 'Pos Gate Utama',
        posTag: 'pos_1',
        judul: 'Pengecekan Gate Ojek',
      );
      final b = await DailyTaskService.createTask(
        tanggal: '2026-10-17',
        teknisiNama: 'Ryan Lumasuge',
        posName: 'Pos Gate Utama',
        posTag: 'pos_1',
        judul: 'Pengecekan Gate Out 1-6 PBM',
      );
      final c = await DailyTaskService.createTask(
        tanggal: '2026-10-17',
        teknisiNama: 'Ryan Lumasuge',
        posName: 'Pos PBM',
        posTag: 'pbm',
        judul: 'Pengecekan Gate Ojek',
      );
      final besok = await DailyTaskService.createTask(
        tanggal: '2026-10-18',
        teknisiNama: 'Ryan Lumasuge',
        posName: 'Pos Gate Utama',
        posTag: 'pos_1',
        judul: 'Pengecekan Gate Ojek',
      );

      final ids = {a!.id, b!.id, c!.id, besok!.id};
      expect(ids.length, equals(4));

      final queue = StorageService.getStringList('pending_daily_task_creations_v1');
      expect(queue?.length, equals(4));
    });
  });
}
