import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/maintenance_submission.dart';
import '../models/template_model.dart';
import '../repositories/auth_repository.dart';
import '../../core/services/logger_service.dart';
import 'daily_task_service.dart';
import 'whatsapp_report_service.dart';
import 'secure_time_service.dart';

class GoogleSheetsService {
  static const String _kAppsScriptUrl = 'bss_google_sheets_script_url_v1';
  static const String _kPendingQueue = 'bss_pending_gsheet_queue_v1';
  static const String _kSecretToken = 'bss_google_sheets_secret_token_v1';


  /// Wajib inject via --dart-define=BSS_GSHEET_SCRIPT_URL=...
  static const String defaultAppsScriptUrl = String.fromEnvironment(
    'BSS_GSHEET_SCRIPT_URL',
  );

  /// Wajib inject via --dart-define=BSS_GSHEET_TOKEN=...
  /// Token auth untuk mencegah unauthorized submission ke Webhook Google Apps Script.
  static const String defaultSecretToken = String.fromEnvironment(
    'BSS_GSHEET_TOKEN',
  );

  /// SEC-08: Formula injection prevention.
  /// Prefixes any cell value starting with [=+\-@\t\r] with a single quote (')
  /// so spreadsheet engines treat it as plain text instead of executing formulas.
  @visibleForTesting
  static String sanitizeForSheet(String value) {
    if (value.isEmpty) return value;
    final firstChar = value[0];
    if (firstChar == '=' ||
        firstChar == '+' ||
        firstChar == '-' ||
        firstChar == '@' ||
        firstChar == '\t' ||
        firstChar == '\r') {
      return "'$value";
    }
    return value;
  }

