import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// APK yang sudah terpasang di HP teknisi (v2.0.66) punya versionCode 2074.
/// Kalau build number lebih kecil, Android menolak update dengan pesan
/// "tidak kompatibel" dan teknisi dipaksa uninstall (data absensi & riwayat hilang).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('build number (versionCode) selalu di atas APK yang sudah terpasang', () {
    const minBuildNumber = 2100;
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(r'^version:\s*(\S+?)\+(\d+)\s*$', multiLine: true)
        .firstMatch(pubspec);
    expect(match, isNotNull, reason: 'version di pubspec.yaml tidak terbaca');

    final versionName = match!.group(1)!;
    final buildNumber = int.parse(match.group(2)!);

    expect(
      buildNumber,
      greaterThanOrEqualTo(minBuildNumber),
      reason:
          'versionCode $buildNumber (< $minBuildNumber) akan ditolak Android '
          'sebagai downgrade saat update di atas APK lama',
    );
    expect(versionName, isNotEmpty);
  });
}
