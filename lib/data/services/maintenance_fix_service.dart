import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/maintenance_temuan_fix.dart';
import '../repositories/auth_repository.dart';
import 'daily_task_service.dart';
import 'maintenance_log_service.dart';
import 'storage_service.dart';

enum FixSubmitStatus { synced, queued, invalid }

class FixSubmitResult {
  final FixSubmitStatus status;
  final MaintenanceTemuanFix? fix;
  final String? message;

  const FixSubmitResult._({
    required this.status,
    this.fix,
    this.message,
  });

  factory FixSubmitResult.synced(MaintenanceTemuanFix fix) =>
      FixSubmitResult._(status: FixSubmitStatus.synced, fix: fix);

  factory FixSubmitResult.queued(MaintenanceTemuanFix fix) =>
      FixSubmitResult._(status: FixSubmitStatus.queued, fix: fix);

  factory FixSubmitResult.invalid(String message) =>
      FixSubmitResult._(status: FixSubmitStatus.invalid, message: message);

  bool get isSuccess =>
      status == FixSubmitStatus.synced || status == FixSubmitStatus.queued;
}

class MaintenanceFixService {
  static const String tableName = 'maintenance_temuan_fixes';
  static const String outboxKey = 'pending_temuan_fixes';

  @visibleForTesting
  static http.Client? clientOverride;

  static Future<http.Response> _get(
    Uri uri, {
    Map<String, String>? headers,
  }) =>
      clientOverride?.get(uri, headers: headers) ??
      http.get(uri, headers: headers);

  static Future<http.Response> _post(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) =>
      clientOverride?.post(uri, headers: headers, body: body) ??
      http.post(uri, headers: headers, body: body);

