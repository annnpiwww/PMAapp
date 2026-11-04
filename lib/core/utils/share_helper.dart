import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'web_bytes/web_bytes.dart';
import 'web_share/web_share.dart';
export 'web_share/web_share_types.dart';

class ShareHelper {
  static const MethodChannel _directChannel =
      MethodChannel('com.bssparking.timemark/direct_share');

  /// Simpan foto ke Galeri native (Android/iOS app).
  ///
  /// Di web, iOS Safari tidak punya akses tulis langsung ke Photos. Default web
  /// adalah unduh ke Files/Downloads; set [shareSheetOnWeb] agar menu Bagikan
  /// dibuka supaya user bisa pilih "Simpan Gambar".
  static Future<bool> savePhotoToGallery(
    String? imagePath, {
    Uint8List? imageBytes,
    String? fileName,
  }) async {
    final outcome = await savePhotoToGalleryOutcome(
      imagePath,
      imageBytes: imageBytes,
      fileName: fileName,
    );
    return outcome == WebShareOutcome.savedToGallery ||
        outcome == WebShareOutcome.shared ||
        outcome == WebShareOutcome.downloaded;
  }

  static Future<WebShareOutcome> savePhotoToGalleryOutcome(
    String? imagePath, {
    Uint8List? imageBytes,
    String? fileName,
    bool shareSheetOnWeb = false,
  }) async {
    if (kIsWeb) {
      var bytes = imageBytes;
      if (bytes == null || bytes.isEmpty) {
        if (imagePath == null || imagePath.trim().isEmpty) {
          return WebShareOutcome.failed;
        }
        bytes = await _readWebImageBytes(imagePath.trim());
      }
      if (bytes == null || bytes.isEmpty) return WebShareOutcome.failed;

      final files = [
        WebShareFile(bytes: bytes, name: fileName ?? _webFileName()),
      ];
      return shareSheetOnWeb
          ? shareFilesOnWeb(files: files)
          : downloadFilesOnWeb(files: files);
    }

    if (imagePath == null || imagePath.isEmpty) {
      return WebShareOutcome.failed;
    }

    File file;
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      try {
        final res = await http.get(Uri.parse(imagePath)).timeout(const Duration(seconds: 25));
        if (res.statusCode != 200) return WebShareOutcome.failed;
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/task_proof_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await tempFile.writeAsBytes(res.bodyBytes);
        file = tempFile;
      } catch (_) {
        return WebShareOutcome.failed;
      }
    } else {
      file = File(imagePath);
      if (!file.existsSync()) return WebShareOutcome.failed;
    }

