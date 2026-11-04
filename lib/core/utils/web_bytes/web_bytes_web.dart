import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Ambil isi `blob:` URL (hasil kamera web) atau URL lain lewat fetch browser.
/// Return null kalau blob sudah mati / tidak bisa dibaca.
Future<Uint8List?> fetchWebBytes(String url) async {
  try {
    final resp = await web.window.fetch(url.toJS).toDart;
    if (resp.status != 200) return null;
    final buffer = await resp.arrayBuffer().toDart;
    return buffer.toDart.asUint8List();
  } catch (_) {
    return null;
  }
}

/// Bungkus byte jadi `blob:` URL (mis. foto yang sudah ber-watermark).
/// Return null kalau browser menolak.
String? createWebBlobUrl(Uint8List bytes, String mimeType) {
  try {
    final blob = web.Blob(<JSUint8Array>[bytes.toJS].toJS, web.BlobPropertyBag()..type = mimeType);
    return web.URL.createObjectURL(blob);
  } catch (_) {
    return null;
  }
}
