import 'package:flutter_test/flutter_test.dart';
import 'package:bssparking_timemark/data/services/notification_service.dart';
import 'package:bssparking_timemark/data/services/absensi_setup_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NotificationService & Shift Notification Logic', () {
    test('NotificationService singleton instance is not null', () {
      final service = NotificationService.instance;
      expect(service, isNotNull);
    });

    test('Shift duration calculation for notifications: Shift 2.2 is 4 hours', () {
      final dur = AbsensiSetupService.getMinimumWorkDuration('Shift 2.2 (10:00 - 14:00)');
      expect(dur.inHours, equals(4));
    });

    test('Shift duration calculation for notifications: Shift 2 is 8 hours', () {
      final dur = AbsensiSetupService.getMinimumWorkDuration('Shift 2 (10:00 - 18:00)');
      expect(dur.inHours, equals(8));
    });

    test('Shift duration calculation for notifications: Shift 3 is 8 hours', () {
      final dur = AbsensiSetupService.getMinimumWorkDuration('Shift 3 (14:00 - 22:00)');
      expect(dur.inHours, equals(8));
    });

    test('Remaining work time is zero or positive appropriately', () {
      final checkIn = DateTime(2026, 9, 13, 10, 0);
      final current = DateTime(2026, 9, 13, 12, 0);
      final remaining = AbsensiSetupService.getRemainingWorkTime(
        shift: 'Shift 2.2 (10:00 - 14:00)',
        checkInTime: checkIn,
        currentTime: current,
      );
      expect(remaining, isNotNull);
      expect(remaining!.inHours, equals(2));
    });
  });
}
