# Design Specification: BSS Parking Optimization & Field Operations

- Date: 2026-08-29
- Author: Antigravity / Opencode
- Target Project: BssparkingTimeMark (Flutter)

---

## 1. Background & Objectives
Aplikasi BSS Parking TimeMark digunakan oleh teknisi dan personil lapangan untuk pelaporan operasional (Absensi, Briefing) dan pemeliharaan perangkat (Barrier Gate, Manless, Pos Kasir, Server). 
Berdasarkan kebutuhan operasional nyata di lapangan:
1. Pembukaan kamera harus instan (pre-warm) tanpa jeda "Tunggu sebentar".
2. Storage internal HP tidak boleh penuh karena timbunan foto lama (auto-cleanup > 7 hari).
3. Tombol shutter kamera harus responsif tanpa micro-stutter (isolate processing untuk image compression & watermark burn).
4. Mode senter (Torch) harus tersedia untuk menerangi kompartemen gelap dispenser tiket, barrier gate, dan rak server.
5. SharedPreferences harus dibersihkan dari base64 agar memory footprint ringan.
6. Laporan hasil maintenance dapat langsung dibagikan ke WhatsApp dengan template teks resmi BSS Parking disertai lampiran foto per-point.
7. Dukungan antrean offline (offline sync queue) saat sinyal di basement nol.

---

## 2. Architectural Components & Design

### 2.1 Camera Pre-Warm Service (`CameraManagerService`)
- Singleton service yang menginisialisasi controller kamera `ResolutionPreset.high` di latar belakang (background) begitu storage terinisialisasi di `main.dart`.
- `CameraCaptureScreen` dan `PointCameraView` akan meminta controller aktif dari `CameraManagerService`. Jika sudah ready, kamera langsung tampil tanpa delay.
- Menambahkan siklus lifecycle terpadu: pause preview / dispose saat background, recreate saat resume.

### 2.2 Flash Mode Selector: Support Torch (Senter)
- Siklus tombol flash diperluas: `FlashMode.off` -> `FlashMode.auto` -> `FlashMode.always` -> `FlashMode.torch`.
- Ikon UI berubah sesuai mode:
  - Off: `Icons.flash_off`
  - Auto: `Icons.flash_auto`
  - On: `Icons.flash_on`
  - Torch: `Icons.highlight` / `Icons.flashlight_on`
- Membantu teknisi memeriksa komponen fisik di ruang minim cahaya sebelum memotret.

### 2.3 Auto-Cleanup Temporary Photos (`PhotoCleanupService`)
- Service memeriksa direktori dokumen/temporary aplikasi saat startup di background.
- Aturan cleanup:
  - File foto watermark berumur > 7 hari (`DateTime.now().difference(file.lastModified()) > Duration(days: 7)`) akan dihapus otomatis dari disk.
  - File foto yang tersimpan di Galeri sistem utama (`Gal`) tetap aman karena sudah berada di storage publik perangkat.

### 2.4 Isolate Processing & Storage Sanitization
- `ImageWatermarkProcessor`:
  - Operasi decoding/scaling/kompresi gambar dijalankan terpisah agar UI thread tetap 60 FPS.
- `MaintenancePointResult` & `StorageService`:
  - Hilangkan penyimpanan string `imageBase64` pada penyimpanan lokal `SharedPreferences`.
  - Hanya simpan `imagePath` lokal dan metadata hasil verifikasi (status, alasan, confidence).

### 2.5 Offline Sync Queue (`SyncQueueService`)
- Setiap `MaintenanceSubmission` memiliki properti `isSynced: bool` (default: false jika offline).
- Jika AI Vision fallback ke offline saat pengambilan foto, submission ditandai `pendingSync`.
- Listener koneksi jaringan akan mendeteksi ketika internet kembali aktif dan memperbarui status sinkronisasi.

### 2.6 WhatsApp Report Generator & Multi-file Sharing
- Menyediakan generator teks template resmi BSS sesuai kategori:
  
#### Format Barrier Gate:
```text
Selamat [Pagi/Siang/Malam]
Izin melaporkan hasil maintenance BG, Palang, IPCAM, dan Sensor Lokasi [Nama Pos/Cabang]
Tanggal [Tanggal Indonesia]
Support [Nama Teknisi]

Note:
1. [Poin 1 kondisi]
2. [Poin 2 kondisi]
...
Terima kasih 🙏
```

#### Format Pos Kasir:
```text
Selamat [Pagi/Siang/Malam]
Izin melaporkan hasil maintenance POS
Tanggal [Tanggal Indonesia]
Lokasi [Nama Pos/Cabang]
Jumlah Gate Out [X] ([Unit terperiksa])
Support [Nama Teknisi]

Note:
- [Poin pemeriksaan pos]
...
Terima kasih 🙏
```

#### Format Manless / Server:
Disesuaikan mengikuti format seragam di atas dengan daftar poin lolos/catatan evaluasi AI.

- Fitur share menggunakan `share_plus` (`Share.shareXFiles`) yang melampirkan teks template sekaligus seluruh file foto watermark yang telah diambil pada sesi maintenance tersebut ke WhatsApp.

---

## 3. Data Model Updates
- `MaintenanceSubmission`:
  - Tambah field `isSynced: bool` (default `true`, `false` jika ada poin offline fallback).
- `MaintenancePointResult`:
  - Hapus string payload `imageBase64` dari serialisasi JSON `toJson()` untuk penyimpanan SharedPreferences (hanya gunakan saat transmisi API AI).

---

## 4. Verification & Testing
- Unit testing format template WhatsApp untuk tiap kategori (`TemplateCategory`).
- Unit testing auto-cleanup (mock file age > 7 hari).
- Unit testing `CameraManagerService` flash mode cycles.
- Integrasi build APK & instalasi ke perangkat fisik Android.
