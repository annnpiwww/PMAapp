import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
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
        fullAddress:
            'Jl. Nusantara No.17, Calaca, Wenang, Kota Manado, Sulawesi Utara',
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
      home: LocationManagementScreen(onLocationSelected: onLocationSelected),
    );
  }

  group('LocationManagementScreen Non-SPV (Petugas) Gate', () {
    testWidgets('non-SPV tidak melihat tombol tambah, edit, atau hapus', (
      tester,
    ) async {
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
    testWidgets('SPV melihat tombol tambah dan menu edit/hapus', (
      tester,
    ) async {
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
        expect(dialogFields, findsAtLeastNWidgets(3));
        await tester.enterText(dialogFields.at(0), 'Pos Terminal Baru');
        await tester.enterText(
          dialogFields.at(1),
          'Jl. Sam Ratulangi No. 10, Manado',
        );
        await tester.enterText(dialogFields.at(2), 'PTB');

        LocationService.nativeGeocodeLookupOverride = (address) async {
          return [
            geo.Location(
              latitude: 1.498,
              longitude: 124.841,
              timestamp: DateTime(2026, 11, 5),
            ),
          ];
        };

        // Tap Simpan di form dialog
        await tester.tap(find.widgetWithText(ElevatedButton, 'Simpan'));
        await tester.pumpAndSettle();

        // Preview peta muncul dengan tombol Ubah Alamat & Lanjut Simpan
        expect(
          find.text(
            'Titik peta mengikuti alamat ini. Kalau meleset, perjelas alamatnya lalu Simpan lagi.',
          ),
          findsOneWidget,
        );
        await tester.tap(find.widgetWithText(ElevatedButton, 'Lanjut Simpan'));
        await tester.pumpAndSettle();

        // Dialog Konfirmasi SPV wajib terbuka
        expect(find.text('Konfirmasi SPV'), findsOneWidget);

        // Input identitas prefilled dengan email SPV
        final identityFinder = find.widgetWithText(
          TextField,
          'spv.manado@bssparking.id',
        );
        expect(identityFinder, findsOneWidget);

        // Input password wajib obscureText == true
        final passwordTextFields = tester
            .widgetList<TextField>(find.byType(TextField))
            .where((tf) => tf.decoration?.labelText == 'Password SPV');
        expect(passwordTextFields, isNotEmpty);
        expect(passwordTextFields.first.obscureText, isTrue);

        // Tombol Batal & Simpan ada di dialog konfirmasi (dialog teratas)
        final topDialog = find.byType(AlertDialog).last;
        expect(
          find.descendant(
            of: topDialog,
            matching: find.widgetWithText(TextButton, 'Batal'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: topDialog,
            matching: find.widgetWithText(ElevatedButton, 'Simpan'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('hapus lokasi langsung membuka dialog Konfirmasi SPV', (
      tester,
    ) async {
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

      final passwordTextFields = tester
          .widgetList<TextField>(find.byType(TextField))
          .where((tf) => tf.decoration?.labelText == 'Password SPV');
      expect(passwordTextFields, isNotEmpty);
      expect(passwordTextFields.first.obscureText, isTrue);
    });

    testWidgets('Alamat field exists and is required in location form dialog', (
      tester,
    ) async {
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

      await tester.tap(find.byIcon(Icons.add_location_alt_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Alamat Lokasi *'), findsOneWidget);

      final dialogFields = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      );
      expect(dialogFields, findsAtLeastNWidgets(3));

      // 1. Simpan with all fields empty -> validation error
      await tester.tap(find.widgetWithText(ElevatedButton, 'Simpan'));
      await tester.pumpAndSettle();
      expect(
        find.text('Nama Lokasi, Tag Card, dan Alamat wajib diisi.'),
        findsOneWidget,
      );

      // 2. Fill name and tag, leave address empty -> validation error persists
      await tester.enterText(dialogFields.at(0), 'Lokasi Uji');
      await tester.enterText(dialogFields.at(2), 'LU');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Simpan'));
      await tester.pumpAndSettle();
      expect(
        find.text('Nama Lokasi, Tag Card, dan Alamat wajib diisi.'),
        findsOneWidget,
      );

      // 3. Fill address as well -> validation error clears
      await tester.enterText(
        dialogFields.at(1),
        'Jl. Sam Ratulangi No. 5, Manado',
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Nama Lokasi, Tag Card, dan Alamat wajib diisi.'),
        findsNothing,
      );
    });

    testWidgets(
      'editing a Bali seed and changing only address triggers geocode and saves new coordinates and fullAddress',
      (tester) async {
        await BranchService.instance.setBranch(AppBranch.bali);

        final spvBali = UserModel(
          id: 'usr_spv_bali',
          nama: 'Supervisor Bali',
          npp: 'BSS-SPV-DPS-01',
          email: 'spv.bali@bssparking.id',
          role: UserRole.supervisor,
          posId: 'POS-DPS-01',
          posName: 'Mall Bali Galeria',
          cabangName: 'KC Bali',
        );
        await AuthRepository.instance.login(spvBali);

        String? capturedGeocodeQuery;
        LocationService.nativeGeocodeLookupOverride = (query) async {
          capturedGeocodeQuery = query;
          return [
            geo.Location(
              latitude: -8.7485,
              longitude: 115.1672,
              timestamp: DateTime(2026, 11, 5),
            ),
          ];
        };

        Map<String, dynamic>? savedPayload;
        LocationService.clientOverride = MockClient((request) async {
          if (request.url.path.contains('pos-locations')) {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            savedPayload = body['location'] as Map<String, dynamic>?;
            return http.Response(jsonEncode({'ok': true}), 200);
          }
          return http.Response('Not found', 404);
        });

        await tester.pumpWidget(buildTestableWidget());
        await tester.pumpAndSettle();

        // Buka popup menu lokasi Bali pertama
        await tester.tap(find.byType(PopupMenuButton<String>).first);
        await tester.pumpAndSettle();

        await tester.tap(find.text('Edit Lokasi'));
        await tester.pumpAndSettle();

        expect(find.text('Edit Lokasi'), findsOneWidget);

        final dialogFields = find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        );

        // Ubah HANYA alamat lokasi
        const newAddress = 'Jl. Bypass Ngurah Rai No. 99, Tuban, Kuta';
        await tester.enterText(dialogFields.at(1), newAddress);
        await tester.pumpAndSettle();

        // Tap Simpan -> trigger geocode
        await tester.tap(find.widgetWithText(ElevatedButton, 'Simpan'));
        await tester.pumpAndSettle();

        expect(capturedGeocodeQuery, isNotNull);
        expect(capturedGeocodeQuery, contains(newAddress));

        // Preview peta muncul dengan FlutterMap dan pesan konfirmasi titik
        expect(find.byType(FlutterMap), findsOneWidget);
        expect(
          find.text(
            'Titik peta mengikuti alamat ini. Kalau meleset, perjelas alamatnya lalu Simpan lagi.',
          ),
          findsOneWidget,
        );
        expect(find.widgetWithText(TextButton, 'Ubah Alamat'), findsOneWidget);
        expect(
          find.widgetWithText(ElevatedButton, 'Lanjut Simpan'),
          findsOneWidget,
        );

        // Tap Lanjut Simpan
        await tester.tap(find.widgetWithText(ElevatedButton, 'Lanjut Simpan'));
        await tester.pumpAndSettle();

        // Dialog Konfirmasi SPV terbuka
        expect(find.text('Konfirmasi SPV'), findsOneWidget);

        final passwordField = find.descendant(
          of: find.byType(AlertDialog).last,
          matching: find.byWidgetPredicate(
            (w) => w is TextField && w.decoration?.labelText == 'Password SPV',
          ),
        );
        await tester.enterText(passwordField, 'rahasia123');

        final confirmBtn = find.descendant(
          of: find.byType(AlertDialog).last,
          matching: find.widgetWithText(ElevatedButton, 'Simpan'),
        );
        await tester.tap(confirmBtn);
        await tester.pumpAndSettle();

        // Verifikasi payload yang dikirim ke remote
        expect(savedPayload, isNotNull);
        expect(savedPayload!['lat'], closeTo(-8.7485, 0.0001));
        expect(savedPayload!['lng'], closeTo(115.1672, 0.0001));
        expect(savedPayload!['full_address'], newAddress);
      },
    );

    testWidgets(
      'editing without changing non-zero-coord address does not geocode and keeps existing coordinates',
      (tester) async {
        await BranchService.instance.setBranch(AppBranch.manado);

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

        var geocodeWasCalled = false;
        LocationService.nativeGeocodeLookupOverride = (_) async {
          geocodeWasCalled = true;
          return [];
        };

        Map<String, dynamic>? savedPayload;
        LocationService.clientOverride = MockClient((request) async {
          if (request.url.path.contains('pos-locations')) {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            savedPayload = body['location'] as Map<String, dynamic>?;
            return http.Response(jsonEncode({'ok': true}), 200);
          }
          return http.Response('Not found', 404);
        });

        await tester.pumpWidget(buildTestableWidget());
        await tester.pumpAndSettle();

        await tester.tap(find.byType(PopupMenuButton<String>).first);
        await tester.pumpAndSettle();

        await tester.tap(find.text('Edit Lokasi'));
        await tester.pumpAndSettle();

        final dialogFields = find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        );

        // Ubah HANYA Nama, alamat tidak diubah
        await tester.enterText(dialogFields.at(0), 'Pasar Bersehati Edit Name');
        await tester.pumpAndSettle();

        // Tap Simpan
        await tester.tap(find.widgetWithText(ElevatedButton, 'Simpan'));
        await tester.pumpAndSettle();

        // Geocoding TIDAK boleh dipanggil
        expect(geocodeWasCalled, isFalse);

        // Langsung menuju dialog Konfirmasi SPV (tanpa preview)
        expect(find.text('Konfirmasi SPV'), findsOneWidget);

        final passwordField = find.descendant(
          of: find.byType(AlertDialog).last,
          matching: find.byWidgetPredicate(
            (w) => w is TextField && w.decoration?.labelText == 'Password SPV',
          ),
        );
        await tester.enterText(passwordField, 'spvpass');

        final confirmBtn = find.descendant(
          of: find.byType(AlertDialog).last,
          matching: find.widgetWithText(ElevatedButton, 'Simpan'),
        );
        await tester.tap(confirmBtn);
        await tester.pumpAndSettle();

        expect(savedPayload, isNotNull);
        // Koordinat lama tetap dipertahankan
        expect(savedPayload!['lat'], closeTo(1.4980709, 0.00001));
        expect(savedPayload!['lng'], closeTo(124.8415709, 0.00001));
        expect(savedPayload!['pos_name'], 'Pasar Bersehati Edit Name');
      },
    );

    testWidgets(
      'geocode null keeps dialog open with not-found error and saveLocationRemote not called',
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

        // Geocoder mengembalikan null / empty list
        LocationService.nativeGeocodeLookupOverride = (_) async => [];

        var remoteSaveWasCalled = false;
        LocationService.clientOverride = MockClient((request) async {
          if (request.method == 'POST') {
            try {
              final body = jsonDecode(request.body);
              if (body is Map && body['action'] == 'upsert') {
                remoteSaveWasCalled = true;
              }
            } catch (_) {}
          }
          return http.Response(jsonEncode({'ok': true}), 200);
        });

        await tester.pumpWidget(buildTestableWidget());
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.add_location_alt_rounded));
        await tester.pumpAndSettle();

        final dialogFields = find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        );
        await tester.enterText(dialogFields.at(0), 'Lokasi Fiktif');
        await tester.enterText(dialogFields.at(1), 'Alamat Antah Berantah 123');
        await tester.enterText(dialogFields.at(2), 'LF');

        await tester.tap(find.widgetWithText(ElevatedButton, 'Simpan'));
        await tester.pumpAndSettle();

        // Error inline muncul
        expect(
          find.text(
            'Alamat tidak ditemukan di peta. Tambahkan nama jalan, kelurahan, atau kota.',
          ),
          findsOneWidget,
        );

        // Dialog tetap terbuka
        expect(find.text('Tambah Lokasi Baru'), findsOneWidget);

        // Remote save TIDAK pernah dipanggil
        expect(remoteSaveWasCalled, isFalse);
      },
    );

    testWidgets(
      'preview dialog Ubah Alamat returns to edit form keeping typed text',
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

        LocationService.nativeGeocodeLookupOverride = (_) async {
          return [
            geo.Location(
              latitude: 1.498,
              longitude: 124.841,
              timestamp: DateTime(2026, 11, 5),
            ),
          ];
        };

        await tester.pumpWidget(buildTestableWidget());
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.add_location_alt_rounded));
        await tester.pumpAndSettle();

        final dialogFields = find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        );
        await tester.enterText(dialogFields.at(0), 'Pos Boulevard');
        await tester.enterText(dialogFields.at(1), 'Jl. Piere Tendean, Manado');
        await tester.enterText(dialogFields.at(2), 'PB');

        await tester.tap(find.widgetWithText(ElevatedButton, 'Simpan'));
        await tester.pumpAndSettle();

        // Masuk ke preview map
        expect(find.byType(FlutterMap), findsOneWidget);
        expect(find.widgetWithText(TextButton, 'Ubah Alamat'), findsOneWidget);

        // Tap Ubah Alamat
        await tester.tap(find.widgetWithText(TextButton, 'Ubah Alamat'));
        await tester.pumpAndSettle();

        // Form input muncul kembali dan teks tetap ada
        expect(find.text('Tambah Lokasi Baru'), findsOneWidget);
        expect(find.text('Pos Boulevard'), findsOneWidget);
        expect(find.text('Jl. Piere Tendean, Manado'), findsOneWidget);
        expect(find.text('PB'), findsOneWidget);
      },
    );
  });
}
