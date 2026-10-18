import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bssparking_timemark/data/services/absensi_setup_service.dart';
import 'package:bssparking_timemark/data/services/branch_service.dart';
import 'package:bssparking_timemark/data/services/location_service.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';
import 'package:bssparking_timemark/features/templates/widgets/absensi_kategori_dialog.dart';

Widget buildTestDialog() {
  return MaterialApp(
    home: MediaQuery(
      data: const MediaQueryData(size: Size(390, 844)),
      child: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => AbsensiKategoriDialog.show(context),
            child: const Text('Open Dialog'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    await StorageService.saveLastTechnicianName('Putu Hyan Parta Wijaya');
    BranchService.instance.resetForTesting();
    await BranchService.instance.setBranch(AppBranch.bali);
  });

  testWidgets('Teknisi Bali bisa isi lokasi standby manual, tidak dikunci ke PBKD', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildTestDialog());
    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    // Kolom manual muncul (Bali), isian awal tetap PBKD
    final lokasiField = find.byKey(const Key('lokasi_standby_field'));
    expect(lokasiField, findsOneWidget);
    expect(find.text('PBKD'), findsWidgets);

    // Ganti manual ke pos lain
    await tester.enterText(lokasiField, 'PCD');
    await tester.pumpAndSettle();

    final simpan = find.text('Simpan Shift');
    await tester.ensureVisible(simpan);
    await tester.tap(simpan);
    await tester.pumpAndSettle();

    final setup = AbsensiSetupService.instance;
    expect(setup.lokasiStandby, 'PCD');
    expect(setup.effectiveLokasiStandby, 'PCD', reason: 'isian manual tidak boleh dikembalikan ke PBKD');
    expect(LocationService.currentPos.locationTag, 'PCD');
  });

  testWidgets('Isian manual Bali tetap tersimpan setelah dialog dibuka ulang', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final setup = AbsensiSetupService.instance;
    setup.updateLokasi('PGA');

    await tester.pumpWidget(buildTestDialog());
    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'PGA'), findsOneWidget);
  });

  test('Pos manual non-default tidak direset service', () async {
    final setup = AbsensiSetupService.instance;
    setup.updateLokasi('pga');
    expect(setup.lokasiStandby, 'PGA');
    expect(setup.effectiveLokasiStandby, 'PGA');

    // Cabang lain tidak ikut terbawa
    await BranchService.instance.setBranch(AppBranch.manado);
    expect(setup.effectiveLokasiStandby, 'PBM');
  });
}
