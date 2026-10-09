import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bssparking_timemark/data/models/template_model.dart';
import 'package:bssparking_timemark/data/models/submission_model.dart';
import 'package:bssparking_timemark/data/repositories/template_repository.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';
import 'package:bssparking_timemark/data/services/absensi_setup_service.dart';
import 'package:bssparking_timemark/data/services/ai_vision_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  group('SPV Farhan Root QA Bypass Tests', () {
    test('Default QA bypass mode is inactive', () {
      expect(StorageService.isSpvQaBypassActive(), isFalse);
    });

    test('Toggle QA bypass mode persists in storage', () async {
      await StorageService.setSpvQaBypassMode(true);
      expect(StorageService.isSpvQaBypassActive(), isTrue);

      await StorageService.setSpvQaBypassMode(false);
      expect(StorageService.isSpvQaBypassActive(), isFalse);
    });

    test('When QA bypass is active, min work duration is zero and isEligibleForAutoPulang is true', () async {
      const shift2 = 'Shift 2 (10:00 - 18:00)';
      final checkInTime = DateTime(2026, 10, 6, 10, 0);

      // Inactive mode: only 1 hour worked, should be false
      await StorageService.setSpvQaBypassMode(false);
      expect(
        AbsensiSetupService.isEligibleForAutoPulang(
          shift: shift2,
          checkInTime: checkInTime,
          currentTime: DateTime(2026, 10, 6, 11, 0),
        ),
        isFalse,
      );
      expect(
        AbsensiSetupService.getMinimumWorkDuration(shift2),
        const Duration(hours: 8),
      );

      // Active mode: 1 hour worked, should be true (bypass 8 hours)
      await StorageService.setSpvQaBypassMode(true);
      expect(
        AbsensiSetupService.isEligibleForAutoPulang(
          shift: shift2,
          checkInTime: checkInTime,
          currentTime: DateTime(2026, 10, 6, 11, 0),
        ),
        isTrue,
      );
      expect(
        AbsensiSetupService.getMinimumWorkDuration(shift2),
        Duration.zero,
      );
      expect(
        AbsensiSetupService.getRemainingWorkTime(
          shift: shift2,
          checkInTime: checkInTime,
          currentTime: DateTime(2026, 10, 6, 11, 0),
        ),
        Duration.zero,
      );
    });

    test('When QA bypass is active, AI vision immediately returns sesuai (Auto-Ijo)', () async {
      final template = TemplateRepository.defaultTemplates.firstWhere(
        (t) => t.jenis == TemplateCategory.absensi,
      );

      // Active mode: returns SESUAI without network call
      await StorageService.setSpvQaBypassMode(true);
      final result = await AiVisionService.verifyPhoto(
        template: template,
        imageBase64: 'dummy_base64_string',
      );

      expect(result.status, VerificationStatus.sesuai);
      expect(result.isApproved, isTrue);
      expect(result.confidenceScore, 1.0);
      expect(result.poinGagal, isEmpty);
      expect(result.poinLolos, isNotEmpty);
      expect(result.alasan, contains('Root QA SPV'));
      expect(result.providerName, contains('Root QA Engine'));
    });
  });
}
