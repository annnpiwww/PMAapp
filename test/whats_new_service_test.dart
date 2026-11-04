import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:bssparking_timemark/data/services/whats_new_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WhatsNewService.shouldShow', () {
    test('pemasangan baru tidak memunculkan layar', () {
      expect(
        WhatsNewService.shouldShow(
          seen: null,
          current: '2.0.117+2130',
          isUpdate: false,
        ),
        isFalse,
      );
    });

    test('menimpa aplikasi lama memunculkan layar sekali', () {
      expect(
        WhatsNewService.shouldShow(
          seen: null,
          current: '2.0.117+2130',
          isUpdate: true,
        ),
        isTrue,
      );
    });

    test('versi yang sama tidak memunculkan layar lagi', () {
      expect(
        WhatsNewService.shouldShow(
          seen: '2.0.117+2130',
          current: '2.0.117+2130',
          isUpdate: true,
        ),
        isFalse,
      );
    });

    test('versi berbeda memunculkan layar lagi', () {
      expect(
        WhatsNewService.shouldShow(
          seen: '2.0.116+2129',
          current: '2.0.117+2130',
          isUpdate: true,
        ),
        isTrue,
      );
    });
  });

  test('isi rilis mengikuti versi di pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(r'^version:\s*(\S+?)\+\d+\s*$', multiLine: true)
        .firstMatch(pubspec);
    expect(match, isNotNull, reason: 'version di pubspec.yaml tidak terbaca');
    expect(
      WhatsNewService.current.version,
      match!.group(1),
      reason: 'Versi naik tapi isi layar "Apa yang baru" belum diperbarui',
    );
  });

  test('setiap bagian rilis terisi', () {
    final release = WhatsNewService.current;
    expect(release.features, isNotEmpty);
    expect(release.features.every((f) => f.trim().isNotEmpty), isTrue);
    expect(release.bugfix.trim(), isNotEmpty);
    expect(release.aiNote, isNotNull);
  });
}
