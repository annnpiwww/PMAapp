import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bssparking_timemark/core/utils/web_bytes/web_bytes.dart';
import 'package:bssparking_timemark/core/utils/web_photo_store/web_photo_store.dart';

void main() {
  test(
    'foto absensi web bisa disimpan, dibaca ulang, dan dihapus dari IndexedDB',
    () async {
      final id = 'att_test_${DateTime.now().millisecondsSinceEpoch}';
      final bytes = Uint8List.fromList(List<int>.generate(1024, (i) => i % 256));

      await putPhotoBlob(id, bytes);
      final read = await getPhotoBlob(id);
      expect(read, isNotNull);
      expect(read, equals(bytes));

      await deletePhotoBlob(id);
      expect(await getPhotoBlob(id), isNull);
    },
    skip: kIsWeb ? false : 'IndexedDB hanya tersedia di web',
  );

  test(
    'blob URL foto ber-watermark bisa dibaca ulang',
    () async {
      final bytes = Uint8List.fromList(List<int>.generate(512, (i) => i % 256));
      final url = createWebBlobUrl(bytes, 'image/jpeg');
      expect(url, isNotNull);
      expect(url!.startsWith('blob:'), isTrue);
      expect(await fetchWebBytes(url), equals(bytes));
    },
    skip: kIsWeb ? false : 'blob URL hanya tersedia di web',
  );
}
