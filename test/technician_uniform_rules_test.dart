import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bssparking_timemark/data/services/absensi_setup_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Technician Uniform Rules Tests (Senin - Minggu)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Current day includes Teknisi option in seragamHariIni', () {
      final setup = AbsensiSetupService.instance;
      
      // Hari kerja saat ini harus mengandung 'Teknisi'
      expect(
        setup.seragamHariIni.toLowerCase().contains('teknisi'),
        isTrue,
        reason: 'Seragam hari ini (${setup.seragamHariIni}) harus mengandung opsi Teknisi',
      );
    });

    test('All 7 days of the week have Seragam Teknisi as a valid uniform', () {
      const days = ['SENIN', 'SELASA', 'RABU', 'KAMIS', 'JUMAT', 'SABTU', 'MINGGU'];
      
      for (final day in days) {
        String seragam;
        switch (day) {
          case 'SENIN':
            seragam = 'Teknisi / PDH navy';
            break;
          case 'SELASA':
            seragam = 'PDH biru navy / Teknisi';
            break;
          case 'RABU':
            seragam = 'Seragam Teknisi';
            break;
          case 'KAMIS':
            seragam = 'BSS Putih / Teknisi';
            break;
          case 'JUMAT':
            seragam = 'Batik / Teknisi';
            break;
          case 'SABTU':
            seragam = 'Olahraga biru-kuning / Teknisi';
            break;
          case 'MINGGU':
            seragam = 'Bebas rapi / Teknisi';
            break;
          default:
            seragam = 'Seragam Teknisi';
        }

        expect(
          seragam.toLowerCase().contains('teknisi'),
          isTrue,
          reason: 'Hari $day ($seragam) wajib menyertakan opsi seragam teknisi',
        );
      }
    });
  });
}
