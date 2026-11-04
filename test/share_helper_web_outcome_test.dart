import 'package:flutter_test/flutter_test.dart';
import 'package:bssparking_timemark/core/utils/share_helper.dart';

void main() {
  group('WebShareOutcomeHint', () {
    test('shared mengarahkan user ke Simpan Gambar', () {
      expect(WebShareOutcome.shared.saveHint, contains('Simpan Gambar'));
    });

    test('downloaded jujur menyebut Files/Downloads, bukan Galeri', () {
      final hint = WebShareOutcome.downloaded.saveHint;
      expect(hint, contains('Files/Downloads'));
      expect(hint, contains('bukan Galeri'));
    });

    test('cancelled tidak mengklaim foto tersimpan', () {
      expect(WebShareOutcome.cancelled.saveHint, contains('belum disimpan'));
    });

    test('failed menyebut kegagalan', () {
      expect(WebShareOutcome.failed.saveHint, contains('gagal'));
    });
  });
}
