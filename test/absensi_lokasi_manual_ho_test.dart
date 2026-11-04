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
    await StorageService.saveLastTechnicianName('AHMAD KHAELANI');
    BranchService.instance.resetForTesting();
    await BranchService.instance.setBranch(AppBranch.ho);
  });

  testWidgets('Dialog absensi HO memakai shift HO, bukan shift Manado', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildTestDialog());
    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    expect(find.text('HO.1'), findsWidgets);
    expect(find.textContaining('08:30 - 12:30'), findsWidgets);
    expect(find.textContaining('03:00 - 11:00'), findsNothing);
    expect(find.textContaining('10:00 - 18:00'), findsNothing);
  });

  testWidgets('Lokasi standby HO bisa diisi manual seperti Bali', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildTestDialog());
    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    final lokasiField = find.byKey(const Key('lokasi_standby_field'));
    expect(lokasiField, findsOneWidget);

    await tester.enterText(lokasiField, 'RSWS');
    await tester.pumpAndSettle();

    final simpan = find.text('Simpan Shift');
    await tester.ensureVisible(simpan);
    await tester.tap(simpan);
    await tester.pumpAndSettle();

    final setup = AbsensiSetupService.instance;
    expect(setup.lokasiStandby, 'RSWS');
    expect(setup.effectiveLokasiStandby, 'RSWS');
    expect(LocationService.currentPos.locationTag, 'RSWS');
  });
}
