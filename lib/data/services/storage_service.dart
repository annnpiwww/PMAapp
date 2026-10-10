import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/template_model.dart';
import '../models/submission_model.dart';
import '../models/maintenance_submission.dart';
import '../models/user_model.dart';
import '../models/ai_vision_config.dart';
import '../models/watermark_config.dart';
import '../models/attendance_record.dart';
import 'location_service.dart';
import 'secure_time_service.dart';

class StorageService {
  static const String _keyUser = 'bss_current_user';
  static const String _keyTemplates = 'bss_templates_v4';
  static const String _keySubmissions = 'bss_submissions';
  static const String _keyAiVisionConfig = 'bss_ai_vision_config';
  static const String _keyCustomLocations = 'bss_custom_locations';
  static const String _keyCardTemplates = 'bss_card_templates';
  static const String _keyWatermarkConfig = 'bss_watermark_config';
  static const String _keyMaintenanceSubmissions = 'bss_maintenance_submissions';
  static const String _keyAttendanceRecords = 'bss_attendance_records_v1';
  static const String _keyTechnicianPin = 'bss_technician_pin_v1';
  static const String _keyTechnicianPinSalt = 'bss_technician_pin_salt_v1';
  static const String _keyPinFailCount = 'bss_pin_fail_count_v1';
  static const String _keyPinLockUntilMs = 'bss_pin_lock_until_v1';
  static const String _keyLastTechnicianName = 'bss_last_technician_name_v1';
  static const String _keyLastCheckInTime = 'bss_last_check_in_time_v1';
  static const String _keyHasSeenTutorial = 'bss_has_seen_tutorial_v1';
  static const String _keyDemoBypassMode = 'bss_demo_bypass_mode_v1';
  static const String _keySpvQaBypassMode = 'bss_spv_qa_bypass_mode_v1';
  static const String _keyCameraTimerSeconds = 'bss_camera_timer_seconds_v1';
  static const String _keyThemeMode = 'bss_theme_mode_v1';
  static const String _keyKnownPendingTaskIds = 'bss_known_pending_task_ids_v1';

  /// Mode QA / Developer SPV Farhan: bypass AI Vision (Auto-Ijo) dan durasi kerja 8 jam untuk testing.
  static bool isSpvQaBypassActive() {
    return _prefs?.getBool(_keySpvQaBypassMode) ?? false;
  }

  static Future<void> setSpvQaBypassMode(bool enabled) async {
    await init();
    await _prefs?.setBool(_keySpvQaBypassMode, enabled);
  }

  /// Mode Demo / SPV Bypass: bypass timer durasi kerja minimal 8 jam / 4 jam untuk testing & demo.
  static bool isDemoBypassActive() {
    final isEnv = const bool.fromEnvironment('BSS_DEMO_MODE', defaultValue: false);
    return isEnv || isSpvQaBypassActive();
  }

  static Future<void> setDemoBypassMode(bool enabled) async {
    await init();
    await _prefs?.setBool(_keyDemoBypassMode, enabled);
  }

  /// Hasil verifikasi PIN teknisi (anti brute-force).
  static const int pinMaxAttempts = 5;
  static const int pinLockSeconds = 60;

  static const int _kPinHashIterations = 1000;
  static const String _kPinConstantSalt = 'BSS_TIMEMARK_PIN_PEPPER_2026';

  /// Multi-round SHA-256 (1.000 iterasi) dengan salt unik + constant pepper
  static String hashPin(String pin, [String? salt]) {
    final effectiveSalt = salt ?? _pinSalt();
    // Round 1: Gabungkan salt + constant pepper + pin
    var digest = sha256.convert(utf8.encode('$effectiveSalt::$_kPinConstantSalt::$pin')).bytes;
    // Multi-round hashing minimal 1.000 iterasi
    for (int i = 1; i < _kPinHashIterations; i++) {
      digest = sha256.convert([...digest, ...utf8.encode(effectiveSalt), i & 0xFF]).bytes;
    }
    return digest.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }


