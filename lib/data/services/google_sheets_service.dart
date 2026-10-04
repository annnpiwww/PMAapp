import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/maintenance_submission.dart';
import '../models/template_model.dart';
import 'whatsapp_report_service.dart';
import 'secure_time_service.dart';

class GoogleSheetsService {
  static const String _kAppsScriptUrl = 'bss_google_sheets_script_url_v1';
  static const String _kSpreadsheetUrl = 'bss_google_spreadsheet_url_v1';
  static const String _kPendingQueue = 'bss_pending_gsheet_queue_v1';
  static const String _kSecretToken = 'bss_google_sheets_secret_token_v1';

  /// Target Spreadsheet Resmi BSS Maintenance:
  /// https://docs.google.com/spreadsheets/d/1b-ifRsQzt1yfyoBxgx5fV3pveYkXAHyt3LwW4xS7eqg/edit?hl=id&gid=0#gid=0
  static const String defaultSpreadsheetUrl =
      'https://docs.google.com/spreadsheets/d/1b-ifRsQzt1yfyoBxgx5fV3pveYkXAHyt3LwW4xS7eqg/edit?hl=id&gid=0#gid=0';

  static const String defaultAppsScriptUrl =
      'https://script.google.com/macros/s/AKfycbwtVVR3uDpylNyEDvXsgnMI-lQ9R6D9I8xyIphhtC_T5ZAXlbD9_xJBIkDX143OPO4Z-Q/exec';

  /// Default secret auth token untuk mencegah unauthorized submission ke Webhook Google Apps Script
  static const String defaultSecretToken = String.fromEnvironment(
    'BSS_GSHEET_TOKEN',
    defaultValue: 'BSS_TIMEMARK_SECURE_TOKEN_2026',
  );

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

  static Future<String> getAppsScriptUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_kAppsScriptUrl) ?? defaultAppsScriptUrl;
    } catch (_) {
      return defaultAppsScriptUrl;
    }
  }

  static Future<void> saveAppsScriptUrl(String url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kAppsScriptUrl, url.trim());
    } catch (_) {}
  }

  static Future<String> getSpreadsheetUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_kSpreadsheetUrl) ?? defaultSpreadsheetUrl;
    } catch (_) {
      return defaultSpreadsheetUrl;
    }
  }

  static Future<void> saveSpreadsheetUrl(String url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kSpreadsheetUrl, url.trim());
    } catch (_) {}
  }

  /// Sinkronisasi otomatis data maintenance ke Google Sheets (Database SPV)
  /// Mengirimkan data terstruktur: tanggal, lokasi, teknisi, perangkat,
  /// jumlah poin lolos, dan daftar masalah/perbaikan yang ditemukan.
  static Future<bool> syncMaintenanceToGoogleSheet({
    required MaintenanceSubmission submission,
    required TemplateCategory category,
    int? unitCount,
  }) async {
    try {
      final url = await getAppsScriptUrl();
      if (url.isEmpty) return false;

      final uri = Uri.parse(url);
      final secretToken = await getSecretToken();

      // Kumpulkan temuan masalah (poin tidakSesuai atau perluCekManual) dengan bullet rapi
      final issues = submission.points
          .where((p) =>
              p.status == PointStatus.tidakSesuai ||
              p.status == PointStatus.perluCekManual)
          .map((p) => '⚠️ ${p.label}: ${p.alasan.isNotEmpty ? p.alasan : "Perlu perbaikan"}')
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

      final payload = {
        'action': 'sync_maintenance',
        'authToken': secretToken,
        'secretToken': secretToken,
        'id': submission.id,
        // Sesuai 5 kolom utama Google Sheet
        'tanggal': tanggalDisplay,
        'lokasi': fullLokasi,
        'itSupport': itSupportName,
        'approve': poinLolos.isNotEmpty ? poinLolos.join('\n') : '-',
        'perluPerbaikan': issues.isNotEmpty ? issues.join('\n') : '-',
        // Metadata tambahan
        'perangkat': submission.templateName,
        'totalPoin': submission.totalPoints,
        'poinLolosCount': submission.sesuaiCount,
        'poinMasalahCount': issues.length,
        'isTimeTampered': isTimeTampered,
        'timeWarning': timeWarning,
        'timestamp': DateTime.now().toIso8601String(),
      };

      debugPrint('[GoogleSheets] Mengirim data maintenance ${submission.id} ke GSheet (Secured Token)...');

      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'X-Auth-Token': secretToken,
              'Authorization': 'Bearer $secretToken',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 12));

      debugPrint('[GoogleSheets] Response status: ${response.statusCode}');
      final success = response.statusCode >= 200 && response.statusCode < 300;
      if (success) {
        // Jika berhasil, coba flush antrean offline yang tertunda jika ada
        unawaited(flushPendingQueue());
      } else {
        await _enqueuePendingPayload(payload);
      }
      return success;
    } catch (e) {
      debugPrint('[GoogleSheets] Gagal sync ke GSheet (Offline / RTO): $e. Menyimpan ke antrean offline.');
      // Simpan ke antrean lokal agar tidak hilang saat teknisi di basement/dead-zone
      try {
        final secretToken = await getSecretToken();
        final now = submission.createdAt.toLocal();
        final dateStr = WhatsAppReportService.formatIndonesianDate(now);
        final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} WITA';
        final isTimeTampered = SecureTimeService.isTampered;
        final timeWarning = isTimeTampered ? SecureTimeService.warningTag ?? '[JAM DIUBAH MANUAL]' : null;
        final tanggalDisplay = timeWarning != null ? '$dateStr $timeStr $timeWarning' : '$dateStr $timeStr';

        await _enqueuePendingPayload({
          'action': 'sync_maintenance',
          'authToken': secretToken,
          'secretToken': secretToken,
          'id': submission.id,
          'tanggal': tanggalDisplay,
          'lokasi': submission.posName,
          'itSupport': submission.userName,
          'approve': submission.points.where((p) => p.status == PointStatus.sesuai).map((p) => '✓ ${p.label}').join('\n'),
          'perluPerbaikan': submission.points.where((p) => p.status != PointStatus.sesuai && p.status != PointStatus.belumFoto).map((p) => '⚠️ ${p.label}: ${p.alasan}').join('\n'),
          'isTimeTampered': isTimeTampered,
          'timeWarning': timeWarning,
          'timestamp': DateTime.now().toIso8601String(),
        });
      } catch (_) {}
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

      for (final item in listStr) {
        try {
          final res = await http.post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'X-Auth-Token': secretToken,
              'Authorization': 'Bearer $secretToken',
            },
            body: item,
          ).timeout(const Duration(seconds: 10));

          if (res.statusCode >= 200 && res.statusCode < 300) {
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
      debugPrint('[GoogleSheets] Antrean offline terkirim: $flushedCount, tersisa: ${remaining.length}');
      return flushedCount;
    } catch (_) {
      return 0;
    }
  }
}
