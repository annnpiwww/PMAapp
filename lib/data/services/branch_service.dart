import 'package:flutter/foundation.dart';
import 'storage_service.dart';

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

  BranchService._internal() {
    _loadFromStorage();
  }

  AppBranch get currentBranch => _currentBranch;

  void _loadFromStorage() {
    final savedCode = StorageService.getString(_kActiveBranchCode);
    _currentBranch = parseBranchFromCode(savedCode);
  }

  @visibleForTesting
  void resetForTesting() {
    _currentBranch = AppBranch.manado;
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
    if (upper == 'DPS' || upper == 'BALI') return AppBranch.bali;
    return AppBranch.manado;
  }

  static AppBranch parseBranchFromName(String? name) {
    if (name == null || name.isEmpty) return AppBranch.manado;
    final lower = name.trim().toLowerCase();
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

    // 1. Cek personil cabang Bali
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

    // 2. Cek personil cabang Manado / BSG
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
      case AppBranch.manado:
        return const [
          'Shift 1 (03:00 - 11:00)',
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
}