  /// Single-round legacy hash untuk fallback verifikasi PIN lama
  static String _legacyHashPin(String pin, String salt) {
    return sha256.convert(utf8.encode('$salt::$pin')).toString();
  }

  static String _pinSalt() {
    var salt = _prefs?.getString(_keyTechnicianPinSalt);
    if (salt == null || salt.isEmpty) {
      final rnd = Random.secure();
      final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
      final randomHex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      final posName = LocationService.currentPos.posName;
      final posTag = posName.isNotEmpty ? posName.replaceAll(' ', '_') : 'BSS_MAIN_POS';
      salt = '$randomHex::$posTag::$_kPinConstantSalt';
      _prefs?.setString(_keyTechnicianPinSalt, salt);
    }
    return salt;
  }

  /// Migrasi sekali jalan: PIN plaintext lama (4-6 digit) -> hash multi-round SHA-256.
  /// Setelah ini tidak ada PIN plaintext yang tersimpan di device.
  static void _migrateLegacyPin() {
    final stored = _prefs?.getString(_keyTechnicianPin);
    if (stored != null &&
        stored.isNotEmpty &&
        RegExp(r'^[0-9]{4,6}$').hasMatch(stored)) {
      _prefs?.setString(_keyTechnicianPin, hashPin(stored, _pinSalt()));
    }
  }

  /// True jika PIN masih default pabrik — wajib diganti di Profil.
  static bool isTechnicianPinDefault() {
    _migrateLegacyPin();
    final stored = _prefs?.getString(_keyTechnicianPin);
    if (stored == null || stored.isEmpty) return true;
    final salt = _pinSalt();
    return stored == hashPin('123321', salt) || stored == _legacyHashPin('123321', salt);
  }

  static int _pinFailCount() => _prefs?.getInt(_keyPinFailCount) ?? 0;

  static DateTime? pinLockedUntil() {
    final ms = _prefs?.getInt(_keyPinLockUntilMs);
    if (ms == null || ms <= 0) return null;
    final until = DateTime.fromMillisecondsSinceEpoch(ms);
    final verifiedNow = SecureTimeService.getVerifiedTime().accurateTime;
    if (verifiedNow.isAfter(until)) {
      _prefs?.remove(_keyPinLockUntilMs);
      _prefs?.setInt(_keyPinFailCount, 0);
      return null;
    }
    return until;
  }

  static Future<PinVerifyResult> verifyTechnicianPin(String enteredPin) async {
    await init();
    _migrateLegacyPin();
    final lockedUntil = pinLockedUntil();
    final verifiedNow = SecureTimeService.getVerifiedTime().accurateTime;
    if (lockedUntil != null) {
      final secs = lockedUntil.difference(verifiedNow).inSeconds + 1;
      return PinVerifyResult(
        ok: false,
        locked: true,
        retryAfterSeconds: secs,
        message: 'Terlalu banyak percobaan. Coba lagi dalam $secs detik.',
      );
    }
    final pin = enteredPin.trim();
    final stored = _prefs?.getString(_keyTechnicianPin);
    final salt = _pinSalt();
    final expectedNew = (stored == null || stored.isEmpty)
        ? hashPin('123321', salt)
        : stored;
    final isMatchNew = pin.isNotEmpty && hashPin(pin, salt) == expectedNew;
    // Fallback kompatibilitas jika tersimpan hash single-round lama
    final isMatchLegacy = pin.isNotEmpty && stored != null && _legacyHashPin(pin, salt) == stored;

    if (isMatchNew || isMatchLegacy) {
      // Jika lolos verifikasi dengan legacy hash, otomatis upgrade ke multi-round hash
      if (isMatchLegacy) {
        await _prefs?.setString(_keyTechnicianPin, hashPin(pin, salt));
      }
      await _prefs?.setInt(_keyPinFailCount, 0);
      await _prefs?.remove(_keyPinLockUntilMs);
      final isDefault = pin == '123321';
      return PinVerifyResult(
        ok: true,
        isDefaultPin: isDefault,
        message: isDefault
            ? 'PIN masih bawaan (123321). Segera ganti di Profil.'
            : 'PIN sesuai.',
      );
    }
    final fails = _pinFailCount() + 1;
    await _prefs?.setInt(_keyPinFailCount, fails);
    if (fails >= pinMaxAttempts) {
      final until =
          verifiedNow.add(const Duration(seconds: pinLockSeconds));
      await _prefs?.setInt(
          _keyPinLockUntilMs, until.millisecondsSinceEpoch);
      return const PinVerifyResult(
        ok: false,
        locked: true,
        retryAfterSeconds: pinLockSeconds,
        message:
            'PIN salah 5 kali. Akses terkunci selama $pinLockSeconds detik.',
      );
    }
    final left = pinMaxAttempts - fails;
    return PinVerifyResult(
      ok: false,
      remainingAttempts: left,
      message: 'PIN salah. Sisa $left kali percobaan.',
    );
  }

