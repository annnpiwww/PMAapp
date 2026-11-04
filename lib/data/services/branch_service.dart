import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'daily_task_service.dart';
import 'storage_service.dart';

AppBranch? _appBranchFromDbKey(String? str) {
  if (str == null) return null;
  final s = str.trim().toLowerCase();
  if (s == 'manado' || s == 'kc manado' || s == 'mdo') return AppBranch.manado;
  if (s == 'bali' || s == 'kc bali' || s == 'dps') return AppBranch.bali;
  if (s == 'ho' || s == 'ho makassar') return AppBranch.ho;
  return null;
}

enum AppBranch {
  manado(
    code: 'MDO',
    name: 'KC Manado',
    recapHeader: 'REKAP DAILY TEAM PMA KC BSG',
    defaultSpv: 'Farhan Lakoro',
    defaultLocationTag: 'PBM',
  ),
  bali(
    code: 'DPS',
    name: 'KC Bali',
    recapHeader: 'REKAP DAILY TEAM PMA KC BALI',
    defaultSpv: 'Indra Yohana',
    defaultLocationTag: 'PBKD',
  ),
  ho(
    code: 'HO',
    name: 'HO Makassar',
    recapHeader: 'REKAP DAILY TEAM PMA HO MAKASSAR',
    defaultSpv: 'ADI SUPRIADI',
    defaultLocationTag: 'HO',
  );

  final String code;
  final String name;
  final String recapHeader;
  final String defaultSpv;
  final String defaultLocationTag;

  const AppBranch({
    required this.code,
    required this.name,
    required this.recapHeader,
    required this.defaultSpv,
    required this.defaultLocationTag,
  });
}

class BranchService extends ChangeNotifier {
  static final BranchService instance = BranchService._internal();

  static const String _kActiveBranchCode = 'active_branch_code';

  AppBranch _currentBranch = AppBranch.manado;
  Map<AppBranch, List<String>> _techniciansCache = {};

  @visibleForTesting
  static http.Client? clientOverride;

  static http.Client get _client => clientOverride ?? http.Client();

  BranchService._internal() {
    _loadFromStorage();
  }

  AppBranch get currentBranch => _currentBranch;

  void _loadFromStorage() {
    final savedCode = StorageService.getString(_kActiveBranchCode);
    _currentBranch = parseBranchFromCode(savedCode);
    _loadTechniciansCache();
  }

  void _loadTechniciansCache() {
    final stored = StorageService.getTechniciansCache();
    if (stored.isNotEmpty) {
      final next = <AppBranch, List<String>>{};
      for (final entry in stored.entries) {
        final b = _appBranchFromDbKey(entry.key);
        if (b != null) {
          next[b] = List.unmodifiable(entry.value);
        }
      }
      _techniciansCache = next;
    } else {
      _techniciansCache.clear();
    }
  }

  @visibleForTesting
  void resetForTesting() {
    _currentBranch = AppBranch.manado;
    clientOverride = null;
    _loadTechniciansCache();
  }

