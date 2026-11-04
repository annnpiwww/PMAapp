import 'package:package_info_plus/package_info_plus.dart';

import 'storage_service.dart';

/// Isi layar "Apa yang baru" untuk satu rilis.
class WhatsNewRelease {
  final String version;
  final String date;
  final List<String> features;
  final String? aiNote;
  final String? mapNote;
  final String bugfix;

  const WhatsNewRelease({
    required this.version,
    required this.date,
    required this.features,
    this.aiNote,
    this.mapNote,
    required this.bugfix,
  });
}

/// Menentukan kapan layar "Apa yang baru" muncul.
///
/// Aturan: pemasangan baru tidak pernah melihat layar ini, yang menimpa
/// aplikasi lama melihatnya satu kali per versi.
class WhatsNewService {
  static const String _keySeenVersion = 'bss_whats_new_seen_version_v1';

  /// Diisi ulang tiap versi naik, bareng bump di pubspec.yaml.
  static const WhatsNewRelease current = WhatsNewRelease(
    version: '2.0.130',
    date: '4 November 2026',
    features: [
      'Halaman Daily Task Team PMA baru: progres tim, filter teknisi, buat tugas lewat lembar bawah',
    ],
    aiNote:
        'Waktu absensi tetap memakai jam terverifikasi server, bukan jam HP',
    mapNote:
        'Lihat peta POS yang sudah dan belum maintenance, lengkap dengan daftar temuan. Buka dari menu samping, pilih Map Maintenance. Khusus KC Manado.',
    bugfix: 'Beberapa bug sudah diperbaiki.',
  );

  /// `seen` kosong berarti aplikasi belum pernah mencatat versi di perangkat ini.
  /// Di kondisi itu layar hanya boleh muncul kalau memang hasil menimpa
  /// aplikasi lama (`isUpdate`), bukan pemasangan baru.
  static bool shouldShow({
    required String? seen,
    required String current,
    required bool isUpdate,
  }) {
    if (seen == current) return false;
    if (seen == null || seen.trim().isEmpty) return isUpdate;
    return true;
  }

  /// Balikin rilis yang perlu ditampilkan, atau null kalau tidak perlu.
  /// Versi langsung dicatat supaya tidak muncul dua kali.
  static Future<WhatsNewRelease?> check() async {
    final info = await PackageInfo.fromPlatform();
    final stamp = '${info.version}+${info.buildNumber}';
    final installTime = info.installTime;
    final updateTime = info.updateTime;
    final isUpdate =
        installTime != null &&
        updateTime != null &&
        updateTime.isAfter(installTime);

    final show = shouldShow(
      seen: StorageService.getString(_keySeenVersion),
      current: stamp,
      isUpdate: isUpdate,
    );
    await StorageService.setString(_keySeenVersion, stamp);
    return show ? current : null;
  }
}
