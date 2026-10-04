import 'package:flutter_test/flutter_test.dart';
import 'package:bssparking_timemark/main.dart';
import 'package:bssparking_timemark/core/utils/verification_code.dart';
import 'package:bssparking_timemark/core/utils/timemark_formatter.dart';
import 'package:bssparking_timemark/data/repositories/template_repository.dart';
import 'package:bssparking_timemark/data/repositories/submission_repository.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    await TemplateRepository.instance.init();
    await SubmissionRepository.instance.init();
  });

  test('Verification code format test', () {
    final now = DateTime(2026, 8, 23, 14, 30, 0);
    final code = VerificationCodeGenerator.generateCode(
      timestamp: now,
      lat: 1.497558,
      lng: 124.841501,
      userId: 'usr_001',
    );

    expect(code.startsWith('BSS-'), isTrue);
    expect(code.length, equals(12)); // 'BSS-' + 8 hex chars
  });

  test('Timemark format WITA test', () {
    final now = DateTime(2026, 8, 23, 14, 30, 15);
    final formatted = TimemarkFormatter.formatTimemarkWib(now, timezone: 'WITA');
    expect(formatted, contains('23 Aug 2026'));
    expect(formatted, contains('14:30:15 WITA'));
  });

  test('Indonesian Full Date & Clock format test', () {
    final now = DateTime(2026, 8, 23, 12, 43, 0);
    final dateStr = TimemarkFormatter.formatIndonesianFullDate(now);
    final clockStr = TimemarkFormatter.formatClockTime(now);

    expect(dateStr, equals('Minggu, 23 Agustus 2026'));
    expect(clockStr, equals('12:43'));
  });

  test('GPS Degree format test', () {
    final gpsStr = TimemarkFormatter.formatGpsDegree(1.497558, 124.841501);
    expect(gpsStr, equals('1.497558°N, 124.841501°E'));
  });

  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const BssParkingTimemarkApp());
    expect(find.byType(BssParkingTimemarkApp), findsOneWidget);
    // Pump out the initial animation frames
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('PMA'), findsOneWidget);
    expect(find.text('Project Maintenance Assembly'), findsOneWidget);
    // Advance timers so that navigation completes cleanly (splash screen duration ~3300ms)
    await tester.pump(const Duration(milliseconds: 3500));
    await tester.pump(const Duration(milliseconds: 600));
    // Menavigasi ke LoginScreen jika belum login, atau CameraCaptureScreen jika sudah login
    expect(find.byType(BssParkingTimemarkApp), findsOneWidget);
  });
}