  static Future<bool> syncTechniciansFromRemote() async {
    try {
      final uri = Uri.parse(
        '${DailyTaskService.baseUrl}/rest/v1/technicians?select=nama,branch,sort_order&active=eq.true&order=branch.asc,sort_order.asc',
      );
      final client = _client;
      final res = await client.get(
        uri,
        headers: {
          'apikey': DailyTaskService.anonKey,
          'Authorization': 'Bearer ${DailyTaskService.anonKey}',
        },
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode != 200) {
        return false;
      }

      final decoded = jsonDecode(res.body);
      if (decoded is! List) return false;

      final branchMap = <String, List<String>>{
        'manado': [],
        'bali': [],
        'ho': [],
      };

      for (final item in decoded) {
        if (item is Map) {
          final branchKey = item['branch']?.toString().trim().toLowerCase();
          final name = item['nama']?.toString().trim();
          if (branchKey != null && name != null && name.isNotEmpty && branchMap.containsKey(branchKey)) {
            branchMap[branchKey]!.add(name);
          }
        }
      }

      await StorageService.saveTechniciansCache(branchMap);
      await StorageService.setTechniciansSyncedRemote(true);

      final nextCache = <AppBranch, List<String>>{};
      for (final entry in branchMap.entries) {
        final b = _appBranchFromDbKey(entry.key);
        if (b != null) {
          nextCache[b] = List.unmodifiable(entry.value);
        }
      }

      instance._techniciansCache = nextCache;
      instance.notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> setBranch(AppBranch branch) async {
    if (_currentBranch == branch) return;
    _currentBranch = branch;
    await StorageService.setString(_kActiveBranchCode, branch.code);
    notifyListeners();
  }

  static AppBranch parseBranchFromCode(String? code) {
    if (code == null || code.isEmpty) return AppBranch.manado;
    final upper = code.trim().toUpperCase();
    if (upper == 'HO' || upper == 'HOM' || upper == 'MAKASSAR' || upper == 'HEADOFFICE') {
      return AppBranch.ho;
    }
    if (upper == 'DPS' || upper == 'BALI') return AppBranch.bali;
    return AppBranch.manado;
  }

  static AppBranch parseBranchFromName(String? name) {
    if (name == null || name.isEmpty) return AppBranch.manado;
    final lower = name.trim().toLowerCase();
    // 'ho' dicek sebagai kata utuh supaya nama orang (mis. 'Yohana') tidak ikut terdeteksi.
    if (lower == 'ho' ||
        lower == 'hom' ||
        lower.contains('ho makassar') ||
        lower.contains('head office') ||
        lower.contains('makassar')) {
      return AppBranch.ho;
    }
    if (lower.contains('bali') || lower.contains('dps')) {
      return AppBranch.bali;
    }
    return AppBranch.manado;
  }

  /// Menentukan cabang operasional secara akurat berdasarkan atribut user
  static AppBranch determineBranch({
    String? cabang,
    String? email,
    String? username,
    String? name,
    AppBranch? fallback,
  }) {
    if (cabang != null && cabang.trim().isNotEmpty) {
      return parseBranchFromName(cabang);
    }

    final hay = '${email ?? ''} ${username ?? ''} ${name ?? ''}'.toLowerCase();

    // 1. Cek personil HO Makassar
    const hoKeywords = [
      'khaelani',
      'hasrul',
      'hardin',
      'ferdinan',
      'alif ahmad',
      'dany',
      'yusuf',
      'rahmad',
      'arif surya',
      'riyan',
      'adi supriadi',
      'makassar',
      'head office',
    ];
    for (final kw in hoKeywords) {
      if (hay.contains(kw)) return AppBranch.ho;
    }

    // 2. Cek personil cabang Bali
    const baliKeywords = [
      'indra',
      'parta',
      'toro',
      'suardana',
      'dika',
      'cokagung',
      'yustikawangsa',
      'bagaskara',
      'triantoro',
      'bali',
      'dps',
    ];
    for (final kw in baliKeywords) {
      if (hay.contains(kw)) return AppBranch.bali;
    }

    // 3. Cek personil cabang Manado / BSG
    const manadoKeywords = [
      'farhan',
      'ryan',
      'raldy',
      'junifer',
      'ale',
      'alessandro',
      'lakoro',
      'lumasuge',
      'sangkop',
      'manua',
      'sulistyo',
      'manado',
      'bsg',
      'mdo',
    ];
    for (final kw in manadoKeywords) {
      if (hay.contains(kw)) return AppBranch.manado;
    }

    return fallback ?? BranchService.instance.currentBranch;
  }

  List<String> getTechnicians({AppBranch? branch}) {
    final b = branch ?? _currentBranch;
    final cached = _techniciansCache[b];
    if (StorageService.hasTechniciansSyncedRemote()) {
      return cached ?? const [];
    }
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }
    return _fallbackTechnicians(b);
  }

  static List<String> _fallbackTechnicians(AppBranch b) {
    switch (b) {
      case AppBranch.bali:
        return const [
          'Putu Hyan Parta Wijaya',
          'Alif Candra Triantoro',
          'I Putu Indra Yohana',
          'I PUTU GEDE SUARDANA PUTRA',
          'ADITYA CAESAR BAGASKARA',
          'ANAK AGUNG GEDE AGUNG YUSTIKAWANGSA',
        ];
      case AppBranch.ho:
        return const [
          'AHMAD KHAELANI',
          'HASRUL HAQ',
          'MUH. HARDIN TAUFIK',
          'FERDINAN PRADANA PANGALA PUTRA',
          'ALIF AHMAD MAULANA',
          'DANY RAMADHANI ASHARI',
          'MUHAMMAD YUSUF SALAM',
          'RAHMAD HIDAYAT',
          'ARIF SURYA WIDODO',
          'RIYAN ADNAN',
        ];
      case AppBranch.manado:
        return const [
          'Ryan Lumasuge',
          'Raldy Sangkop',
          'Junifer Manua',
          'Alessandro Sulistyo',
        ];
    }
  }

  List<String> getShifts({AppBranch? branch}) {
    final b = branch ?? _currentBranch;
    switch (b) {
      case AppBranch.bali:
        return const [
          'Shift 1 (06.00 - 14.00)',
          'Shift 2 (14.00 - 22.00)',
          'Shift 3 (22.00 - 06.00)',
          'Shift 4 (08.30 - 16.30)',
          'Shift 2.2 (18.00 - 22.00)',
          'Shift 4.1 (08.00 - 12.00)',
        ];
      case AppBranch.ho:
        return const [
          'Shift 1 (08.00 - 16.00)',
          'Shift 2 (16.00 - 24.00)',
          'Shift 3 (24.00 - 08.00)',
          'Shift 1.1 (08.00 - 12.00)',
          'HO.1 (08.30 - 12.30)',
          'GMM 1 (09.00 - 17.00)',
          'GMM 2 (15.00 - 23.00)',
          'RSWS (15.00 - 23.00)',
          'RSWS (08.30 - 16.30)',
          'JP (08.30 - 16.30)',
          'JP (17.00 - 01.00)',
        ];
      case AppBranch.manado:
        return const [
          'Shift 1 (03:00 - 11:00)',
          'Shift 1.1 (06:00 - 14:00)',
          'Shift 2.2 (10:00 - 14:00)',
          'Shift 2 (10:00 - 18:00)',
          'Shift 3 (14:00 - 22:00)',
        ];
    }
  }

  List<String> getLocationTags({AppBranch? branch}) {
    final b = branch ?? _currentBranch;
    switch (b) {
      case AppBranch.bali:
        return const [
          'PBKD',
          'PCD',
          'PKRD',
          'PAS',
          'PSD',
          'PGA',
          'TBB',
          'TBG',
          'KIH',
          'BMS',
          'BMK',
          'SPD',
          'GYS',
          'PBB',
          'RSPM',
        ];
      case AppBranch.ho:
        return const [
          'TBP',
          'GMM',
          'RSWS',
          'MGPO',
          'MGPI',
          'MGWJ',
          'PCC',
          'MGPP',
          'MGSP',
          'MGKW',
          'KMS',
          'PJT',
        ];
      case AppBranch.manado:
        return const [
          'PBM',
          'PKM',
          'MPP',
          'NBM',
          'PPM',
          'TBM',
          'MGAM',
          'MGMM',
          'MGBP',
          'MGTO',
          'MGKB',
          'MGNW',
          'MGGJ',
          'MGLG',
          'MEGAMAS',
          'MTC',
        ];
    }
  }

  /// Tag lokasi milik cabang selain cabang aktif (guard kebocoran tag antar cabang).
  static Set<String> get otherBranchLocationTags {
    final current = instance.currentBranch;
    return AppBranch.values
        .where((b) => b != current)
        .expand((b) => instance.getLocationTags(branch: b))
        .map((t) => t.trim().toUpperCase())
        .toSet();
  }

  /// Shift ini milik cabang lain? Dipakai supaya pilihan shift tidak bocor antar cabang.
  static bool isShiftOfOtherBranch(String shift) {
    final clean = shift.trim();
    if (clean.isEmpty) return false;
    return AppBranch.values.any((b) =>
        b != instance.currentBranch &&
        instance.getShifts(branch: b).contains(clean));
  }
}
