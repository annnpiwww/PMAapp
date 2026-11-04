import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Foto absensi di Web disimpan di IndexedDB.
///
/// Kamera web menghasilkan `blob:` URL yang mati setiap kali Safari iOS
/// me-reload tab (memory pressure / pindah app). Karena `photoPath` di riwayat
/// hanya menyimpan URL itu, thumbnail jadi rusak setelah refresh. Byte foto
/// disimpan permanen di IndexedDB supaya riwayat tetap bisa tampil & diunduh.
const String _dbName = 'bss_attendance_photos';
const String _storeName = 'photos';

Future<web.IDBDatabase?>? _dbFuture;

Future<web.IDBDatabase?> _db() => _dbFuture ??= _openDb();

Future<web.IDBDatabase?> _openDb() async {
  try {
    final request = web.window.indexedDB.open(_dbName, 1);
    request.onupgradeneeded = ((web.Event _) {
      final db = request.result as web.IDBDatabase?;
      if (db != null && !db.objectStoreNames.contains(_storeName)) {
        db.createObjectStore(_storeName);
      }
    }).toJS;
    return await _wait(request) as web.IDBDatabase?;
  } catch (_) {
    // Private mode / kuota habis: biarkan fitur lain jalan tanpa foto tersimpan.
    _dbFuture = null;
    return null;
  }
}

Future<JSAny?> _wait(web.IDBRequest request) {
  final completer = Completer<JSAny?>();
  request.onsuccess = ((web.Event _) {
    if (!completer.isCompleted) completer.complete(request.result);
  }).toJS;
  request.onerror = ((web.Event _) {
    if (!completer.isCompleted) {
      completer.completeError(StateError('IndexedDB: ${request.error?.message}'));
    }
  }).toJS;
  return completer.future;
}

Future<void> putPhotoBlob(String id, Uint8List bytes) async {
  final db = await _db();
  if (db == null) return;
  try {
    final store = db.transaction(_storeName.toJS, 'readwrite').objectStore(_storeName);
    await _wait(store.put(bytes.toJS, id.toJS));
  } catch (_) {}
}

Future<Uint8List?> getPhotoBlob(String id) async {
  final db = await _db();
  if (db == null) return null;
  try {
    final store = db.transaction(_storeName.toJS).objectStore(_storeName);
    final value = await _wait(store.get(id.toJS));
    if (value == null || !value.isA<JSUint8Array>()) return null;
    return (value as JSUint8Array).toDart;
  } catch (_) {
    return null;
  }
}

Future<void> deletePhotoBlob(String id) async {
  final db = await _db();
  if (db == null) return;
  try {
    final store = db.transaction(_storeName.toJS, 'readwrite').objectStore(_storeName);
    await _wait(store.delete(id.toJS));
  } catch (_) {}
}

Future<void> clearAllPhotoBlobs() async {
  final db = await _db();
  if (db == null) return;
  try {
    final store = db.transaction(_storeName.toJS, 'readwrite').objectStore(_storeName);
    await _wait(store.clear());
  } catch (_) {}
}
