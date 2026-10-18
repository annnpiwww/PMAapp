import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/daily_task_model.dart';
import '../models/maintenance_submission.dart';
import '../services/storage_service.dart';
import '../services/location_service.dart';
import 'branch_service.dart';
import 'notification_service.dart';

class DailyTaskService {
  static const String _defaultBaseUrl = 'https://sxsjixnnlzhjinzcyhjb.supabase.co';
  static const String _defaultAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN4c2ppeG5ubHpoamluemN5aGpiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODYwMDUwNjYsImV4cCI6MjEwMTU4MTA2Nn0.8syTnWhD9yC6SxzTY8K_UEyXKQ8GTlyuHTWYa8eoLTs';

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

    debugPrint('[DailyTaskService] Memulai Realtime Poller & Sync untuk teknisi: $cleanName');

    // 1. Pengecekan awal instan
    _checkNewTasks(cleanName);

    // 2. Periodic Poller (setiap 25 detik) sebagai fallback yang andal
    _pollingTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      _checkNewTasks(cleanName);
    });
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

  static String get baseUrl {
    // Bersihkan key legacy pocketbase jika masih ada di local storage / shared preferences
    try {
      if (StorageService.getString('custom_pocketbase_url') != null) {
        StorageService.remove('custom_pocketbase_url');
      }
    } catch (_) {}

    final custom = StorageService.getString('custom_supabase_url');
    if (custom != null && custom.isNotEmpty && custom.startsWith('https://') && !custom.contains('8090') && !custom.contains('trakingduit')) {
      return custom;
    }
    return const String.fromEnvironment('SUPABASE_URL', defaultValue: _defaultBaseUrl);
  }

  static String get anonKey {
    final custom = StorageService.getString('custom_supabase_anon_key');
    if (custom != null && custom.isNotEmpty) return custom;
    return const String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: _defaultAnonKey);
  }

  static String? _authToken;
  static String? get authToken => _authToken ?? StorageService.getString('sb_auth_token') ?? StorageService.getString('pb_auth_token');

  static void setAuthToken(String? token) {
    _authToken = token;
    if (token != null) {
      StorageService.setString('sb_auth_token', token);
    } else {
      StorageService.remove('sb_auth_token');
      StorageService.remove('pb_auth_token');
    }
  }

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'apikey': anonKey,
    'Authorization': 'Bearer $anonKey',
  };

  static Map<String, String> get _getHeaders => {
    'Accept': 'application/json',
    'apikey': anonKey,
    'Authorization': 'Bearer $anonKey',
  };

  static Map<String, String> get getHeaders => _getHeaders;

  /// Helper untuk mencocokkan nama teknisi secara fleksibel
  static bool _matchesTechnician(String taskTech, String targetTech) {
    final cleanTarget = targetTech.trim().toLowerCase();
    final tName = taskTech.trim().toLowerCase();
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
  }

  /// Tugas ini milik/ikut dikerjakan [nama]? Pemilik ATAU pelaksana tambahan.
  static bool isAssignedTo(DailyTaskModel task, String nama) {
    if (_matchesTechnician(task.teknisiNama, nama)) return true;
    for (final p in task.pesertaList) {
      if (_matchesTechnician(p, nama)) return true;
    }
    return false;
  }

  /// Ambil daftar tugas harian untuk teknisi tertentu (semua tugas pending + tugas hari ini)
  static Future<List<DailyTaskModel>> getTasksForTeknisi({
    required String tanggal,
    required String teknisiNama,
  }) async {
    List<DailyTaskModel> allTasks = [];
    bool serverSuccess = false;

    try {
      final uri = Uri.parse('$baseUrl/rest/v1/daily_tasks').replace(
        queryParameters: {
          'or': '(status.eq.pending,tanggal.eq.$tanggal)',
          'order': 'created_at.desc',
          'limit': '100',
        },
      );
      final res = await http.get(uri, headers: _getHeaders).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final List items = decoded is List ? decoded : ((decoded as Map<String, dynamic>)['items'] as List? ?? []);
        allTasks = items.map((e) => DailyTaskModel.fromJson(e as Map<String, dynamic>)).toList();
        serverSuccess = true;
      } else {
        debugPrint('[DailyTaskService] getTasksForTeknisi failed: ${res.statusCode} ${res.body}');
      }
    } catch (e) {
      debugPrint('[DailyTaskService] getTasks error, fallback local: $e');
    }

    final localCached = getCachedTasksLocally();

    if (!serverSuccess) {
      // Offline fallback: filter dari cache lokal berdasarkan nama teknisi
      final offlineFiltered = localCached.where((t) {
        if (!isAssignedTo(t, teknisiNama)) return false;
        return !t.isCompleted || t.tanggal == tanggal;
      }).toList();
      offlineFiltered.sort((a, b) => b.id.compareTo(a.id));
      debugPrint('[DailyTaskService] getTasksForTeknisi offline fallback: ${offlineFiltered.length} tugas untuk $teknisiNama');
      return offlineFiltered;
    }

    final serverFiltered = allTasks.where((t) => isAssignedTo(t, teknisiNama)).toList();
    final serverIds = serverFiltered.map((t) => t.id).toSet();
    final pendingLocal = localCached.where((t) {
      if (!t.id.startsWith('local_')) return false;
      if (serverIds.contains(t.id)) return false;
      if (!isAssignedTo(t, teknisiNama)) return false;
      return !t.isCompleted || t.tanggal == tanggal;
    }).toList();

    // Cross-check dengan local cache & maintenance submissions agar status 'completed' tidak ter-reset
    final localCompletedMap = {
      for (final t in localCached.where((e) => e.isCompleted)) t.id: t
    };
    final completedSubs = (StorageService.getMaintenanceSubmissions() ?? []).where((s) => s.isComplete).toList();

    final syncedList = [...serverFiltered, ...pendingLocal].map((task) {
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
        final sopPhotos = matchSub.points
            .map((r) => r.imagePath)
            .where((p) => p != null && p.isNotEmpty)
            .cast<String>()
            .toList();
        return task.copyWith(
          status: TaskStatus.completed,
          jamSelesai: task.jamSelesai ?? timeStr,
          catatanTeknisi: task.catatanTeknisi ??
              'SOP Maintenance ${matchSub.templateName} selesai (${matchSub.sesuaiCount}/${matchSub.totalPoints} poin sesuai${matchSub.tidakTerpasangCount > 0 ? ", ${matchSub.tidakTerpasangCount} tidak terpasang" : ""})',
          fotoBuktiUrls: task.fotoBuktiUrls.isNotEmpty ? task.fotoBuktiUrls : sopPhotos,
        );
      }
      return task;
    }).toList();

    syncedList.sort((a, b) => b.id.compareTo(a.id));

    // Cache ke local storage untuk offline access di basement
    final otherTasks = localCached.where((t) => !isAssignedTo(t, teknisiNama)).toList();
    await _cacheTasksLocally([...syncedList, ...otherTasks]);
    debugPrint('[DailyTaskService] getTasksForTeknisi: loaded ${syncedList.length}/${allTasks.length} tasks for "$teknisiNama"');

    unawaited(flushPendingTaskCreationQueue());
    return syncedList;
  }

  /// SPV: Ambil semua tugas hari ini dari seluruh teknisi (Online dengan Offline Cache Fallback).
  /// Termasuk tugas pending beberapa hari terakhir supaya pekerjaan yang diserahkan
  /// shift sebelumnya (serah terima) tetap terlihat di layar SPV.
  static Future<List<DailyTaskModel>> getAllTasksToday(String tanggal) async {
    List<DailyTaskModel> serverTasks = [];
    bool serverSuccess = false;

    final batasLanjutan = _tanggalBatasLanjutan(tanggal);

    try {
      final uri = Uri.parse('$baseUrl/rest/v1/daily_tasks').replace(
        queryParameters: {
          'or': '(tanggal.eq.$tanggal,and(status.eq.pending,tanggal.gte.$batasLanjutan))',
          'order': 'created_at.desc',
          'limit': '200',
        },
      );
      final res = await http.get(uri, headers: _getHeaders).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final List items = decoded is List ? decoded : ((decoded as Map<String, dynamic>)['items'] as List? ?? []);
        serverTasks = items.map((e) => DailyTaskModel.fromJson(e as Map<String, dynamic>)).toList();
        serverSuccess = true;
      } else {
        debugPrint('[DailyTaskService] getAllTasksToday failed: ${res.statusCode} ${res.body}');
      }
    } catch (e) {
      debugPrint('[DailyTaskService] getAllTasksToday error: $e');
    }

    final localCached = getCachedTasksLocally();
    final localForDate = localCached
        .where((t) => t.tanggal == tanggal || !t.isCompleted)
        .toList();

    if (!serverSuccess) {
      debugPrint('[DailyTaskService] getAllTasksToday fallback offline: ${localForDate.length} tugas di cache lokal');
      localForDate.sort((a, b) => b.id.compareTo(a.id));
      return localForDate;
    }

    // Jika server sukses: gabungkan dengan task lokal pending sync untuk tanggal ini
    final serverIds = serverTasks.map((t) => t.id).toSet();
    final pendingLocal = localForDate.where((t) => t.id.startsWith('local_') && !serverIds.contains(t.id)).toList();

    final localCompletedMap = {
      for (final t in localCached.where((e) => e.isCompleted)) t.id: t
    };
    final completedSubs = (StorageService.getMaintenanceSubmissions() ?? []).where((s) => s.isComplete).toList();

    final syncedList = [...serverTasks, ...pendingLocal].map((task) {
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
        final sopPhotos = matchSub.points
            .map((r) => r.imagePath)
            .where((p) => p != null && p.isNotEmpty)
            .cast<String>()
            .toList();
        return task.copyWith(
          status: TaskStatus.completed,
          jamSelesai: task.jamSelesai ?? timeStr,
          catatanTeknisi: task.catatanTeknisi ??
              'SOP Maintenance ${matchSub.templateName} selesai (${matchSub.sesuaiCount}/${matchSub.totalPoints} poin sesuai${matchSub.tidakTerpasangCount > 0 ? ", ${matchSub.tidakTerpasangCount} tidak terpasang" : ""})',
          fotoBuktiUrls: task.fotoBuktiUrls.isNotEmpty ? task.fotoBuktiUrls : sopPhotos,
        );
      }
      return task;
    }).toList();

    syncedList.sort((a, b) => b.id.compareTo(a.id));

    // Simpan ke local cache (gabungkan dengan tanggal lainnya, tanpa id kembar)
    final keptIds = syncedList.map((t) => t.id).toSet();
    final otherDateTasks = localCached
        .where((t) => t.tanggal != tanggal && !keptIds.contains(t.id))
        .toList();
    await _cacheTasksLocally([...syncedList, ...otherDateTasks]);

    unawaited(flushPendingTaskCreationQueue());
    return syncedList;
  }

  /// Batas tanggal untuk menarik tugas pending lama (serah terima antar shift).
  static String _tanggalBatasLanjutan(String tanggal) {
    try {
      final d = DateTime.parse(tanggal).subtract(const Duration(days: 7));
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return tanggal;
    }
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

  /// Kunci unik tugas: satu tugas identik (tanggal + teknisi + judul + pos) cukup satu baris.
  static DailyTaskModel? _findCachedDuplicate({
    required String tanggal,
    required String teknisiNama,
    required String judul,
    required String posTag,
  }) {
    for (final t in getCachedTasksLocally()) {
      if (t.tanggal == tanggal &&
          t.teknisiNama == teknisiNama &&
          t.judul == judul &&
          t.posTag == posTag) {
        return t;
      }
    }
    return null;
  }

  /// Cek duplikat di server (jaring kedua saat cache lokal belum sinkron / beda device).
  static Future<DailyTaskModel?> _findServerDuplicate({
    required String tanggal,
    required String teknisiNama,
    required String judul,
    required String posTag,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/rest/v1/daily_tasks').replace(
        queryParameters: {
          'tanggal': 'eq.$tanggal',
          'teknisi_nama': 'eq.$teknisiNama',
          'judul': 'eq.$judul',
          'pos_tag': 'eq.$posTag',
          'order': 'created_at.desc',
          'limit': '1',
        },
      );
      final res = await http.get(uri, headers: _getHeaders).timeout(const Duration(seconds: 7));
      if (res.statusCode != 200) return null;
      final decoded = jsonDecode(res.body);
      if (decoded is List && decoded.isNotEmpty) {
        return DailyTaskModel.fromJson(decoded.first as Map<String, dynamic>);
      }
    } catch (e) {
      debugPrint('[DailyTaskService] _findServerDuplicate error: $e');
    }
    return null;
  }

  /// SPV: Buat tugas baru untuk teknisi (Online dengan Offline & Local Cache Fallback)
  /// [peserta] diisi kalau tugas dikerjakan bareng (nama tambahan, dipisah koma).
  static Future<DailyTaskModel?> createTask({
    required String tanggal,
    required String teknisiNama,
    required String posName,
    required String posTag,
    required String judul,
    String deskripsi = '',
    String kategori = 'khusus',
    String? templateId,
    String peserta = '',
  }) async {
    final pesertaClean = peserta.trim();
    // shortcut: dedupe per (tanggal, teknisi, judul, pos) supaya klik dobel /
    // request timeout tidak melahirkan tugas kembar. Perlu penugasan ulang di
    // hari yang sama? Upgrade ke kunci yang menyertakan jam/urutan dispatch.
    final cachedDuplicate = _findCachedDuplicate(
      tanggal: tanggal,
      teknisiNama: teknisiNama,
      judul: judul,
      posTag: posTag,
    );
    if (cachedDuplicate != null) {
      debugPrint('[DailyTaskService] Tugas identik sudah ada (${cachedDuplicate.id}), tidak membuat dobel.');
      return cachedDuplicate;
    }

    final localId = 'local_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9000) + 1000}';
    final serverId = 'task_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9000) + 1000}';
    final payload = {
      'id': serverId,
      'tanggal': tanggal,
      'teknisi_nama': teknisiNama,
      'pos_name': posName,
      'pos_tag': posTag,
      'judul': judul,
      'deskripsi': deskripsi,
      'kategori': kategori,
      'template_id': templateId,
      'status': 'pending',
      // Hanya dikirim kalau ada, supaya instalasi lama (kolom belum ada) tetap jalan.
      if (pesertaClean.isNotEmpty) 'peserta': pesertaClean,
    };

    DailyTaskModel? resultTask;
    bool rejectedAsDuplicate = false;

    try {
      final uri = Uri.parse('$baseUrl/rest/v1/daily_tasks');
      final body = jsonEncode(payload);
      final res = await http.post(
        uri,
        headers: {
          ..._headers,
          'Prefer': 'return=representation',
        },
        body: body,
      ).timeout(const Duration(seconds: 7));

      if (res.statusCode == 200 || res.statusCode == 201) {
        final decoded = jsonDecode(res.body);
        final Map<String, dynamic> map = (decoded is List && decoded.isNotEmpty)
            ? (decoded.first as Map<String, dynamic>)
            : (decoded as Map<String, dynamic>);
        resultTask = DailyTaskModel.fromJson(map);
        debugPrint('[DailyTaskService] Task sukses dibuat di Supabase: ${resultTask.id}');
      } else if (res.statusCode == 409) {
        // Unique index server menolak duplikat: pakai task yang sudah ada.
        rejectedAsDuplicate = true;
        resultTask = await _findServerDuplicate(
          tanggal: tanggal,
          teknisiNama: teknisiNama,
          judul: judul,
          posTag: posTag,
        );
        debugPrint('[DailyTaskService] Duplikat ditolak server (409). Pakai task lama: ${resultTask?.id}');
      } else {
        debugPrint('[DailyTaskService] Supabase HTTP status ${res.statusCode}. Menjalankan fallback offline.');
      }
    } catch (e) {
      debugPrint('[DailyTaskService] createTask error / timeout: $e. Menjalankan fallback offline.');
    }

    if (resultTask == null && rejectedAsDuplicate) {
      // Server sudah punya tugas ini, hanya gagal dibaca ulang. Jangan bikin
      // salinan lokal, karena justru melahirkan tampilan kembar.
      debugPrint('[DailyTaskService] Duplikat terdeteksi tapi gagal dibaca ulang. Tidak membuat salinan lokal.');
      return null;
    }

    if (resultTask == null) {
      // Buat instance lokal jika server offline / unreachable
      resultTask = DailyTaskModel(
        id: localId,
        tanggal: tanggal,
        teknisiId: '',
        teknisiNama: teknisiNama,
        posName: posName,
        posTag: posTag,
        judul: judul,
        deskripsi: deskripsi,
        kategori: kategori,
        templateId: templateId,
        status: TaskStatus.pending,
        jamSelesai: null,
        fotoBuktiUrls: const [],
        catatanTeknisi: null,
        peserta: pesertaClean,
      );
      // Simpan ke antrean sinkronisasi offline (menggunakan localId)
      final offlinePayload = Map<String, dynamic>.from(payload)..['id'] = localId;
      await _enqueuePendingTaskCreation(offlinePayload, localId: localId);
    }

    // Selalu simpan ke local cache seketika
    try {
      await _upsertTaskToLocalCache(resultTask);
    } catch (e) {
      debugPrint('[DailyTaskService] _upsertTaskToLocalCache warning: $e');
    }

    // Kirim notifikasi Telegram (non-blocking)
    try {
      unawaited(sendTelegramTaskNotification(
        teknisiNama: teknisiNama,
        judul: judul,
        posName: posName,
        deskripsi: deskripsi,
        tanggal: tanggal,
      ));
    } catch (_) {}

    return resultTask;
  }

  static String _stampSekarang() {
    final n = DateTime.now();
    const bulan = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    return '${n.day.toString().padLeft(2, '0')} ${bulan[n.month - 1]} '
        '${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}';
  }

  /// Serah terima tugas yang belum selesai ke shift berikutnya.
  /// [keTeknisi] kosong = dilepas ke daftar terbuka (siapa pun boleh ambil).
  static Future<bool> transferTask({
    required DailyTaskModel task,
    required String keTeknisi,
    required String alasan,
    required String olehSiapa,
  }) async {
    final tujuan = keTeknisi.trim();
    final entry = TaskHandover(
      dari: olehSiapa.trim().isEmpty ? task.teknisiNama : olehSiapa.trim(),
      ke: tujuan,
      alasan: alasan.trim().replaceAll('|', '/').replaceAll('\n', ' '),
      waktu: _stampSekarang(),
    );
    final logBaru = task.handoverList.map((e) => e.toLine()).toList()..add(entry.toLine());

    final updated = task.copyWith(
      teknisiNama: tujuan.isNotEmpty ? tujuan : task.teknisiNama,
      // Penerus mulai dari nol; kalau dilepas terbuka, pelaksana lama tetap tercatat.
      peserta: tujuan.isNotEmpty ? '' : task.peserta,
      serahTerima: logBaru.join('\n'),
      status: TaskStatus.pending,
    );

    if (task.id.startsWith('local_')) {
      await _upsertTaskToLocalCache(updated);
      return true;
    }

    try {
      final uri = Uri.parse('$baseUrl/rest/v1/daily_tasks').replace(
        queryParameters: {'id': 'eq.${task.id}'},
      );
      final res = await http.patch(
        uri,
        headers: {..._headers, 'Prefer': 'return=representation'},
        body: jsonEncode({
          'teknisi_nama': updated.teknisiNama,
          'peserta': updated.peserta,
          'serah_terima': updated.serahTerima,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }),
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode == 200 || res.statusCode == 204) {
        await _upsertTaskToLocalCache(updated);
        return true;
      }
      debugPrint('[DailyTaskService] transferTask gagal: ${res.statusCode} ${res.body}');
      return false;
    } catch (e) {
      debugPrint('[DailyTaskService] transferTask error: $e');
      return false;
    }
  }

  /// Teknisi shift berikutnya mengambil tugas yang dilepas ke daftar terbuka.
  static Future<bool> claimTask({
    required DailyTaskModel task,
    required String olehSiapa,
  }) {
    return transferTask(
      task: task,
      keTeknisi: olehSiapa,
      alasan: 'Ambil tugas terbuka',
      olehSiapa: task.handoverDari ?? task.teknisiNama,
    );
  }

  /// Tugas yang diserahkan tanpa penerus (daftar terbuka) di cabang aktif.
  /// [excludeTeknisi] dipakai supaya tugas yang sudah jadi milik teknisi ini tidak muncul lagi.
  /// Tugas pending dianggap terbuka untuk teknisi lain kalau:
  /// - teknisi sudah melepasnya lewat `Belum Selesai` (penerus kosong), atau
  /// - masih pending dan tanggalnya kemarin (ditinggal pulang tanpa diserahkan).
  /// Tugas pending hari ini yang masih dipegang teknisinya TIDAK dibuka, supaya
  /// tugas yang sudah dikhususkan ke orang lain tidak muncul di layar semua orang.
  static bool isTerbukaUntukShiftLain(DailyTaskModel task, {DateTime? sekarang}) {
    if (task.isCompleted) return false;
    if (task.isOpenHandover) return true;

    final now = sekarang ?? DateTime.now();
    final kemarin = now.subtract(const Duration(days: 1));
    final kemarinStr =
        '${kemarin.year}-${kemarin.month.toString().padLeft(2, '0')}-${kemarin.day.toString().padLeft(2, '0')}';
    return task.tanggal == kemarinStr;
  }

  static Future<List<DailyTaskModel>> getOpenHandoverTasks({
    String? excludeTeknisi,
  }) async {
    List<DailyTaskModel> kandidat = [];

    try {
      final uri = Uri.parse('$baseUrl/rest/v1/daily_tasks').replace(
        queryParameters: {
          'status': 'eq.pending',
          'order': 'created_at.desc',
          'limit': '100',
        },
      );
      final res = await http.get(uri, headers: _getHeaders).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final List items = decoded is List
            ? decoded
            : ((decoded as Map<String, dynamic>)['items'] as List? ?? []);
        kandidat = items.map((e) => DailyTaskModel.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('[DailyTaskService] getOpenHandoverTasks error: $e');
    }

    if (kandidat.isEmpty) {
      kandidat = getCachedTasksLocally();
    }

    final posCabang = LocationService.getLocationsByBranch(BranchService.instance.currentBranch);
    return kandidat.where((t) {
      if (!isTerbukaUntukShiftLain(t)) return false;
      if (excludeTeknisi != null && excludeTeknisi.isNotEmpty && isAssignedTo(t, excludeTeknisi)) {
        return false;
      }
      return posCabang.any((p) =>
          p.locationTag.toUpperCase() == t.posTag.toUpperCase() ||
          p.posName.toLowerCase() == t.posName.toLowerCase());
    }).toList();
  }

  /// Format pesan Telegram notifikasi penugasan baru dari SPV
  static String formatTelegramTaskMessage({
    required String teknisiNama,
    required String judul,
    required String posName,
    String deskripsi = '',
    String? timeStr,
    String? tanggal,
  }) {
    final now = DateTime.now();
    final todayKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final isTomorrowOrOther = tanggal != null && tanggal != todayKey;
    final dateBadge = isTomorrowOrOther ? ' [JADWAL: $tanggal]' : '';
    final time = timeStr ?? '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} WITA';
    final descLine = deskripsi.trim().isNotEmpty ? '\n📝 <b>Catatan:</b> ${deskripsi.trim()}' : '';
    final targetDateLine = isTomorrowOrOther ? '\n📅 <b>Target Tanggal:</b> $tanggal' : '';

    return '''🔔 <b>TUGAS BARU DARI SUPERVISOR$dateBadge</b>
━━━━━━━━━━━━━━━━━━
👤 <b>Teknisi:</b> $teknisiNama
📍 <b>Lokasi:</b> $posName
📋 <b>Tugas:</b> $judul$targetDateLine$descLine
⏰ <b>Waktu Dibuat:</b> $time

<i>Buka aplikasi PMAapp buat konfirmasi dan mulai kerjakan ya.</i>''';
  }

  /// Kirim notifikasi instan via Telegram bot (menggunakan tools/telegram_notify.sh atau Telegram Bot API)
  static Future<bool> sendTelegramTaskNotification({
    required String teknisiNama,
    required String judul,
    required String posName,
    String deskripsi = '',
    String? timeStr,
    String? tanggal,
  }) async {
    try {
      final message = formatTelegramTaskMessage(
        teknisiNama: teknisiNama,
        judul: judul,
        posName: posName,
        deskripsi: deskripsi,
        timeStr: timeStr,
        tanggal: tanggal,
      );

      // 1. Coba eksekusi lewat tools/telegram_notify.sh jika script tersedia (Native only)
      if (!kIsWeb) {
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
      }

      // 2. Fallback direct Telegram Bot API
      String token = const String.fromEnvironment('BSS_TG_BOT_TOKEN', defaultValue: '');
      String chatId = const String.fromEnvironment('BSS_TG_CHAT_ID', defaultValue: '');

      if (!kIsWeb && (token.isEmpty || chatId.isEmpty)) {
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
    try {
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

    // 3. Update status tugas di local cache seketika (agar langsung tercoret di UI dan foto bukti tersimpan)
    await markTaskCompletedLocally(
      taskId: taskId,
      jamSelesai: jamSelesai,
      catatan: effectiveCatatan.isNotEmpty ? effectiveCatatan : null,
      fotoBuktiUrls: photosToUpload,
    );

    // Jika task berstatus local (belum pernah tersinkron ke Supabase)
    if (taskId.startsWith('local_')) {
      await _updatePendingQueueTaskStatus(
        localId: taskId,
        status: 'completed',
        jamSelesai: jamSelesai,
        catatan: effectiveCatatan,
      );
      return true;
    }

      final uploadedUrls = <String>[];
      if (photosToUpload.isNotEmpty) {
        for (int i = 0; i < photosToUpload.length; i++) {
          try {
            final filePath = photosToUpload[i];
            final fileName = 'proof_${taskId}_${i + 1}_${DateTime.now().millisecondsSinceEpoch}.jpg';
            final uploadUri = Uri.parse('$baseUrl/storage/v1/object/task-proofs/$fileName');
            final bytes = await File(filePath).readAsBytes();
            final uploadRes = await http.post(
              uploadUri,
              headers: {
                'apikey': anonKey,
                'Authorization': 'Bearer $anonKey',
                'Content-Type': 'image/jpeg',
              },
              body: bytes,
            ).timeout(const Duration(seconds: 15));

            if (uploadRes.statusCode == 200 || uploadRes.statusCode == 201) {
              final publicUrl = '$baseUrl/storage/v1/object/public/task-proofs/$fileName';
              uploadedUrls.add(publicUrl);
            } else {
              debugPrint('[DailyTaskService] Upload bukti foto gagal: ${uploadRes.statusCode} ${uploadRes.body}');
            }
          } catch (uploadError) {
            debugPrint('[DailyTaskService] Upload bukti foto error: $uploadError');
          }
        }
      }

      final patchUri = Uri.parse('$baseUrl/rest/v1/daily_tasks').replace(
        queryParameters: {'id': 'eq.$taskId'},
      );
      final patchBody = jsonEncode({
        'status': 'completed',
        'jam_selesai': jamSelesai,
        if (effectiveCatatan.isNotEmpty) 'catatan_teknisi': effectiveCatatan,
        if (uploadedUrls.isNotEmpty) 'foto_bukti': uploadedUrls,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });

      final res = await http.patch(
        patchUri,
        headers: {
          ..._headers,
          'Prefer': 'return=representation',
        },
        body: patchBody,
      ).timeout(const Duration(seconds: 15));

      final success = res.statusCode == 200 || res.statusCode == 204;
      if (success && uploadedUrls.isNotEmpty) {
        await markTaskCompletedLocally(
          taskId: taskId,
          jamSelesai: jamSelesai,
          catatan: effectiveCatatan.isNotEmpty ? effectiveCatatan : null,
          fotoBuktiUrls: uploadedUrls,
        );
      }
      if (!success) {
        debugPrint('[DailyTaskService] completeTask patch failed: ${res.statusCode} ${res.body}');
      }
      return success;
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
  /// [partners] diisi kalau tugas dikerjakan bareng, mis. `['Budi']`.
  static String formatPerTaskReport({
    String? judul,
    required String notes,
    List<String> partners = const [],
  }) {
    final cleanNotes = notes.trim();
    final dasar = cleanNotes.isNotEmpty && cleanNotes != '-'
        ? cleanNotes
        : ((judul != null && judul.trim().isNotEmpty) ? judul.trim() : '');
    if (dasar.isEmpty) return '';
    if (partners.isEmpty) return dasar;

    final bersih = partners.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (bersih.isEmpty) return dasar;
    return '$dasar\nDikerjakan bersama ${bersih.join(', ')}';
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

  /// Format broadcast penugasan pagi tim untuk WhatsApp / Telegram
  static String formatMorningDispatchReport({
    required List<DailyTaskModel> tasks,
    required Map<String, String> techShiftMap,
    AppBranch? branch,
  }) {
    if (tasks.isEmpty) {
      return 'Selamat pagi\nList pekerjaan hari ini belum ada.\n\nTetap semangat team🔥';
    }

    final activeBranch = branch ?? BranchService.instance.currentBranch;
    final officialShifts = BranchService.instance.getShifts(branch: activeBranch);

    // Filter tasks & group by technician
    final techTaskMap = <String, List<DailyTaskModel>>{};
    for (final t in tasks) {
      final name = t.teknisiNama.trim();
      if (name.isNotEmpty) {
        techTaskMap.putIfAbsent(name, () => []).add(t);
      }
    }

    final defaultShift = officialShifts.isNotEmpty ? officialShifts.first : 'Shift 1';
    final shiftToTechs = <String, List<String>>{};

    for (final tech in techTaskMap.keys) {
      final shift = techShiftMap[tech] ?? defaultShift;
      shiftToTechs.putIfAbsent(shift, () => []).add(tech);
    }

    // Sort shifts according to officialShifts order
    final sortedShifts = shiftToTechs.keys.toList()
      ..sort((a, b) {
        final indexA = officialShifts.indexOf(a);
        final indexB = officialShifts.indexOf(b);
        if (indexA != -1 && indexB != -1) return indexA.compareTo(indexB);
        if (indexA != -1) return -1;
        if (indexB != -1) return 1;
        return a.compareTo(b);
      });

    final sb = StringBuffer();
    sb.writeln('Selamat pagi');
    sb.writeln('List pekerjaan hari ini \n');

    for (int sIdx = 0; sIdx < sortedShifts.length; sIdx++) {
      final shift = sortedShifts[sIdx];
      final techs = shiftToTechs[shift]!;

      for (int tIdx = 0; tIdx < techs.length; tIdx++) {
        final tech = techs[tIdx];
        final techTasks = techTaskMap[tech] ?? [];

        sb.writeln('$shift : $tech');
        for (int i = 0; i < techTasks.length; i++) {
          final t = techTasks[i];
          final tags = <String>[
            if (t.isShared) 'bersama ${t.pesertaList.join(', ')}',
            if (t.isHandover) 'lanjutan${t.handoverDari != null ? ' dari ${t.handoverDari}' : ''}',
          ];
          final suffix = tags.isEmpty ? '' : ' (${tags.join(', ')})';
          sb.writeln('${i + 1}. ${t.judul.trim()}$suffix');
        }
        sb.writeln();
      }
    }

    sb.write('Tetap semangat team🔥');
    return sb.toString();
  }

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
    // Progres dihitung dari tugas bertanggal hari itu saja. Tugas yang diserahkan
    // ke shift berikutnya tetap terhitung "belum selesai" di rekap hari asalnya.
    final tugasHariIni = tasks.where((t) => t.tanggal == tanggal).toList();
    final completedHariIni = tugasHariIni.where((t) => t.isCompleted).length;
    final total = tugasHariIni.length;
    final percent = total > 0 ? ((completedHariIni / total) * 100).toInt() : 0;

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
    sb.writeln('Progress : $completedHariIni/$total ($percent%)');

    // Status Daily Teknisi (tugas bareng ikut terhitung untuk semua pelaksananya)
    final techMap = <String, List<DailyTaskModel>>{};
    for (final t in tasks) {
      for (final nama in {t.teknisiNama, ...t.pesertaList}) {
        if (nama.trim().isEmpty) continue;
        techMap.putIfAbsent(nama, () => []).add(t);
      }
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

    String lanjutanMark(DailyTaskModel t) =>
        t.isHandover ? ' [lanjutan dari ${t.handoverDari}]' : '';

    if (completed.isNotEmpty) {
      sb.writeln('\nSelesai (${completed.length}):');
      for (int i = 0; i < completed.length; i++) {
        final t = completed[i];
        final timeStr = (t.jamSelesai != null && t.jamSelesai!.isNotEmpty) ? ' [${t.jamSelesai}]' : '';
        sb.writeln('${i + 1}. ${t.labelPelaksana} - ${t.judul} (${t.posName})$timeStr${lanjutanMark(t)}');
      }
    }

    if (pending.isNotEmpty) {
      sb.writeln('\nBelum Selesai (${pending.length}):');
      for (int i = 0; i < pending.length; i++) {
        final t = pending[i];
        sb.writeln('${i + 1}. ${t.labelPelaksana} - ${t.judul} (${t.posName})${lanjutanMark(t)}');
      }
    }

    final serahTerima = pending.where((t) => t.isHandover).toList();
    if (serahTerima.isNotEmpty) {
      sb.writeln('\nSerah Terima (belum selesai):');
      for (final t in serahTerima) {
        final e = t.handoverList.last;
        final tujuan = e.isOpen ? 'terbuka, siapa pun boleh ambil' : e.ke;
        final alasan = e.alasan.isEmpty ? '' : ', ${e.alasan}';
        sb.writeln('- ${t.judul} (${t.posName}), ${e.dari} → $tujuan$alasan');
      }
    }

    sb.writeln('\nTerima kasih');
    return sb.toString();
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
    List<String>? fotoBuktiUrls,
  }) async {
    final current = getCachedTasksLocally();
    bool updated = false;
    for (int i = 0; i < current.length; i++) {
      if (current[i].id == taskId) {
        current[i] = current[i].copyWith(
          status: TaskStatus.completed,
          jamSelesai: jamSelesai,
          catatanTeknisi: (catatan != null && catatan.isNotEmpty) ? catatan : current[i].catatanTeknisi,
          fotoBuktiUrls: (fotoBuktiUrls != null && fotoBuktiUrls.isNotEmpty)
              ? fotoBuktiUrls
              : current[i].fotoBuktiUrls,
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

  // --- Offline Sync Queue Management ---
  static const String _kPendingTaskCreations = 'pending_daily_task_creations_v1';

  static Future<void> _upsertTaskToLocalCache(DailyTaskModel task) async {
    final current = getCachedTasksLocally();
    final idx = current.indexWhere((t) => t.id == task.id);
    if (idx >= 0) {
      current[idx] = task;
    } else {
      current.insert(0, task);
    }
    await _cacheTasksLocally(current);
  }

  static Future<void> _enqueuePendingTaskCreation(Map<String, dynamic> payload, {required String localId}) async {
    try {
      await StorageService.init();
      final list = StorageService.getStringList(_kPendingTaskCreations) ?? [];
      final item = jsonEncode({
        'localId': localId,
        'payload': payload,
        'timestamp': DateTime.now().toIso8601String(),
      });
      list.add(item);
      final capped = list.length > 100 ? list.sublist(list.length - 100) : list;
      await StorageService.setStringList(_kPendingTaskCreations, capped);
      debugPrint('[DailyTaskService] Task di antrean offline: $localId (total: ${capped.length})');
    } catch (e) {
      debugPrint('[DailyTaskService] Gagal enqueue pending task: $e');
    }
  }

  static Future<void> _replaceLocalTaskId({
    required String localId,
    required DailyTaskModel newServerTask,
  }) async {
    final current = getCachedTasksLocally();
    final idx = current.indexWhere((t) => t.id == localId);
    if (idx >= 0) {
      final existing = current[idx];
      current[idx] = newServerTask.copyWith(
        status: existing.status,
        jamSelesai: existing.jamSelesai ?? newServerTask.jamSelesai,
        catatanTeknisi: existing.catatanTeknisi ?? newServerTask.catatanTeknisi,
      );
      await _cacheTasksLocally(current);
    }
  }

  static Future<void> _updatePendingQueueTaskStatus({
    required String localId,
    required String status,
    required String jamSelesai,
    String? catatan,
  }) async {
    try {
      await StorageService.init();
      final list = StorageService.getStringList(_kPendingTaskCreations) ?? [];
      final updatedList = <String>[];
      for (final itemStr in list) {
        try {
          final item = jsonDecode(itemStr) as Map<String, dynamic>;
          if (item['localId'] == localId) {
            final payload = item['payload'] as Map<String, dynamic>;
            payload['status'] = status;
            payload['jam_selesai'] = jamSelesai;
            if (catatan != null && catatan.isNotEmpty) {
              payload['catatan_teknisi'] = catatan;
            }
            item['payload'] = payload;
            updatedList.add(jsonEncode(item));
          } else {
            updatedList.add(itemStr);
          }
        } catch (_) {
          updatedList.add(itemStr);
        }
      }
      await StorageService.setStringList(_kPendingTaskCreations, updatedList);
    } catch (_) {}
  }

  /// Sinkronisasi otomatis semua tugas harian yang dibuat saat offline ke server Supabase
  static Future<int> flushPendingTaskCreationQueue() async {
    try {
      await StorageService.init();
      final list = StorageService.getStringList(_kPendingTaskCreations) ?? [];
      if (list.isEmpty) return 0;

      final uri = Uri.parse('$baseUrl/rest/v1/daily_tasks');
      final remaining = <String>[];
      int flushed = 0;

      for (final itemStr in list) {
        try {
          final item = jsonDecode(itemStr) as Map<String, dynamic>;
          final localId = item['localId'] as String;
          final payload = item['payload'] as Map<String, dynamic>;

          // Kasus paling rawan: insert pertama sudah masuk server tapi responsnya
          // putus (timeout), lalu item ini diantre ulang. Cek dulu sebelum kirim.
          final dupeKeys = (
            tanggal: payload['tanggal'] as String? ?? '',
            teknisiNama: payload['teknisi_nama'] as String? ?? '',
            judul: payload['judul'] as String? ?? '',
            posTag: payload['pos_tag'] as String? ?? '',
          );
          final serverDuplicate = await _findServerDuplicate(
            tanggal: dupeKeys.tanggal,
            teknisiNama: dupeKeys.teknisiNama,
            judul: dupeKeys.judul,
            posTag: dupeKeys.posTag,
          );
          if (serverDuplicate != null) {
            flushed++;
            await _replaceLocalTaskId(localId: localId, newServerTask: serverDuplicate);
            continue;
          }

          final res = await http.post(
            uri,
            headers: {
              ..._headers,
              'Prefer': 'return=representation',
            },
            body: jsonEncode(payload),
          ).timeout(const Duration(seconds: 7));

          if (res.statusCode == 200 || res.statusCode == 201) {
            flushed++;
            final decoded = jsonDecode(res.body);
            final Map<String, dynamic> map = (decoded is List && decoded.isNotEmpty)
                ? (decoded.first as Map<String, dynamic>)
                : (decoded as Map<String, dynamic>);
            final serverTask = DailyTaskModel.fromJson(map);
            await _replaceLocalTaskId(localId: localId, newServerTask: serverTask);
          } else if (res.statusCode == 409) {
            final existing = await _findServerDuplicate(
              tanggal: dupeKeys.tanggal,
              teknisiNama: dupeKeys.teknisiNama,
              judul: dupeKeys.judul,
              posTag: dupeKeys.posTag,
            );
            if (existing != null) {
              flushed++;
              await _replaceLocalTaskId(localId: localId, newServerTask: existing);
            } else {
              remaining.add(itemStr);
            }
          } else if (res.statusCode >= 400 && res.statusCode < 500) {
            debugPrint('[DailyTaskService] Drop invalid pending task: ${res.statusCode}');
          } else {
            remaining.add(itemStr);
          }
        } catch (_) {
          remaining.add(itemStr);
          break;
        }
      }

      await StorageService.setStringList(_kPendingTaskCreations, remaining);
      if (flushed > 0) {
        debugPrint('[DailyTaskService] Flush offline queue: berhasil sync $flushed task, tersisa ${remaining.length}');
      }
      return flushed;
    } catch (e) {
      debugPrint('[DailyTaskService] flushPendingTaskCreationQueue error: $e');
      return 0;
    }
  }
}
