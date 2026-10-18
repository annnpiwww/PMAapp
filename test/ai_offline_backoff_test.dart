import 'package:flutter_test/flutter_test.dart';
import 'package:bssparking_timemark/features/maintenance/screens/point_camera_view.dart';

void main() {
  setUp(() => PointCameraView.resetAutoOffline());

  group('Backoff otomatis verifikasi AI maintenance', () {
    test('poin normal tetap dilewatkan ke AI', () {
      expect(PointCameraView.consumeAutoOffline(), isFalse);
    });

    test('1 kegagalan melewati 3 poin, lalu AI dicoba lagi', () {
      PointCameraView.noteAiFailure('Timeout 8s (gemini-3.1-flash-lite)');
      expect(PointCameraView.lastAiError, contains('Timeout 8s'));

      expect(PointCameraView.consumeAutoOffline(), isTrue);
      expect(PointCameraView.consumeAutoOffline(), isTrue);
      expect(PointCameraView.consumeAutoOffline(), isTrue);
      // Poin ke-4 sudah dicoba AI lagi, bukan dilewati selamanya.
      expect(PointCameraView.consumeAutoOffline(), isFalse);
    });

    test('kegagalan beruntun memperbesar jeda sampai batas 24 poin', () {
      for (var i = 0; i < 10; i++) {
        PointCameraView.noteAiFailure('Koneksi terputus');
      }
      var dilewati = 0;
      while (PointCameraView.consumeAutoOffline()) {
        dilewati++;
      }
      expect(dilewati, 24);
      expect(PointCameraView.consumeAutoOffline(), isFalse);
    });

    test('AI yang berhasil mengembalikan backoff ke normal', () {
      PointCameraView.noteAiFailure('Koneksi terputus');
      PointCameraView.resetAutoOffline();

      expect(PointCameraView.consumeAutoOffline(), isFalse);
      expect(PointCameraView.lastAiError, isEmpty);
      // Backoff berikutnya kembali ke 3 poin, bukan melanjutkan jeda panjang.
      PointCameraView.noteAiFailure('Koneksi terputus');
      var dilewati = 0;
      while (PointCameraView.consumeAutoOffline()) {
        dilewati++;
      }
      expect(dilewati, 3);
    });
  });
}
