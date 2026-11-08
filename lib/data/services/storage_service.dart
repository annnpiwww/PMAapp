import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/template_model.dart';
import '../models/submission_model.dart';
import '../models/maintenance_submission.dart';
import '../models/user_model.dart';
import '../models/ai_vision_config.dart';
import '../models/watermark_config.dart';
import '../models/attendance_record.dart';
import '../../core/utils/web_photo_store/web_photo_store.dart';
import 'location_service.dart';

class StorageService {
  static const String _keyUser = 'bss_current_user';
  static const String _keyTemplates = 'bss_templates_v4';
  static const String _keySubmissions = 'bss_submissions';
  static const String _keyAiVisionConfig = 'bss_ai_vision_config';
  static const String _keyCustomLocations = 'bss_custom_locations';
  static const String _keyLocationImportQueue = 'bss_location_import_queue_v1';
  static const String _keyLocationHasSyncedRemote = 'bss_location_has_synced_remote_v1';
  static const String _keyTechniciansCache = 'bss_technicians_cache_v1';
  static const String _keyTechniciansSyncedRemote = 'bss_technicians_synced_remote_v1';
  static const String _keyWatermarkConfig = 'bss_watermark_config';
  static const String _keyMaintenanceSubmissions = 'bss_maintenance_submissions';
  static const String _keyAttendanceRecords = 'bss_attendance_records_v1';
  static const String _keyLastTechnicianName = 'bss_last_technician_name_v1';
  static const String _keyLastCheckInTime = 'bss_last_check_in_time_v1';
  static const String _keyHasSeenTutorial = 'bss_has_seen_tutorial_v1';
  static const String _keyCameraTimerSeconds = 'bss_camera_timer_seconds_v1';
  static const String _keyThemeMode = 'bss_theme_mode_v1';
  static const String _keyKnownPendingTaskIds = 'bss_known_pending_task_ids_v1';
  static const String _keySpvTechShifts = 'bss_spv_tech_shifts_v1';

  /// Mode Demo: bypass timer durasi kerja minimal 8 jam / 4 jam untuk testing & demo.
  static bool isDemoBypassActive() {
    return const bool.fromEnvironment('BSS_DEMO_MODE', defaultValue: false);
  }

  static SharedPreferences? _prefs;

  static Future<void> init() async {
    final newPrefs = await SharedPreferences.getInstance();
    // Invalidate in-memory caches when binding a new SharedPreferences instance (CODE-17)
    if (_prefs != newPrefs) {
      _prefs = newPrefs;
      _submissionsCache = null;
      _attendanceRecordsCache = null;
      _maintenanceSubmissionsCache = null;
      _rawMaintenanceJsonList = null;
    }
    // Sisa pref bypass QA dari versi lama dibersihkan sekali di sini.
    await _prefs?.remove('bss_spv_qa_bypass_mode_v1');
  }

  // --- GENERIC KEY VALUE HELPERS ---
  static String? getString(String key) => _prefs?.getString(key);
  static Future<bool>? setString(String key, String val) => _prefs?.setString(key, val);
  static List<String>? getStringList(String key) => _prefs?.getStringList(key);
  static Future<bool>? setStringList(String key, List<String> val) => _prefs?.setStringList(key, val);
  static bool? getBool(String key) => _prefs?.getBool(key);
  static Future<bool>? setBool(String key, bool val) => _prefs?.setBool(key, val);
  static Future<bool>? remove(String key) {
    if (key == _keyAttendanceRecords) {
      _attendanceRecordsCache = null;
    } else if (key == _keySubmissions) {
      _submissionsCache = null;
    } else if (key == _keyMaintenanceSubmissions) {
      _maintenanceSubmissionsCache = null;
      _rawMaintenanceJsonList = null;
    }
    return _prefs?.remove(key);
  }

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
          // F-03: pakai isAfter(subtract 24h) agar tepat 24j edge inclusive; inHours<24 hilang via trunc
          final cutoff = now.subtract(const Duration(hours: 24));
          final isRecent = s.timestampCapture.isAfter(cutoff);
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
        // F-03: 24h edge fix — Duration check bukan inHours trunc
        if (parsed.isAfter(DateTime.now().subtract(const Duration(hours: 24)))) {
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
      // F-03: Duration 24h edge fix
      return lastCheckIn != null && lastCheckIn.isAfter(DateTime.now().subtract(const Duration(hours: 24)));
    }
    final now = DateTime.now();

