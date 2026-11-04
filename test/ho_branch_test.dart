import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bssparking_timemark/data/repositories/auth_repository.dart';
import 'package:bssparking_timemark/data/services/absensi_setup_service.dart';
import 'package:bssparking_timemark/data/services/branch_service.dart';
import 'package:bssparking_timemark/data/services/daily_task_service.dart';
import 'package:bssparking_timemark/data/services/location_service.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';

/// Cabang ketiga (HO Makassar): 10 teknisi, 11 shift, 12 lokasi visit,
/// tabel `daily_tasks_ho`, dan lokasi yang tidak bocor antar cabang.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    BranchService.instance.resetForTesting();
    LocationService.resetForTesting();
  });

  tearDown(() => BranchService.instance.resetForTesting());

  test('identitas cabang HO', () async {
    await BranchService.instance.setBranch(AppBranch.ho);
    final b = BranchService.instance.currentBranch;
    expect(b.code, 'HO');
    expect(b.name, 'HO Makassar');
    expect(b.defaultSpv, 'ADI SUPRIADI');
    expect(b.defaultLocationTag, 'HO');
    expect(StorageService.getString('active_branch_code'), 'HO');
    expect(BranchService.parseBranchFromCode('HO'), AppBranch.ho);
    expect(BranchService.parseBranchFromName('HO Makassar'), AppBranch.ho);
  });

  test('10 teknisi & 11 shift HO', () async {
    await BranchService.instance.setBranch(AppBranch.ho);
    final techs = BranchService.instance.getTechnicians();
    expect(techs.length, 10);
    expect(techs, contains('AHMAD KHAELANI'));
    expect(techs, contains('RIYAN ADNAN'));

    final shifts = BranchService.instance.getShifts();
    expect(shifts.length, 11);
    expect(shifts, contains('Shift 1 (08.00 - 16.00)'));
    expect(shifts, contains('HO.1 (08.30 - 12.30)'));
    expect(shifts, contains('GMM 2 (15.00 - 23.00)'));
    expect(shifts, contains('JP (17.00 - 01.00)'));
    expect(shifts.toSet().length, 11, reason: 'label shift HO harus unik');
  });

  test('12 tag lokasi visit HO', () async {
    await BranchService.instance.setBranch(AppBranch.ho);
    final tags = BranchService.instance.getLocationTags();
    expect(tags.length, 12);
    expect(tags, contains('TBP'));
    expect(tags, contains('RSWS'));
    expect(tags, contains('PJT'));
    // Tag Bali tidak boleh ikut berubah saat HO dapat tag baru
    expect(BranchService.instance.getLocationTags(branch: AppBranch.bali), contains('TBB'));
  });

  test('tugas HO memakai tabel & cache terpisah', () async {
    await BranchService.instance.setBranch(AppBranch.ho);
    expect(DailyTaskService.tasksTable, 'daily_tasks_ho');
    expect(DailyTaskService.localCacheKey, 'cached_daily_tasks_ho');
  });

  test('lokasi visit HO tidak bocor ke cabang lain dan sebaliknya', () async {
    await BranchService.instance.setBranch(AppBranch.ho);
    final hoList = LocationService.availablePosList;
    expect(hoList.length, 12);
    expect(hoList.map((e) => e.locationTag), contains('TBP'));
    expect(hoList.any((e) => e.locationTag == 'PBM'), isFalse);

    BranchService.instance.resetForTesting();
    final manadoTags = LocationService.availablePosList.map((e) => e.locationTag).toList();
    expect(manadoTags, contains('PBM'));
    expect(manadoTags, isNot(contains('TBP')));

    await BranchService.instance.setBranch(AppBranch.bali);
    final baliList = LocationService.availablePosList;
    expect(baliList.length, 15);
    expect(baliList.any((e) => e.posId.startsWith('POS-HO-')), isFalse,
        reason: 'seed HO tidak boleh bocor ke Bali meski tag mirip');
  });

  test('auto-detect shift & jam pulang HO ikut jam rentang shift', () async {
    await BranchService.instance.setBranch(AppBranch.ho);
    expect(
      AbsensiSetupService.autoDetectShift(DateTime(2026, 10, 19, 10, 0)),
      'GMM 1 (09.00 - 17.00)',
    );
    expect(
      AbsensiSetupService.autoDetectShift(DateTime(2026, 10, 19, 18, 30)),
      'JP (17.00 - 01.00)',
    );
    expect(
      AbsensiSetupService.autoDetectShift(DateTime(2026, 10, 19, 3, 0)),
      'Shift 3 (24.00 - 08.00)',
    );
    expect(AbsensiSetupService.autoDetectJamPulang(shift: 'Shift 1 (08.00 - 16.00)'), '16:00');
    expect(AbsensiSetupService.autoDetectJamPulang(shift: 'Shift 3 (24.00 - 08.00)'), '08:00');
    expect(AbsensiSetupService.autoDetectJamPulang(shift: 'HO.1 (08.30 - 12.30)'), '12:30');
  });

  test('shift HO dipilih manual tetap valid, shift cabang lain ditolak', () async {
    await BranchService.instance.setBranch(AppBranch.ho);
    expect(BranchService.isShiftOfOtherBranch('Shift 1 (03:00 - 11:00)'), isTrue);
    expect(BranchService.isShiftOfOtherBranch('Shift 1 (08.00 - 16.00)'), isFalse);
  });

  test('determineBranch mengenali personil & cabang HO Makassar', () {
    expect(BranchService.determineBranch(email: 'ahmad@pma.com', name: 'AHMAD KHAELANI'), AppBranch.ho);
    expect(BranchService.determineBranch(email: 'riyan@pma.com', name: 'RIYAN ADNAN'), AppBranch.ho);
    expect(BranchService.determineBranch(cabang: 'HO Makassar'), AppBranch.ho);
    // Nama lama tetap di cabangnya masing-masing
    expect(BranchService.determineBranch(email: 'toro@pma.com', name: 'Alif Candra Triantoro'), AppBranch.bali);
    expect(BranchService.determineBranch(email: 'ryan@pma.com', name: 'Ryan Lumasuge'), AppBranch.manado);
    // 'Yohana' tidak boleh dianggap cabang HO
    expect(BranchService.determineBranch(email: 'indra@pma.com', name: 'Indra Yohana'), AppBranch.bali);
  });

  test('login HO tidak menyeret akun Bali yang namanya mirip', () async {
    // 'adi' dulu bisa cocok ke ADITYA (Bali) lewat potongan nama
    expect(await AuthRepository.instance.loginWithPassword(identity: 'adi', password: 'spvho'), isTrue);
    expect(AuthRepository.instance.currentUser?.nama, 'ADI SUPRIADI');
    expect(BranchService.instance.currentBranch, AppBranch.ho);

    expect(await AuthRepository.instance.loginWithPassword(identity: 'alifahmad', password: 'teknisi123'), isTrue);
    expect(AuthRepository.instance.currentUser?.nama, 'ALIF AHMAD MAULANA');
    expect(BranchService.instance.currentBranch, AppBranch.ho);

    // 'alif' ambigu (Alif Candra/Bali vs Alif Ahmad/HO) -> ditolak, bukan salah cabang
    expect(await AuthRepository.instance.loginWithPassword(identity: 'alif', password: 'teknisi123'), isFalse);
    // Nama lengkap tetap bisa
    expect(await AuthRepository.instance.loginWithPassword(identity: 'alif candra triantoro', password: 'teknisi123'), isTrue);
    expect(BranchService.instance.currentBranch, AppBranch.bali);
  });
}
