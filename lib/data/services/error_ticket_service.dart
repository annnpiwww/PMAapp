import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/daily_task_model.dart';
import '../models/error_report.dart';
import 'branch_service.dart';
import 'daily_task_service.dart';
import 'google_sheets_service.dart';
import 'location_service.dart';

extension DailyTaskErrorTicketExt on DailyTaskModel {
  String get createdBy => teknisiNama;
}

class ErrorTicketService {
  static const kategori = 'error';

  /// Open error tickets for the logged-in branch, newest first, limit 100.
  /// Server: GET `rest/v1/<tasksTable>?kategori=eq.error&status=eq.pending`
  /// Offline: filter DailyTaskService local cache the same way.
  static Future<List<DailyTaskModel>> fetchOpen() async {
    try {
      final uri = Uri.parse('${DailyTaskService.baseUrl}/rest/v1/${DailyTaskService.tasksTable}').replace(
        queryParameters: {
          'kategori': 'eq.$kategori',
          'status': 'eq.pending',
          'order': 'created_at.desc',
          'limit': '100',
        },
      );
      final res = await DailyTaskService.httpGet(uri, headers: DailyTaskService.getHeaders)
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final List items = decoded is List
            ? decoded
            : ((decoded as Map<String, dynamic>)['items'] as List? ?? []);
        return items
            .map((e) => DailyTaskModel.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        debugPrint('[ErrorTicketService] fetchOpen non-200: ${res.statusCode}');
      }
    } catch (e) {
      debugPrint('[ErrorTicketService] fetchOpen error, fallback local: $e');
    }
    return filterOpenTickets(DailyTaskService.getCachedTasksLocally());
  }

  @visibleForTesting
  static List<DailyTaskModel> filterOpenTickets(List<DailyTaskModel> tasks) {
    return tasks.where((t) => t.kategori == kategori && !t.isCompleted).toList();
  }

  /// Pure. Returns the single best pos match or null when none/ambiguous.
  static PosLocation? guessPos(String text, List<PosLocation> options) {
    final cleanText = text.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleanText.isEmpty || options.isEmpty) return null;

    List<PosLocation> winners = [];
    int topScore = 0;
    bool topIsName = false;

    for (final pos in options) {
      final posNameNorm = pos.posName.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
      final tagNorm = pos.locationTag.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

      int scoreForPos = 0;
      bool isNameForPos = false;

      // 1. posName whole-word match
      if (posNameNorm.isNotEmpty) {
        final pattern = RegExp(
          '(?<![\\p{L}\\p{N}])${RegExp.escape(posNameNorm)}(?![\\p{L}\\p{N}])',
          unicode: true,
        );
        if (pattern.hasMatch(cleanText)) {
          scoreForPos = posNameNorm.length;
          isNameForPos = true;
        }
      }

      // 2. locationTag whole-word match (len >= 2)
      if (tagNorm.length >= 2) {
        final pattern = RegExp(
          '(?<![\\p{L}\\p{N}])${RegExp.escape(tagNorm)}(?![\\p{L}\\p{N}])',
          unicode: true,
        );
        if (pattern.hasMatch(cleanText)) {
          final tagScore = tagNorm.length;
          // Rule 3: posName match beats tag match of equal length
          if (tagScore > scoreForPos) {
            scoreForPos = tagScore;
            isNameForPos = false;
          }
        }
      }

      if (scoreForPos == 0) continue;

      if (winners.isEmpty) {
        winners.add(pos);
        topScore = scoreForPos;
        topIsName = isNameForPos;
      } else {
        final cmp = _compareMatches(scoreForPos, isNameForPos, topScore, topIsName);
        if (cmp > 0) {
          winners = [pos];
          topScore = scoreForPos;
          topIsName = isNameForPos;
        } else if (cmp == 0) {
          winners.add(pos);
        }
      }
    }

    if (winners.isEmpty) return null;
    if (winners.length == 1) return winners.first;

