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
    version: '2.0.132',
    date: '5 November 2026',
    features: [
      'Map Maintenance: lihat lokasi mana yang bermasalah, sekarang untuk Manado, Bali, dan HO',
      'SPV bisa isi alamat lokasi, titik di peta otomatis mengikuti alamat',
      'Analisa ulang foto dengan AI saat koneksi gagal, tanpa foto ulang',
      'Teknisi bisa ganti shift kalau salah pilih saat absen',
      'Halaman Daily Task SPV lebih ringkas, tombol Buat Tugas di kanan bawah',
    ],
    aiNote: 'AI lebih cepat membalas, dengan cadangan otomatis saat server AI sibuk',
    mapNote: 'Buka dari menu samping, pilih Map Maintenance.',
    bugfix: 'Beberapa bug sudah diperbaiki dan aplikasi lebih ringan saat memuat tugas.',
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