    DateTime? latestMasuk;
    DateTime? latestPulang;

    for (final s in submissions) {
      // F-03: pakai isAfter cutoff untuk tepat 24j edge
      final isRecent = s.timestampCapture.isAfter(now.subtract(const Duration(hours: 24)));
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
    return lastCheckIn != null && lastCheckIn.isAfter(now.subtract(const Duration(hours: 24)));
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

  // --- IN-MEMORY CACHES (CODE-17 & CODE-18) ---
  static List<SubmissionModel>? _submissionsCache;
  @visibleForTesting
  static int submissionsDecodeCountForTesting = 0;

  static List<AttendanceRecord>? _attendanceRecordsCache;
  @visibleForTesting
  static int attendanceRecordsDecodeCountForTesting = 0;

  static List<MaintenanceSubmission>? _maintenanceSubmissionsCache;
  static List<Map<String, dynamic>>? _rawMaintenanceJsonList;
  @visibleForTesting
  static int maintenanceSaveCountForTesting = 0;

  @visibleForTesting
  static void resetForTesting() {
    _submissionsCache = null;
    _attendanceRecordsCache = null;
    _maintenanceSubmissionsCache = null;
    _rawMaintenanceJsonList = null;
    submissionsDecodeCountForTesting = 0;
    attendanceRecordsDecodeCountForTesting = 0;
    maintenanceSaveCountForTesting = 0;
  }

  // --- SUBMISSIONS ---
  static Future<void> saveSubmissions(List<SubmissionModel> submissions) async {
    await init();
    // Pruning otomatis: simpan maksimal 150 riwayat terbaru (urut berdasarkan createdAt descending)
    final sorted = List<SubmissionModel>.from(submissions)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final pruned = sorted.length > maxStoredSubmissions
        ? sorted.sublist(0, maxStoredSubmissions)
        : sorted;
    _submissionsCache = pruned;
    final listJson = pruned.map((s) => s.toJson()).toList();
    await _prefs?.setString(_keySubmissions, jsonEncode(listJson));
  }

  static List<SubmissionModel>? getSubmissions() {
    if (_submissionsCache != null) return _submissionsCache;
    final str = _prefs?.getString(_keySubmissions);
    if (str == null) return null;
    try {
      submissionsDecodeCountForTesting++;
      final decoded = jsonDecode(str) as List<dynamic>;
      _submissionsCache = decoded
          .map((e) => SubmissionModel.fromJson(e as Map<String, dynamic>))
          .toList();
      return _submissionsCache;
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

      // MIGRATION: Force-overwrite legacy endpoint / model -> default model aktif (Google Cloud AI).
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
        // 2026-10-23: 3.6-flash kena kuota free tier cuma 20 request/hari.
        // 2026-11-05: 3.1-flash-lite terus 503 (high demand), pindah ke
        // AiVisionConfig.defaultCustomModel.
        'gemini-3.6-flash',
        'gemini-3.1-flash-lite',
        'google/gemini-3.1-flash-lite',
        'agy/gemini-3.1-flash-lite',
        'ollama-cloud/gemma4:31b',
        'ollama-cloud/minimax-m3',
        'Minimax/MiniMaxAI/MiniMax-M3',
        'ocrgambar',
      };
      final isLegacyModel = legacyModels.contains(raw.modelName);

      // Migrasi key lama: prefix sk- (Omniroute/OpenAI), mengandung omniroute,
      // atau key bawaan lama (53 karakter berawalan AQ.) yang dulu tersimpan di lokal.
      final trimmedKey = raw.apiKey.trim();
      final isOldEmbeddedKey =
          trimmedKey.length == 53 && trimmedKey.startsWith('AQ.');
      final isLegacyKey = trimmedKey.startsWith('sk-') ||
          trimmedKey.toLowerCase().contains('omniroute') ||
          isOldEmbeddedKey;

      // Migrasi timeout lama: jika di storage masih 10s atau < 25s, upgrade ke 25s
      final isLowTimeout = raw.timeoutSeconds < AiVisionConfig.perModelTimeoutSeconds;
      final isLowMaxTokens = raw.maxTokens < 800;

      if (isLegacyUrl || isLegacyModel || isLegacyKey || isLowTimeout || isLowMaxTokens) {
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
          timeoutSeconds: isLowTimeout
              ? AiVisionConfig.perModelTimeoutSeconds
              : raw.timeoutSeconds,
          maxTokens: isLowMaxTokens ? 800 : raw.maxTokens,
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

  static List<PosLocation> getLocationImportQueue() {
    final str = _prefs?.getString(_keyLocationImportQueue);
    if (str == null || str.isEmpty) return [];
    try {
      final decoded = jsonDecode(str) as List<dynamic>;
      return decoded
          .map((e) => PosLocation.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveLocationImportQueue(List<PosLocation> queue) async {
    await init();
    final listJson = queue.map((loc) => loc.toJson()).toList();
    await _prefs?.setString(_keyLocationImportQueue, jsonEncode(listJson));
  }

  static bool hasLocationSyncedRemote() {
    return _prefs?.getBool(_keyLocationHasSyncedRemote) ?? false;
  }

  static Future<void> setLocationSyncedRemote(bool value) async {
    await init();
    await _prefs?.setBool(_keyLocationHasSyncedRemote, value);
  }

  // --- MAINTENANCE SUBMISSIONS (per-point) ---
  static Future<void> saveMaintenanceSubmissions(List<MaintenanceSubmission> list) async {
    await init();
    maintenanceSaveCountForTesting++;
    // Pruning otomatis: simpan maksimal 150 riwayat maintenance terbaru (urut timestamp descending)
    final sorted = List<MaintenanceSubmission>.from(list)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final pruned = sorted.length > maxStoredSubmissions
        ? sorted.sublist(0, maxStoredSubmissions)
        : sorted;
    _maintenanceSubmissionsCache = pruned;
    final j = pruned.map((e) => e.toJson()).toList();
    _rawMaintenanceJsonList = j;
    await _prefs?.setString(_keyMaintenanceSubmissions, jsonEncode(j));
  }

  static List<MaintenanceSubmission>? getMaintenanceSubmissions() {
    if (_maintenanceSubmissionsCache != null) return _maintenanceSubmissionsCache;
    final str = _prefs?.getString(_keyMaintenanceSubmissions);
    if (str == null) return null;
    try {
      final d = jsonDecode(str) as List<dynamic>;
      _rawMaintenanceJsonList = d.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      _maintenanceSubmissionsCache = _rawMaintenanceJsonList!
          .map((e) => MaintenanceSubmission.fromJson(e))
          .toList();
      return _maintenanceSubmissionsCache;
    } catch (_) {
      return null;
    }
  }

  /// Incremental per-draft upsert (CODE-18):
  /// Only serializes [submission], preserving existing raw JSON for all other drafts.
  static Future<void> upsertMaintenanceSubmission(MaintenanceSubmission submission) async {
    await init();
    maintenanceSaveCountForTesting++;
    if (_rawMaintenanceJsonList == null) {
      getMaintenanceSubmissions();
    }
    _rawMaintenanceJsonList ??= [];
    _maintenanceSubmissionsCache ??= [];

    final rawJson = submission.toJson();
    final rawIdx = _rawMaintenanceJsonList!.indexWhere((e) => e['id'] == submission.id);
    if (rawIdx >= 0) {
      _rawMaintenanceJsonList![rawIdx] = rawJson;
    } else {
      _rawMaintenanceJsonList!.insert(0, rawJson);
      _rawMaintenanceJsonList!.sort((a, b) {
        final aTime = DateTime.tryParse(a['createdAt']?.toString() ?? '') ?? DateTime(1970);
        final bTime = DateTime.tryParse(b['createdAt']?.toString() ?? '') ?? DateTime(1970);
        return bTime.compareTo(aTime);
      });
      if (_rawMaintenanceJsonList!.length > maxStoredSubmissions) {
        _rawMaintenanceJsonList!.removeRange(maxStoredSubmissions, _rawMaintenanceJsonList!.length);
      }
    }

    final cacheIdx = _maintenanceSubmissionsCache!.indexWhere((e) => e.id == submission.id);
    if (cacheIdx >= 0) {
      _maintenanceSubmissionsCache![cacheIdx] = submission;
    } else {
      _maintenanceSubmissionsCache!.insert(0, submission);
      _maintenanceSubmissionsCache!.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (_maintenanceSubmissionsCache!.length > maxStoredSubmissions) {
        _maintenanceSubmissionsCache!.removeRange(maxStoredSubmissions, _maintenanceSubmissionsCache!.length);
      }
    }

    await _prefs?.setString(_keyMaintenanceSubmissions, jsonEncode(_rawMaintenanceJsonList));
  }

  static Future<void> deleteMaintenanceSubmission(String id) async {
    final list = getMaintenanceSubmissions() ?? [];
    list.removeWhere((e) => e.id == id);
    _maintenanceSubmissionsCache = list;
    _rawMaintenanceJsonList?.removeWhere((e) => e['id'] == id);
    await saveMaintenanceSubmissions(list);
  }

  static Future<void> deleteSubmission(String id) async {
    final list = getSubmissions() ?? [];
    list.removeWhere((e) => e.id == id);
    _submissionsCache = list;
    await saveSubmissions(list);
  }

  // --- CUSTOM CARD TEMPLATES ---


  // --- ATTENDANCE RECORDS ---
  static List<AttendanceRecord> getAttendanceRecords() {
    if (_attendanceRecordsCache != null) return _attendanceRecordsCache!;

    attendanceRecordsDecodeCountForTesting++;
    // 1. Coba baca sebagai JSON String
    final str = _prefs?.getString(_keyAttendanceRecords);
    if (str != null && str.isNotEmpty) {
      try {
        final decoded = jsonDecode(str) as List<dynamic>;
        final list = decoded
            .map((e) => AttendanceRecord.fromJson(e as Map<String, dynamic>))
            .toList();
        list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        _attendanceRecordsCache = list;
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
        _attendanceRecordsCache = list;
        return list;
      } catch (_) {}
    }

    _attendanceRecordsCache = [];
    return [];
  }

  static Future<void> _saveAttendanceRecordsInternal(List<AttendanceRecord> records) async {
    await init();
    _attendanceRecordsCache = records;
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
      await deletePhotoBlob(r.id);
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
      await deletePhotoBlob(r.id);
      if (!kIsWeb && r.photoPath != null && r.photoPath!.isNotEmpty) {
        try {
          final file = File(r.photoPath!);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (_) {}
      }
    }
    _attendanceRecordsCache = [];
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
      await deletePhotoBlob(record.id);
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
    await clearAllPhotoBlobs();
    _attendanceRecordsCache = [];
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

  // --- SPV TECHNICIAN SHIFTS PREFERENCES ---
  static Map<String, String> getSpvTechShifts() {
    final raw = _prefs?.getString(_keySpvTechShifts);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          return decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
        }
      } catch (_) {}
    }
    return <String, String>{};
  }

  static Future<void> saveSpvTechShift(String techName, String shift) async {
    await init();
    final map = getSpvTechShifts();
    map[techName.trim()] = shift.trim();
    await _prefs?.setString(_keySpvTechShifts, jsonEncode(map));
  }

  // --- TECHNICIANS CACHE & REMOTE SYNC FLAG ---
  static bool hasTechniciansSyncedRemote() {
    return _prefs?.getBool(_keyTechniciansSyncedRemote) ?? false;
  }

  static Future<void> setTechniciansSyncedRemote(bool value) async {
    await init();
    await _prefs?.setBool(_keyTechniciansSyncedRemote, value);
  }

  static Map<String, List<String>> getTechniciansCache() {
    final raw = _prefs?.getString(_keyTechniciansCache);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          final res = <String, List<String>>{};
          for (final entry in decoded.entries) {
            if (entry.value is List) {
              res[entry.key.toString()] = (entry.value as List)
                  .map((e) => e.toString())
                  .toList();
            }
          }
          return res;
        }
      } catch (_) {}
    }
    return <String, List<String>>{};
  }

  static Future<void> saveTechniciansCache(Map<String, List<String>> cache) async {
    await init();
    await _prefs?.setString(_keyTechniciansCache, jsonEncode(cache));
  }
}

/// Hasil verifikasi PIN teknisi (anti brute-force).