    final firstPosId = winners.first.posId;
    if (winners.every((w) => w.posId == firstPosId)) {
      return winners.first;
    }
    return null;
  }

  static int _compareMatches(int scoreA, bool isNameA, int scoreB, bool isNameB) {
    if (scoreA != scoreB) return scoreA.compareTo(scoreB);
    if (isNameA != isNameB) return isNameA ? 1 : -1;
    return 0;
  }

  /// Pure. Lowercased trimmed pos_name set, used by map to flag markers.
  static Set<String> openPosNames(List<DailyTaskModel> open) {
    return open
        .map((t) => t.posName.trim().toLowerCase())
        .where((name) => name.isNotEmpty)
        .toSet();
  }

  @visibleForTesting
  static Map<String, dynamic> buildSheetPayload(
    DailyTaskModel task, {
    required String stage,
    DateTime? selesai,
  }) {
    final report = ErrorReport.parse(task.deskripsi);

    String tanggalLapor = '';
    String waktuLapor = '';
    if (report.reportedAt != null) {
      final r = report.reportedAt!;
      final d = r.day.toString().padLeft(2, '0');
      final m = r.month.toString().padLeft(2, '0');
      final y = r.year.toString().padLeft(4, '0');
      final h = r.hour.toString().padLeft(2, '0');
      final min = r.minute.toString().padLeft(2, '0');
      tanggalLapor = '$d-$m-$y';
      waktuLapor = '$h.$min';
    }

    final lokasi = report.lokasi.trim().isNotEmpty ? report.lokasi.trim() : task.posName.trim();
    final kendala = report.kendala.trim().isNotEmpty ? report.kendala.trim() : task.judul.trim();
    final solusiSementara = report.solusiSementara.trim();
    final pelapor = task.createdBy.trim();
    final teknisi = task.teknisiNama.trim();

    String penyebab = report.penyebab.trim();
    String solusiPerbaikan = '';
    String catatan = '';
    String selesaiStr = '';
    String durasiPerbaikan = '';

    if (stage == 'done') {
      if (task.catatanTeknisi != null && task.catatanTeknisi!.trim().isNotEmpty) {
        final lines = task.catatanTeknisi!.split('\n');
        final lineRegex = RegExp(r'^\s*[-•*]?\s*([^:]+?)\s*:\s*(.*)$');
        for (final line in lines) {
          final match = lineRegex.firstMatch(line);
          if (match == null) continue;
          final label = match.group(1)!.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
          final rawVal = match.group(2)!.trim();
          final val = rawVal == '-' ? '' : rawVal;
          if (label == 'penyebab') {
            if (val.isNotEmpty) penyebab = val;
          } else if (label == 'solusi perbaikan' || label == 'solusi') {
            solusiPerbaikan = val;
          } else if (label == 'catatan') {
            catatan = val;
          }
        }
      }

      if (selesai != null) {
        final sD = selesai.day.toString().padLeft(2, '0');
        final sM = selesai.month.toString().padLeft(2, '0');
        final sY = selesai.year.toString().padLeft(4, '0');
        final sH = selesai.hour.toString().padLeft(2, '0');
        final sMin = selesai.minute.toString().padLeft(2, '0');
        selesaiStr = '$sD-$sM-$sY $sH.$sMin';

        if (report.reportedAt != null) {
          durasiPerbaikan = formatDurasi(selesai.difference(report.reportedAt!));
        }
      }
    }

    return {
      'kind': 'error',
      'stage': stage,
      'id': task.id,
      'tanggalLapor': tanggalLapor,
      'waktuLapor': waktuLapor,
      'lokasi': lokasi,
      'kendala': kendala,
      'penyebab': penyebab,
      'solusiSementara': solusiSementara,
      'pelapor': pelapor,
      'teknisi': teknisi,
      'solusiPerbaikan': solusiPerbaikan,
      'selesai': selesaiStr,
      'durasiPerbaikan': durasiPerbaikan,
      'catatan': catatan,
    };
  }

  static Future<void> syncSheetOpen(DailyTaskModel task) async {
    if (BranchService.instance.currentBranch != AppBranch.manado) return;
    if (task.kategori != kategori) return;
    if (task.id.startsWith('local_')) return;

    try {
      final payload = buildSheetPayload(task, stage: 'open');
      await GoogleSheetsService.postPayload(payload);
    } catch (e) {
      debugPrint('[ErrorTicketService] syncSheetOpen error: $e');
    }
  }

  static Future<void> syncSheetDone(DailyTaskModel task, {required DateTime selesai}) async {
    if (BranchService.instance.currentBranch != AppBranch.manado) return;
    if (task.kategori != kategori) return;

    try {
      final payload = buildSheetPayload(task, stage: 'done', selesai: selesai);
      await GoogleSheetsService.postPayload(payload);
    } catch (e) {
      debugPrint('[ErrorTicketService] syncSheetDone error: $e');
    }
  }
}