  static Future<void> saveTechnicianPin(String pin) async {
    final clean = pin.trim();
    if (!RegExp(r'^[0-9]{4,6}$').hasMatch(clean)) {
      throw ArgumentError('PIN harus 4-6 digit angka.');
    }
    if (clean == '123321') {
      throw ArgumentError('PIN tidak boleh default 123321.');
    }
    await init();
    await _prefs?.setString(_keyTechnicianPin, hashPin(clean, _pinSalt()));
    await _prefs?.setInt(_keyPinFailCount, 0);
    await _prefs?.remove(_keyPinLockUntilMs);
  }

  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // --- GENERIC KEY VALUE HELPERS ---
  static String? getString(String key) => _prefs?.getString(key);
  static Future<bool>? setString(String key, String val) => _prefs?.setString(key, val);
  static bool? getBool(String key) => _prefs?.getBool(key);
  static Future<bool>? setBool(String key, bool val) => _prefs?.setBool(key, val);
  static Future<bool>? remove(String key) => _prefs?.remove(key);

  // --- TECHNICIAN SUPPORT NAME ---
  static String getLastTechnicianName() {
    return _prefs?.getString(_keyLastTechnicianName) ?? '';
  }

  static Future<void> saveLastTechnicianName(String name) async {
    await init();
    await _prefs?.setString(_keyLastTechnicianName, name);
  }

  // --- CHECK-IN TRACKING TIME (Untuk Shift Tracker) ---
  static DateTime? getLastCheckInTime() {
    // 1. Prioritaskan pengecekan history submissions untuk memastikan status riil sesi aktif:
    try {
      final submissions = getSubmissions();
      if (submissions != null && submissions.isNotEmpty) {
        final now = DateTime.now();
        DateTime? latestMasuk;
        DateTime? latestPulang;

        for (final s in submissions) {
          final isRecent = now.difference(s.timestampCapture).inHours < 24;
          if (!isRecent) continue;

          final isAbsensi = s.templateName.toLowerCase().contains('absensi') ||
              s.absensiKategori != null;
          if (!isAbsensi) continue;

          if (s.tipeLaporan == 'Masuk' &&
              (latestMasuk == null || s.timestampCapture.isAfter(latestMasuk))) {
            latestMasuk = s.timestampCapture;
          } else if (s.tipeLaporan == 'Pulang' &&
              (latestPulang == null || s.timestampCapture.isAfter(latestPulang))) {
            latestPulang = s.timestampCapture;
          }
        }

        // Jika teknisi sudah absen Pulang setelah Masuk, berarti sesi kerja hari ini sudah selesai
        if (latestPulang != null && (latestMasuk == null || latestPulang.isAfter(latestMasuk))) {
          _prefs?.remove(_keyLastCheckInTime);
          return null;
        }

        // Jika ada absen Masuk dan belum ada Pulang setelahnya:
        if (latestMasuk != null) {
          saveLastCheckInTime(latestMasuk);
          return latestMasuk;
        }
      }
    } catch (_) {}

    // 2. Fallback baca langsung dari cache SharedPreferences jika submissions belum termuat:
    final str = _prefs?.getString(_keyLastCheckInTime);
    if (str != null && str.isNotEmpty) {
      try {
        final parsed = DateTime.parse(str);
        if (DateTime.now().difference(parsed).inHours < 24) {
          return parsed;
        }
      } catch (_) {}
    }

    return null;
  }