  static String _generateFixId() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final rnd = Random().nextInt(0x10000).toRadixString(16).padLeft(4, '0');
    return 'fix_${now}_$rnd';
  }

  static List<Map<String, dynamic>> _readOutbox() {
    final raw = StorageService.getString(outboxKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _writeOutbox(List<Map<String, dynamic>> list) async {
    await StorageService.setString(outboxKey, jsonEncode(list));
  }

  /// Daftar perbaikan lokal yang masih berada di outbox (belum tersinkron ke server).
  static List<MaintenanceTemuanFix> pendingLocal() {
    return _readOutbox()
        .map((m) => MaintenanceTemuanFix.fromLocalJson(m))
        .toList();
  }

  /// Mengambil daftar perbaikan untuk kumpulan `logIds`.
  /// Melakukan chunking per 80 id dan menggabungkan dengan outbox pending lokal.
  static Future<Map<String, MaintenanceTemuanFix>> fetchForLogs(
    List<String> logIds,
  ) async {
    unawaited(flushPending());

    final result = <String, MaintenanceTemuanFix>{};
    final distinctIds = logIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    for (int i = 0; i < distinctIds.length; i += 80) {
      final chunk = distinctIds.sublist(i, min(i + 80, distinctIds.length));
      final encodedIds =
          chunk.map((id) => Uri.encodeQueryComponent(id)).join(',');
      final uri = Uri.parse(
        '${DailyTaskService.baseUrl}/rest/v1/$tableName?log_id=in.($encodedIds)&select=*',
      );

      try {
        final response = await _get(
          uri,
          headers: {
            'apikey': DailyTaskService.anonKey,
            'Authorization': 'Bearer ${DailyTaskService.anonKey}',
          },
        ).timeout(const Duration(seconds: 12));

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final decoded = jsonDecode(response.body);
          if (decoded is List) {
            for (final row in decoded) {
              if (row is Map) {
                final fix = MaintenanceTemuanFix.fromJson(
                  Map<String, dynamic>.from(row),
                );
                result[fix.key] = fix;
              }
            }
          }
        } else {
          debugPrint(
            '[MaintenanceFixService] fetchForLogs HTTP ${response.statusCode}: ${response.body}',
          );
        }
      } catch (e) {
        debugPrint('[MaintenanceFixService] fetchForLogs error: $e');
      }
    }

    // Merge dengan pending lokal: pending hanya masuk jika belum ada remote row
    for (final local in pendingLocal()) {
      result.putIfAbsent(local.key, () => local);
    }

    return result;
  }

  /// Mengirimkan perbaikan temuan.
  /// Validasi input, simpan ke outbox lokal terlebih dahulu, upload foto bukti,
  /// dan POST row ke database Supabase.
  static Future<FixSubmitResult> submitFix({
    required MaintenanceLogEntry log,
    required MaintenanceTemuan temuan,
    required String catatan,
    required List<String> photoPaths,
  }) async {
    final trimmedCatatan = catatan.trim();
    if (trimmedCatatan.length < 3 || trimmedCatatan.length > 500) {
      return FixSubmitResult.invalid(
        'Catatan tindakan harus diisi antara 3 sampai 500 karakter.',
      );
    }

    if (photoPaths.isEmpty || photoPaths.length > 3) {
      return FixSubmitResult.invalid(
        'Wajib sertakan 1 sampai 3 foto bukti perbaikan.',
      );
    }

    final id = _generateFixId();
    // Yang memperbaiki = user aktif (bisa beda dari teknisi yang menemukan temuan).
    final user = AuthRepository.instance.currentUser;
    final lastTech = StorageService.getLastTechnicianName().trim();
    final fixerNama = lastTech.isNotEmpty ? lastTech : (user?.nama ?? log.teknisiNama);
    final fix = MaintenanceTemuanFix(
      id: id,
      logId: log.id,
      temuanLabel: temuan.label,
      posId: log.posId,
      posName: log.posName,
      branch: log.branch,
      teknisiNama: fixerNama,
      teknisiNpp: user?.npp ?? '',
      catatan: trimmedCatatan,
      photoUrls: List<String>.from(photoPaths),
      fixedAt: DateTime.now(),
      pendingSync: true,
    );

    // 1. Simpan ke outbox lokal terlebih dahulu
    final outbox = _readOutbox();
    outbox.removeWhere(
      (e) => e['logId'] == fix.logId && e['temuanLabel'] == fix.temuanLabel,
    );
    outbox.add(fix.toLocalJson());
    await _writeOutbox(outbox);

    // 2. Coba upload foto dan insert ke remote
    try {
      final uploadedUrls = <String>[];
      for (int i = 0; i < photoPaths.length; i++) {
        final p = photoPaths[i];
        if (p.startsWith('http://') || p.startsWith('https://')) {
          uploadedUrls.add(p);
        } else {
          final url = await DailyTaskService.uploadProofPhoto(
            p,
            keyPrefix: id,
            index: i,
          );
          if (url == null) {
            return FixSubmitResult.queued(fix);
          }
          uploadedUrls.add(url);
        }
      }

      final syncedFix = fix.copyWith(
        photoUrls: uploadedUrls,
        pendingSync: false,
      );

      final postUri = Uri.parse(
        '${DailyTaskService.baseUrl}/rest/v1/$tableName',
      );
      final response = await _post(
        postUri,
        headers: {
          'apikey': DailyTaskService.anonKey,
          'Authorization': 'Bearer ${DailyTaskService.anonKey}',
          'Content-Type': 'application/json',
          'Prefer': 'resolution=ignore-duplicates,return=minimal',
        },
        body: jsonEncode(syncedFix.toRow()),
      ).timeout(const Duration(seconds: 15));

      if ((response.statusCode >= 200 && response.statusCode < 300) ||
          response.statusCode == 409) {
        // Hapus dari outbox karena sudah berhasil tersimpan
        final updatedOutbox = _readOutbox()
          ..removeWhere((e) => e['id'] == id);
        await _writeOutbox(updatedOutbox);
        return FixSubmitResult.synced(syncedFix);
      } else {
        debugPrint(
          '[MaintenanceFixService] submitFix POST ${response.statusCode}: ${response.body}',
        );
        return FixSubmitResult.queued(fix);
      }
    } catch (e) {
      debugPrint('[MaintenanceFixService] submitFix network error: $e');
      return FixSubmitResult.queued(fix);
    }
  }

  /// Mengirim ulang item perbaikan yang tertunda di outbox.
  static Future<void> flushPending() async {
    final items = _readOutbox();
    if (items.isEmpty) return;

    final remaining = <Map<String, dynamic>>[];
    for (final raw in items) {
      try {
        final fix = MaintenanceTemuanFix.fromLocalJson(raw);
        final uploadedUrls = <String>[];
        bool uploadFailed = false;

        for (int i = 0; i < fix.photoUrls.length; i++) {
          final p = fix.photoUrls[i];
          if (p.startsWith('http://') || p.startsWith('https://')) {
            uploadedUrls.add(p);
          } else {
            final url = await DailyTaskService.uploadProofPhoto(
              p,
              keyPrefix: fix.id,
              index: i,
            );
            if (url == null) {
              uploadFailed = true;
              break;
            }
            uploadedUrls.add(url);
          }
        }

        if (uploadFailed) {
          final updated = Map<String, dynamic>.from(raw);
          if (uploadedUrls.isNotEmpty) {
            updated['photoUrls'] = [
              ...uploadedUrls,
              ...fix.photoUrls.sublist(uploadedUrls.length),
            ];
          }
          remaining.add(updated);
          continue;
        }

        final syncedFix = fix.copyWith(
          photoUrls: uploadedUrls,
          pendingSync: false,
        );

        final postUri = Uri.parse(
          '${DailyTaskService.baseUrl}/rest/v1/$tableName',
        );
        final response = await _post(
          postUri,
          headers: {
            'apikey': DailyTaskService.anonKey,
            'Authorization': 'Bearer ${DailyTaskService.anonKey}',
            'Content-Type': 'application/json',
            'Prefer': 'resolution=ignore-duplicates,return=minimal',
          },
          body: jsonEncode(syncedFix.toRow()),
        ).timeout(const Duration(seconds: 15));

        if ((response.statusCode >= 200 && response.statusCode < 300) ||
            response.statusCode == 409) {
          // Success! Item selesai disinkron
        } else {
          remaining.add(syncedFix.toLocalJson());
        }
      } catch (e) {
        debugPrint('[MaintenanceFixService] flushPending error: $e');
        remaining.add(raw);
      }
    }

    await _writeOutbox(remaining);
  }
}