    try {
      final hasAccess = await Gal.hasAccess(toAlbum: true);
      if (!hasAccess) {
        await Gal.requestAccess(toAlbum: true);
      }
      await Gal.putImage(file.path, album: 'BSS Parking');
      return WebShareOutcome.savedToGallery;
    } catch (_) {
      // Fallback silent fail if permission denied
      return WebShareOutcome.failed;
    }
  }

  static String _webFileName() {
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return 'PMAapp_${now.year}${two(now.month)}${two(now.day)}_'
        '${two(now.hour)}${two(now.minute)}${two(now.second)}.jpg';
  }

  static Future<Uint8List?> _readWebImageBytes(String path) async {
    if (path.startsWith('data:image')) {
      final comma = path.indexOf(',');
      if (comma < 0) return null;
      try {
        return base64Decode(path.substring(comma + 1));
      } catch (_) {
        return null;
      }
    }
    // blob: URL (hasil kamera web) tidak bisa diambil lewat http, harus fetch.
    if (path.startsWith('blob:')) {
      return fetchWebBytes(path);
    }
    try {
      final res = await http.get(Uri.parse(path)).timeout(const Duration(seconds: 25));
      if (res.statusCode != 200 || res.bodyBytes.isEmpty) return null;
      return res.bodyBytes;
    } catch (_) {
      return null;
    }
  }

  static Future<WebShareOutcome> _shareOnWeb({
    required String text,
    String? imagePath,
    List<String>? imagePaths,
    Uint8List? imageBytes,
    List<WebShareFile>? webFiles,
    String? fileName,
    required bool telegram,
  }) async {
    final files = <WebShareFile>[];

    // Jalur cepat: byte sudah di memori (kamera / hasil watermark web). Tidak ada
    // await sebelum share sheet dibuka supaya user activation Safari tidak hilang.
    if (webFiles != null && webFiles.isNotEmpty) {
      files.addAll(webFiles);
    } else if (imageBytes != null && imageBytes.isNotEmpty) {
      files.add(WebShareFile(bytes: imageBytes, name: fileName ?? _webFileName()));
    } else {
      final paths = <String>[
        if (imagePaths != null) ...imagePaths,
        if (imagePath != null && imagePath.trim().isNotEmpty) imagePath.trim(),
      ];
      for (final path in paths) {
        final bytes = await _readWebImageBytes(path);
        if (bytes != null && bytes.isNotEmpty) {
          files.add(WebShareFile(bytes: bytes, name: fileName ?? _webFileName()));
        }
      }
    }

    if (files.isEmpty) {
      return _openWebTextOnly(text: text, telegram: telegram);
    }

    return shareFilesOnWeb(files: files, text: text, title: 'Laporan PMAapp');
  }

  /// iOS/WhatsApp membuang `text` saat yang dibagikan berupa foto, jadi caption
  /// disalin setelah share sheet dibuka supaya teknisi bisa tinggal paste.
  static Future<void> _copyCaptionOnWeb(String text) async {
    if (text.trim().isEmpty) return;
    try {
      await Clipboard.setData(ClipboardData(text: text));
    } catch (_) {}
  }

  static Future<WebShareOutcome> _openWebTextOnly({
    required String text,
    required bool telegram,
  }) async {
    final uri = telegram
        ? Uri.parse('https://t.me/share/url?text=${Uri.encodeComponent(text)}')
        : Uri.parse('https://api.whatsapp.com/send?text=${Uri.encodeComponent(text)}');
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        return WebShareOutcome.shared;
      }
    } catch (_) {}
    return WebShareOutcome.failed;
  }

  /// Mengonversi format markdown bold (*teks*) menjadi Unicode Mathematical Bold
  /// agar tetap tebal saat dibagikan ke Telegram (yang tidak mem-parse asterisks secara otomatis).
  static String convertMarkdownBoldToUnicode(String input) {
    if (!input.contains('*')) return input;

    final regex = RegExp(r'\*([^*]+)\*');
    return input.replaceAllMapped(regex, (match) {
      final inner = match.group(1) ?? '';
      final buffer = StringBuffer();
      for (final rune in inner.runes) {
        // A-Z (0x41 - 0x5A) -> Mathematical Bold Capital (0x1D400 - 0x1D419)
        if (rune >= 0x41 && rune <= 0x5A) {
          buffer.writeCharCode(0x1D400 + (rune - 0x41));
        }
        // a-z (0x61 - 0x7A) -> Mathematical Bold Small (0x1D41A - 0x1D433)
        else if (rune >= 0x61 && rune <= 0x7A) {
          buffer.writeCharCode(0x1D41A + (rune - 0x61));
        }
        // 0-9 (0x30 - 0x39) -> Mathematical Bold Digit (0x1D7CE - 0x1D7D7)
        else if (rune >= 0x30 && rune <= 0x39) {
          buffer.writeCharCode(0x1D7CE + (rune - 0x30));
        } else {
          buffer.writeCharCode(rune);
        }
      }
      return buffer.toString();
    });
  }

  /// Opens Telegram directly with pre-filled message and/or shares image without system picker
  static Future<WebShareOutcome> shareToTelegram({
    required String text,
    String? imagePath,
    List<String>? imagePaths,
    Uint8List? imageBytes,
    List<WebShareFile>? webFiles,
    String? fileName,
  }) async {
    // Format text khusus Telegram: konversi *teks* menjadi karakter Unicode Bold
    final formattedText = convertMarkdownBoldToUnicode(text);

    // Web: buka share sheet sebelum await apa pun agar user activation Safari valid.
    if (kIsWeb) {
      final outcome = _shareOnWeb(
        text: formattedText,
        imagePath: imagePath,
        imagePaths: imagePaths,
        imageBytes: imageBytes,
        webFiles: webFiles,
        fileName: fileName,
        telegram: true,
      );
      await _copyCaptionOnWeb(formattedText);
      return outcome;
    }

    // Otomatis selalu salin teks ke clipboard jika ada teks laporan
    // (Jaminan anti-gagal jika Telegram/WA di device tertentu mengabaikan EXTRA_TEXT saat mengirim gambar)
    if (formattedText.isNotEmpty) {
      try { await Clipboard.setData(ClipboardData(text: formattedText)); } catch (_) {}
    }

    // 1. Coba Direct Intent Android (Langsung Buka Telegram tanpa dialog picker)
    if (Platform.isAndroid) {
      try {
        final success = await _directChannel.invokeMethod<bool>('shareDirect', {
          'target': 'telegram',
          'text': formattedText,
          'imagePath': imagePath,
          'imagePaths': imagePaths,
        });
        if (success == true) return WebShareOutcome.shared;
      } catch (_) {}
    }

    // 2. Fallback: SharePlus atau URI scheme
    final encodedText = Uri.encodeComponent(formattedText);
    final tgDirectUri = Uri.parse('tg://msg?text=$encodedText');
    final tgWebUri = Uri.parse('https://t.me/share/url?text=$encodedText');

    final validFiles = <XFile>[];
    if (imagePaths != null && imagePaths.isNotEmpty) {
      for (final p in imagePaths) {
        if (File(p).existsSync()) validFiles.add(XFile(p));
      }
    } else if (imagePath != null && File(imagePath).existsSync()) {
      validFiles.add(XFile(imagePath));
    }

    if (validFiles.isNotEmpty) {
      try {
        await SharePlus.instance.share(
          ShareParams(
            files: validFiles,
            text: formattedText,
            subject: 'Laporan PMAapp',
          ),
        );
        return WebShareOutcome.shared;
      } catch (e) {
        debugPrint('[ShareHelper] SharePlus Telegram with files failed: $e');
        return WebShareOutcome.failed;
      }
    }

    try {
      if (await canLaunchUrl(tgDirectUri)) {
        if (await launchUrl(tgDirectUri, mode: LaunchMode.externalApplication)) {
          return WebShareOutcome.shared;
        }
      } else if (await canLaunchUrl(tgWebUri)) {
        if (await launchUrl(tgWebUri, mode: LaunchMode.externalApplication)) {
          return WebShareOutcome.shared;
        }
      }
      await SharePlus.instance.share(
        ShareParams(text: formattedText, subject: 'Laporan PMAapp'),
      );
      return WebShareOutcome.shared;
    } catch (_) {
      try {
        await SharePlus.instance.share(
          ShareParams(text: formattedText, subject: 'Laporan PMAapp'),
        );
        return WebShareOutcome.shared;
      } catch (_) {
        return WebShareOutcome.failed;
      }
    }
  }

  /// Opens WhatsApp directly with pre-filled message and/or shares image without system picker
  static Future<WebShareOutcome> shareToWhatsApp({
    required String text,
    String? imagePath,
    List<String>? imagePaths,
    Uint8List? imageBytes,
    List<WebShareFile>? webFiles,
    String? fileName,
  }) async {
    // Web: buka share sheet sebelum await apa pun agar user activation Safari valid.
    if (kIsWeb) {
      final outcome = _shareOnWeb(
        text: text,
        imagePath: imagePath,
        imagePaths: imagePaths,
        imageBytes: imageBytes,
        webFiles: webFiles,
        fileName: fileName,
        telegram: false,
      );
      await _copyCaptionOnWeb(text);
      return outcome;
    }

    // Otomatis selalu salin teks ke clipboard jika ada teks laporan
    // (Jaminan anti-gagal jika WhatsApp di device tertentu mengabaikan EXTRA_TEXT saat mengirim gambar)
    if (text.isNotEmpty) {
      try { await Clipboard.setData(ClipboardData(text: text)); } catch (_) {}
    }

    // 1. Coba Direct Intent Android (Langsung Buka WhatsApp / WA Business tanpa dialog picker)
    if (Platform.isAndroid) {
      try {
        final success = await _directChannel.invokeMethod<bool>('shareDirect', {
          'target': 'whatsapp',
          'text': text,
          'imagePath': imagePath,
          'imagePaths': imagePaths,
        });
        if (success == true) return WebShareOutcome.shared;
      } catch (e) {
        debugPrint('[ShareHelper] Direct share to WhatsApp failed: $e');
      }
    }

    // 2. Fallback: SharePlus atau URI scheme
    final validFiles = <XFile>[];
    if (imagePaths != null && imagePaths.isNotEmpty) {
      for (final p in imagePaths) {
        if (File(p).existsSync()) validFiles.add(XFile(p));
      }
    } else if (imagePath != null && File(imagePath).existsSync()) {
      validFiles.add(XFile(imagePath));
    }

    // PENTING: Jika ada file media (foto/video), kirim melalui SharePlus dengan lampiran file.
    // JANGAN PERNAH fallback ke waDirectUri (whatsapp://send?text=...) karena URI scheme
    // WhatsApp HANYA menerima teks dan otomatis membuang/menghilangkan semua file foto dan video!
    if (validFiles.isNotEmpty) {
      try {
        await SharePlus.instance.share(
          ShareParams(
            files: validFiles,
            text: text,
            subject: 'Laporan PMAapp',
          ),
        );
        return WebShareOutcome.shared;
      } catch (e) {
        debugPrint('[ShareHelper] SharePlus WhatsApp with files failed: $e');
        return WebShareOutcome.failed;
      }
    }

    // Hanya jika benar-benar TIDAK ADA file media (laporan teks murni)
    final encodedText = Uri.encodeComponent(text);
    final waDirectUri = Uri.parse('whatsapp://send?text=$encodedText');
    final waWebUri = Uri.parse('https://api.whatsapp.com/send?text=$encodedText');

    try {
      if (await canLaunchUrl(waDirectUri)) {
        if (await launchUrl(waDirectUri, mode: LaunchMode.externalApplication)) {
          return WebShareOutcome.shared;
        }
      } else if (await canLaunchUrl(waWebUri)) {
        if (await launchUrl(waWebUri, mode: LaunchMode.externalApplication)) {
          return WebShareOutcome.shared;
        }
      }
      await SharePlus.instance.share(
        ShareParams(text: text, subject: 'Laporan PMAapp'),
      );
      return WebShareOutcome.shared;
    } catch (_) {
      try {
        await SharePlus.instance.share(
          ShareParams(text: text, subject: 'Laporan PMAapp'),
        );
        return WebShareOutcome.shared;
      } catch (_) {
        return WebShareOutcome.failed;
      }
    }
  }
}
