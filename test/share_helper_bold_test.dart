import 'package:flutter_test/flutter_test.dart';
import 'package:bssparking_timemark/core/utils/share_helper.dart';

void main() {
  group('ShareHelper.convertMarkdownBoldToUnicode', () {
    test('converts basic uppercase and lowercase bold text', () {
      const input = '1. *Pembersihan total printer tiket* :';
      final output = ShareHelper.convertMarkdownBoldToUnicode(input);
      // Pembersihan total printer tiket in Unicode Bold
      expect(output.contains('*'), isFalse);
      expect(output, contains('1. 𝐏𝐞𝐦𝐛𝐞𝐫𝐬𝐢𝐡𝐚𝐧 𝐭𝐨𝐭𝐚𝐥 𝐩𝐫𝐢𝐧𝐭𝐞𝐫 𝐭𝐢𝐤𝐞𝐭 :'));
    });

    test('converts alphanumeric bold text', () {
      const input = '*Barrier Gate 1*';
      final output = ShareHelper.convertMarkdownBoldToUnicode(input);
      expect(output, equals('𝐁𝐚𝐫𝐫𝐢𝐞𝐫 𝐆𝐚𝐭𝐞 𝟏'));
    });

    test('leaves non-bold text intact', () {
      const input = 'Selamat Malam\nIzin melaporkan hasil';
      final output = ShareHelper.convertMarkdownBoldToUnicode(input);
      expect(output, equals(input));
    });
  });
}