  static bool hasCheckedInTodayWithoutCheckOut() {
    final submissions = getSubmissions();
    if (submissions == null || submissions.isEmpty) {
      final lastCheckIn = getLastCheckInTime();
      return lastCheckIn != null && DateTime.now().difference(lastCheckIn).inHours < 24;
    }
    final now = DateTime.now();

    DateTime? latestMasuk;
    DateTime? latestPulang;

    for (final s in submissions) {
      final isRecent = now.difference(s.timestampCapture).inHours < 24;
      if (!isRecent) continue;

      final isAbsensi = s.templateName.toLowerCase().contains('absensi') ||
          s.absensiKategori != null;
      if (!isAbsensi) continue;

      if (s.tipeLaporan == 'Masuk' &&
          (latestMasuk == null || s.timestampCapture.isAfter(latestMasuk))) {
        latestMasuk = s.timestampCapture;
      } else if (s.tipeLaporan == 'Pulang' &&
          (latestPulang == null || s.timestampCapture.isAfter(latestPulang))) {
        latestPulang = s.timestampCapture;
      }
    }

    if (latestMasuk != null) {
      return latestPulang == null || latestMasuk.isAfter(latestPulang);
    }
    final lastCheckIn = getLastCheckInTime();
    return lastCheckIn != null && now.difference(lastCheckIn).inHours < 24;
  }

  static Future<void> saveLastCheckInTime(DateTime time) async {
    await init();
    await _prefs?.setString(_keyLastCheckInTime, time.toIso8601String());
  }

  static Future<void> clearLastCheckInTime() async {
    await init();
    await _prefs?.remove(_keyLastCheckInTime);
  }

  // --- DAILY REPORT & HANDOVER TRACKING (ISI DAILY DULU YA) ---
  static const _keyLastDailyReportDate = 'last_daily_report_date';

  static bool isDailyReportCompletedToday() {
    final dateStr = _prefs?.getString(_keyLastDailyReportDate);
    if (dateStr == null) return false;
    final now = DateTime.now();
    final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return dateStr == today;
  }

  static Future<void> markDailyReportCompletedToday() async {
    await init();
    final now = DateTime.now();
    final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    await _prefs?.setString(_keyLastDailyReportDate, today);
  }

  static Future<void> clearDailyReportStatus() async {
    await init();
    await _prefs?.remove(_keyLastDailyReportDate);
  }

  // --- USER SESSION ---
  static Future<void> saveUser(UserModel user) async {
    await init();
    await _prefs?.setString(_keyUser, jsonEncode(user.toJson()));
  }

