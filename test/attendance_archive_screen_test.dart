import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bssparking_timemark/data/models/attendance_record.dart';
import 'package:bssparking_timemark/data/services/branch_service.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';
import 'package:bssparking_timemark/features/history/screens/attendance_archive_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    await BranchService.instance.setBranch(AppBranch.manado);
    await StorageService.saveAttendanceRecord(
      AttendanceRecord(
        id: 'test_1',
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
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

  testWidgets('AttendanceArchiveScreen has export CSV button', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AttendanceArchiveScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Export ke Sheets (CSV)'), findsOneWidget);
  });

  testWidgets('delete only removes active-branch records; other-branch records survive', (tester) async {
    await BranchService.instance.setBranch(AppBranch.manado);
    await StorageService.saveAttendanceRecord(
      AttendanceRecord(
        id: 'test_bali',
        timestamp: DateTime.now().subtract(const Duration(hours: 3)),
        type: AttendanceType.masuk,
        shiftName: 'Shift 1 (06.00 - 14.00)',
        technicianName: 'Indra Yohana',
        posName: 'PBKD',
        lat: -8.650000,
        lng: 115.216667,
        fullAddress: 'Denpasar, Bali',
      ),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: AttendanceArchiveScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify only Manado record is displayed
    expect(find.textContaining('PKM Kalimas'), findsOneWidget);
    expect(find.textContaining('PBKD'), findsNothing);

    // Tap Bersihkan Arsip
    final clearButton = find.byTooltip('Bersihkan Arsip');
    expect(clearButton, findsOneWidget);
    await tester.tap(clearButton);
    await tester.pumpAndSettle();

    // Dialog copy keeps the count and adds the branch name
    expect(find.textContaining('Hapus 1 catatan absen cabang KC Manado?'), findsOneWidget);

    // Confirm delete
    await tester.tap(find.text('Hapus 1 Catatan'));
    await tester.pumpAndSettle();

    // Verify Manado record is removed from storage
    final remainingRecords = StorageService.getAttendanceRecords();
    expect(remainingRecords.any((r) => r.id == 'test_1'), isFalse);

    // Verify Bali record survived
    expect(remainingRecords.any((r) => r.id == 'test_bali'), isTrue);
  });

  testWidgets('cross-midnight shifts: Shift 3 (22.00 - 06.00) at 21:55 is on time, 22:20 is late; HO Shift 3 at 23:58 is on time', (tester) async {
    // 1. Bali tests
    await StorageService.clearAllAttendanceRecords();
    await BranchService.instance.setBranch(AppBranch.bali);

    await StorageService.saveAttendanceRecord(
      AttendanceRecord(
        id: 'bali_ontime',
        timestamp: DateTime(2026, 11, 7, 21, 55),
        type: AttendanceType.masuk,
        shiftName: 'Shift 3 (22.00 - 06.00)',
        technicianName: 'Indra Yohana',
        posName: 'PBKD',
        lat: -8.65,
        lng: 115.21,
        fullAddress: 'Denpasar, Bali',
      ),
    );
    await StorageService.saveAttendanceRecord(
      AttendanceRecord(
        id: 'bali_late',
        timestamp: DateTime(2026, 11, 7, 22, 20),
        type: AttendanceType.masuk,
        shiftName: 'Shift 3 (22.00 - 06.00)',
        technicianName: 'Indra Yohana',
        posName: 'PBKD',
        lat: -8.65,
        lng: 115.21,
        fullAddress: 'Denpasar, Bali',
      ),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: AttendanceArchiveScreen(key: Key('bali_archive')),
      ),
    );
    await tester.pumpAndSettle();

    // Bali verification: 1 on-time badge, 1 late badge, terlambat count = 1
    final onTimeBadgeFinder = find.byWidgetPredicate(
      (w) => w is Text && w.data == 'Tepat Waktu' && w.style?.fontSize == 9.5,
    );
    final lateBadgeFinder = find.byWidgetPredicate(
      (w) => w is Text && w.data == 'Terlambat' && w.style?.fontSize == 9.5,
    );

    expect(onTimeBadgeFinder, findsOneWidget);
    expect(lateBadgeFinder, findsOneWidget);

    // 2. HO test: Shift 3 (24.00 - 08.00) checked in at 23:58 is NOT late
    await StorageService.clearAllAttendanceRecords();
    await BranchService.instance.setBranch(AppBranch.ho);

    await StorageService.saveAttendanceRecord(
      AttendanceRecord(
        id: 'ho_ontime',
        timestamp: DateTime(2026, 11, 7, 23, 58),
        type: AttendanceType.masuk,
        shiftName: 'Shift 3 (24.00 - 08.00)',
        technicianName: 'ADI SUPRIADI',
        posName: 'HO',
        lat: -5.14,
        lng: 119.43,
        fullAddress: 'Makassar',
      ),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: AttendanceArchiveScreen(key: Key('ho_archive')),
      ),
    );
    await tester.pumpAndSettle();

    expect(onTimeBadgeFinder, findsOneWidget);
    expect(lateBadgeFinder, findsNothing);
  });
}
