import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class PhotoCleanupService {
  /// Bersihkan file temporary foto di cache / app doc yang usianya > [maxDays] hari
  static Future<int> cleanOldPhotos({int maxDays = 7}) async {
    int deletedCount = 0;
    try {
      final now = DateTime.now();
      final threshold = Duration(days: maxDays);

      final dirs = <Directory>[];

      try {
        final tempDir = await getTemporaryDirectory();
        dirs.add(tempDir);
      } catch (_) {}

      try {
        final appDocDir = await getApplicationDocumentsDirectory();
        dirs.add(appDocDir);
      } catch (_) {}

      for (final dir in dirs) {
        if (!dir.existsSync()) continue;

        try {
          await for (final entity in dir.list(recursive: true, followLinks: false)) {
            if (entity is File) {
              final pathLower = entity.path.toLowerCase();
              if (pathLower.endsWith('.jpg') || pathLower.endsWith('.jpeg') || pathLower.endsWith('.png')) {
                try {
                  final stat = await entity.stat();
                  final age = now.difference(stat.modified);
                  if (age > threshold) {
                    await entity.delete();
                    deletedCount++;
                  }
                } catch (_) {}
              }
            }
          }
        } catch (_) {}
      }

      debugPrint('[BSS-Storage] Auto-cleanup complete. Deleted $deletedCount old temporary photos (> $maxDays days).');
    } catch (e) {
      debugPrint('[BSS-Storage] Cleanup error: $e');
    }
    return deletedCount;
  }
}
