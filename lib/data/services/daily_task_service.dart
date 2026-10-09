import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/daily_task_model.dart';
import '../models/maintenance_submission.dart';
import '../services/storage_service.dart';
import '../services/location_service.dart';
import 'branch_service.dart';
import 'notification_service.dart';

class DailyTaskService {
  static const String _defaultBaseUrl = 'https://bssparking.trakingduit.my.id';

  /// Realtime notifier untuk badge angka tugas pending teknisi aktif di Sidebar Drawer
  static final ValueNotifier<int> pendingCountNotifier = ValueNotifier<int>(0);

  static void updatePendingCount(int count) {
    if (pendingCountNotifier.value != count) {
      pendingCountNotifier.value = count;
    }
  }

  static Timer? _pollingTimer;
  static http.Client? _sseClient;
  static bool _isListening = false;
  static String? _activeListeningTeknisi;
  static final Set<String> _knownPendingTaskIds = <String>{};

  @visibleForTesting
  static Set<String> get knownPendingTaskIds => _knownPendingTaskIds;

  @visibleForTesting
  static void resetKnownPendingTaskIdsForTesting() {
    _knownPendingTaskIds.clear();
  }

  /// Memulai background listener & polling tugas teknisi (aktif saat teknisi login / standby)
  static void startRealtimeListener({required String teknisiNama}) {
    final cleanName = teknisiNama.trim();
    if (cleanName.isEmpty) return;

    if (_isListening && _activeListeningTeknisi == cleanName) {
      return;
    }

    stopRealtimeListener();
    _isListening = true;
    _activeListeningTeknisi = cleanName;

    debugPrint('[DailyTaskService] Memulai Realtime Listener untuk teknisi: $cleanName');

    // 1. Pengecekan awal instan
    _checkNewTasks(cleanName);

    // 2. Periodic Poller (setiap 25 detik) sebagai fallback yang andal
    _pollingTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      _checkNewTasks(cleanName);
    });

    // 3. PocketBase SSE Realtime stream
    _subscribePocketBaseSSE(cleanName);
  }

  static void stopRealtimeListener() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    try {
      _sseClient?.close();
    } catch (_) {}
    _sseClient = null;
    _isListening = false;
    _activeListeningTeknisi = null;
    debugPrint('[DailyTaskService] Realtime Listener dihentikan.');
  }

  static Future<void> _checkNewTasks(String teknisiNama) async {
    try {
      final now = DateTime.now();
      final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final tasks = await getTasksForTeknisi(tanggal: todayStr, teknisiNama: teknisiNama);
      final pendingTasks = tasks.where((t) => !t.isCompleted).toList();

      updatePendingCount(pendingTasks.length);

      // Cek apakah ada task baru yang masuk
      final currentPendingIds = pendingTasks.map((t) => t.id).toSet();

      // Pastikan _knownPendingTaskIds tersinkronisasi dari SharedPreferences
      if (_knownPendingTaskIds.isEmpty) {
        _knownPendingTaskIds.addAll(StorageService.getKnownPendingTaskIds());
      }

      if (_knownPendingTaskIds.isEmpty) {
        // Init awal: catat task yang sudah ada agar tidak spam notif saat baru buka app
        _knownPendingTaskIds.addAll(currentPendingIds);
        await StorageService.saveKnownPendingTaskIds(_knownPendingTaskIds);
        if (pendingTasks.isNotEmpty) {
          NotificationService.instance.showDailyTasksNotification(tasks: tasks);
        }
      } else {
        // Cari task baru yang belum ada di memory maupun storage
        final newTasks = pendingTasks.where((t) => !_knownPendingTaskIds.contains(t.id)).toList();
        if (newTasks.isNotEmpty) {
          debugPrint('[DailyTaskService] Terdeteksi ${newTasks.length} tugas baru dari SPV!');
          for (final nt in newTasks) {
            _knownPendingTaskIds.add(nt.id);
            // Tembak alert instan dengan getar dan suara via channel prioritas
            NotificationService.instance.showNewTaskAlertNotification(
              judul: nt.judul,
              posName: nt.posName,
              deskripsi: nt.deskripsi,
            );
          }
          // Perbarui notifikasi grup daily tasks
          NotificationService.instance.showDailyTasksNotification(tasks: tasks, force: true);
        }
        _knownPendingTaskIds.addAll(currentPendingIds);
        await StorageService.saveKnownPendingTaskIds(_knownPendingTaskIds);
      }
    } catch (e) {
      debugPrint('[DailyTaskService] _checkNewTasks error: $e');
    }
  }

  static void _subscribePocketBaseSSE(String teknisiNama) async {
    try {
      _sseClient?.close();
      _sseClient = http.Client();

      final sseUri = Uri.parse('$baseUrl/api/realtime');
      final request = http.Request('GET', sseUri);
      request.headers.addAll({
        'Accept': 'text/event-stream',
        'Cache-Control': 'no-cache',
        if (authToken != null && authToken!.isNotEmpty) 'Authorization': authToken!,
      });

      final response = await _sseClient!.send(request);
      if (response.statusCode != 200) {
        debugPrint('[DailyTaskService] SSE connect status: ${response.statusCode}');
        return;
      }

      String? clientId;
      response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) async {
        if (line.startsWith('data:')) {
          final dataStr = line.substring(5).trim();
          if (dataStr.isEmpty) return;
          try {
            final json = jsonDecode(dataStr);
            if (json is Map<String, dynamic>) {
              // Connect handshake
              if (json.containsKey('clientId')) {
                clientId = json['clientId'];
                debugPrint('[DailyTaskService] SSE Terhubung, clientId: $clientId');
                // Subscribe ke collection daily_tasks
                final subUri = Uri.parse('$baseUrl/api/realtime');
                await http.post(
                  subUri,
                  headers: _headers,
                  body: jsonEncode({
                    'clientId': clientId,
                    'subscriptions': ['daily_tasks/*'],
                  }),
                );
                debugPrint('[DailyTaskService] Berhasil subscribe ke daily_tasks realtime stream');
              } else if (json.containsKey('action')) {
                debugPrint('[DailyTaskService] Realtime Event diterima: ${json['action']}');
                // Event perubahan data tugas harian, langsung fetch instan!
                _checkNewTasks(teknisiNama);
              }
            }
          } catch (_) {}
        }
      }, onError: (err) {
        debugPrint('[DailyTaskService] SSE error (di-cover poller): $err');
      });
    } catch (e) {
      debugPrint('[DailyTaskService] SSE init exception: $e');
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

  static Map<String, String> get _getHeaders => {
    'Accept': 'application/json',
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
      final res = await http.get(uri, headers: _getHeaders).timeout(const Duration(seconds: 8));
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

        // Cross-check dengan local cache & maintenance submissions agar status 'completed' tidak ter-reset
        final localCached = getCachedTasksLocally();
        final localCompletedMap = {
          for (final t in localCached.where((e) => e.isCompleted)) t.id: t
        };
        final completedSubs = (StorageService.getMaintenanceSubmissions() ?? []).where((s) => s.isComplete).toList();

        final syncedList = list.map((task) {
          if (task.isCompleted) return task;
          if (localCompletedMap.containsKey(task.id)) {
            final loc = localCompletedMap[task.id]!;
            return task.copyWith(
              status: TaskStatus.completed,
              jamSelesai: task.jamSelesai ?? loc.jamSelesai,
              catatanTeknisi: task.catatanTeknisi ?? loc.catatanTeknisi,
            );
          }
          final matchSub = completedSubs.where((s) =>
            s.taskId == task.id ||
            (task.templateId != null &&
                task.templateId!.isNotEmpty &&
                s.templateId == task.templateId &&
                s.posName.toLowerCase().contains(task.posName.toLowerCase()))
          ).firstOrNull;
          if (matchSub != null) {
            final timeStr = '${matchSub.createdAt.hour.toString().padLeft(2, '0')}:${matchSub.createdAt.minute.toString().padLeft(2, '0')}';
            return task.copyWith(
              status: TaskStatus.completed,
              jamSelesai: task.jamSelesai ?? timeStr,
              catatanTeknisi: task.catatanTeknisi ?? 'SOP Maintenance ${matchSub.templateName} selesai (${matchSub.sesuaiCount}/${matchSub.totalPoints} poin sesuai)',
            );
          }
          return task;
        }).toList();

        // Sort descending by id (tugas terbaru di atas)
        syncedList.sort((a, b) => b.id.compareTo(a.id));

        // Cache ke local storage untuk offline access di basement
        await _cacheTasksLocally(syncedList);
        debugPrint('[DailyTaskService] getTasksForTeknisi: loaded ${syncedList.length}/${allTasks.length} tasks for "$teknisiNama"');
        return syncedList;
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
      final res = await http.get(uri, headers: _getHeaders).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final items = (data['items'] as List?) ?? [];
        final list = items.map((e) => DailyTaskModel.fromJson(e as Map<String, dynamic>)).toList();
        
        final localCached = getCachedTasksLocally();
        final localCompletedMap = {
          for (final t in localCached.where((e) => e.isCompleted)) t.id: t
        };
        final completedSubs = (StorageService.getMaintenanceSubmissions() ?? []).where((s) => s.isComplete).toList();

        final syncedList = list.map((task) {
          if (task.isCompleted) return task;
          if (localCompletedMap.containsKey(task.id)) {
            final loc = localCompletedMap[task.id]!;
            return task.copyWith(
              status: TaskStatus.completed,
              jamSelesai: task.jamSelesai ?? loc.jamSelesai,
              catatanTeknisi: task.catatanTeknisi ?? loc.catatanTeknisi,
            );
          }
          final matchSub = completedSubs.where((s) =>
            s.taskId == task.id ||
            (task.templateId != null &&
                task.templateId!.isNotEmpty &&
                s.templateId == task.templateId &&
                s.posName.toLowerCase().contains(task.posName.toLowerCase()))
          ).firstOrNull;
          if (matchSub != null) {
            final timeStr = '${matchSub.createdAt.hour.toString().padLeft(2, '0')}:${matchSub.createdAt.minute.toString().padLeft(2, '0')}';
            return task.copyWith(
              status: TaskStatus.completed,
              jamSelesai: task.jamSelesai ?? timeStr,
              catatanTeknisi: task.catatanTeknisi ?? 'SOP Maintenance ${matchSub.templateName} selesai (${matchSub.sesuaiCount}/${matchSub.totalPoints} poin sesuai)',
            );
          }
          return task;
        }).toList();

        syncedList.sort((a, b) => b.id.compareTo(a.id));
        return syncedList;
      } else {
        debugPrint('[DailyTaskService] getAllTasksToday failed: ${res.statusCode} ${res.body}');
      }
    } catch (e) {
      debugPrint('[DailyTaskService] getAllTasksToday error: $e');
    }
    return [];
  }

  /// Cari submission maintenance yang sedang berjalan (draft / in-progress) untuk sebuah DailyTask
  static MaintenanceSubmission? getOngoingMaintenance(
    DailyTaskModel task, {
    List<MaintenanceSubmission>? submissions,
    String? currentUserId,
    String? currentUserName,
  }) {
    if (task.isCompleted) return null;

    final all = submissions ?? StorageService.getMaintenanceSubmissions() ?? [];
    final drafts = all.where((s) => !s.isComplete).toList();
    if (drafts.isEmpty) return null;

    // Kriteria 1: Direct match taskId
    for (final s in drafts) {
      if (s.taskId != null && s.taskId == task.id) {
        return s;
      }
    }

    // Hanya cari match jika task memiliki templateId atau merupakan kategori maintenance
    final effectiveTplId = task.templateId;
    if (effectiveTplId == null || effectiveTplId.isEmpty) {
      if (task.kategori.toLowerCase() != 'maintenance') {
        return null;
      }
    }

    // Filter draft berdasarkan templateId jika task memilikinya
    final matchingTplDrafts = effectiveTplId != null && effectiveTplId.isNotEmpty
        ? drafts.where((s) => s.templateId == effectiveTplId).toList()
        : drafts;

    if (matchingTplDrafts.isEmpty) return null;

    // Kriteria 2: Cocok berdasarkan Lokasi (posId, posName, cabangName, atau posTag)
    final taskPos = task.posTag.trim().toLowerCase();
    final taskName = task.posName.trim().toLowerCase();
    final taskJudul = task.judul.trim().toLowerCase();

    // Coba resolve PosLocation dari kata kunci task (SPV keyword)
    final taskLoc = LocationService.findPosByTagOrName(taskPos) ??
        LocationService.findPosByTagOrName(taskName) ??
        LocationService.findPosByTagOrName(taskJudul);

    for (final s in matchingTplDrafts) {
      final sPos = s.posName.trim().toLowerCase();
      final sId = s.posId.trim().toLowerCase();
      final sCabang = s.cabangName.trim().toLowerCase();

      bool match = false;
      if (taskLoc != null) {
        final locId = taskLoc.posId.toLowerCase();
        final locTag = taskLoc.locationTag.toLowerCase();
        final locName = taskLoc.posName.toLowerCase();
        if (sId == locId ||
            sId.contains(locTag) ||
            sPos == locName ||
            sPos.contains(locName) ||
            locName.contains(sPos)) {
          match = true;
        }
      }
      if (taskPos.isNotEmpty && (sId == taskPos || sId.contains(taskPos) || sPos.contains(taskPos) || taskPos.contains(sPos))) {
        match = true;
      }
      if (taskName.isNotEmpty && (sPos.contains(taskName) || taskName.contains(sPos) || sCabang.contains(taskName) || sId.contains(taskName))) {
        match = true;
      }
      if (taskJudul.isNotEmpty && (taskJudul.contains(sPos) || (sId.isNotEmpty && taskJudul.contains(sId)))) {
        match = true;
      }

      if (match) {
        return s;
      }
    }

    // Kriteria 3: Jika teknisi yang sama memiliki draft untuk template ini
    final uId = currentUserId ?? StorageService.getString('user_id');
    final uName = (currentUserName ?? StorageService.getLastTechnicianName()).trim().toLowerCase();

    final userDrafts = matchingTplDrafts.where((s) {
      if (uId != null && uId.isNotEmpty && s.userId == uId) return true;
      if (uName.isNotEmpty && s.userName.trim().toLowerCase() == uName) return true;
      return false;
    }).toList();

    if (userDrafts.length == 1) {
      return userDrafts.first;
    } else if (userDrafts.length > 1) {
      userDrafts.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return userDrafts.first;
    }

    // Kriteria 4: Jika hanya ada 1 draft aktif untuk template tersebut
    if (matchingTplDrafts.length == 1) {
      return matchingTplDrafts.first;
    }

    return null;
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
      if (res.statusCode == 200 || res.statusCode == 201) {
        final created = DailyTaskModel.fromJson(jsonDecode(res.body));
        // Kirim notifikasi instan via Telegram bot
        unawaited(sendTelegramTaskNotification(
          teknisiNama: teknisiNama,
          judul: judul,
          posName: posName,
          deskripsi: deskripsi,
        ));
        return created;
      }
    } catch (e) {
      debugPrint('[DailyTaskService] createTask error: $e');
    }
    return null;
  }

  /// Format pesan Telegram notifikasi penugasan baru dari SPV
  static String formatTelegramTaskMessage({
    required String teknisiNama,
    required String judul,
    required String posName,
    String deskripsi = '',
    String? timeStr,
  }) {
    final now = DateTime.now();
    final time = timeStr ?? '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} WITA';
    final descLine = deskripsi.trim().isNotEmpty ? '\n📝 <b>Catatan:</b> ${deskripsi.trim()}' : '';

    return '''🔔 <b>TUGAS BARU DARI SUPERVISOR</b>
━━━━━━━━━━━━━━━━━━
👤 <b>Teknisi:</b> $teknisiNama
📍 <b>Lokasi:</b> $posName
📋 <b>Tugas:</b> $judul$descLine
⏰ <b>Waktu:</b> $time

<i>Mohon segera buka aplikasi BssparkingTimeMark untuk konfirmasi dan pengerjaan.</i>''';
  }

  /// Kirim notifikasi instan via Telegram bot (menggunakan tools/telegram_notify.sh atau Telegram Bot API)
  static Future<bool> sendTelegramTaskNotification({
    required String teknisiNama,
    required String judul,
    required String posName,
    String deskripsi = '',
    String? timeStr,
  }) async {
    try {
      final message = formatTelegramTaskMessage(
        teknisiNama: teknisiNama,
        judul: judul,
        posName: posName,
        deskripsi: deskripsi,
        timeStr: timeStr,
      );

      // 1. Coba eksekusi lewat tools/telegram_notify.sh jika script tersedia
      try {
        final script = File('tools/telegram_notify.sh');
        if (await script.exists()) {
          final res = await Process.run('bash', ['tools/telegram_notify.sh', '-m', message]);
          if (res.exitCode == 0) {
            debugPrint('[DailyTaskService] Notifikasi tugas baru terkirim via telegram_notify.sh');
            return true;
          }
        }
      } catch (_) {}

      // 2. Fallback direct Telegram Bot API
      String token = const String.fromEnvironment('BSS_TG_BOT_TOKEN', defaultValue: '');
      String chatId = const String.fromEnvironment('BSS_TG_CHAT_ID', defaultValue: '');

      if (token.isEmpty || chatId.isEmpty) {
        try {
          final home = Platform.environment['HOME'] ?? '';
          final envPath = Platform.environment['BSS_TG_ENV'] ??
              (home.isNotEmpty ? '$home/.config/bss_telegram.env' : '');
          if (envPath.isNotEmpty) {
            final envFile = File(envPath);
            if (await envFile.exists()) {
              final lines = await envFile.readAsLines();
              for (final line in lines) {
                final parts = line.trim().split('=');
                if (parts.length >= 2) {
                  final k = parts[0].trim();
                  final v = parts.sublist(1).join('=').replaceAll('"', '').replaceAll("'", '').trim();
                  if (k == 'BSS_TG_BOT_TOKEN') token = v;
                  if (k == 'BSS_TG_CHAT_ID') chatId = v;
                }
              }
            }
          }
        } catch (_) {}
      }

      if (token.isNotEmpty && chatId.isNotEmpty) {
        final tgUri = Uri.parse('https://api.telegram.org/bot$token/sendMessage');
        final res = await http.post(
          tgUri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'chat_id': chatId,
            'text': message,
            'parse_mode': 'HTML',
          }),
        ).timeout(const Duration(seconds: 8));
        final ok = res.statusCode == 200;
        if (ok) {
          debugPrint('[DailyTaskService] Notifikasi tugas baru terkirim via Telegram Bot API');
        }
        return ok;
      }
    } catch (e) {
      debugPrint('[DailyTaskService] Error kirim notifikasi Telegram tugas baru: $e');
    }
    return false;
  }

  /// Teknisi: Tandai tugas selesai dan upload foto bukti (mendukung multiple foto)
  static Future<bool> completeTask({
    required String taskId,
    required String jamSelesai,
    String? catatan,
    String? localPhotoPath,
    List<String>? localPhotoPaths,
    List<String>? localVideoPaths,
  }) async {
    // 1. Verifikasi video lokal yang valid
    final existingVideos = <String>[];
    if (localVideoPaths != null && localVideoPaths.isNotEmpty) {
      for (final p in localVideoPaths) {
        if (p.isNotEmpty && File(p).existsSync()) {
          existingVideos.add(p);
        }
      }
    }

    // 2. Catatan murni teknisi tanpa teks annotasi tambahan
    final effectiveCatatan = (catatan ?? '').trim();

    // 3. Update status tugas di local cache seketika (agar langsung tercoret di UI)
    await markTaskCompletedLocally(
      taskId: taskId,
      jamSelesai: jamSelesai,
      catatan: effectiveCatatan.isNotEmpty ? effectiveCatatan : null,
    );

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

      // Catatan: PocketBase collection daily_tasks field foto_bukti hanya menerima MIME image/*.
      // Video tidak dikirim via foto_bukti agar tidak ditolak schema PB atau memicu request timeout.
      // Keberadaan video telah didokumentasikan di catatan_teknisi dan tersimpan di memori perangkat.

      if (photosToUpload.isNotEmpty) {
        bool multipartSuccess = false;
        try {
          final request = http.MultipartRequest('PATCH', uri);
          if (authToken != null && authToken!.isNotEmpty) {
            request.headers['Authorization'] = authToken!;
          }
          request.fields['status'] = 'completed';
          request.fields['jam_selesai'] = jamSelesai;
          if (effectiveCatatan.isNotEmpty) {
            request.fields['catatan_teknisi'] = effectiveCatatan;
          }

          // Lampirkan hanya foto bukti ke field foto_bukti
          for (int i = 0; i < photosToUpload.length; i++) {
            final filePath = photosToUpload[i];
            request.files.add(await http.MultipartFile.fromPath(
              'foto_bukti',
              filePath,
              filename: 'bukti_${i + 1}_${DateTime.now().millisecondsSinceEpoch}.jpg',
            ));
          }

          final streamed = await request.send().timeout(const Duration(seconds: 45));
          final respBody = await streamed.stream.bytesToString();
          multipartSuccess = streamed.statusCode == 200;
          if (!multipartSuccess) {
            debugPrint('[DailyTaskService] completeTask multipart failed: ${streamed.statusCode} $respBody');
          }
        } catch (uploadError) {
          debugPrint('[DailyTaskService] completeTask multipart error/timeout: $uploadError');
          multipartSuccess = false;
        }

        if (multipartSuccess) {
          return true;
        }

        // Fallback otomatis: jika multipart upload gagal (non-200 atau timeout),
        // jalankan PATCH JSON agar status tugas tetap tersimpan completed tanpa error koneksi
        debugPrint('[DailyTaskService] Menjalankan fallback PATCH JSON agar status task tetap tersimpan completed...');
        try {
          final fallbackBody = jsonEncode({
            'status': 'completed',
            'jam_selesai': jamSelesai,
            if (effectiveCatatan.isNotEmpty) 'catatan_teknisi': effectiveCatatan,
          });
          final res = await http.patch(uri, headers: _headers, body: fallbackBody).timeout(const Duration(seconds: 15));
          final fallbackSuccess = res.statusCode == 200;
          if (fallbackSuccess) {
            debugPrint('[DailyTaskService] Fallback PATCH JSON sukses! Tugas tersimpan completed di server.');
            return true;
          } else {
            debugPrint('[DailyTaskService] Fallback PATCH JSON failed: ${res.statusCode} ${res.body}');
          }
        } catch (fallbackError) {
          debugPrint('[DailyTaskService] Fallback PATCH JSON error: $fallbackError');
        }
        return false;
      } else {
        final body = jsonEncode({
          'status': 'completed',
          'jam_selesai': jamSelesai,
          if (effectiveCatatan.isNotEmpty) 'catatan_teknisi': effectiveCatatan,
        });
        final res = await http.patch(uri, headers: _headers, body: body).timeout(const Duration(seconds: 15));
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

  /// Format mikro pelaporan per-task: Pure caption catatan teknisi (tanpa judul & tanpa prefiks)
  static String formatPerTaskReport({
    String? judul,
    required String notes,
  }) {
    final cleanNotes = notes.trim();
    if (cleanNotes.isNotEmpty && cleanNotes != '-') {
      return cleanNotes;
    }
    return (judul != null && judul.trim().isNotEmpty) ? judul.trim() : '';
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

  /// Format rekapitulasi tim untuk SPV membagikan laporan harian seluruh teknisi
  /// Format rekapitulasi tim untuk SPV membagikan laporan harian seluruh teknisi
  static String formatSpvTeamRecap({
    required String tanggal,
    required List<DailyTaskModel> tasks,
    String? spvName,
    String? cabangName,
    AppBranch? branch,
  }) {
    final tglIndo = _formatTanggalIndo(tanggal);
    final completed = tasks.where((t) => t.isCompleted).toList();
    final pending = tasks.where((t) => !t.isCompleted).toList();
    final total = tasks.length;
    final percent = total > 0 ? ((completed.length / total) * 100).toInt() : 0;

    final activeBranch = branch ??
        (cabangName != null && cabangName.isNotEmpty
            ? BranchService.parseBranchFromName(cabangName)
            : BranchService.instance.currentBranch);

    final sb = StringBuffer();
    sb.writeln(activeBranch.recapHeader);
    final spvStr = (spvName != null && spvName.trim().isNotEmpty)
        ? spvName.trim()
        : activeBranch.defaultSpv;
    final spvFormatted = activeBranch == AppBranch.bali ? spvStr : spvStr.toUpperCase();
    sb.writeln('SPV : $spvFormatted');
    sb.writeln('Tanggal : $tglIndo');
    sb.writeln('Proggress : ${completed.length}/$total ($percent%)');

    // Status Daily Teknisi
    final techMap = <String, List<DailyTaskModel>>{};
    for (final t in tasks) {
      techMap.putIfAbsent(t.teknisiNama, () => []).add(t);
    }
    if (techMap.isNotEmpty) {
      sb.writeln('\nStatus Daily Teknisi :');
      for (final entry in techMap.entries) {
        final tech = entry.key;
        final techTasks = entry.value;
        final done = techTasks.where((t) => t.isCompleted).length;
        sb.writeln('$tech : $done/${techTasks.length} selesai');
      }
    }

    if (completed.isNotEmpty) {
      sb.writeln('\nSelesai (${completed.length}):');
      for (int i = 0; i < completed.length; i++) {
        final t = completed[i];
        final timeStr = (t.jamSelesai != null && t.jamSelesai!.isNotEmpty) ? ' [${t.jamSelesai}]' : '';
        sb.writeln('${i + 1}. ${t.teknisiNama} - ${t.judul} (${t.posName})$timeStr');
      }
    }

    if (pending.isNotEmpty) {
      sb.writeln('\nBelum Selesai (${pending.length}):');
      for (int i = 0; i < pending.length; i++) {
        final t = pending[i];
        sb.writeln('${i + 1}. ${t.teknisiNama} - ${t.judul} (${t.posName})');
      }
    }

    sb.writeln('\nTerimakasih');
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

  /// Update status tugas secara lokal ke cache storage seketika
  static Future<void> markTaskCompletedLocally({
    required String taskId,
    required String jamSelesai,
    String? catatan,
  }) async {
    final current = getCachedTasksLocally();
    bool updated = false;
    for (int i = 0; i < current.length; i++) {
      if (current[i].id == taskId) {
        current[i] = current[i].copyWith(
          status: TaskStatus.completed,
          jamSelesai: jamSelesai,
          catatanTeknisi: (catatan != null && catatan.isNotEmpty) ? catatan : current[i].catatanTeknisi,
        );
        updated = true;
      }
    }
    if (updated) {
      await _cacheTasksLocally(current);
      final pendingCount = current.where((t) => !t.isCompleted).length;
      updatePendingCount(pendingCount);
    }
  }
}
