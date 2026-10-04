import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/daily_task_model.dart';
import '../services/storage_service.dart';
import '../services/location_service.dart';

class DailyTaskService {
  static const String _defaultBaseUrl = 'https://bssparking.trakingduit.my.id';

  /// Realtime notifier untuk badge angka tugas pending teknisi aktif di Sidebar Drawer
  static final ValueNotifier<int> pendingCountNotifier = ValueNotifier<int>(0);

  static void updatePendingCount(int count) {
    if (pendingCountNotifier.value != count) {
      pendingCountNotifier.value = count;
    }
  }

  static String get baseUrl {
    // Bisa dioverride dari storage jika admin ganti domain
    final custom = StorageService.getString('custom_pocketbase_url');
    if (custom != null && custom.isNotEmpty) return custom;
    return const String.fromEnvironment('POCKETBASE_URL', defaultValue: _defaultBaseUrl);
  }

  static String? _authToken;
  static String? get authToken => _authToken ?? StorageService.getString('pb_auth_token');

  static void setAuthToken(String? token) {
    _authToken = token;
    if (token != null) {
      StorageService.setString('pb_auth_token', token);
    } else {
      StorageService.remove('pb_auth_token');
    }
  }

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (authToken != null && authToken!.isNotEmpty) 'Authorization': authToken!,
  };

  /// Ambil daftar tugas harian untuk teknisi tertentu (semua tugas pending + tugas hari ini)
  static Future<List<DailyTaskModel>> getTasksForTeknisi({
    required String tanggal,
    required String teknisiNama,
  }) async {
    try {
      // Ambil tugas yang pending atau bertanggal hari ini agar tidak hilang karena timezone
      final uri = Uri.parse('$baseUrl/api/collections/daily_tasks/records').replace(
        queryParameters: {
          'filter': '(status="pending" || tanggal="$tanggal")',
          'sort': '-id',
          'perPage': '100',
        },
      );
      final res = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final items = (data['items'] as List?) ?? [];
        final allTasks = items.map((e) => DailyTaskModel.fromJson(e as Map<String, dynamic>)).toList();

        final cleanTarget = teknisiNama.trim().toLowerCase();
        final list = allTasks.where((t) {
          final tName = t.teknisiNama.trim().toLowerCase();
          if (cleanTarget.isEmpty) return true;
          if (tName == cleanTarget) return true;
          if (tName.contains(cleanTarget) || cleanTarget.contains(tName)) return true;
          final targetParts = cleanTarget.split(' ').where((p) => p.length >= 3);
          for (final p in targetParts) {
            if (tName.contains(p)) return true;
          }
          final nameParts = tName.split(' ').where((p) => p.length >= 3);
          for (final p in nameParts) {
            if (cleanTarget.contains(p)) return true;
          }
          return false;
        }).toList();

        // Sort descending by id (tugas terbaru di atas)
        list.sort((a, b) => b.id.compareTo(a.id));

        // Cache ke local storage untuk offline access di basement
        await _cacheTasksLocally(list);
        debugPrint('[DailyTaskService] getTasksForTeknisi: loaded ${list.length}/${allTasks.length} tasks for "$teknisiNama"');
        return list;
      } else {
        debugPrint('[DailyTaskService] getTasksForTeknisi failed: ${res.statusCode} ${res.body}');
      }
    } catch (e) {
      debugPrint('[DailyTaskService] getTasks error, fallback local: $e');
    }
    // Offline fallback
    return getCachedTasksLocally();
  }

  /// SPV: Ambil semua tugas hari ini dari seluruh teknisi
  static Future<List<DailyTaskModel>> getAllTasksToday(String tanggal) async {
    try {
      final uri = Uri.parse('$baseUrl/api/collections/daily_tasks/records').replace(
        queryParameters: {
          'filter': 'tanggal="$tanggal"',
          'sort': '-id',
          'perPage': '100',
        },
      );
      final res = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final items = (data['items'] as List?) ?? [];
        final list = items.map((e) => DailyTaskModel.fromJson(e as Map<String, dynamic>)).toList();
        list.sort((a, b) => b.id.compareTo(a.id));
        return list;
      } else {
        debugPrint('[DailyTaskService] getAllTasksToday failed: ${res.statusCode} ${res.body}');
      }
    } catch (e) {
      debugPrint('[DailyTaskService] getAllTasksToday error: $e');
    }
    return [];
  }

  /// SPV: Buat tugas baru untuk teknisi
  static Future<DailyTaskModel?> createTask({
    required String tanggal,
    required String teknisiNama,
    required String posName,
    required String posTag,
    required String judul,
    String deskripsi = '',
    String kategori = 'khusus',
    String? templateId,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/collections/daily_tasks/records');
      final body = jsonEncode({
        'tanggal': tanggal,
        'teknisi_nama': teknisiNama,
        'pos_name': posName,
        'pos_tag': posTag,
        'judul': judul,
        'deskripsi': deskripsi,
        'kategori': kategori,
        'template_id': templateId,
        'status': 'pending',
      });
      final res = await http.post(uri, headers: _headers, body: body).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        return DailyTaskModel.fromJson(jsonDecode(res.body));
      }
    } catch (e) {
      debugPrint('[DailyTaskService] createTask error: $e');
    }
    return null;
  }

  /// Teknisi: Tandai tugas selesai dan upload foto bukti (mendukung multiple foto)
  static Future<bool> completeTask({
    required String taskId,
    required String jamSelesai,
    String? catatan,
    String? localPhotoPath,
    List<String>? localPhotoPaths,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/collections/daily_tasks/records/$taskId');
      
      final photosToUpload = <String>[];
      if (localPhotoPaths != null && localPhotoPaths.isNotEmpty) {
        for (final p in localPhotoPaths) {
          if (p.isNotEmpty && File(p).existsSync()) {
            photosToUpload.add(p);
          }
        }
      } else if (localPhotoPath != null && File(localPhotoPath).existsSync()) {
        photosToUpload.add(localPhotoPath);
      }

      if (photosToUpload.isNotEmpty) {
        final request = http.MultipartRequest('PATCH', uri);
        if (authToken != null && authToken!.isNotEmpty) {
          request.headers['Authorization'] = authToken!;
        }
        request.fields['status'] = 'completed';
        request.fields['jam_selesai'] = jamSelesai;
        if (catatan != null && catatan.isNotEmpty) {
          request.fields['catatan_teknisi'] = catatan;
        }

        for (int i = 0; i < photosToUpload.length; i++) {
          final filePath = photosToUpload[i];
          request.files.add(await http.MultipartFile.fromPath(
            'foto_bukti',
            filePath,
            filename: 'bukti_${i + 1}_${DateTime.now().millisecondsSinceEpoch}.jpg',
          ));
        }

        final streamed = await request.send().timeout(const Duration(seconds: 40));
        final respBody = await streamed.stream.bytesToString();
        final success = streamed.statusCode == 200;
        if (!success) {
          debugPrint('[DailyTaskService] completeTask multipart failed: ${streamed.statusCode} $respBody');
        }
        return success;
      } else {
        final body = jsonEncode({
          'status': 'completed',
          'jam_selesai': jamSelesai,
          if (catatan != null && catatan.isNotEmpty) 'catatan_teknisi': catatan,
        });
        final res = await http.patch(uri, headers: _headers, body: body).timeout(const Duration(seconds: 10));
        final success = res.statusCode == 200;
        if (!success) {
          debugPrint('[DailyTaskService] completeTask patch failed: ${res.statusCode} ${res.body}');
        }
        return success;
      }
    } catch (e) {
      debugPrint('[DailyTaskService] completeTask error: $e');
      return false;
    }
  }

  static String _formatTanggalIndo(String rawDate) {
    try {
      final parts = rawDate.split('-');
      if (parts.length == 3) {
        final year = parts[0];
        final monthInt = int.tryParse(parts[1]) ?? 1;
        final day = parts[2].padLeft(2, '0');
        const months = [
          'januari', 'februari', 'maret', 'april', 'mei', 'juni',
          'juli', 'agustus', 'september', 'oktober', 'november', 'desember'
        ];
        final monthName = (monthInt >= 1 && monthInt <= 12) ? months[monthInt - 1] : parts[1];
        return '$day $monthName $year';
      }
    } catch (_) {}
    return rawDate;
  }

  static String _resolveTag(String lokasi, String? posTag) {
    if (posTag != null && posTag.trim().isNotEmpty) {
      return posTag.trim();
    }
    final match = RegExp(r'\(([^)]+)\)').firstMatch(lokasi);
    if (match != null && match.group(1) != null) {
      return match.group(1)!.trim();
    }
    final found = LocationService.findPosByTagOrName(lokasi);
    if (found != null && found.locationTag.isNotEmpty) {
      return found.locationTag;
    }
    return lokasi.trim();
  }

  /// Format mikro pelaporan per-task: Dokumentasi + Notes langsung dikirim dengan foto
  static String formatPerTaskReport({
    required String judul,
    required String notes,
  }) {
    final cleanNotes = notes.trim().isNotEmpty ? notes.trim() : '-';
    return '''Dokumentasi: ${judul.trim()}
Notes: $cleanNotes''';
  }

  /// Format makro pelaporan rekapitulasi harian (hanya teks ringkasan)
  static String formatFinalDailyReport({
    required String teknisiNama,
    required String tanggal,
    required String lokasi,
    String? posTag,
    required List<DailyTaskModel> completedTasks,
    required List<DailyTaskModel> pendingTasks,
    String? notes,
  }) {
    final tglIndo = _formatTanggalIndo(tanggal);
    final tagLokasi = _resolveTag(lokasi, posTag);

    final sb = StringBuffer();
    sb.writeln('Laporan Daily Hari ini');
    sb.writeln('Teknisi : ${teknisiNama.trim()}');
    sb.writeln('Tanggal : $tglIndo');
    sb.writeln('Lokasi : $tagLokasi');
    sb.writeln('');
    sb.writeln('Daftar list pekerjaan :');

    if (completedTasks.isEmpty) {
      sb.writeln('(Belum ada pekerjaan yang diselesaikan)');
    } else {
      for (int i = 0; i < completedTasks.length; i++) {
        final t = completedTasks[i];
        final jam = (t.jamSelesai != null && t.jamSelesai!.isNotEmpty) ? t.jamSelesai! : 'Selesai';
        sb.writeln('${i + 1}. ${t.judul} (Selesai $jam)');
        if (t.catatanTeknisi != null && t.catatanTeknisi!.trim().isNotEmpty) {
          sb.writeln('   ${t.catatanTeknisi!.trim()}');
        }
      }
    }

    if (pendingTasks.isNotEmpty) {
      sb.writeln('');
      sb.writeln('Pekerjaan Belum Selesai :');
      for (final p in pendingTasks) {
        sb.writeln('- ${p.judul} (Pending)');
      }
    }

    sb.writeln('');
    sb.writeln('Status : ${completedTasks.length} Selesai, ${pendingTasks.length} Pending');
    sb.writeln('-----');
    sb.writeln('Notes:');
    sb.write((notes != null && notes.trim().isNotEmpty) ? notes.trim() : '-');

    return sb.toString();
  }

  /// Format ringkas laporan lama untuk backward compatibility
  static String formatShortReport({
    required String teknisiNama,
    required String tanggal,
    required String lokasi,
    String? posTag,
    required String pekerjaan,
    required String jamSelesai,
    String? catatan,
  }) {
    final tglIndo = _formatTanggalIndo(tanggal);
    final tagLokasi = _resolveTag(lokasi, posTag);
    final note = (catatan != null && catatan.trim().isNotEmpty) ? catatan.trim() : '-';

    return '''Laporan Daily Hari ini
Teknisi : $teknisiNama
Tanggal : $tglIndo
Lokasi : $tagLokasi
Pekerjaan : $pekerjaan
Status : Selesai ($jamSelesai)
-----
Catatan :
$note''';
  }

  // --- Local Cache Management (Untuk Sinyal Basement) ---
  static const String _localTasksKey = 'cached_daily_tasks';

  static Future<void> _cacheTasksLocally(List<DailyTaskModel> list) async {
    final raw = jsonEncode(list.map((e) => e.toJson()).toList());
    await StorageService.setString(_localTasksKey, raw);
  }

  static List<DailyTaskModel> getCachedTasksLocally() {
    final raw = StorageService.getString(_localTasksKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List;
      return decoded.map((e) => DailyTaskModel.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }
}
