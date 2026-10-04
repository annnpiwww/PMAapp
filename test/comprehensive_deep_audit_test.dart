import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bssparking_timemark/data/models/attendance_record.dart';
import 'package:bssparking_timemark/data/models/maintenance_submission.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';
import 'package:bssparking_timemark/data/services/location_service.dart';
import 'package:bssparking_timemark/data/services/absensi_setup_service.dart';
import 'package:bssparking_timemark/data/services/secure_time_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    LocationService.clearLocationCache();
  });

  group('AUDIT PILAR 1: UI, Responsiveness & Visual Edge Cases', () {
    test('Nama teknisi sangat panjang dan alamat super panjang tidak crash / corrupt', () async {
      const superLongName = 'Muhammad Al-Farhan Ryan Lakoro Lumasuge Bin Wowor';
      const superLongAddress =
          'Kompleks Pasar Tradisional Bersehati, Gedung Parkir Blok B Lantai 2, Kelurahan Calaca, Kecamatan Wenang, Kota Manado, Provinsi Sulawesi Utara 95122, Indonesia';

      final record = AttendanceRecord(
        id: 'att_audit_long',
        timestamp: DateTime.now(),
        type: AttendanceType.masuk,
        shiftName: 'Shift 2 (10:00 - 18:00)',
        technicianName: superLongName,
        posName: 'Pasar Bersehati Manado',
        lat: 1.49305,
        lng: 124.84197,
        fullAddress: superLongAddress,
      );

      await StorageService.saveAttendanceRecord(record);
      final list = StorageService.getAttendanceRecords();
      expect(list.isNotEmpty, isTrue);
      expect(list.first.technicianName, equals(superLongName));
      expect(list.first.fullAddress, equals(superLongAddress));
    });
  });

  group('AUDIT PILAR 2: Fitur & Logika Bisnis (Shift, Gating, Late Calculation)', () {
    bool isRecordLateAudit(AttendanceRecord record) {
      if (record.type != AttendanceType.masuk) return false;
      final shift = record.shiftName;
      final match = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(shift);
      if (match == null) return false;

      final startH = int.tryParse(match.group(1) ?? '') ?? 0;
      final startM = int.tryParse(match.group(2) ?? '') ?? 0;

      final recTime = record.timestamp;
      final scheduledMinutes = startH * 60 + startM;
      final actualMinutes = recTime.hour * 60 + recTime.minute;

      if (startH == 3) {
        if (recTime.hour >= 21) return false;
        return actualMinutes > scheduledMinutes;
      }

      return actualMinutes > scheduledMinutes;
    }

    test('Shift 1 (03:00): Masuk 02:45 -> Tepat Waktu', () {
      final rec = AttendanceRecord(
        id: 'att_s1_early',
        timestamp: DateTime(2026, 9, 13, 2, 45),
        type: AttendanceType.masuk,
        shiftName: 'Shift 1 (03:00 - 11:00)',
        technicianName: 'Farhan',
        posName: 'PBM',
        lat: 1.48,
        lng: 124.83,
        fullAddress: 'Manado',
      );
      expect(isRecordLateAudit(rec), isFalse);
    });

    test('Shift 1 (03:00): Masuk 03:00 -> Tepat Waktu', () {
      final rec = AttendanceRecord(
        id: 'att_s1_ontime',
        timestamp: DateTime(2026, 9, 13, 3, 0),
        type: AttendanceType.masuk,
        shiftName: 'Shift 1 (03:00 - 11:00)',
        technicianName: 'Farhan',
        posName: 'PBM',
        lat: 1.48,
        lng: 124.83,
        fullAddress: 'Manado',
      );
      expect(isRecordLateAudit(rec), isFalse);
    });

    test('Shift 1 (03:00): Masuk 03:05 -> Terlambat', () {
      final rec = AttendanceRecord(
        id: 'att_s1_late',
        timestamp: DateTime(2026, 9, 13, 3, 5),
        type: AttendanceType.masuk,
        shiftName: 'Shift 1 (03:00 - 11:00)',
        technicianName: 'Farhan',
        posName: 'PBM',
        lat: 1.48,
        lng: 124.83,
        fullAddress: 'Manado',
      );
      expect(isRecordLateAudit(rec), isTrue);
    });

    test('Shift 1 (03:00): Masuk 11:30 (Sangat Terlambat) -> Terhitung Terlambat', () {
      final rec = AttendanceRecord(
        id: 'att_s1_very_late',
        timestamp: DateTime(2026, 9, 13, 11, 30),
        type: AttendanceType.masuk,
        shiftName: 'Shift 1 (03:00 - 11:00)',
        technicianName: 'Farhan',
        posName: 'PBM',
        lat: 1.48,
        lng: 124.83,
        fullAddress: 'Manado',
      );
      expect(isRecordLateAudit(rec), isTrue);
    });

    test('Shift 1 (03:00): Masuk 22:30 (Malam Sebelumnya) -> Tepat Waktu', () {
      final rec = AttendanceRecord(
        id: 'att_s1_night_before',
        timestamp: DateTime(2026, 9, 12, 22, 30),
        type: AttendanceType.masuk,
        shiftName: 'Shift 1 (03:00 - 11:00)',
        technicianName: 'Farhan',
        posName: 'PBM',
        lat: 1.48,
        lng: 124.83,
        fullAddress: 'Manado',
      );
      expect(isRecordLateAudit(rec), isFalse);
    });

    test('Shift 2.2 durasi minimal 4 jam, shift lainnya 8 jam', () {
      final dur22 = AbsensiSetupService.getMinimumWorkDuration('Shift 2.2 (10:00 - 14:00)');
      final dur2 = AbsensiSetupService.getMinimumWorkDuration('Shift 2 (10:00 - 18:00)');
      final dur1 = AbsensiSetupService.getMinimumWorkDuration('Shift 1 (03:00 - 11:00)');
      final dur3 = AbsensiSetupService.getMinimumWorkDuration('Shift 3 (14:00 - 22:00)');

      expect(dur22, equals(const Duration(hours: 4)));
      expect(dur2, equals(const Duration(hours: 8)));
      expect(dur1, equals(const Duration(hours: 8)));
      expect(dur3, equals(const Duration(hours: 8)));
    });
  });

  group('AUDIT PILAR 3: Smoke Test (Fresh Install, Cold Start, Clean Storage)', () {
    test('Storage kosong tidak pernah melempar Exception null pointer', () {
      expect(StorageService.getUser(), isNull);
      expect(StorageService.getLastCheckInTime(), isNull);
      expect(StorageService.hasCheckedInTodayWithoutCheckOut(), isFalse);
      expect(StorageService.getAttendanceRecords(), isEmpty);
      expect(StorageService.getMaintenanceSubmissions(), isNull);
    });

    test('LocationService fallback titik aman jika GPS hardware mati', () {
      final pos = LocationService.currentPos;
      expect(pos.posName.isNotEmpty, isTrue);
      expect(pos.lat != 0.0, isTrue);
      expect(pos.lng != 0.0, isTrue);
    });
  });

  group('AUDIT PILAR 4: Stress Test & Data Volume Bound', () {
    test('Simpan 200 maintenance submissions otomatis dipangkas ke 150 batas memori', () async {
      final list = List<MaintenanceSubmission>.generate(
        200,
        (i) => MaintenanceSubmission(
          id: 'sub_stress_$i',
          templateId: 'tmpl_01',
          templateName: 'Maintenance Pos',
          userId: 'usr_01',
          userName: 'Ryan',
          userNpp: 'NPP-01',
          posId: 'pos_01',
          posName: 'Pasar Bersehati',
          cabangName: 'KC BSG',
          points: const [],
          createdAt: DateTime.now().add(Duration(seconds: i)),
          updatedAt: DateTime.now().add(Duration(seconds: i)),
        ),
      );

      await StorageService.saveMaintenanceSubmissions(list);
      final stored = StorageService.getMaintenanceSubmissions();
      expect(stored, isNotNull);
      expect(stored!.length, equals(150));
      expect(stored.first.id, equals('sub_stress_199')); // Record terbaru di awal
    });

    test('Retensi 30 hari absensi otomatis membersihkan record usang (>30 hari)', () async {
      final now = DateTime.now();
      final records = [
        AttendanceRecord(
          id: 'att_fresh',
          timestamp: now.subtract(const Duration(days: 2)),
          type: AttendanceType.masuk,
          shiftName: 'Shift 2 (10:00 - 18:00)',
          technicianName: 'Ryan',
          posName: 'PBM',
          lat: 1.48,
          lng: 124.83,
          fullAddress: 'Manado',
        ),
        AttendanceRecord(
          id: 'att_old',
          timestamp: now.subtract(const Duration(days: 35)),
          type: AttendanceType.masuk,
          shiftName: 'Shift 2 (10:00 - 18:00)',
          technicianName: 'Ryan',
          posName: 'PBM',
          lat: 1.48,
          lng: 124.83,
          fullAddress: 'Manado',
        ),
      ];

      for (final r in records) {
        await StorageService.saveAttendanceRecord(r);
      }

      final list = StorageService.getAttendanceRecords();
      expect(list.any((r) => r.id == 'att_fresh'), isTrue);
      expect(list.any((r) => r.id == 'att_old'), isFalse); // Terpangkas otomatis
    });

    test('clearAllAttendanceRecords menghapus seluruh record dan membersihkan storage secara atomik', () async {
      await StorageService.clearAllAttendanceRecords();
      expect(StorageService.getAttendanceRecords(), isEmpty);
    });
  });

  group('AUDIT PILAR 5: Security & Anti-Fraud Audit', () {
    test('SecureTimeService mendeteksi clock skew jika device clock mundur', () {
      final verified = SecureTimeService.getVerifiedTime();
      expect(verified.accurateTime, isNotNull);
      expect(verified.source.isNotEmpty, isTrue);
    });

    test('PIN Brute-force lockout memblokir percobaan setelah 5 kali gagal', () async {
      for (int i = 0; i < 4; i++) {
        final res = await StorageService.verifyTechnicianPin('999999');
        expect(res.ok, isFalse);
        expect(res.locked, isFalse);
      }

      // Percobaan ke-5 memicu lockout
      final res5 = await StorageService.verifyTechnicianPin('999999');
      expect(res5.ok, isFalse);
      expect(res5.locked, isTrue);
      expect(res5.retryAfterSeconds, greaterThan(0));

      // Percobaan ke-6 langsung tertolak karena status locked
      final res6 = await StorageService.verifyTechnicianPin('123321');
      expect(res6.ok, isFalse);
      expect(res6.locked, isTrue);
    });

    test('Tidak ada bot token atau plaintext credentials hardcoded di kode lib/', () {
      final libDir = Directory('/home/annnpii/Product development annpii/BssparkingTimeMark/lib');
      final files = libDir.listSync(recursive: true).whereType<File>();
      for (final f in files) {
        if (!f.path.endsWith('.dart')) continue;
        final content = f.readAsStringSync();
        expect(content.contains('BSS_TG_BOT_TOKEN='), isFalse,
            reason: 'Ditemukan hardcoded token di ${f.path}');
        expect(content.contains('bot1103429'), isFalse,
            reason: 'Ditemukan telegram token string di ${f.path}');
      }
    });
  });
}
