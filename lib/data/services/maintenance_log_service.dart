import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/maintenance_submission.dart';
import 'branch_service.dart';
import 'daily_task_service.dart';
import 'location_service.dart';
import 'storage_service.dart';

/// Model item temuan pada maintenance (khusus tidak sesuai & perlu cek manual).
class MaintenanceTemuan {
  final String label;
  final String status; // 'tidak_sesuai' | 'perlu_cek_manual'
  final String alasan;
  final bool urgent;

  const MaintenanceTemuan({
    required this.label,
    required this.status,
    required this.alasan,
    required this.urgent,
  });

  factory MaintenanceTemuan.fromJson(Map<String, dynamic> json) {
    return MaintenanceTemuan(
      label: json['label'] as String? ?? '',
      status: json['status'] as String? ?? 'tidak_sesuai',
      alasan: json['alasan'] as String? ?? '',
      urgent: json['urgent'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'label': label,
    'status': status,
    'alasan': alasan,
    'urgent': urgent,
  };
}

/// Model log maintenance per checkpoint/sesi di Supabase atau fallback lokal.
class MaintenanceLogEntry {
  final String id;
  final String tanggal;
  final String jamSelesai;
  final String posId;
  final String posName;
  final String teknisiNama;
  final String teknisiNpp;
  final String? templateId;
  final String templateName;
  final int totalPoin;
  final int sesuaiPoin;
  final List<MaintenanceTemuan> temuan;
  final String branch;

  const MaintenanceLogEntry({
    required this.id,
    required this.tanggal,
    required this.jamSelesai,
    required this.posId,
    required this.posName,
    required this.teknisiNama,
    this.teknisiNpp = '',
    this.templateId,
    this.templateName = '',
    this.totalPoin = 0,
    this.sesuaiPoin = 0,
    this.temuan = const [],
    this.branch = 'MDO',
  });

  bool get hasTemuan => temuan.isNotEmpty;

  factory MaintenanceLogEntry.fromJson(Map<String, dynamic> json) {
    final rawTemuan = json['temuan'];
    final list = <MaintenanceTemuan>[];
    if (rawTemuan is List) {
      for (final item in rawTemuan) {
        if (item is Map<String, dynamic>) {
          list.add(MaintenanceTemuan.fromJson(item));
        } else if (item is Map) {
          list.add(MaintenanceTemuan.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }
    return MaintenanceLogEntry(
      id: json['id'] as String? ?? '',
      tanggal: json['tanggal'] as String? ?? '',
      jamSelesai: json['jam_selesai'] as String? ?? '',
      posId: json['pos_id'] as String? ?? '',
      posName: json['pos_name'] as String? ?? '',
      teknisiNama: json['teknisi_nama'] as String? ?? '',
      teknisiNpp: json['teknisi_npp'] as String? ?? '',
      templateId: json['template_id'] as String?,
      templateName: json['template_name'] as String? ?? '',
      totalPoin: (json['total_poin'] as num?)?.toInt() ?? 0,
      sesuaiPoin: (json['sesuai_poin'] as num?)?.toInt() ?? 0,
      temuan: list,
      branch: json['branch'] as String? ?? 'MDO',
    );
  }

  Map<String, dynamic> toRow() => {
    'id': id,
    'tanggal': tanggal,
    'jam_selesai': jamSelesai,
    'pos_id': posId,
    'pos_name': posName,
    'teknisi_nama': teknisiNama,
    'teknisi_npp': teknisiNpp,
    'template_id': templateId,
    'template_name': templateName,
    'total_poin': totalPoin,
    'sesuai_poin': sesuaiPoin,
    'temuan': temuan.map((t) => t.toJson()).toList(),
    'branch': branch,
  };

  static List<MaintenanceTemuan> _extractTemuan(
    List<MaintenancePointResult> points,
  ) {
    final temuanList = <MaintenanceTemuan>[];
    for (final p in points) {
      if (p.status == PointStatus.tidakSesuai ||
          p.status == PointStatus.perluCekManual) {
        temuanList.add(
          MaintenanceTemuan(
            label: p.label,
            status: p.status == PointStatus.tidakSesuai
                ? 'tidak_sesuai'
                : 'perlu_cek_manual',
            alasan: p.alasan,
            urgent: p.urgensi == TingkatUrgensi.urgent,
          ),
        );
      }
    }
    return temuanList;
  }

  static MaintenanceLogEntry _entryFromPoints(
    MaintenanceSubmission s,
    List<MaintenancePointResult> points, {
    String? id,
    String? templateId,
    String? templateName,
    String? branch,
  }) {
    final y = s.createdAt.year.toString().padLeft(4, '0');
    final m = s.createdAt.month.toString().padLeft(2, '0');
    final d = s.createdAt.day.toString().padLeft(2, '0');
    final tanggal = '$y-$m-$d';

    final jamTime = s.updatedAt;
    final hh = jamTime.hour.toString().padLeft(2, '0');
    final mm = jamTime.minute.toString().padLeft(2, '0');
    final jamSelesai = '$hh:$mm';

    final temuanList = _extractTemuan(points);
    final sesuaiCount =
        points.where((p) => p.status == PointStatus.sesuai).length;

    return MaintenanceLogEntry(
      id: id ?? s.id,
      tanggal: tanggal,
      jamSelesai: jamSelesai,
      posId: s.posId,
      posName: s.posName,
      teknisiNama: s.userName,
      teknisiNpp: s.userNpp,
      templateId: templateId ?? s.templateId,
      templateName: templateName ?? s.templateName,
      totalPoin: points.length,
      sesuaiPoin: sesuaiCount,
      temuan: temuanList,
      branch: branch ?? BranchService.instance.currentBranch.code,
    );
  }

  factory MaintenanceLogEntry.fromSubmission(
    MaintenanceSubmission s, {
    String? branch,
  }) {
    return _entryFromPoints(s, s.points, branch: branch);
  }
}

/// Status agregat lokasi dan kumpulan log pada suatu periode bulan.
class PosMaintenanceStatus {
  final PosLocation location;
  final String wilayah;
  final List<MaintenanceLogEntry> logs;

  const PosMaintenanceStatus({
    required this.location,
    required this.wilayah,
    this.logs = const [],
  });

  bool get sudah => logs.isNotEmpty;
  bool get adaTemuan => logs.isNotEmpty && logs.first.hasTemuan;

  /// Mengambil log yang cocok untuk fase tertentu (1..4) urut terbaru dulu.
  List<MaintenanceLogEntry> logsForPhase(int phase) {
    return logs
        .where((log) =>
            MaintenanceLogService.phaseForTemplate(log.templateId) == phase)
        .toList();
  }

  /// Mengecek apakah suatu fase sudah diselesaikan.
  bool isPhaseDone(int phase) => logsForPhase(phase).isNotEmpty;

  /// Mengecek apakah ada temuan pada log terbaru untuk fase tersebut.
  bool hasPhaseTemuan(int phase) {
    final pLogs = logsForPhase(phase);
    return pLogs.isNotEmpty && pLogs.first.hasTemuan;
  }

  /// Mengecek apakah seluruh 4 fase (1 s/d 4) telah selesai di bulan ini.
  bool get isAllPhasesDone =>
      isPhaseDone(1) && isPhaseDone(2) && isPhaseDone(3) && isPhaseDone(4);

  /// Status spesifik untuk fase tertentu ('belum', 'selesai_aman', 'selesai_temuan').
  String statusForPhase(int phase) {
    final pLogs = logsForPhase(phase);
    if (pLogs.isEmpty) return 'belum';
    return pLogs.first.hasTemuan ? 'selesai_temuan' : 'selesai_aman';
  }
}

/// Service log maintenance untuk sinkronisasi dan visualisasi map semua cabang.
class MaintenanceLogService {
  static const String tableName = 'maintenance_logs_manado';

  static List<String> wilayahListFor(AppBranch b) {
    switch (b) {
      case AppBranch.manado:
        return const [
          'Manado',
          'Airmadidi',
          'Bitung',
          'Tomohon',
          'Kotamobagu',
          'Gorontalo',
        ];
      case AppBranch.bali:
        return const [
          'Denpasar',
          'Badung',
          'Gianyar',
          'Tabanan',
          'Klungkung',
          'Bangli',
          'Karangasem',
          'Buleleng',
          'Jembrana',
          'Lainnya',
        ];
      case AppBranch.ho:
        return const [
          'Makassar',
          'Gowa',
          'Maros',
          'Takalar',
          'Lainnya',
        ];
    }
  }

  static const Map<int, String> phaseNames = {
    1: 'Manless & Pulau Gate In/Out',
    2: 'Pos Parkir',
    3: 'Barrier, Sensor & CCTV',
    4: 'PC Server & Kasir',
  };

  static const Map<int, String> phaseTemplates = {
    1: 'tpl_maint_manless',
    2: 'tpl_maint_pos',
    3: 'tpl_maint_barrier',
    4: 'tpl_maint_server',
  };

  /// Mengembalikan nomor fase (1-4) dari templateId.
  /// Return null untuk tpl_maint_lengkap atau lainnya
  /// (karena Maintenance Lengkap dijadwalkan manual SPV, tidak otomatis menandai fase).
  static int? phaseForTemplate(String? templateId) {
    if (templateId == null || templateId.isEmpty) return null;
    switch (templateId) {
      case 'tpl_maint_manless':
        return 1;
      case 'tpl_maint_pos':
        return 2;
      case 'tpl_maint_barrier':
        return 3;
      case 'tpl_maint_server':
        return 4;
      default:
        return null;
    }
  }

  /// Mengembalikan fase tetap (1-4) berdasarkan tanggal dalam bulan:
  /// - tgl 1-7: Fase 1 (Manless & Pulau Gate In/Out)
  /// - tgl 8-14: Fase 2 (Pos Parkir)
  /// - tgl 15-21: Fase 3 (Barrier, Sensor & CCTV)
  /// - tgl 22-akhir: Fase 4 (PC Server & Kasir)
  static int phaseForDate(DateTime dt) {
    final d = dt.day;
    if (d <= 7) return 1;
    if (d <= 14) return 2;
    if (d <= 21) return 3;
    return 4;
  }

  /// Mengelompokkan lokasi pos ke wilayah berdasarkan alamat dan nama pos.
  static String wilayahOf(PosLocation p, [AppBranch? b]) {
    final branch = b ?? BranchService.instance.currentBranch;
    final combined = '${p.fullAddress} ${p.posName}'.toLowerCase();
    switch (branch) {
      case AppBranch.manado:
        if (combined.contains('bitung')) return 'Bitung';
        if (combined.contains('tomohon')) return 'Tomohon';
        if (combined.contains('kotamobagu')) return 'Kotamobagu';
        if (combined.contains('gorontalo') || combined.contains('limboto')) {
          return 'Gorontalo';
        }
        if (combined.contains('airmadidi')) return 'Airmadidi';
        return 'Manado';

      case AppBranch.bali:
        if (combined.contains('denpasar')) return 'Denpasar';
        if (combined.contains('badung') ||
            combined.contains('kuta') ||
            combined.contains('seminyak') ||
            combined.contains('legian') ||
            combined.contains('jimbaran') ||
            combined.contains('nusa dua') ||
            combined.contains('mengwi') ||
            combined.contains('canggu')) {
          return 'Badung';
        }
        if (combined.contains('gianyar') || combined.contains('ubud')) {
          return 'Gianyar';
        }
        if (combined.contains('tabanan')) return 'Tabanan';
        if (combined.contains('klungkung') ||
            combined.contains('semarapura')) {
          return 'Klungkung';
        }
        if (combined.contains('bangli')) return 'Bangli';
        if (combined.contains('karangasem') ||
            combined.contains('amlapura')) {
          return 'Karangasem';
        }
        if (combined.contains('buleleng') ||
            combined.contains('singaraja') ||
            combined.contains('lovina')) {
          return 'Buleleng';
        }
        if (combined.contains('jembrana') || combined.contains('negara')) {
          return 'Jembrana';
        }
        return 'Lainnya';

      case AppBranch.ho:
        if (combined.contains('makassar')) return 'Makassar';
        if (combined.contains('gowa') || combined.contains('sungguminasa')) {
          return 'Gowa';
        }
        if (combined.contains('maros')) return 'Maros';
        if (combined.contains('takalar')) return 'Takalar';
        return 'Lainnya';
    }
  }

  /// Membangun daftar status maintenance per lokasi dari daftar log bulan terpilih.
  static List<PosMaintenanceStatus> buildStatuses(
    List<PosLocation> locations,
    List<MaintenanceLogEntry> logs, [
    AppBranch? branch,
  ]) {
    final activeBranch = branch ?? BranchService.instance.currentBranch;
    return locations.map((loc) {
      final locDispName = LocationService.displayName(loc);
      final matchedLogs = logs.where((log) {
        final matchId = log.posId.isNotEmpty && log.posId == loc.posId;
        final matchName = log.posName.isNotEmpty &&
            (log.posName == locDispName || log.posName == loc.posName);
        return matchId || matchName;
      }).toList();

      matchedLogs.sort((a, b) {
        final cmpTanggal = b.tanggal.compareTo(a.tanggal);
        if (cmpTanggal != 0) return cmpTanggal;
        return b.jamSelesai.compareTo(a.jamSelesai);
      });

      return PosMaintenanceStatus(
        location: loc,
        wilayah: wilayahOf(loc, activeBranch),
        logs: matchedLogs,
      );
    }).toList();
  }

  /// Cek apakah submission berasal dari cabang yang ditentukan (posId atau nama pos cocok).
  @visibleForTesting
  static bool isBranchSubmission(MaintenanceSubmission s, AppBranch branch) {
    final locations = LocationService.getLocationsByBranch(branch);
    final ids = locations
        .map((l) => l.posId)
        .where((id) => id.isNotEmpty)
        .toSet();
    final names = <String>{};
    for (final l in locations) {
      if (l.posName.isNotEmpty) names.add(l.posName);
      final disp = LocationService.displayName(l);
      if (disp.isNotEmpty) names.add(disp);
    }
    final matchId = s.posId.isNotEmpty && ids.contains(s.posId);
    final matchName = s.posName.isNotEmpty && names.contains(s.posName);
    return matchId || matchName;
  }

  /// Memecah submission menjadi satu atau lebih log entry:
  /// - Non-lengkap: 1 log entry asli
  /// - Lengkap: dipecah per area (barrier, manless, pos, server) sesuai prefix pointId
  static List<MaintenanceLogEntry> entriesFromSubmission(
    MaintenanceSubmission s, {
    AppBranch? branch,
  }) {
    final branchCode =
        branch?.code ?? BranchService.instance.currentBranch.code;
    if (s.templateId != 'tpl_maint_lengkap') {
      return [MaintenanceLogEntry.fromSubmission(s, branch: branchCode)];
    }

    final groups = <String, List<MaintenancePointResult>>{};
    for (final p in s.points) {
      final idx = p.pointId.indexOf('_');
      final prefix =
          (idx >= 0 ? p.pointId.substring(0, idx) : p.pointId).toLowerCase();
      final String? areaTemplateId;
      switch (prefix) {
        case 'bar':
          areaTemplateId = 'tpl_maint_barrier';
          break;
        case 'man':
        case 'mout':
        case 'mpep':
          areaTemplateId = 'tpl_maint_manless';
          break;
        case 'pos':
        case 'booth':
          areaTemplateId = 'tpl_maint_pos';
          break;
        case 'srv':
          areaTemplateId = 'tpl_maint_server';
          break;
        default:
          areaTemplateId = null;
      }
      if (areaTemplateId == null) continue;
      groups.putIfAbsent(areaTemplateId, () => []).add(p);
    }

    final entries = <MaintenanceLogEntry>[];
    for (final entry in groups.entries) {
      final areaTemplateId = entry.key;
      final groupPoints = entry.value;
      if (groupPoints.isEmpty) continue;

      final phase = phaseForTemplate(areaTemplateId);
      final phaseName = phase != null ? phaseNames[phase] : null;
      final templateName = phaseName != null
          ? '${s.templateName} ($phaseName)'
          : s.templateName;

      entries.add(
        MaintenanceLogEntry._entryFromPoints(
          s,
          groupPoints,
          id: '${s.id}__$areaTemplateId',
          templateId: areaTemplateId,
          templateName: templateName,
          branch: branchCode,
        ),
      );
    }

    return entries;
  }

  /// Mengirim semua submission lengkap lokal 62 hari terakhir ke Supabase (idempotent / upsert).
  static Future<void> syncLocal() async {
    try {
      final branch = BranchService.instance.currentBranch;
      final all = StorageService.getMaintenanceSubmissions() ?? [];
      final cutoff = DateTime.now().subtract(const Duration(days: 62));
      final candidates = all
          .where((s) =>
              s.isComplete &&
              s.createdAt.isAfter(cutoff) &&
              isBranchSubmission(s, branch))
          .toList();

      if (candidates.isEmpty) return;

      final rows = candidates
          .expand((s) => entriesFromSubmission(s, branch: branch))
          .map((entry) => entry.toRow())
          .toList();

      if (rows.isEmpty) return;

      final uri = Uri.parse(
        '${DailyTaskService.baseUrl}/rest/v1/$tableName?on_conflict=id',
      );
      final headers = {
        'apikey': DailyTaskService.anonKey,
        'Authorization': 'Bearer ${DailyTaskService.anonKey}',
        'Content-Type': 'application/json',
        'Prefer': 'resolution=merge-duplicates,return=minimal',
      };

      final res = await http
          .post(uri, headers: headers, body: jsonEncode(rows))
          .timeout(const Duration(seconds: 15));

      if (res.statusCode < 200 || res.statusCode >= 300) {
        debugPrint('MaintenanceLogService.syncLocal HTTP ${res.statusCode}');
      }
    } catch (e) {
      debugPrint('MaintenanceLogService.syncLocal error: $e');
    }
  }

  /// Mengambil data log maintenance bulan tertentu dari Supabase dengan fallback data lokal.
  static Future<({List<MaintenanceLogEntry> logs, bool offline})> fetchMonth(
    DateTime month, {
    AppBranch? branch,
  }) async {
    final activeBranch = branch ?? BranchService.instance.currentBranch;
    final y = month.year;
    final m = month.month;
    final yStr = y.toString().padLeft(4, '0');
    final mStr = m.toString().padLeft(2, '0');
    final lastDay = DateTime(y, m + 1, 0).day;
    final lastDayStr = lastDay.toString().padLeft(2, '0');
    final startTanggal = '$yStr-$mStr-01';
    final endTanggal = '$yStr-$mStr-$lastDayStr';

    try {
      final uri = Uri.parse(
        '${DailyTaskService.baseUrl}/rest/v1/$tableName?tanggal=gte.$startTanggal&tanggal=lte.$endTanggal&branch=eq.${activeBranch.code}&order=tanggal.desc,jam_selesai.desc',
      );
      final headers = {
        'apikey': DailyTaskService.anonKey,
        'Authorization': 'Bearer ${DailyTaskService.anonKey}',
      };

      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 12));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) {
          final entries = decoded
              .map((row) => MaintenanceLogEntry.fromJson(
                  Map<String, dynamic>.from(row as Map)))
              .toList();
          return (logs: entries, offline: false);
        }
      }
    } catch (e) {
      debugPrint('MaintenanceLogService.fetchMonth error: $e');
    }

    // Fallback ke submission lokal bulan itu
    final all = StorageService.getMaintenanceSubmissions() ?? [];
    final localSubmissions = all
        .where(
          (s) =>
              s.isComplete &&
              s.createdAt.year == month.year &&
              s.createdAt.month == month.month &&
              isBranchSubmission(s, activeBranch),
        )
        .toList();

    localSubmissions.sort((a, b) {
      final aDate = a.updatedAt;
      final bDate = b.updatedAt;
      return bDate.compareTo(aDate);
    });

    final localLogs = localSubmissions
        .expand((s) => entriesFromSubmission(s, branch: activeBranch))
        .toList();

    return (logs: localLogs, offline: true);
  }
}
