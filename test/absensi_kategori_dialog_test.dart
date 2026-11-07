import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';
import 'package:bssparking_timemark/data/services/branch_service.dart';
import 'package:bssparking_timemark/data/services/absensi_setup_service.dart';
import 'package:bssparking_timemark/data/services/location_service.dart';
import 'package:bssparking_timemark/features/templates/widgets/absensi_kategori_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'bss_last_technician_name_v1': 'Junifer Manua',
      'absensi_lokasi_standby_v1': 'PBM',
      'absensi_jadwal_shift_v1': 'Shift 1 (03:00 - 11:00)',
      'absensi_tipe_laporan_v1': 'Masuk',
    });
    await StorageService.init();
    await StorageService.saveLastTechnicianName('Junifer Manua');
  });

  Widget buildTestDialog({Size size = const Size(390, 844)}) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: size),
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

  testWidgets('AbsensiKategoriDialog renders all sections with fixed PBM and 2x2 shift grid without overflow', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildTestDialog());
    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    // 1. Header
    expect(find.text('Atur Shift & Absensi'), findsOneWidget);
    expect(find.byTooltip('Tutup dialog'), findsOneWidget);

    // 2. Section 1: Teknisi
    expect(find.text('TEKNISI BERTUGAS'), findsOneWidget);
    expect(find.text('Junifer Manua'), findsOneWidget);

    // 3. Section 2: Fixed Location PBM (Non-interactive, no dropdown / quick-switch buttons)
    expect(find.text('Jadwal shift & Lokasi standby'), findsOneWidget);
    expect(find.text('Jadwal shift teknisi'), findsOneWidget);
    expect(find.text('LOKASI STANDBY'), findsOneWidget);
    expect(find.text('Pasar Bersehati Manado'), findsOneWidget);
    expect(find.text('PBM'), findsOneWidget);
    // Manado tetap terkunci: tidak ada kolom isian manual
    expect(find.byKey(const Key('lokasi_standby_field')), findsNothing);
    // Verifikasi tombol quick-switch lama sudah terhapus
    expect(find.text('PKM'), findsNothing);
    expect(find.text('NBM'), findsNothing);
    expect(find.text('MGLG'), findsNothing);
    expect(find.byIcon(Icons.map_outlined), findsNothing);

    // 4. Section 3: 2x2 Shift Grid (Primary Visual Focus)
    expect(find.text('PILIH JADWAL SHIFT'), findsOneWidget);
    expect(find.text('Shift 1'), findsOneWidget);
    expect(find.text('Shift 2'), findsOneWidget);
    expect(find.text('Shift 2.2'), findsOneWidget);
    expect(find.text('Shift 3'), findsOneWidget);
    expect(find.text('03:00 - 11:00 WITA'), findsOneWidget);
    expect(find.text('10:00 - 18:00 WITA'), findsOneWidget);

    // Custom Shift compact control
    expect(find.text('Custom Shift'), findsOneWidget);
    expect(find.text('Atur Shift sendiri'), findsOneWidget);

    // Redundant shift summary card removed to streamline modal
    expect(find.text('Konfirmasi Pilihan Shift'), findsNothing);

    // 5. Section 4: Attendance Type
    expect(find.text('JENIS SHIFT'), findsOneWidget);
    expect(find.text('Masuk'), findsOneWidget);
    expect(find.text('Pulang'), findsOneWidget);

    // 6. Footer
    expect(find.text('Batal'), findsOneWidget);
    expect(find.text('Simpan Shift'), findsOneWidget);

    // No overflow exception thrown
    expect(tester.takeException(), isNull);
  });

  testWidgets('AbsensiKategoriDialog toggles shift selection and persists PBM on save', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildTestDialog());
    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    // Tap Shift 2
    await tester.tap(find.text('Shift 2'));
    await tester.pumpAndSettle();

    // Tap Simpan Shift
    await tester.tap(find.text('Simpan Shift'));
    await tester.pumpAndSettle();

    // Verifikasi data tersimpan
    expect(AbsensiSetupService.instance.lokasiStandby, 'PBM');
    expect(AbsensiSetupService.instance.jadwalShift, 'Shift 2 (10:00 - 18:00)');
    expect(LocationService.currentPos.locationTag, 'PBM');
  });

  testWidgets('AbsensiKategoriDialog toggles Custom Shift input', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildTestDialog());
    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    // Scroll to Custom Shift control before tapping
    final customCtrlFinder = find.text('Custom Shift');
    await tester.ensureVisible(customCtrlFinder);
    await tester.pumpAndSettle();

    // Tap Custom Shift control
    await tester.tap(customCtrlFinder);
    await tester.pumpAndSettle();

    // Harus muncul dua kolom isian manual: nama shift dan jamnya
    expect(find.byKey(const Key('custom_shift_nama')), findsOneWidget);
    expect(find.byKey(const Key('custom_shift_jam')), findsOneWidget);

    // Isi nama shift & jam kerja
    await tester.enterText(find.byKey(const Key('custom_shift_nama')), 'Shift Lembur');
    await tester.enterText(find.byKey(const Key('custom_shift_jam')), '08:00 - 17:00');
    await tester.pumpAndSettle();

    // Scroll to and tap Simpan Shift
    final simpanFinder = find.text('Simpan Shift');
    await tester.ensureVisible(simpanFinder);
    await tester.tap(simpanFinder);
    await tester.pumpAndSettle();

    expect(AbsensiSetupService.instance.jadwalShift, 'Shift Lembur (08:00 - 17:00)');
    expect(AbsensiSetupService.instance.lokasiStandby, 'PBM');
  });

  testWidgets('AbsensiKategoriDialog validates empty technician name on save', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildTestDialog());
    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    // Clear technician text field
    final techField = find.widgetWithText(TextField, 'Junifer Manua');
    await tester.enterText(techField, '');
    await tester.pumpAndSettle();

    // Tap Simpan Shift
    await tester.tap(find.text('Simpan Shift'));
    await tester.pumpAndSettle();

    // Dialog should NOT close, validation error must appear
    expect(find.text('Nama teknisi wajib diisi'), findsOneWidget);
    expect(find.text('Atur Shift & Absensi'), findsOneWidget);
  });

  testWidgets('AbsensiKategoriDialog renders cleanly on narrow compact screen (360x640)', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildTestDialog(size: const Size(360, 640)));
    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    expect(find.text('Atur Shift & Absensi'), findsOneWidget);
    expect(find.text('Batal'), findsOneWidget);
    expect(find.text('Simpan Shift'), findsOneWidget);

    // Scroll inside SingleChildScrollView using find.byType(SingleChildScrollView)
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -200));
    await tester.pumpAndSettle();

    expect(find.text('Simpan Shift'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AbsensiKategoriDialog renders HO Makassar shifts matching BranchService exactly', (tester) async {
    await BranchService.instance.setBranch(AppBranch.ho);

    await tester.pumpWidget(buildTestDialog());
    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    // Scroll to shift cards section
    await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -300));
    await tester.pumpAndSettle();

    expect(find.text('RSWS 1'), findsOneWidget);
    expect(find.text('RSWS 2'), findsOneWidget);
    expect(find.text('JP 1'), findsOneWidget);
    expect(find.text('JP 2'), findsOneWidget);
    expect(find.text('GMM 2'), findsNothing);
  });

  testWidgets('choosing Pulang does NOT show handover form in AbsensiKategoriDialog', (tester) async {
    await BranchService.instance.setBranch(AppBranch.manado);
    // Set check in time so auto-pulang eligibility check passes
    final checkIn = DateTime.now().subtract(const Duration(hours: 9));
    await StorageService.saveLastCheckInTime(checkIn);

    await tester.pumpWidget(buildTestDialog());
    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    // Scroll down to Jenis Shift section
    await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -300));
    await tester.pumpAndSettle();

    // Tap Pulang
    await tester.tap(find.text('Pulang'));
    await tester.pumpAndSettle();

    // Handover form elements must NOT exist in the dialog
    expect(find.text('Handover & Laporan Pulang'), findsNothing);
    expect(find.text('Ada Rekan Shift Berikutnya?'), findsNothing);
    expect(find.text('Pilih / Ketik Nama Rekan Pengganti:'), findsNothing);
    expect(find.text('Catatan Pekerjaan Selesai (Wajib):'), findsNothing);
    expect(find.text('Semua Pekerjaan Selesai Hari Ini?'), findsNothing);
  });
}
