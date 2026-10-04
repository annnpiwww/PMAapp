import 'package:flutter_test/flutter_test.dart';
import 'package:bssparking_timemark/data/services/photo_cleanup_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PhotoCleanupService Tests', () {
    test('Service executes without throwing exceptions', () async {
      final count = await PhotoCleanupService.cleanOldPhotos(maxDays: 7);
      expect(count >= 0, isTrue);
    });
  });
}
