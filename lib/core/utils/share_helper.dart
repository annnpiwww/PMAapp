import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class ShareHelper {
  static const MethodChannel _directChannel =
      MethodChannel('com.bssparking.timemark/direct_share');

  /// Saves photo to device gallery
  static Future<bool> savePhotoToGallery(String? imagePath) async {
    if (kIsWeb) return true; // Web browser doesn't have native Gallery access
    if (imagePath == null || imagePath.isEmpty) return false;
    final file = File(imagePath);
    if (!file.existsSync()) return false;

    try {
      final hasAccess = await Gal.hasAccess(toAlbum: true);
      if (!hasAccess) {
        await Gal.requestAccess(toAlbum: true);
      }
      await Gal.putImage(file.path, album: 'BSS Parking');
      return true;
    } catch (_) {
      // Fallback silent fail if permission denied
      return false;
    }
  }

  /// Opens Telegram directly with pre-filled message and/or shares image without system picker
  static Future<void> shareToTelegram({
    required String text,
    String? imagePath,
    List<String>? imagePaths,
  }) async {
    // Otomatis selalu salin teks ke clipboard jika ada teks laporan
    // (Jaminan anti-gagal jika Telegram/WA di device tertentu mengabaikan EXTRA_TEXT saat mengirim gambar)
    if (text.isNotEmpty) {
      try { await Clipboard.setData(ClipboardData(text: text)); } catch (_) {}
    }

    // 1. Coba Direct Intent Android (Langsung Buka Telegram tanpa dialog picker)
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final success = await _directChannel.invokeMethod<bool>('shareDirect', {
          'target': 'telegram',
          'text': text,
          'imagePath': imagePath,
          'imagePaths': imagePaths,
        });
        if (success == true) return;
      } catch (_) {}
    }

    // 2. Fallback: SharePlus atau URI scheme
    final encodedText = Uri.encodeComponent(text);
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
            text: text,
            subject: 'Laporan BSS Parking Timemark',
          ),
        );
      } catch (e) {
        debugPrint('[ShareHelper] SharePlus Telegram with files failed: $e');
      }
      return;
    }

    try {
      if (await canLaunchUrl(tgDirectUri)) {
        await launchUrl(tgDirectUri, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(tgWebUri)) {
        await launchUrl(tgWebUri, mode: LaunchMode.externalApplication);
      } else {
        await SharePlus.instance.share(
          ShareParams(text: text, subject: 'Laporan BSS Parking Timemark'),
        );
      }
    } catch (_) {
      await SharePlus.instance.share(
        ShareParams(text: text, subject: 'Laporan BSS Parking Timemark'),
      );
    }
  }

  /// Opens WhatsApp directly with pre-filled message and/or shares image without system picker
  static Future<void> shareToWhatsApp({
    required String text,
    String? imagePath,
    List<String>? imagePaths,
  }) async {
    // Otomatis selalu salin teks ke clipboard jika ada teks laporan
    // (Jaminan anti-gagal jika WhatsApp di device tertentu mengabaikan EXTRA_TEXT saat mengirim gambar)
    if (text.isNotEmpty) {
      try { await Clipboard.setData(ClipboardData(text: text)); } catch (_) {}
    }

    // 1. Coba Direct Intent Android (Langsung Buka WhatsApp / WA Business tanpa dialog picker)
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final success = await _directChannel.invokeMethod<bool>('shareDirect', {
          'target': 'whatsapp',
          'text': text,
          'imagePath': imagePath,
          'imagePaths': imagePaths,
        });
        if (success == true) return;
      } catch (e) {
        debugPrint('[ShareHelper] Direct share to WhatsApp failed: $e');
      }
    }

    // 2. Fallback: SharePlus atau URI scheme
    final validFiles = <XFile>[];
    if (!kIsWeb) {
      if (imagePaths != null && imagePaths.isNotEmpty) {
        for (final p in imagePaths) {
          if (File(p).existsSync()) validFiles.add(XFile(p));
        }
      } else if (imagePath != null && File(imagePath).existsSync()) {
        validFiles.add(XFile(imagePath));
      }
    } else {
      if (imagePaths != null && imagePaths.isNotEmpty) {
        for (final p in imagePaths) {
          validFiles.add(XFile(p));
        }
      } else if (imagePath != null) {
        validFiles.add(XFile(imagePath));
      }
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
            subject: 'Laporan BSS Parking Timemark',
          ),
        );
      } catch (e) {
        debugPrint('[ShareHelper] SharePlus WhatsApp with files failed: $e');
      }
      return;
    }

    // Hanya jika benar-benar TIDAK ADA file media (laporan teks murni)
    final encodedText = Uri.encodeComponent(text);
    final waDirectUri = Uri.parse('whatsapp://send?text=$encodedText');
    final waWebUri = Uri.parse('https://api.whatsapp.com/send?text=$encodedText');

    try {
      if (await canLaunchUrl(waDirectUri)) {
        await launchUrl(waDirectUri, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(waWebUri)) {
        await launchUrl(waWebUri, mode: LaunchMode.externalApplication);
      } else {
        await SharePlus.instance.share(
          ShareParams(text: text, subject: 'Laporan BSS Parking Timemark'),
        );
      }
    } catch (_) {
      await SharePlus.instance.share(
        ShareParams(text: text, subject: 'Laporan BSS Parking Timemark'),
      );
    }
  }
}
