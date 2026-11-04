import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Encode RGBA mentah ke JPEG memakai canvas browser.
///
/// Jauh lebih cepat daripada encoder JPEG Dart murni di Safari, terutama untuk
/// foto kamera 1-2 MP. Return null kalau browser gagal supaya pemanggil bisa
/// jatuh ke encoder isolate.
Future<Uint8List?> encodeRgbaToJpegWeb(
  Uint8List rgbaBytes,
  int width,
  int height,
  int quality,
) async {
  try {
    final canvas = web.HTMLCanvasElement()
      ..width = width
      ..height = height;
    final ctx = canvas.getContext('2d') as web.CanvasRenderingContext2D?;
    if (ctx == null) return null;

    final imageData = ctx.createImageData(width.toJS, height);
    imageData.data.toDart.setAll(0, rgbaBytes);
    ctx.putImageData(imageData, 0, 0);

    final completer = Completer<web.Blob?>();
    canvas.toBlob(
      ((web.Blob? blob) => completer.complete(blob)).toJS,
      'image/jpeg',
      (quality / 100).toJS,
    );
    final blob = await completer.future;
    if (blob == null) return null;

    final buffer = await blob.arrayBuffer().toDart;
    return buffer.toDart.asUint8List();
  } catch (_) {
    return null;
  }
}
