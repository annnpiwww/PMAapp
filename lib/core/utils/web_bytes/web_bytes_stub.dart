import 'dart:typed_data';

/// Non-web: tidak ada blob URL, jadi selalu null.
Future<Uint8List?> fetchWebBytes(String url) async => null;

String? createWebBlobUrl(Uint8List bytes, String mimeType) => null;
