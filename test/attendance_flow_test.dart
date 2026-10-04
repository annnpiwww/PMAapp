import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bssparking_timemark/data/services/absensi_setup_service.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';
import 'package:bssparking_timemark/data/models/submission_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  test('Auto-detect shift returns valid shift string with 10-min buffer', () {
    // 09:49 -> Shift 1
    final beforeShift2 = DateTime(2026, 9, 14, 9, 49);
    expect(AbsensiSetupService.autoDetectShift(beforeShift2), contains('Shift 1'));

    // 09:50 -> Automatically Shift 2
    final atShift2Buffer = DateTime(2026, 9, 14, 9, 50);
    expect(AbsensiSetupService.autoDetectShift(atShift2Buffer), contains('Shift 2'));
    expect(AbsensiSetupService.autoDetectShift(atShift2Buffer), contains('10:00 - 18:00'));

    // 13:49 -> Still Shift 2
    final beforeShift3 = DateTime(2026, 9, 14, 13, 49);
    expect(AbsensiSetupService.autoDetectShift(beforeShift3), contains('Shift 2'));

    // 13:50 -> Automatically Shift 3
    final atShift3Buffer = DateTime(2026, 9, 14, 13, 50);
    expect(AbsensiSetupService.autoDetectShift(atShift3Buffer), contains('Shift 3'));
    expect(AbsensiSetupService.autoDetectShift(atShift3Buffer), contains('14:00 - 22:00'));

    // 21:50 -> Next Shift 1
    final atShift1Night = DateTime(2026, 9, 14, 21, 55);
    expect(AbsensiSetupService.autoDetectShift(atShift1Night), contains('Shift 1'));
  });

  test('Auto-pulang eligibility requires jam pulang passed AND min work duration', () {
    const shift2 = 'Shift 2 (10:00 - 18:00)';
    final checkInShift2 = DateTime(2026, 9, 14, 10, 0);

    // Midday (4 hours in, jam pulang 18:00 not passed) -> false
    expect(
      AbsensiSetupService.isEligibleForAutoPulang(
        shift: shift2,
        checkInTime: checkInShift2,
        currentTime: DateTime(2026, 9, 14, 14, 0),
      ),
      isFalse,
    );

    // 17:59 (7h 59m in, jam pulang not passed) -> false
    expect(
      AbsensiSetupService.isEligibleForAutoPulang(
        shift: shift2,
        checkInTime: checkInShift2,
        currentTime: DateTime(2026, 9, 14, 17, 59),
      ),
      isFalse,
    );

    // 18:00 (8h in, jam pulang 18:00 reached) -> true!
    expect(
      AbsensiSetupService.isEligibleForAutoPulang(
        shift: shift2,
        checkInTime: checkInShift2,
        currentTime: DateTime(2026, 9, 14, 18, 0),
      ),
      isTrue,
    );

    // Late check-in: 10:30 on Shift 2 (10:00 - 18:00).
    final checkInLate = DateTime(2026, 9, 14, 10, 30);
    // At 17:30 (before 18:00 & only 7h) -> Early departure blocked -> false!
    expect(
      AbsensiSetupService.isEligibleForAutoPulang(
        shift: shift2,
        checkInTime: checkInLate,
        currentTime: DateTime(2026, 9, 14, 17, 30),
      ),
      isFalse,
    );
    // At 18:00 (jam shift 18:00 reached -> shift handover allowed even if late -> true!)
    expect(
      AbsensiSetupService.isEligibleForAutoPulang(
        shift: shift2,
        checkInTime: checkInLate,
        currentTime: DateTime(2026, 9, 14, 18, 0),
      ),
      isTrue,
    );
    // At 18:30 (8h completed) -> true!
    expect(
      AbsensiSetupService.isEligibleForAutoPulang(
        shift: shift2,
        checkInTime: checkInLate,
        currentTime: DateTime(2026, 9, 14, 18, 30),
      ),
      isTrue,
    );

    // Kasus Spesifik: Shift 1 (03:00 - 11:00) terlambat masuk jam 06:00
    const shift1 = 'Shift 1 (03:00 - 11:00)';
    final checkInShift1Late = DateTime(2026, 9, 14, 6, 0);
    // Jam 10:00 (baru 4 jam & shift belum selesai) -> false
    expect(
      AbsensiSetupService.isEligibleForAutoPulang(
        shift: shift1,
        checkInTime: checkInShift1Late,
        currentTime: DateTime(2026, 9, 14, 10, 0),
      ),
      isFalse,
    );
    // Jam 11:00 (shift 1 selesai -> bisa pulang untuk handover pos -> true!)
    expect(
      AbsensiSetupService.isEligibleForAutoPulang(
        shift: shift1,
        checkInTime: checkInShift1Late,
        currentTime: DateTime(2026, 9, 14, 11, 0),
      ),
      isTrue,
    );

    // Kasus Spesifik: Shift 3 (14:00 - 22:00) terlambat masuk jam 16:00
    const shift3 = 'Shift 3 (14:00 - 22:00)';
    final checkInShift3Late = DateTime(2026, 9, 14, 16, 0);
    // Jam 21:30 (baru 5.5 jam & shift belum selesai) -> false
    expect(
      AbsensiSetupService.isEligibleForAutoPulang(
        shift: shift3,
        checkInTime: checkInShift3Late,
        currentTime: DateTime(2026, 9, 14, 21, 30),
      ),
      isFalse,
    );
    // Jam 22:00 (shift 3 selesai -> bisa pulang -> true!)
    expect(
      AbsensiSetupService.isEligibleForAutoPulang(
        shift: shift3,
        checkInTime: checkInShift3Late,
        currentTime: DateTime(2026, 9, 14, 22, 0),
      ),
      isTrue,
    );

    // Shift 2.2 (10:00 - 14:00): Requires 4 hours
    const shift2_2 = 'Shift 2.2 (10:00 - 14:00)';
    final checkIn2_2 = DateTime(2026, 9, 14, 10, 0);

    // At 13:50 (3h 50m in) -> false
    expect(
      AbsensiSetupService.isEligibleForAutoPulang(
        shift: shift2_2,
        checkInTime: checkIn2_2,
        currentTime: DateTime(2026, 9, 14, 13, 50),
      ),
      isFalse,
    );

    // At 14:00 (4h completed & 14:00 reached) -> true!
    expect(
      AbsensiSetupService.isEligibleForAutoPulang(
        shift: shift2_2,
        checkInTime: checkIn2_2,
        currentTime: DateTime(2026, 9, 14, 14, 0),
      ),
      isTrue,
    );
  });

  test('Technician name sync persists to StorageService', () async {
    await StorageService.saveLastTechnicianName('Farhan Lakoro');
    expect(StorageService.getLastTechnicianName(), equals('Farhan Lakoro'));
  });

  test('Check-in tracking persists and can be cleared', () async {
    final now = DateTime.now().subtract(const Duration(hours: 1));
    await StorageService.saveLastCheckInTime(now);
    expect(StorageService.getLastCheckInTime(), equals(now));

    await StorageService.clearLastCheckInTime();
    expect(StorageService.getLastCheckInTime(), isNull);
  });

  test('Attendance transition Masuk -> Pulang -> Masuk updates state properly', () async {
    final setup = AbsensiSetupService.instance;
    setup.updateTipe('Masuk');
    expect(setup.tipeLaporan, equals('Masuk'));

    // Simulate checkin
    final checkOutTime = DateTime.now();
    final checkInTime = checkOutTime.subtract(const Duration(hours: 8, minutes: 30));
    await StorageService.saveLastCheckInTime(checkInTime);
    setup.updateTipe('Pulang');
    expect(setup.tipeLaporan, equals('Pulang'));

    // Duration calculation
    final diff = checkOutTime.difference(StorageService.getLastCheckInTime()!);
    expect(diff.inHours, equals(8));
    expect(diff.inMinutes.remainder(60), equals(30));

    // Simulate checkout
    await StorageService.clearLastCheckInTime();
    setup.updateTipe('Masuk');
    expect(setup.tipeLaporan, equals('Masuk'));
    expect(StorageService.getLastCheckInTime(), isNull);
  });

  test('Auto-recovery restores check-in from previous submissions without explicit key', () async {
    // Simulate user who checked in on older version (has submission, but no keyLastCheckInTime)
    await StorageService.clearLastCheckInTime();
    expect(StorageService.getLastCheckInTime(), isNull);

    final checkInTime = DateTime.now().subtract(const Duration(hours: 4));
    final mockSub = SubmissionModel(
      id: 'mock_legacy_1',
      templateId: 'tpl_absensi_teknisi',
      templateName: 'Absensi Teknisi',
      userId: 'usr_1',
      userName: 'Farhan Lakoro',
      userNpp: 'BSS-001',
      posId: 'pos_1',
      posName: 'Pos 1',
      cabangName: 'PBM',
      timestampCapture: checkInTime,
      kodeVerifikasi: 'VERIF-123',
      status: VerificationStatus.sesuai,
      alasanAI: 'Seragam lengkap',
      poinGagal: [],
      poinLolos: [],
      createdAt: checkInTime,
      tipeLaporan: 'Masuk',
    );
    await StorageService.saveSubmissions([mockSub]);

    // Should automatically detect active check-in today
    expect(StorageService.hasCheckedInTodayWithoutCheckOut(), isTrue);

    // getLastCheckInTime should recover the timestamp
    final recovered = StorageService.getLastCheckInTime();
    expect(recovered, isNotNull);
    expect(recovered!.difference(checkInTime).inSeconds.abs(), lessThanOrEqualTo(1));
  });

  test('Daily job & handover gating blocks pulang until completed', () async {
    final setup = AbsensiSetupService.instance;
    setup.updateTipe('Pulang');
    setup.updateNextShift('-');
    setup.updatePekerjaanSelesai('-');

    // Gating check: Pulang mode requires daily report
    expect(setup.isDailyHandoverComplete(), isFalse);

    // Simulate filling DailyPulangBottomSheet
    setup.updateNextShift('Ryan Lumasuge');
    setup.updatePekerjaanSelesai('1. Pembersihan printer tiket\n2. Kalibrasi sensor loop');
    setup.updatePekerjaanBelum('-');
    await StorageService.markDailyReportCompletedToday();

    // Now gating passes
    expect(setup.isDailyHandoverComplete(), isTrue);
    expect(StorageService.isDailyReportCompletedToday(), isTrue);

    // Formatted WhatsApp report includes next shift & tasks
    final shareText = '''Selamat Sore

Izin Update Laporan Jadwal Pulang Technical Support Staff

IT Support : Alessandro Sulistyo
Lokasi Standby : PBM
Jadwal Shift : Shift 2 (10:00 - 18:00)
IT Support Shift Selanjutnya : ${setup.shiftSelanjutnya}

List Pekerjaan yang Selesai :
${setup.pekerjaanSelesai}

List Pekerjaan yang Belum Selesai :
${setup.pekerjaanBelum}

Terima Kasih''';

    expect(shareText, contains('IT Support Shift Selanjutnya : Ryan Lumasuge'));
    expect(shareText, contains('1. Pembersihan printer tiket'));
    expect(shareText, contains('2. Kalibrasi sensor loop'));
  });
}
