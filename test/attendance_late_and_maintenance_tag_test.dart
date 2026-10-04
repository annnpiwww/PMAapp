import 'package:flutter_test/flutter_test.dart';
import 'package:bssparking_timemark/data/models/attendance_record.dart';
import 'package:bssparking_timemark/data/services/location_service.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  group('Logika Terlambat Absensi Shift Tests', () {
    bool isRecordLate(AttendanceRecord record) {
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
        if (recTime.hour >= 3 && recTime.hour < 11) {
          return (recTime.hour > 3) || (recTime.hour == 3 && recTime.minute > 0);
        }
        return false;
      }

      return actualMinutes > scheduledMinutes;
    }

    test('Shift 2 (10:00 - 18:00) masuk 10:07 terhitung TERLAMBAT', () {
      final rec = AttendanceRecord(
        id: 'att_1',
        timestamp: DateTime(2026, 9, 13, 10, 7),
        type: AttendanceType.masuk,
        shiftName: 'Shift 2 (10:00 - 18:00)',
        technicianName: 'Ryan Lumasuge',
        posName: 'Pasar Bersehati Manado',
        lat: 1.488,
        lng: 124.838,
        fullAddress: 'Manado',
      );
      expect(isRecordLate(rec), isTrue);
    });

    test('Shift 2 (10:00 - 18:00) masuk 09:50 terhitung TEPAT WAKTU', () {
      final rec = AttendanceRecord(
        id: 'att_2',
        timestamp: DateTime(2026, 9, 13, 9, 50),
        type: AttendanceType.masuk,
        shiftName: 'Shift 2 (10:00 - 18:00)',
        technicianName: 'Ryan Lumasuge',
        posName: 'Pasar Bersehati Manado',
        lat: 1.488,
        lng: 124.838,
        fullAddress: 'Manado',
      );
      expect(isRecordLate(rec), isFalse);
    });

    test('Shift 1 (03:00 - 11:00) masuk 03:05 terhitung TERLAMBAT', () {
      final rec = AttendanceRecord(
        id: 'att_3',
        timestamp: DateTime(2026, 9, 13, 3, 5),
        type: AttendanceType.masuk,
        shiftName: 'Shift 1 (03:00 - 11:00)',
        technicianName: 'Ryan Lumasuge',
        posName: 'Pasar Bersehati Manado',
        lat: 1.488,
        lng: 124.838,
        fullAddress: 'Manado',
      );
      expect(isRecordLate(rec), isTrue);
    });

    test('Absensi Pulang tidak pernah terhitung terlambat', () {
      final rec = AttendanceRecord(
        id: 'att_4',
        timestamp: DateTime(2026, 9, 13, 18, 5),
        type: AttendanceType.pulang,
        shiftName: 'Shift 2 (10:00 - 18:00)',
        technicianName: 'Ryan Lumasuge',
        posName: 'Pasar Bersehati Manado',
        lat: 1.488,
        lng: 124.838,
        fullAddress: 'Manado',
      );
      expect(isRecordLate(rec), isFalse);
    });
  });

  group('LocationService findPosByTagOrName Tests', () {
    test('findPosByTagOrName finds location by exact tag', () {
      final pos = LocationService.findPosByTagOrName('PBM');
      expect(pos, isNotNull);
      expect(pos!.locationTag, equals('PBM'));
    });

    test('findPosByTagOrName finds location by partial name', () {
      final pos = LocationService.findPosByTagOrName('Bersehati');
      expect(pos, isNotNull);
      expect(pos!.posName, contains('Bersehati'));
    });
  });
}
