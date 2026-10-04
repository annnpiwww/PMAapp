import 'package:flutter_test/flutter_test.dart';
import 'package:bssparking_timemark/data/services/location_service.dart';

void main() {
  group('LocationService.cleanAddressString', () {
    test('cleans duplicated messy address as reported by user', () {
      const raw = 'singkil satu kec singkil kota manado sulawesi utara, indonesia. singkil satu kota manado sulawesi utara';
      final cleaned = LocationService.cleanAddressString(raw);
      expect(cleaned, equals('Singkil Satu, Kec. Singkil, Kota Manado, Sulawesi Utara'));
    });

    test('removes trailing Indonesia and ID tokens', () {
      const raw = 'Jl. Sam Ratulangi No. 45, Wenang, Kota Manado, Sulawesi Utara, Indonesia';
      final cleaned = LocationService.cleanAddressString(raw);
      expect(cleaned, equals('Jl. Sam Ratulangi No. 45, Wenang, Kota Manado, Sulawesi Utara'));
    });

    test('formats abbreviation prefixes properly', () {
      const raw = 'jl. piere tendean no. 12, kec. wenang, kota manado';
      final cleaned = LocationService.cleanAddressString(raw);
      expect(cleaned, equals('Jl. Piere Tendean No. 12, Kec. Wenang, Kota Manado'));
    });

    test('handles empty input gracefully', () {
      expect(LocationService.cleanAddressString(''), equals(''));
      expect(LocationService.cleanAddressString('   '), equals(''));
    });
  });
}
