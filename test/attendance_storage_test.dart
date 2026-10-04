import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bssparking_timemark/data/models/attendance_record.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    await StorageService.clearAttendanceRecords();
  });

  group('AttendanceRecord Serialization & Model Tests', () {
    test('AttendanceRecord serialization works', () {
      final now = DateTime(2026, 9, 13, 8, 30, 0);
      final original = AttendanceRecord(
        id: 'att_001',
        timestamp: now,
        type: AttendanceType.masuk,
        shiftName: 'Shift 1 Pagi (07:00 - 15:00)',
        technicianName: 'Budi Santoso',
        posName: 'Pos Masuk Barat',
        lat: -6.2088,
        lng: 106.8456,
        fullAddress: 'Jl. Sudirman Kav 20, Jakarta Selatan',
        photoPath: '/cache/att_001.jpg',
        workDuration: '8 Jam',
        isAiVerified: true,
        aiStatusText: 'SESUAI SOP',
      );

      final json = original.toJson();
      expect(json['id'], equals('att_001'));
      expect(json['timestamp'], equals(now.toIso8601String()));
      expect(json['type'], equals('masuk'));
      expect(json['shiftName'], equals('Shift 1 Pagi (07:00 - 15:00)'));
      expect(json['technicianName'], equals('Budi Santoso'));
      expect(json['posName'], equals('Pos Masuk Barat'));
      expect(json['lat'], equals(-6.2088));
      expect(json['lng'], equals(106.8456));
      expect(json['fullAddress'], equals('Jl. Sudirman Kav 20, Jakarta Selatan'));
      expect(json['photoPath'], equals('/cache/att_001.jpg'));
      expect(json['workDuration'], equals('8 Jam'));
      expect(json['isAiVerified'], isTrue);
      expect(json['aiStatusText'], equals('SESUAI SOP'));

      final deserialized = AttendanceRecord.fromJson(json);
      expect(deserialized.id, equals(original.id));
      expect(deserialized.timestamp, equals(original.timestamp));
      expect(deserialized.type, equals(AttendanceType.masuk));
      expect(deserialized.shiftName, equals(original.shiftName));
      expect(deserialized.technicianName, equals(original.technicianName));
      expect(deserialized.posName, equals(original.posName));
      expect(deserialized.lat, equals(original.lat));
      expect(deserialized.lng, equals(original.lng));
      expect(deserialized.fullAddress, equals(original.fullAddress));
      expect(deserialized.photoPath, equals(original.photoPath));
      expect(deserialized.workDuration, equals(original.workDuration));
      expect(deserialized.isAiVerified, equals(original.isAiVerified));
      expect(deserialized.aiStatusText, equals(original.aiStatusText));
    });

    test('AttendanceRecord defaults and enum parsing', () {
      final minimalJson = {
        'id': 'att_min',
        'type': 'pulang',
        'shiftName': 'Shift 2 Siang',
        'technicianName': 'Ahmad',
        'posName': 'Pos Keluar',
        'lat': -6.1,
        'lng': 106.8,
        'fullAddress': 'Pos Keluar',
      };

      final record = AttendanceRecord.fromJson(minimalJson);
      expect(record.id, equals('att_min'));
      expect(record.type, equals(AttendanceType.pulang));
      expect(record.isAiVerified, isTrue);
      expect(record.aiStatusText, equals('SESUAI SOP'));
      expect(record.photoPath, isNull);
      expect(record.workDuration, isNull);

      // Enum test
      expect(AttendanceType.fromString('masuk'), equals(AttendanceType.masuk));
      expect(AttendanceType.fromString('pulang'), equals(AttendanceType.pulang));
      expect(AttendanceType.fromString('PULANG'), equals(AttendanceType.pulang));
      expect(AttendanceType.fromString(null), equals(AttendanceType.masuk));
      expect(AttendanceType.fromString('unknown'), equals(AttendanceType.masuk));
      expect(AttendanceType.masuk.displayName, equals('Masuk'));
      expect(AttendanceType.pulang.displayName, equals('Pulang'));
    });
  });

  group('StorageService Attendance Records & Auto-Pruning Tests', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('bss_att_storage_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('StorageService autoPruneAttendanceRecords removes entries older than 30 days', () async {
      final now = DateTime.now();
      final oldDate = now.subtract(const Duration(days: 35));
      final recentDate = now.subtract(const Duration(days: 5));

      // Buat file foto sementara
      final oldPhotoFile = File('${tempDir.path}/old_photo.jpg');
      oldPhotoFile.writeAsStringSync('old photo data');
      expect(oldPhotoFile.existsSync(), isTrue);

      final recentPhotoFile = File('${tempDir.path}/recent_photo.jpg');
      recentPhotoFile.writeAsStringSync('recent photo data');
      expect(recentPhotoFile.existsSync(), isTrue);

      final oldRecord = AttendanceRecord(
        id: 'att_old',
        timestamp: oldDate,
        type: AttendanceType.masuk,
        shiftName: 'Shift 1',
        technicianName: 'Teknisi A',
        posName: 'Pos 1',
        lat: -6.2,
        lng: 106.8,
        fullAddress: 'Alamat Pos 1',
        photoPath: oldPhotoFile.path,
      );

      final recentRecord = AttendanceRecord(
        id: 'att_recent',
        timestamp: recentDate,
        type: AttendanceType.pulang,
        shiftName: 'Shift 1',
        technicianName: 'Teknisi A',
        posName: 'Pos 1',
        lat: -6.2,
        lng: 106.8,
        fullAddress: 'Alamat Pos 1',
        photoPath: recentPhotoFile.path,
      );

      // Simpan langsung record (menguji autoPruneAttendanceRecords)
      await StorageService.saveAttendanceRecord(oldRecord);
      await StorageService.saveAttendanceRecord(recentRecord);

      // Jalankan eksplisit autoPrune dengan retentionDays: 30
      await StorageService.autoPruneAttendanceRecords(retentionDays: 30);

      final list = StorageService.getAttendanceRecords();

      // Hanya recentRecord yang tersisa
      expect(list.length, equals(1));
      expect(list.first.id, equals('att_recent'));
      expect(list.any((r) => r.id == 'att_old'), isFalse);

      // File foto lama (> 30 hari) harus terhapus
      expect(oldPhotoFile.existsSync(), isFalse);

      // File foto baru (< 30 hari) tetap ada
      expect(recentPhotoFile.existsSync(), isTrue);
    });

    test('StorageService saveAttendanceRecord and sorting works', () async {
      final recordEarlier = AttendanceRecord(
        id: 'rec_1',
        timestamp: DateTime(2026, 9, 13, 7, 0),
        type: AttendanceType.masuk,
        shiftName: 'Shift Pagi',
        technicianName: 'Budi',
        posName: 'Pos Barat',
        lat: -6.2,
        lng: 106.8,
        fullAddress: 'Jakarta',
      );

      final recordLater = AttendanceRecord(
        id: 'rec_2',
        timestamp: DateTime(2026, 9, 13, 15, 30),
        type: AttendanceType.pulang,
        shiftName: 'Shift Pagi',
        technicianName: 'Budi',
        posName: 'Pos Barat',
        lat: -6.2,
        lng: 106.8,
        fullAddress: 'Jakarta',
        workDuration: '8 Jam 30 Menit',
      );

      await StorageService.saveAttendanceRecord(recordEarlier);
      await StorageService.saveAttendanceRecord(recordLater);

      final records = StorageService.getAttendanceRecords();
      expect(records.length, equals(2));
      // Descending sorting: yang terbaru di paling atas
      expect(records.first.id, equals('rec_2'));
      expect(records.last.id, equals('rec_1'));

      // Update record yang sudah ada
      final updatedRecordLater = recordLater.copyWith(
        workDuration: '9 Jam',
      );
      await StorageService.saveAttendanceRecord(updatedRecordLater);

      final updatedRecords = StorageService.getAttendanceRecords();
      expect(updatedRecords.length, equals(2));
      expect(updatedRecords.first.workDuration, equals('9 Jam'));
    });

    test('StorageService deleteAttendanceRecord removes record and deletes photo', () async {
      final photoFile = File('${tempDir.path}/delete_test.jpg');
      photoFile.writeAsStringSync('sample photo');
      expect(photoFile.existsSync(), isTrue);

      final record = AttendanceRecord(
        id: 'att_del',
        timestamp: DateTime.now(),
        type: AttendanceType.masuk,
        shiftName: 'Shift 1',
        technicianName: 'Budi',
        posName: 'Pos 1',
        lat: -6.2,
        lng: 106.8,
        fullAddress: 'Jakarta',
        photoPath: photoFile.path,
      );

      await StorageService.saveAttendanceRecord(record);
      expect(StorageService.getAttendanceRecords().length, equals(1));

      await StorageService.deleteAttendanceRecord('att_del');
      expect(StorageService.getAttendanceRecords().length, equals(0));
      expect(photoFile.existsSync(), isFalse);
    });
  });
}
