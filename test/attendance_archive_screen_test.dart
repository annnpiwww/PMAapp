import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bssparking_timemark/data/models/attendance_record.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';
import 'package:bssparking_timemark/features/history/screens/attendance_archive_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    await StorageService.saveAttendanceRecord(
      AttendanceRecord(
        id: 'test_1',
        timestamp: DateTime(2026, 9, 14, 8, 15),
        type: AttendanceType.masuk,
        shiftName: 'Shift 1 (03:00 - 11:00)',
        technicianName: 'Farhan Lakoro',
        posName: 'PKM Kalimas',
        lat: 1.500147,
        lng: 124.850032,
        fullAddress: 'Singkil Satu, Manado',
      ),
    );
  });

  testWidgets('AttendanceArchiveScreen renders table and records', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AttendanceArchiveScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Riwayat Kerja'), findsOneWidget);
    expect(find.textContaining('PKM Kalimas'), findsOneWidget);
    expect(find.text('Jam Masuk'), findsOneWidget);
  });
}
