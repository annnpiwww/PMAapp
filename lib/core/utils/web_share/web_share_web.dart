import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'web_share_types.dart';

/// Membuka share sheet browser (iOS: Bagikan -> Simpan Gambar / WhatsApp /
/// Telegram). Dipanggil tanpa await sebelum fungsi ini agar user activation
/// dari tap tombol masih valid di Safari.
Future<WebShareOutcome> shareFilesOnWeb({
  required List<WebShareFile> files,
  String? text,
  String? title,
}) async {
  if (files.isEmpty) return WebShareOutcome.failed;

  final jsFiles = <web.File>[];
  try {
    for (final file in files) {
      jsFiles.add(_toJsFile(file));
    }
  } catch (_) {
    return WebShareOutcome.failed;
  }

  final shareText = text?.trim() ?? '';
  final shareTitle = title?.trim() ?? '';
  final web.ShareData data;
  if (shareText.isEmpty && shareTitle.isEmpty) {
    data = web.ShareData(files: jsFiles.toJS);
  } else if (shareText.isEmpty) {
    data = web.ShareData(files: jsFiles.toJS, title: shareTitle);
  } else if (shareTitle.isEmpty) {
    data = web.ShareData(files: jsFiles.toJS, text: shareText);
  } else {
    data = web.ShareData(files: jsFiles.toJS, title: shareTitle, text: shareText);
  }

  try {
    if (!web.window.navigator.canShare(data)) {
      return _download(files);
    }
  } catch (_) {
    return _download(files);
  }

  try {
    await web.window.navigator.share(data).toDart;
    return WebShareOutcome.shared;
  } on web.DOMException catch (e) {
    if (e.name == 'AbortError') return WebShareOutcome.cancelled;
    return _download(files);
  } catch (_) {
    return _download(files);
  }
}

/// Membuka share sheet browser khusus teks tanpa lampiran file.
/// Dipanggil tanpa await sebelum fungsi ini agar user activation Safari valid.
Future<WebShareOutcome> shareTextOnWeb({
  required String text,
  String? title,
}) async {
  final shareText = text.trim();
  if (shareText.isEmpty) return WebShareOutcome.failed;

  final shareTitle = title?.trim() ?? '';
  final data = shareTitle.isEmpty
      ? web.ShareData(text: shareText)
      : web.ShareData(text: shareText, title: shareTitle);

  try {
    await web.window.navigator.share(data).toDart;
    return WebShareOutcome.shared;
  } on web.DOMException catch (e) {
    if (e.name == 'AbortError') return WebShareOutcome.cancelled;
    return WebShareOutcome.failed;
  } catch (_) {
    return WebShareOutcome.failed;
  }
}

/// Unduh langsung ke folder Downloads/Files browser.
Future<WebShareOutcome> downloadFilesOnWeb({
  required List<WebShareFile> files,
}) async {
  if (files.isEmpty) return WebShareOutcome.failed;
  return _download(files);
}

web.File _toJsFile(WebShareFile file) {
  return web.File(
    <JSUint8Array>[file.bytes.toJS].toJS,
    file.name,
    web.FilePropertyBag()..type = file.mimeType,
  );
}

WebShareOutcome _download(List<WebShareFile> files) {
  try {
    for (final file in files) {
      final url = web.URL.createObjectURL(_toJsFile(file));
      final anchor = web.HTMLAnchorElement()
        ..href = url
        ..download = file.name
        ..style.display = 'none';
      web.document.body?.appendChild(anchor);
      anchor.click();
      anchor.remove();
      // Jangan revoke langsung: Safari butuh waktu memulai unduhan.
      Timer(const Duration(minutes: 1), () => web.URL.revokeObjectURL(url));
    }
    return WebShareOutcome.downloaded;
  } catch (_) {
    return WebShareOutcome.failed;
  }
}