  static Future<String> getSecretToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_kSecretToken) ?? defaultSecretToken;
    } catch (_) {
      return defaultSecretToken;
    }
  }

  static Future<void> saveSecretToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kSecretToken, token.trim());
    } catch (_) {}
  }

  static String get defaultEndpointUrl =>
      '${DailyTaskService.baseUrl}/functions/v1/sheets-sync';

  static Future<String> getAppsScriptUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final custom = prefs.getString(_kAppsScriptUrl);
      if (custom != null && custom.isNotEmpty) return custom;
      if (defaultAppsScriptUrl.isNotEmpty) return defaultAppsScriptUrl;
      return defaultEndpointUrl;
    } catch (_) {
      return defaultAppsScriptUrl.isNotEmpty ? defaultAppsScriptUrl : defaultEndpointUrl;
    }
  }

  static Future<void> saveAppsScriptUrl(String url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kAppsScriptUrl, url.trim());
    } catch (_) {}
  }



  @visibleForTesting
  static http.Client? clientOverride;

  static Future<http.Response> _post(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) =>
      clientOverride?.post(uri, headers: headers, body: body) ??
      http.post(uri, headers: headers, body: body);

  static bool _isSuccessOrRedirect(int statusCode) =>
      (statusCode >= 200 && statusCode < 300) ||
      statusCode == 302 ||
      statusCode == 303;

  /// Sinkronisasi otomatis data maintenance ke Google Sheets (Database SPV)
  /// Mengirimkan data terstruktur: tanggal, lokasi, teknisi, perangkat,
  /// jumlah poin lolos, dan daftar masalah/perbaikan yang ditemukan.
  static Future<bool> syncMaintenanceToGoogleSheet({
    required MaintenanceSubmission submission,
    required TemplateCategory category,
    int? unitCount,
  }) async {
    Map<String, dynamic>? payload;
    try {
      final url = await getAppsScriptUrl();
      if (url.isEmpty) return false;

      final uri = Uri.parse(url);
      final secretToken = await getSecretToken();

      // CODE-03: perlu_cek_manual bukan temuan; hanya tidakSesuai yang dihitung sebagai masalah
      final issues = submission.points
          .where((p) => p.status == PointStatus.tidakSesuai)
          .map((p) {
            final urgensiTag = p.urgensi == TingkatUrgensi.normal ? '' : ' [${p.urgensi.label.toUpperCase()}]';
            return '⚠️ ${p.label}: ${p.alasan.isNotEmpty ? p.alasan : "Perlu perbaikan"}$urgensiTag';
          })
          .toList();

      // Poin yang memang tidak terpasang / tidak ada di lokasi (bukan temuan)
      final poinTidakTerpasang = submission.points
          .where((p) => p.isTidakTerpasang)
          .map((p) => '⛔ ${p.label}')
          .toList();

      // Poin bertingkat URGENT — dipakai supervisor untuk prioritas perbaikan
      final poinUrgent = submission.points
          .where((p) => p.urgensi == TingkatUrgensi.urgent)
          .map((p) => '🚨 ${p.label}')
          .toList();

      // Kumpulkan daftar poin yang lolos / approve
      final poinLolos = submission.points
          .where((p) => p.status == PointStatus.sesuai)
          .map((p) {
            final reason = p.alasan.isNotEmpty && p.alasan.toLowerCase() != 'sesuai'
                ? ' (${p.alasan})'
                : '';
            return '✓ ${p.label}$reason';
          })
          .toList();

      final now = submission.createdAt.toLocal();
      final dateStr = WhatsAppReportService.formatIndonesianDate(now);
      final timeStr =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} WITA';
      final fullTanggal = '$dateStr $timeStr';

      // Indikator jam diubah manual jika terdeteksi clock skew / fake time
      final isTimeTampered = SecureTimeService.isTampered;
      final timeWarning = isTimeTampered ? SecureTimeService.warningTag ?? '[JAM DIUBAH MANUAL]' : null;
      final tanggalDisplay = timeWarning != null ? '$fullTanggal $timeWarning' : fullTanggal;

      final fullLokasi = submission.cabangName.isNotEmpty &&
              submission.cabangName != submission.posName
          ? '${submission.posName} (${submission.cabangName})'
          : submission.posName;

      final itSupportName = submission.userName.isNotEmpty ? submission.userName : 'Teknisi BSS';

      payload = {
        'action': 'sync_maintenance',
        'secretToken': secretToken,
        'id': submission.id,
        // Sesuai 5 kolom utama Google Sheet (dengan sanitasi formula SEC-08)
        'tanggal': sanitizeForSheet(tanggalDisplay),
        'lokasi': sanitizeForSheet(fullLokasi),
        'itSupport': sanitizeForSheet(itSupportName),
        'approve': sanitizeForSheet(poinLolos.isNotEmpty ? poinLolos.join('\n') : '-'),
        'perluPerbaikan': sanitizeForSheet(issues.isNotEmpty ? issues.join('\n') : '-'),
        // Metadata tambahan
        'perangkat': sanitizeForSheet(submission.templateName),
        'totalPoin': submission.totalPoints,
        'poinLolosCount': submission.sesuaiCount,
        'poinMasalahCount': issues.length,
        'poinTidakTerpasang': sanitizeForSheet(poinTidakTerpasang.isNotEmpty ? poinTidakTerpasang.join('\n') : '-'),
        'poinTidakTerpasangCount': poinTidakTerpasang.length,
        'daftarUrgent': sanitizeForSheet(poinUrgent.isNotEmpty ? poinUrgent.join('\n') : '-'),
        'urgentCount': submission.urgentCount,
        'isTimeTampered': isTimeTampered,
        'timeWarning': timeWarning != null ? sanitizeForSheet(timeWarning) : null,
        'timestamp': DateTime.now().toIso8601String(),
      };

      debugPrint('[GoogleSheets] Mengirim data maintenance ${submission.id} ke GSheet (Secured Token)...');

      final sessionToken = AuthRepository.instance.sessionToken;
      final response = await _post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'apikey': DailyTaskService.anonKey,
              'Authorization': 'Bearer ${DailyTaskService.anonKey}',
              if (sessionToken != null && sessionToken.isNotEmpty)
                'x-app-session': sessionToken,
              if (secretToken.isNotEmpty) 'X-Auth-Token': secretToken,
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 12));

      debugPrint('[GoogleSheets] Response status: ${response.statusCode}');
      final success = _isSuccessOrRedirect(response.statusCode);
      if (success) {
        // Jika berhasil, coba flush antrean offline yang tertunda jika ada
        unawaited(flushPendingQueue());
      } else {
        await _enqueuePendingPayload(payload);
      }
      return success;
    } catch (e) {
      debugPrint('[GoogleSheets] Gagal sync ke GSheet (Offline / RTO): $e. Menyimpan ke antrean offline.');
      // Simpan payload lengkap 19 field ke antrean lokal agar metadata tidak hilang saat offline
      try {
        if (payload != null) {
          await _enqueuePendingPayload(payload);
        }
      } catch (e, stack) {
        LoggerService.error('Failed to sync or enqueue maintenance to Google Sheets', tag: 'GoogleSheetsService', error: e, stackTrace: stack);
      }
      return false;
    }
  }

  /// Menyimpan payload ke antrean lokal saat offline
  static Future<void> _enqueuePendingPayload(Map<String, dynamic> payload) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final listStr = prefs.getStringList(_kPendingQueue) ?? [];
      listStr.add(jsonEncode(payload));
      // Batasi maksimal 50 antrean agar storage aman
      final capped = listStr.length > 50 ? listStr.sublist(listStr.length - 50) : listStr;
      await prefs.setStringList(_kPendingQueue, capped);
      debugPrint('[GoogleSheets] Tersimpan ke antrean offline (${capped.length} antrean).');
    } catch (_) {}
  }

  /// Mengirim ulang semua antrean data yang tertunda saat koneksi kembali online
  static Future<int> flushPendingQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final listStr = prefs.getStringList(_kPendingQueue) ?? [];
      if (listStr.isEmpty) return 0;

      final url = await getAppsScriptUrl();
      if (url.isEmpty) return 0;

      final uri = Uri.parse(url);
      final secretToken = await getSecretToken();
      final remaining = <String>[];
      int flushedCount = 0;

      final sessionToken = AuthRepository.instance.sessionToken;
      for (final item in listStr) {
        try {
          final res = await _post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'apikey': DailyTaskService.anonKey,
              'Authorization': 'Bearer ${DailyTaskService.anonKey}',
              if (sessionToken != null && sessionToken.isNotEmpty)
                'x-app-session': sessionToken,
              if (secretToken.isNotEmpty) 'X-Auth-Token': secretToken,
            },
            body: item,
          ).timeout(const Duration(seconds: 10));

          if (_isSuccessOrRedirect(res.statusCode)) {
            flushedCount++;
          } else if (res.statusCode >= 400 && res.statusCode < 500) {
            // Client error (400 Bad Request / 401 Unauthorized / malformed data):
            // Buang dari antrean agar tidak menyumbat antrean selamanya (anti-poison pill)
            debugPrint('[GoogleSheets] Drop malformed item status ${res.statusCode}');
          } else {
            // Server error (500/502/503/504) atau jaringan sementara: coba lagi berikutnya
            remaining.add(item);
          }
        } catch (_) {
          remaining.add(item);
          break; // Hentikan loop jika masih offline
        }
      }

      await prefs.setStringList(_kPendingQueue, remaining);
      LoggerService.info('Antrean offline terkirim: $flushedCount, tersisa: ${remaining.length}', tag: 'GoogleSheetsService');
      return flushedCount;
    } catch (e, stack) {
      LoggerService.error('Error during flushPendingQueue', tag: 'GoogleSheetsService', error: e, stackTrace: stack);
      return 0;
    }
  }
}
