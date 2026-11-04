import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bssparking_timemark/data/models/user_model.dart';
import 'package:bssparking_timemark/data/repositories/auth_repository.dart';
import 'package:bssparking_timemark/data/services/branch_service.dart';
import 'package:bssparking_timemark/data/services/location_service.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';
import 'package:bssparking_timemark/features/locations/screens/location_management_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    await BranchService.instance.setBranch(AppBranch.manado);
    LocationService.resetForTesting();
    LocationService.setCachedLocationForTesting(
      LocationResult(
        lat: 1.4980709,
        lng: 124.8415709,
        accuracyMeter: 5.0,
        isGpsEnabled: true,
        isMockLocation: false,
        posName: 'Pasar Bersehati Manado',
        cabangName: 'KC BSG',
        fullAddress: 'Jl. Nusantara No.17, Calaca, Wenang, Kota Manado, Sulawesi Utara',
        locationTag: 'PBM',
        tagColor: const Color(0xFFF59E0B),
      ),
    );
  });

  tearDown(() async {
    await AuthRepository.instance.logout();
  });

  Widget buildTestableWidget({ValueChanged<PosLocation>? onLocationSelected}) {
    return MaterialApp(
      home: LocationManagementScreen(
        onLocationSelected: onLocationSelected,
      ),
    );
  }

  group('LocationManagementScreen Non-SPV (Petugas) Gate', () {
    testWidgets('non-SPV tidak melihat tombol tambah, edit, atau hapus',
        (tester) async {
      final petugas = UserModel(
        id: 'usr_tek_01',
        nama: 'Teknisi BSS',
        npp: 'BSS-TEK-01',
        email: 'teknisi@bssparking.id',
        role: UserRole.petugas,
        posId: 'POS-PBM-01',
        posName: 'Pasar Bersehati Manado',
        cabangName: 'KC BSG',
      );
      await AuthRepository.instance.login(petugas);

      PosLocation? selectedLocation;
      await tester.pumpWidget(
        buildTestableWidget(
          onLocationSelected: (pos) => selectedLocation = pos,
        ),
      );
      await tester.pumpAndSettle();

      // Banner non-SPV wajib muncul
      expect(
        find.text('Lokasi dikelola SPV. Minta SPV kalau ada lokasi baru.'),
        findsOneWidget,
      );

      // Tombol add di AppBar TIDAK boleh ada
      expect(find.byIcon(Icons.add_location_alt_rounded), findsNothing);

      // Popup menu edit / delete TIDAK boleh ada
      expect(find.byType(PopupMenuButton<String>), findsNothing);
      expect(find.text('Edit Lokasi'), findsNothing);
      expect(find.text('Hapus'), findsNothing);

      // Tapping list item tetap berfungsi untuk memilih lokasi aktif
      final firstTile = find.byType(ListTile).first;
      expect(firstTile, findsOneWidget);
      await tester.tap(firstTile);
      await tester.pumpAndSettle();

      expect(selectedLocation, isNotNull);
      expect(selectedLocation!.posId, isNotEmpty);
    });
  });

  group('LocationManagementScreen SPV Gate & Confirmation Dialog', () {
    testWidgets('SPV melihat tombol tambah dan menu edit/hapus',
        (tester) async {
      final spv = UserModel(
        id: 'usr_spv_01',
        nama: 'Supervisor BSS',
        npp: 'BSS-SPV-01',
        email: 'spv@bssparking.id',
        role: UserRole.supervisor,
        posId: 'POS-PBM-01',
        posName: 'Pasar Bersehati Manado',
        cabangName: 'KC BSG',
      );
      await AuthRepository.instance.login(spv);

      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      // Banner non-SPV TIDAK boleh muncul
      expect(
        find.text('Lokasi dikelola SPV. Minta SPV kalau ada lokasi baru.'),
        findsNothing,
      );

      // Tombol add di AppBar HARUS ada
      expect(find.byIcon(Icons.add_location_alt_rounded), findsOneWidget);

      // PopupMenuButton HARUS ada untuk tiap lokasi
      expect(find.byType(PopupMenuButton<String>), findsWidgets);

      // Buka popup menu pertama
      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();

      expect(find.text('Jadikan Lokasi Aktif'), findsOneWidget);
      expect(find.text('Edit Lokasi'), findsOneWidget);
      expect(find.text('Hapus'), findsOneWidget);
    });

    testWidgets(
        'form tambah lokasi membuka dialog Konfirmasi SPV dengan password obscure',
        (tester) async {
      final spv = UserModel(
        id: 'usr_spv_01',
        nama: 'Supervisor BSS',
        npp: 'BSS-SPV-01',
        email: 'spv.manado@bssparking.id',
        role: UserRole.supervisor,
        posId: 'POS-PBM-01',
        posName: 'Pasar Bersehati Manado',
        cabangName: 'KC BSG',
      );
      await AuthRepository.instance.login(spv);

      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      // Tap tambah lokasi
      await tester.tap(find.byIcon(Icons.add_location_alt_rounded));
      await tester.pumpAndSettle();

      // Isi form dialog (pastikan mengisi TextField dalam dialog)
      expect(find.text('Tambah Lokasi Baru'), findsOneWidget);
      final dialogFields = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      );
      expect(dialogFields, findsAtLeastNWidgets(2));
      await tester.enterText(dialogFields.at(0), 'Pos Terminal Baru');
      await tester.enterText(dialogFields.at(1), 'PTB');

      // Tap Simpan di form dialog
      await tester.tap(find.widgetWithText(ElevatedButton, 'Simpan'));
      await tester.pumpAndSettle();

      // Dialog Konfirmasi SPV wajib terbuka
      expect(find.text('Konfirmasi SPV'), findsOneWidget);

      // Input identitas prefilled dengan email SPV
      final identityFinder = find.widgetWithText(TextField, 'spv.manado@bssparking.id');
      expect(identityFinder, findsOneWidget);

      // Input password wajib obscureText == true
      final passwordTextFields = tester.widgetList<TextField>(find.byType(TextField)).where(
        (tf) => tf.decoration?.labelText == 'Password SPV',
      );
      expect(passwordTextFields, isNotEmpty);
      expect(passwordTextFields.first.obscureText, isTrue);

      // Tombol Batal & Simpan ada di dialog konfirmasi (dialog teratas)
      final topDialog = find.byType(AlertDialog).last;
      expect(
        find.descendant(of: topDialog, matching: find.widgetWithText(TextButton, 'Batal')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: topDialog, matching: find.widgetWithText(ElevatedButton, 'Simpan')),
        findsOneWidget,
      );
    });

    testWidgets('hapus lokasi langsung membuka dialog Konfirmasi SPV',
        (tester) async {
      final spv = UserModel(
        id: 'usr_spv_01',
        nama: 'Supervisor BSS',
        npp: 'BSS-SPV-01',
        email: 'spv.manado@bssparking.id',
        role: UserRole.supervisor,
        posId: 'POS-PBM-01',
        posName: 'Pasar Bersehati Manado',
        cabangName: 'KC BSG',
      );
      await AuthRepository.instance.login(spv);

      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      // Buka popup menu pertama
      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();

      // Tap Hapus
      await tester.tap(find.text('Hapus'));
      await tester.pumpAndSettle();

      // Dialog Konfirmasi SPV wajib terbuka untuk penghapusan
      expect(find.text('Konfirmasi SPV'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Hapus'), findsOneWidget);

      final passwordTextFields = tester.widgetList<TextField>(find.byType(TextField)).where(
        (tf) => tf.decoration?.labelText == 'Password SPV',
      );
      expect(passwordTextFields, isNotEmpty);
      expect(passwordTextFields.first.obscureText, isTrue);
    });
  });
}
