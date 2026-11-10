import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bssparking_timemark/core/constants/app_colors.dart';
import 'package:bssparking_timemark/data/models/daily_task_model.dart';
import 'package:bssparking_timemark/data/services/daily_task_service.dart';
import 'package:bssparking_timemark/data/services/location_service.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';
import 'package:bssparking_timemark/features/daily_tasks/widgets/ad_hoc_task_dialog.dart';

/// Kerjaan dadakan (bukan tugas SPV) harus bisa dicatat teknisi sendiri,
/// supaya masuk daftar hari itu dan bisa diserahterimakan ke shift berikutnya.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  const lokasi = PosLocation(
    posId: 'pos_gate1',
    posName: 'Pos Gate 1',
    cabangName: 'KC BSG',
    fullAddress: 'Jl. Test',
    locationTag: 'GATE 1',
    tagColor: AppColors.accent,
    lat: 1.0,
    lng: 1.0,
  );

  Future<void> bukaDialog(WidgetTester tester, {List<PosLocation> options = const [lokasi]}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => TextButton(
              onPressed: () async {
                await AdHocTaskDialog.show(
                  ctx,
                  teknisiNama: 'Andi',
                  tanggal: '2026-10-18',
                  lokasiOptions: options,
                  lokasiAwal: options.isEmpty ? null : options.first,
                );
              },
              child: const Text('buka'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();
  }

  testWidgets('kerjaan dadakan tersimpan sebagai tugas pending hari itu', (tester) async {
    await bukaDialog(tester);

    await tester.enterText(find.byType(TextField).first, 'Kabel sensor putus di Gate 1');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle(const Duration(seconds: 1));

    final task = DailyTaskService.getCachedTasksLocally()
        .firstWhere((t) => t.judul == 'Kabel sensor putus di Gate 1');
    expect(task.teknisiNama, equals('Andi'));
    expect(task.tanggal, equals('2026-10-18'));
    expect(task.posName, equals('Pos Gate 1'));
    expect(task.posTag, equals('GATE 1'));
    expect(task.status, equals(TaskStatus.pending));
    expect(task.isMaintenance, isFalse);
  });

  testWidgets('judul kosong ditolak dan dialog tidak tertutup', (tester) async {
    await bukaDialog(tester);

    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(find.text('Wajib diisi'), findsOneWidget);
    expect(find.text('Catat Kerjaan'), findsOneWidget);
    expect(DailyTaskService.getCachedTasksLocally(), isEmpty);
  });

  testWidgets('tanpa data lokasi penambahan kerjaan ditolak', (tester) async {
    await bukaDialog(tester, options: const []);

    await tester.enterText(find.byType(TextField).first, 'Kabel sensor putus');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(find.text('Pilih salah satu lokasi'), findsOneWidget);
    expect(DailyTaskService.getCachedTasksLocally(), isEmpty);
  });
}
