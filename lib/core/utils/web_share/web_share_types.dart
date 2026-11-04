import 'dart:typed_data';

/// Hasil aksi simpan/bagikan foto di web.
///
/// iOS Safari tidak bisa menulis langsung ke aplikasi Photos. Satu-satunya
/// jalur resmi adalah menu Bagikan (share sheet) lalu pilih "Simpan Gambar".
enum WebShareOutcome {
  /// Menu Bagikan berhasil dibuka.
  shared,

  /// Browser mengunduh file ke folder Downloads/Files.
  downloaded,

  /// Foto tersimpan ke Galeri native (Android/iOS app).
  savedToGallery,

  /// User menutup menu Bagikan tanpa memilih aksi.
  cancelled,

  /// Browser tidak mendukung atau proses gagal.
  failed,
}

/// Satu file gambar yang akan dibagikan/diunduh lewat browser.
class WebShareFile {
  const WebShareFile({
    required this.bytes,
    required this.name,
    this.mimeType = 'image/jpeg',
  });

  final Uint8List bytes;
  final String name;
  final String mimeType;
}

extension WebShareOutcomeHint on WebShareOutcome {
  /// Petunjuk singkat yang jujur untuk user web/iPhone.
  String get saveHint {
    switch (this) {
      case WebShareOutcome.shared:
        return 'Pilih "Simpan Gambar" di menu Bagikan untuk masuk Galeri.';
      case WebShareOutcome.downloaded:
        return 'Foto diunduh ke Files/Downloads (bukan Galeri).';
      case WebShareOutcome.cancelled:
        return 'Foto belum disimpan ke Galeri.';
      case WebShareOutcome.savedToGallery:
        return 'Foto tersimpan di Galeri.';
      case WebShareOutcome.failed:
        return 'Foto gagal disimpan.';
    }
  }
}
