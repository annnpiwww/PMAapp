import 'dart:typed_data';

/// Non-web fallback: pemanggil memakai encoder isolate seperti biasa.
Future<Uint8List?> encodeRgbaToJpegWeb(
  Uint8List rgbaBytes,
  int width,
  int height,
  int quality,
) async {
  return null;
}
