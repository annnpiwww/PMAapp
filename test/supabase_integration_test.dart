import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bssparking_timemark/data/repositories/auth_repository.dart';
import 'package:bssparking_timemark/data/services/daily_task_service.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';
import 'package:bssparking_timemark/data/models/user_model.dart';

class _RealHttpOverrides extends HttpOverrides {}

/// Test tulis ini nembak Supabase produksi (bikin row nyata di daily_tasks),
/// jadi default-nya dilewati agar `flutter test` tidak menumpuk task sampah.
const bool _allowLiveWrite = bool.fromEnvironment('ALLOW_LIVE_WRITE');

const String _liveWriteSkipReason =
    'Test ini menulis task nyata ke Supabase produksi. Jalankan dengan '
    '--dart-define=ALLOW_LIVE_WRITE=true bila memang perlu.';

/// Password SPV Farhan hanya ada di lokal/CI, tidak lagi di source code.
final String? _spvPassword = Platform.environment['SUPABASE_TEST_SPV_PASSWORD'];

const String _spvSkipReason =
    'Butuh password SPV nyata. Set env SUPABASE_TEST_SPV_PASSWORD untuk '
    'menjalankan test login online ini.';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = _RealHttpOverrides();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  group('Supabase Cloud Backend Integration Tests', () {
    test('Online login for SPV Farhan Lakoro against Supabase app_users table', () async {
      final success = await AuthRepository.instance.loginWithPassword(
        identity: 'farhan',
        password: _spvPassword!,
      );

      expect(success, isTrue);
      final user = AuthRepository.instance.currentUser;
      expect(user, isNotNull);
      expect(user!.nama, equals('Farhan Lakoro'));
      expect(user.role, equals(UserRole.supervisor));
      expect(user.email, contains('farhan'));
    }, skip: _spvPassword == null ? _spvSkipReason : false);

    test('Online login for SPV Farhan using full name "Farhan Lakoro"', () async {
      final success = await AuthRepository.instance.loginWithPassword(
        identity: 'Farhan Lakoro',
        password: _spvPassword!,
      );

      expect(success, isTrue);
      final user = AuthRepository.instance.currentUser;
      expect(user, isNotNull);
      expect(user!.nama, equals('Farhan Lakoro'));
      expect(user.role, equals(UserRole.supervisor));
    }, skip: _spvPassword == null ? _spvSkipReason : false);

    test('Online login for SPV Farhan using email "farhan@pma.com"', () async {
      final success = await AuthRepository.instance.loginWithPassword(
        identity: 'farhan@pma.com',
        password: _spvPassword!,
      );

      expect(success, isTrue);
      final user = AuthRepository.instance.currentUser;
      expect(user, isNotNull);
      expect(user!.nama, equals('Farhan Lakoro'));
      expect(user.role, equals(UserRole.supervisor));
    }, skip: _spvPassword == null ? _spvSkipReason : false);

    test('Online login for Teknisi Ryan Lumasuge against Supabase app_users table', () async {
      final success = await AuthRepository.instance.loginWithPassword(
        identity: 'ryan',
        password: 'teknisi123',
      );

      expect(success, isTrue);
      final user = AuthRepository.instance.currentUser;
      expect(user, isNotNull);
      expect(user!.nama, equals('Ryan Lumasuge'));
      expect(user.role, equals(UserRole.petugas));
    });

    test('Create, retrieve and complete task online via Supabase', () async {
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);

      // 1. Create task
      final created = await DailyTaskService.createTask(
        tanggal: todayStr,
        teknisiNama: 'Ryan Lumasuge',
        posName: 'Pos Gate Utama',
        posTag: 'pos_1',
        judul: 'Uji Integrasi Supabase Cloud 24/7',
        deskripsi: 'Verifikasi migrasi dari PocketBase ke Supabase',
        kategori: 'khusus',
      );

      expect(created, isNotNull);
      expect(created!.judul, equals('Uji Integrasi Supabase Cloud 24/7'));
      expect(created.teknisiNama, equals('Ryan Lumasuge'));

      // 2. Fetch tasks
      final tasks = await DailyTaskService.getAllTasksToday(todayStr);
      expect(tasks.any((t) => t.id == created.id), isTrue);

      // 3. Complete task
      final completed = await DailyTaskService.completeTask(
        taskId: created.id,
        jamSelesai: '13:00 WITA',
        catatan: 'Verifikasi sukses 100%',
      );
      expect(completed, isTrue);
    }, skip: _allowLiveWrite ? false : _liveWriteSkipReason);
  });
}
