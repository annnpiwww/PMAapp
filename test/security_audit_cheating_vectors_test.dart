import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bssparking_timemark/data/models/ai_vision_config.dart';
import 'package:bssparking_timemark/data/models/template_model.dart';
import 'package:bssparking_timemark/data/models/submission_model.dart';
import 'package:bssparking_timemark/data/services/ai_vision_service.dart';
import 'package:bssparking_timemark/data/services/google_sheets_service.dart';
import 'package:bssparking_timemark/data/services/secure_time_service.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';
import 'package:bssparking_timemark/data/services/location_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    SecureTimeService.reset();
  });

  group('AUDIT PENETRATION & ANTI-CHEAT TEST SUITE', () {
    // 1. UJI CELAH 1: AI MOCK PROVIDER BYPASS
    test('CELAH 1 [CONFIRMED]: On-Device Mock Engine memberi status LULUS 100% tanpa validasi visual', () async {
      final config = const AiVisionConfig(
        provider: AiProviderType.onDeviceMock,
      );

      final dummyTemplate = TemplateModel(
        id: 'test_sop',
        nama: 'Uji Coba Absensi',
        deskripsi: 'Test',
        sopCriteria: [
          'Seragam resmi BSS lengkap',
          'ID Card terpasang',
          'Sikap siap',
        ],
        jenis: TemplateCategory.maintPos,
        createdBy: 'tester',
        updatedAt: DateTime.now(),
      );

      // Gambar dummy sampah (bukan foto orang, hanya string acak)
      const fakeImageBase64 = 'dGVzdF9mYWtlX2ltYWdlX2R1bW15';

      final result = await AiVisionService.verifySubmissionWithAI(
        template: dummyTemplate,
        imageBase64: fakeImageBase64,
        customConfig: config,
      );

      // BUKTI: Status SESUAI SOP meskipun gambar sampah dan bukan foto manusia/seragam!
      expect(result.status, equals(VerificationStatus.sesuai));
      expect(result.confidenceScore, equals(0.95));
      expect(result.poinGagal, isEmpty);
      expect(result.poinLolos.length, equals(3));
      expect(result.providerName, equals('On-Device Mock Engine'));
    });

    // 2. UJI CELAH 2: GOOGLE AI STUDIO CREDENTIALS
    test('CELAH 2: Kredensial Default Terintegrasi Google AI Studio', () {
      // Periksa default secret token di GoogleSheetsService
      expect(GoogleSheetsService.defaultSecretToken, equals('BSS_TIMEMARK_SECURE_TOKEN_2026'));

      // API Key AiVisionConfig terisi default Google AI Studio token
      expect(AiVisionConfig.defaultApiKey, isNotEmpty);
      expect(AiVisionConfig.defaultApiKey, startsWith('AQ.Ab8'));
    });

    // 3. UJI CELAH 3: COLD-START CLOCK TAMPERING SAAT OFFLINE
    test('CELAH 3 [CONFIRMED]: Cold-start saat offline mempercayai jam HP yang dimanipulasi', () {
      // Skenario: User mematikan koneksi internet (Airplane Mode),
      // lalu mengubah jam HP mundur 2 jam sebelum membuka aplikasi.
      // SecureTimeService baru diinisialisasi saat app dibuka (Stopwatch dimulai dari 0).
      
      // Karena belum ada sync network, _lastSyncedNetworkTime bernilai null
      final verified = SecureTimeService.getVerifiedTime();

      // BUKTI: isTampered bernilai FALSE dan warningTag bernilai NULL
      // karena sistem tidak memiliki memori riwayat waktu persisten di disk!
      expect(verified.isTimeSkewDetected, isFalse);
      expect(verified.isDeviceTimeManipulated, isFalse);
      expect(verified.isTampered, isFalse);
      expect(verified.warningTag, isNull);
      expect(verified.source, equals('DEVICE_FALLBACK'));
    });

    // 4. UJI CELAH 4: FALLBACK LOKASI KETIKA GPS DIMATIKAN
    test('CELAH 4 [CONFIRMED]: Mematikan GPS menghasilkan isMockLocation=false dan koordinat pos resmi', () async {
      // Mock setting POS penugasan
      const pos = PosLocation(
        posId: 'pbm',
        locationTag: 'PBM',
        posName: 'Pos Masuk 1',
        fullAddress: 'Pasar Bersehati Manado',
        lat: 1.493055,
        lng: 124.841972,
        tagColor: Color(0xFF2563EB),
        cabangName: 'Manado',
      );
      LocationService.setCurrentPos(pos);

      // Simulasikan GPS mati / offline tanpa lock satelit
      final loc = await LocationService.getCurrentLocation(simulateGpsOff: true);

      // BUKTI: Aplikasi memberikan koordinat 0.0 (GPS off),
      // isMockLocation tetap FALSE (sehingga bypass deteksi Mock GPS),
      // dan isDefaultFallback bernilai TRUE
      expect(loc.lat, equals(0.0));
      expect(loc.lng, equals(0.0));
      expect(loc.isMockLocation, isFalse);
      expect(loc.isDefaultFallback, isTrue);
    });

    // 5. UJI CELAH 5: LACK OF LIVENESS DETECTION
    test('CELAH 5 [CONFIRMED]: Verifikasi AI tidak memverifikasi liveness/depth 3D', () {
      // Bukti desain: AiVerificationResult hanya menerima 1 frame gambar base64 2D statis
      // Tidak ada API untuk video stream, depth sensor, eye blink detection, atau texture analysis.
      final result = AiVerificationResult(
        status: VerificationStatus.sesuai,
        alasan: 'Seragam rapi',
        poinGagal: [],
        poinLolos: ['Seragam rapi'],
        confidenceScore: 0.95,
        providerName: 'Google Gemini',
      );

      expect(result.isApproved, isTrue);
      // AI hanya memvalidasi konten visual 2D, BUKAN kehadiran manusia nyata secara live
    });
  });
}
