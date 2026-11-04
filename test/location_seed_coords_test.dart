import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bssparking_timemark/data/services/location_service.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    LocationService.resetForTesting();
  });

  group('Migrasi Koordinat Seed Lokasi KC Manado', () {
    test('menimpa koordinat lama seed sekali saja saat flag belum ada', () {
      // 1. Simulasikan device lama yang menyimpan koordinat lama POS-PBM-01
      const oldPbm = PosLocation(
        posId: 'POS-PBM-01',
        posName: 'Pasar Bersehati Manado',
        cabangName: 'KC BSG',
        fullAddress: 'Pasar Bersehati, Kota Manado, Sulawesi Utara',
        locationTag: 'PBM',
        tagColor: Color(0xFFF59E0B),
        lat: 1.493055, // Koordinat lama
        lng: 124.841972,
      );

      StorageService.saveLocations([oldPbm]);
      expect(
        StorageService.getBool(LocationService.keySeedCoordsMigration),
        isNull,
      );

      // 2. Inisialisasi LocationService (menjalankan migrasi sekali jalan)
      LocationService.resetForTesting();
      final locations = LocationService.allLocations;
      final migratedPbm = locations.firstWhere((p) => p.posId == 'POS-PBM-01');

      // 3. Pastikan koordinat dan alamat ter-update ke seed baru
      expect(migratedPbm.lat, 1.4980709);
      expect(migratedPbm.lng, 124.8415709);
      expect(
        migratedPbm.fullAddress,
        'Jl. Nusantara No.17, Calaca, Wenang, Kota Manado, Sulawesi Utara',
      );

      // 4. Pastikan flag migrasi sudah aktif
      expect(
        StorageService.getBool(LocationService.keySeedCoordsMigration),
        isTrue,
      );
    });

    test('self-healing menimpa koordinat lama salah meskipun flag migrasi sudah true', () {
      // 1. Simulasikan device yang sudah ter-set flag true tapi koordinat MGBP masih Manado
      const oldMgbp = PosLocation(
        posId: 'POS-MGBP-01',
        posName: 'Mie Gacoan Babe Palar',
        cabangName: 'KC BSG',
        fullAddress: 'Jl. Babe Palar, Kota Manado, Sulawesi Utara',
        locationTag: 'MGBP',
        tagColor: Color(0xFFF59E0B),
        lat: 1.472000, // Koordinat lama Manado
        lng: 124.838000,
      );

      StorageService.saveLocations([oldMgbp]);
      StorageService.setBool(LocationService.keySeedCoordsMigration, true);

      // 2. Inisialisasi LocationService (self-healing harus mendeteksi koordinat lama ini)
      LocationService.resetForTesting();
      final locations = LocationService.allLocations;
      final mgbp = locations.firstWhere((p) => p.locationTag == 'MGBP');

      // 3. Koordinat harus terkoreksi ke Bitung
      expect(mgbp.lat, 1.4429952);
      expect(mgbp.lng, 125.1583095);
      expect(mgbp.fullAddress.contains('Bitung'), isTrue);
    });

    test('tidak menimpa perubahan manual SPV setelah flag migrasi aktif', () async {
      // 1. Jalankan inisialisasi awal sehingga migrasi selesai dan flag diset
      LocationService.resetForTesting();
      final initialLocations = LocationService.allLocations;
      final pbm = initialLocations.firstWhere((p) => p.posId == 'POS-PBM-01');

      expect(
        StorageService.getBool(LocationService.keySeedCoordsMigration),
        isTrue,
      );

      // 2. SPV mengupdate titik koordinat lokasi secara custom
      final customPbm = pbm.copyWith(
        lat: 1.4995555,
        lng: 124.8428888,
        fullAddress: 'Jl. Custom SPV Update No. 1',
      );
      await LocationService.updateLocation(customPbm);

      // 3. Simulasikan restart app dengan reset cache memori
      LocationService.resetForTesting();

      // 4. Muat ulang lokasi
      final reloadedLocations = LocationService.allLocations;
      final updatedPbm =
          reloadedLocations.firstWhere((p) => p.posId == 'POS-PBM-01');

      // 5. Pastikan perubahan SPV TIDAK tertimpa seed lagi
      expect(updatedPbm.lat, 1.4995555);
      expect(updatedPbm.lng, 124.8428888);
      expect(updatedPbm.fullAddress, 'Jl. Custom SPV Update No. 1');
    });
  });
}
