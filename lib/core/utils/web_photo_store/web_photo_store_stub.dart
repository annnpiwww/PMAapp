import 'dart:typed_data';

/// Native (Android/iOS) menyimpan foto sebagai file, jadi IndexedDB tidak dipakai.
Future<void> putPhotoBlob(String id, Uint8List bytes) async {}

Future<Uint8List?> getPhotoBlob(String id) async => null;

Future<void> deletePhotoBlob(String id) async {}

Future<void> clearAllPhotoBlobs() async {}