  static UserModel? getUser() {
    final str = _prefs?.getString(_keyUser);
    if (str == null) return null;
    try {
      return UserModel.fromJson(jsonDecode(str) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearUser() async {
    await init();
    await _prefs?.remove(_keyUser);
  }

  // --- TEMPLATES (SOP) ---
  static Future<void> saveTemplates(List<TemplateModel> templates) async {
    await init();
    final listJson = templates.map((t) => t.toJson()).toList();
    await _prefs?.setString(_keyTemplates, jsonEncode(listJson));
  }

  static List<TemplateModel>? getTemplates() {
    final str = _prefs?.getString(_keyTemplates);
    if (str == null) return null;
    try {
      final decoded = jsonDecode(str) as List<dynamic>;
      return decoded
          .map((e) => TemplateModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null;
    }
  }

  /// Batas maksimal riwayat tersimpan di SharedPreferences untuk menjaga performa & memori HP
  static const int maxStoredSubmissions = 150;

  // --- SUBMISSIONS ---
  static Future<void> saveSubmissions(List<SubmissionModel> submissions) async {
    await init();
    // Pruning otomatis: simpan maksimal 150 riwayat terbaru (urut berdasarkan createdAt descending)
    final sorted = List<SubmissionModel>.from(submissions)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final pruned = sorted.length > maxStoredSubmissions
        ? sorted.sublist(0, maxStoredSubmissions)
        : sorted;
    final listJson = pruned.map((s) => s.toJson()).toList();
    await _prefs?.setString(_keySubmissions, jsonEncode(listJson));
  }

  static List<SubmissionModel>? getSubmissions() {
    final str = _prefs?.getString(_keySubmissions);
    if (str == null) return null;
    try {
      final decoded = jsonDecode(str) as List<dynamic>;
      return decoded
          .map((e) => SubmissionModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null;
    }
  }

  // --- AI VISION CONFIG ---
  static Future<void> saveAiVisionConfig(AiVisionConfig config) async {
    await init();
    await _prefs?.setString(_keyAiVisionConfig, jsonEncode(config.toJson()));
  }

  static AiVisionConfig getAiVisionConfig() {
    final str = _prefs?.getString(_keyAiVisionConfig);
    if (str == null) return AiVisionConfig.defaultConfig();
    try {
      final raw = AiVisionConfig.fromJson(
          jsonDecode(str) as Map<String, dynamic>);

      // MIGRATION: Force-overwrite legacy endpoint / model -> gemini-3.1-flash-lite (Google Cloud AI).
      const oldUrls = [
        'pizza-namespace-brings-desert.trycloudflare.com',
        'bss-tunnel.trycloudflare.com',
        'hermesagent.tailcb6f2e.ts.net',
        'ai.trakingduit.my.id',
        'localhost',
        'omniroute',
      ];
      final isLegacyUrl = oldUrls.any((u) => raw.baseUrl.contains(u)) ||
          ((raw.provider == AiProviderType.customEndpoint ||
                  raw.provider == AiProviderType.geminiVision) &&
              !raw.baseUrl.contains('generativelanguage.googleapis.com'));

      const legacyModels = {
        'gemini-3.7-flash-high',
        'google/gemini-3.1-flash-lite',
        'agy/gemini-3.1-flash-lite',
        'ollama-cloud/gemma4:31b',
        'ollama-cloud/minimax-m3',
        'Minimax/MiniMaxAI/MiniMax-M3',
        'ocrgambar',
      };
      final isLegacyModel = legacyModels.contains(raw.modelName);

      // Migrasi key lama: kosong, prefix sk- (Omniroute/OpenAI), atau mengandung omniroute
      final isLegacyKey = raw.apiKey.trim().isEmpty ||
          raw.apiKey.startsWith('sk-') ||
          raw.apiKey.toLowerCase().contains('omniroute');

      // Migrasi timeout lama: jika di storage masih 10s atau < 25s, upgrade ke 25s
      final isLowTimeout = raw.timeoutSeconds < AiVisionConfig.perModelTimeoutSeconds;

      if (isLegacyUrl || isLegacyModel || isLegacyKey || isLowTimeout) {
        final migrated = raw.copyWith(
          baseUrl: isLegacyUrl
              ? AiVisionConfig.defaultCustomUrl
              : raw.baseUrl,
          modelName: isLegacyModel
              ? AiVisionConfig.defaultCustomModel
              : raw.modelName,
          apiKey: isLegacyKey
              ? AiVisionConfig.defaultApiKey
              : raw.apiKey,
          timeoutSeconds: AiVisionConfig.perModelTimeoutSeconds,
          maxTokens: 350,
          temperature: 0.0,
        );
        // Persist migration synchronously-ish
        saveAiVisionConfig(migrated);
        return migrated;
      }

      return raw;
    } catch (_) {
      return AiVisionConfig.defaultConfig();
    }
  }

  // --- WATERMARK CONFIG (LOGO & CARD STYLES) ---
  static Future<void> saveWatermarkConfig(WatermarkConfig config) async {
    await init();
    await _prefs?.setString(_keyWatermarkConfig, jsonEncode(config.toJson()));
  }

  static WatermarkConfig getWatermarkConfig() {
    final str = _prefs?.getString(_keyWatermarkConfig);
    if (str == null) return const WatermarkConfig();
    try {
      final cfg = WatermarkConfig.fromJson(jsonDecode(str) as Map<String, dynamic>);
      bool modified = false;
      var updated = cfg;

      // Migrasi: jika badgeTag masih 'PBM/PKM', ganti ke 'Absensi' dan scale 50% di kiri bawah
      if (updated.badgeTag == 'PBM/PKM') {
        updated = updated.copyWith(
          badgeTag: 'Absensi',
          scale: updated.scale == 1.0 ? 0.5 : updated.scale,
          positionX: 0.0,
          positionY: 1.0,
        );
        modified = true;
      }

      // Migrasi: jika posisi masih memakai default lama (0.04, 0.82 / 0.78), update ke standar pojok kiri bawah (0.0, 1.0)
      if ((updated.positionX - 0.04).abs() < 0.02 &&
          ((updated.positionY - 0.82).abs() < 0.03 || (updated.positionY - 0.78).abs() < 0.03)) {
        updated = updated.copyWith(
          positionX: 0.0,
          positionY: 1.0,
        );
        modified = true;
      }

      // Migrasi: hapus permanen judul Absensi — paksa showTitle false jika masih true
      if (updated.elements.showTitle == true) {
        updated = updated.copyWith(elements: updated.elements.copyWith(showTitle: false), customTitle: '');
        modified = true;
      }

      // Migrasi: cegah kebocoran tag cabang Bali (misal PCD) jika cabang aktif adalah KC Manado
      final currentBranchCode = _prefs?.getString('app_branch');
      final isManado = currentBranchCode == null || currentBranchCode == 'manado';
      const baliTags = {
        'PCD', 'PBKD', 'PKRD', 'PAS', 'PSD', 'PGA', 'TBB', 'TBG', 'KIH',
        'BMS', 'BMK', 'SPD', 'GYS', 'PBB', 'RSPM'
      };
      if (isManado && baliTags.contains(updated.badgeTag.trim().toUpperCase())) {
        updated = updated.copyWith(badgeTag: 'Absensi');
        modified = true;
      }

      if (modified) {
        saveWatermarkConfig(updated);
      }
      return updated;
    } catch (_) {
      return const WatermarkConfig();
    }
  }

  // --- ONBOARDING / FEATURE TUTORIAL (FIRST-TIME INSTALL ONLY) ---
  static bool hasSeenTutorial() {
    return _prefs?.getBool(_keyHasSeenTutorial) ?? false;
  }

  static Future<void> setHasSeenTutorial(bool value) async {
    await init();
    await _prefs?.setBool(_keyHasSeenTutorial, value);
  }

  // --- CUSTOM USER-MANAGED LOCATIONS ---
  static Future<void> saveLocations(List<PosLocation> locations) async {
    await init();
    final listJson = locations.map((loc) => loc.toJson()).toList();
    await _prefs?.setString(_keyCustomLocations, jsonEncode(listJson));
  }

  static List<PosLocation>? getLocations() {
    final str = _prefs?.getString(_keyCustomLocations);
    if (str == null) return null;
    try {
      final decoded = jsonDecode(str) as List<dynamic>;
      return decoded
          .map((e) => PosLocation.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null;
    }
  }

  // --- MAINTENANCE SUBMISSIONS (per-point) ---
  static Future<void> saveMaintenanceSubmissions(List<MaintenanceSubmission> list) async {
    await init();
    // Pruning otomatis: simpan maksimal 150 riwayat maintenance terbaru (urut timestamp descending)
    final sorted = List<MaintenanceSubmission>.from(list)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final pruned = sorted.length > maxStoredSubmissions
        ? sorted.sublist(0, maxStoredSubmissions)
        : sorted;
    final j = pruned.map((e) => e.toJson()).toList();
    await _prefs?.setString(_keyMaintenanceSubmissions, jsonEncode(j));
  }

  static List<MaintenanceSubmission>? getMaintenanceSubmissions() {
    final str = _prefs?.getString(_keyMaintenanceSubmissions);
    if (str == null) return null;
    try {
      final d = jsonDecode(str) as List<dynamic>;
      return d.map((e) => MaintenanceSubmission.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return null;
    }
  }

  static Future<void> deleteMaintenanceSubmission(String id) async {
    final list = getMaintenanceSubmissions() ?? [];
    list.removeWhere((e) => e.id == id);
    await saveMaintenanceSubmissions(list);
  }

  static Future<void> clearMaintenanceSubmissions() async {
    await saveMaintenanceSubmissions([]);
  }

  static Future<void> deleteSubmission(String id) async {
    final list = getSubmissions() ?? [];
    list.removeWhere((e) => e.id == id);
    await saveSubmissions(list);
  }

  // --- CUSTOM CARD TEMPLATES ---
  static Future<void> saveCardTemplates(List<Map<String, dynamic>> templates) async {
    await init();
    await _prefs?.setString(_keyCardTemplates, jsonEncode(templates));
  }

  static List<Map<String, dynamic>>? getCardTemplates() {
    final str = _prefs?.getString(_keyCardTemplates);
    if (str == null) return null;
    try {
      final decoded = jsonDecode(str) as List<dynamic>;
      return decoded.map((e) => e as Map<String, dynamic>).toList();
    } catch (_) {
      return null;
    }
  }

  // --- ATTENDANCE RECORDS ---
  static List<AttendanceRecord> getAttendanceRecords() {
    // 1. Coba baca sebagai JSON String
    final str = _prefs?.getString(_keyAttendanceRecords);
    if (str != null && str.isNotEmpty) {
      try {
        final decoded = jsonDecode(str) as List<dynamic>;
        final list = decoded
            .map((e) => AttendanceRecord.fromJson(e as Map<String, dynamic>))
            .toList();
        list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        return list;
      } catch (_) {}
    }

    // 2. Fallback baca sebagai List<String>
    final strList = _prefs?.getStringList(_keyAttendanceRecords);
    if (strList != null && strList.isNotEmpty) {
      try {
        final list = strList
            .map((e) => AttendanceRecord.fromJson(jsonDecode(e) as Map<String, dynamic>))
            .toList();
        list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        return list;
      } catch (_) {}
    }

    return [];
  }

  static Future<void> _saveAttendanceRecordsInternal(List<AttendanceRecord> records) async {
    await init();
    final listJson = records.map((r) => r.toJson()).toList();
    await _prefs?.setString(_keyAttendanceRecords, jsonEncode(listJson));
  }

  static Future<void> saveAttendanceRecord(AttendanceRecord record) async {
    await init();
    final existing = getAttendanceRecords();
    final index = existing.indexWhere((r) => r.id == record.id);
    if (index != -1) {
      existing[index] = record;
    } else {
      existing.insert(0, record);
    }
    existing.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    await _saveAttendanceRecordsInternal(existing);
    await autoPruneAttendanceRecords(retentionDays: 30);
  }

  static Future<void> deleteAttendanceRecord(String id) async {
    await init();
    final existing = getAttendanceRecords();
    final target = existing.where((r) => r.id == id).toList();
    for (final r in target) {
      if (!kIsWeb && r.photoPath != null && r.photoPath!.isNotEmpty) {
        try {
          final file = File(r.photoPath!);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (_) {}
      }
    }
    existing.removeWhere((r) => r.id == id);
    await _saveAttendanceRecordsInternal(existing);
  }

  /// Menghapus seluruh riwayat absensi dan file fotonya secara atomik (O(N) single disk write).
  static Future<void> clearAllAttendanceRecords() async {
    await init();
    final existing = getAttendanceRecords();
    for (final r in existing) {
      if (!kIsWeb && r.photoPath != null && r.photoPath!.isNotEmpty) {
        try {
          final file = File(r.photoPath!);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (_) {}
      }
    }
    await _prefs?.remove(_keyAttendanceRecords);
  }

  static Future<void> autoPruneAttendanceRecords({int retentionDays = 30}) async {
    await init();
    final records = getAttendanceRecords();
    if (records.isEmpty) return;

    final now = DateTime.now();
    final cutoff = now.subtract(Duration(days: retentionDays));

    final keptRecords = <AttendanceRecord>[];
    final prunedRecords = <AttendanceRecord>[];

    for (final record in records) {
      if (record.timestamp.isBefore(cutoff)) {
        prunedRecords.add(record);
      } else {
        keptRecords.add(record);
      }
    }

    // Hapus file foto dari record yang dipangkas
    for (final record in prunedRecords) {
      if (!kIsWeb && record.photoPath != null && record.photoPath!.isNotEmpty) {
        try {
          final file = File(record.photoPath!);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (_) {}
      }
    }

    // Untuk record yang masih tersimpan, periksa file foto jika modified > retentionDays
    for (final record in keptRecords) {
      if (!kIsWeb && record.photoPath != null && record.photoPath!.isNotEmpty) {
        try {
          final file = File(record.photoPath!);
          if (await file.exists()) {
            final stat = await file.stat();
            if (now.difference(stat.modified).inDays >= retentionDays) {
              await file.delete();
            }
          }
        } catch (_) {}
      }
    }

    await _saveAttendanceRecordsInternal(keptRecords);
  }

  static Future<void> clearAttendanceRecords() async {
    await init();
    await _prefs?.remove(_keyAttendanceRecords);
  }

  /// Lock & simpan preferensi timer kamera secara persisten
  static int getCameraTimerSeconds() {
    return _prefs?.getInt(_keyCameraTimerSeconds) ?? 0;
  }

  static Future<void> saveCameraTimerSeconds(int seconds) async {
    await init();
    await _prefs?.setInt(_keyCameraTimerSeconds, seconds);
  }

  /// Preferensi tema tampilan (light, dark, system)
  static String getThemeMode() {
    return _prefs?.getString(_keyThemeMode) ?? 'system';
  }

  static Future<void> saveThemeMode(String mode) async {
    await init();
    await _prefs?.setString(_keyThemeMode, mode);
  }

  // --- KNOWN PENDING TASK IDS (Untuk Push Alert SPV) ---
  static Set<String> getKnownPendingTaskIds() {
    final list = _prefs?.getStringList(_keyKnownPendingTaskIds);
    if (list != null) return list.toSet();
    return <String>{};
  }

  static Future<void> saveKnownPendingTaskIds(Set<String> ids) async {
    await init();
    await _prefs?.setStringList(_keyKnownPendingTaskIds, ids.toList());
  }

  static Future<void> clearKnownPendingTaskIds() async {
    await init();
    await _prefs?.remove(_keyKnownPendingTaskIds);
  }
}

/// Hasil verifikasi PIN teknisi (anti brute-force).
class PinVerifyResult {
  final bool ok;
  final bool locked;
  final bool isDefaultPin;
  final int remainingAttempts;
  final int retryAfterSeconds;
  final String message;

  const PinVerifyResult({
    required this.ok,
    this.locked = false,
    this.isDefaultPin = false,
    this.remainingAttempts = 0,
    this.retryAfterSeconds = 0,
    this.message = '',
  });
}
