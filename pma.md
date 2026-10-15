# Dokumentasi Sistem BssparkingTimeMark (pma.md)

Dokumen ini memuat data riil, fitur lengkap, arsitektur, parameter teknis, dan Standard Operating Procedure (SOP) resmi yang ada pada proyek **BssparkingTimeMark** (PMA Parking TimeMark & Attendance App).

---

## 🏢 1. Profil Proyek & Identitas Aplikasi
- **Nama Aplikasi**: PMA App (BssparkingTimeMark)
- **Paket / Versi**: `bssparking_timemark` v2.0.86+94
- **Platform Didukung**:
  - Android APK (Split ABI: `arm64-v8a`, `armeabi-v7a`, `x86_64`)
  - Web PWA: [https://bssparking-pma.vercel.app](https://bssparking-pma.vercel.app)
- **Organisasi / Perusahaan**: BSS Parking (PT Bahana Sulut Sentosa)
- **Cabang Operasional**:
  - **KC Manado (`MDO`)**: Default SPV: Farhan Lakoro | Tag Default: `PBM` | Header Rekap: `REKAP DAILY TEAM PMA KC BSG`
  - **KC Bali (`DPS`)**: Default SPV: Indra Yohana | Tag Default: `PBKD` | Header Rekap: `REKAP DAILY TEAM PMA KC BALI`

---

## 🎨 2. Sistem Desain & Identitas Visual (AppColors)
- **Brand Signature**:
  - **Royal Blue (`0xFF1A428A`)**: Warna primer identitas BSS Parking.
  - **Vibrant Blue (`0xFF2563EB`)**: Warna aksen operasional terang.
  - **Safety Orange (`0xFFFF6500`)**: Tombol aksi utama, watermark accent, shutter ring.
- **Surface & Background**:
  - **Warm Cream Slate (`0xFFFAF8F5`)**: Background canvas anti-silau.
  - **Warm White (`0xFFFFFDF9`)**: Surface card utama.
- **Status & Outdoor High-Contrast**:
  - **Sesuai (Emerald Green)**: `#059669` (Teks putih di atas badge solid).
  - **Tidak Sesuai / Warning (Deep Amber)**: `#C2410C` / `#752505` (Kontras tinggi tahan terik matahari).
  - **Bahaya / Reject (Rose Red)**: `#DC2626`.

---

## 🛡️ 3. Fitur Keamanan, Anti-Cheat & Offline-First

### 3.1. SecureTimeService (Anti-Tampering Jam Kerja)
- Sinkronisasi waktu jaringan via Google Date Header / NTP HTTP (`https://www.google.com/generate_204`).
- **Deteksi Manipulasi Jam (Clock Tampering)**: Toleransi perbedaan waktu lokal HP vs server adalah **300 detik (5 menit)**.
- **Deteksi Clock Skew**: Menggunakan hardware monotonic `Stopwatch` sejak startup aplikasi. Jika jam HP diubah maju/mundur saat aplikasi berjalan, sistem menandai watermark dengan tag:
  `[JAM DIUBAH MANUAL]`
- **Offline Cold-Start Defense**: Menyimpan anchor waktu jaringan terakhir di local storage terenkripsi.

### 3.2. LocationService & Geofencing GPS
- Verifikasi koordinat latitude/longitude GPS dengan reverse geocoding alamat nyata.
- Fallback toleran ketika hardware GPS kehilangan sinyal atau berada di area basement.

### 3.3. Penyimpanan & Sanitasi Otomatis
- **StorageService**: Penyimpanan lokal terisolasi via SharedPreferences dan File System.
- **PhotoCleanupService**: Pembersihan otomatis file temporary foto watermarking di cache aplikasi (>30 hari atau setelah sinkronisasi selesai) untuk menghemat ruang memori teknisi.
- **Memory Limit Safety**: Pembatasan log histori absensi maksimal 150 item guna mencegah crash kehabisan memori.

---

## 📋 4. Standard Operating Procedure (SOP) & Template Checklist

### 4.1. Template Absensi (`tpl_absensi_01`)
- **Tujuan**: Dokumentasi kehadiran masuk shift dan pulang shift seluruh petugas.
- **Kategori Personil**:
  - **Teknisi BSS**: Wajib seragam teknisi resmi / PDH harian, lanyard ID card, celana panjang, dan sepatu tertutup.
- **Jadwal Seragam Teknisi**:
  - *Senin*: Seragam Teknisi / PDH navy
  - *Selasa*: PDH navy / Seragam Teknisi
  - *Rabu*: Seragam Teknisi
  - *Kamis*: BSS Putih / Seragam Teknisi
  - *Jumat*: Batik / Seragam Teknisi
  - *Sabtu*: Olahraga biru-kuning / Seragam Teknisi
  - *Minggu*: Bebas rapi / Seragam Teknisi
- **Aturan Absen Masuk**: Foto full-body menghadap kamera memperlihatkan seragam, lanyard ID card, dan sepatu kerja.
- **Aturan Absen Pulang**: Foto setengah badan sah; ID card / tali lanyard terlihat; tidak wajib verifikasi sepatu.

---

### 4.2. Maintenance: Pos Parkir (`tpl_maint_pos`) — 9 Poin SOP
*Wajib 1 poin 1 foto per unit pos.*
1. **Pembersihan Total Printer Pos (`pos_01`)**: Head thermal, roller karet, dan ruang tempat kertas bersih dari serbuk potongan kertas.
2. **Kerapian Jalur Kabel & Stopkontak (`pos_02`)**: Kabel diikat rapi memakai spiral/kabel ties, tidak ada sambungan terkelupas, colokan adaptor kencang.
3. **Standarisasi Item dalam Pos (`pos_03`)**: Kelengkapan meja pos: Monitor, Keyboard, Mouse, Barcode Scanner, Printer Thermal, dan Kipas Angin.
4. **Fungsi Sistem Aplikasi Kasir (`pos_04`)**: Layar monitor menampilkan aplikasi kasir BSS dalam status ready online.
5. **Kunci Pintu Pos / Grendel Pintu (`pos_05`)**: Grendel pintu pos terpasang kuat dan bisa dikunci/dibuka normal.
6. **Stiker Logo BSS Parking — Sisi Depan (`pos_06`)**: Bodi depan menampilkan logo resmi BSS Parking menempel rapi.
7. **Stiker BSS Parking & Parkways — Sisi Kiri (`pos_07`)**: Bodi kiri memuat stiker BSS Parking & Parkways rapi.
8. **Stiker BSS Parking & Parkways — Sisi Kanan (`pos_08`)**: Bodi kanan memuat stiker BSS Parking & Parkways rapi.
9. **Kondisi Pulau Parkir (`pos_09`)**: Cat marka kuning-hitam jelas, beton utuh bebas retak parah, tanpa kabel terlihat di permukaan.

---

### 4.3. Maintenance: Barrier Gate (`tpl_maint_barrier`) — 9 Poin SOP
*Wajib 1 poin 1 foto per unit barrier gate.*
1. **Dudukan Mesin & Baut Dynabolt (`bar_01`)**: Baseplate mesin kokoh ke beton pulau dan baut dynabolt kencang.
2. **Fisik Palang Tertutup Lurus (`bar_02`)**: Palang menutup posisi 0° lurus horizontal sejajar jalan, baut pengikat kencang.
3. **Fisik Palang Terbuka (`bar_03`)**: Palang terbuka 90° tegak lurus, pergerakan lancar tanpa macet.
4. **Pelumas Spring / Bearing (`bar_04`)**: Per spring dan bearing as mesin terlumasi grease baru bebas karat.
5. **Sensor Loop Detector (`bar_05`)**: Modul loop detector aktif (indikator LED DETECT menyala saat ada kendaraan).
6. **Jalur Kabel Sensor (`bar_06`)**: Kabel tertanam rapi di bawah aspal/beton atau susunan paving block tanpa kabel mencuat ke permukaan.
7. **Stiker Receiver Barrier Gate (`bar_07`)**: Stiker receiver kuning peringatan palang utuh, jelas, dan tidak terkelupas.
8. **Tiang CCTV & Housing (`bar_08`)**: Tiang CCTV kokoh, bracket kencang, dan housing pelindung kamera bersih bening.
9. **Speedbump Gate (`bar_09`)**: Karet speed bump terpasang kuat di lajur gate dengan baut dynabolt lengkap.

---

### 4.4. Maintenance: Manless & Pulau Gate (`tpl_maint_manless`) — 8 Poin SOP
*Wajib 1 poin 1 foto per unit dispenser manless.*
1. **Pembersihan Total Printer Tiket (`man_01`)**: Head thermal, roller karet, dan ruang tempat kertas bebas debu/sobekan kertas.
2. **Kebersihan Dalam & Kerapihan Kabel (`man_02`)**: Ruang dalam manless bersih bebas sarang laba-laba/debu, kabel terikat rapi kabel ties.
3. **Fungsi Tombol & Struk Tiket Keluar (`man_03`)**: Tombol tiket responsif dan struk karcis tercetak jelas dengan tanggal/jam terkini.
4. **Sensor Loop Kendaraan (`man_04`)**: Layar display menampilkan panduan tiket atau indikator LED loop aktif.
5. **Kebersihan Luar & Stiker Panduan (`man_05`)**: Bodi luar manless bersih, stiker panduan ambil tiket / tap kartu utuh dan terbaca jelas.
6. **Dudukan Bawah Manless ke Pulau (`man_06`)**: Baut pengikat dudukan baseplate ke lantai beton pulau kencang dan kokoh.
7. **Kondisi Fisik Beton Pulau Gate (`man_07`)**: Permukaan beton pulau bersih dari ceceran oli/sampah, cat marka pembatas rapi.
8. **Kunci Manless & Gembok (`man_08`)**: Kunci pintu dan gembok berfungsi lancar, tidak macet, dan bebas karat.

---

### 4.5. Maintenance: Server & Kasir (`tpl_maint_server`) — 6 Poin SOP
*Wajib foto layar monitor atau perangkat sebagai bukti.*
1. **Pembersihan Storage & File Temp (`srv_01`)**: Sisa kapasitas Drive C: aman (>20 GB indikator biru) dan folder temp dikosongkan.
2. **Matikan Windows Update, Antivirus & Firewall (`srv_02`)**: Windows Update status Paused/Disabled, Windows Security Real-time Protection OFF, Firewall OFF.
3. **Fungsi Keyboard & Mouse (`srv_03`)**: Pengujian tuts via Notepad / keytest.com dan pergerakan kursor mouse normal.
4. **Pembersihan Debu CPU & Pasta Processor (`srv_04`)**: Motherboard, fan heatsink, dan power supply bersih debu; pasta pendingin baru.
5. **Port USB & Kerapian Kabel Belakang CPU (`srv_05`)**: Kabel power, LAN, monitor terikat rapi; kabel USB scanner/reader kencang.
6. **Koneksi Jaringan Bebas RTO (`srv_06`)**: Uji ping CMD ke Gateway/Server stabil (time < 5ms, packet loss 0% tanpa RTO).

---

## 🤖 5. Integrasi AI Vision (Google Gemini)

### 5.1. Konfigurasi Endpoint & Autentikasi
- **Endpoint**: `https://generativelanguage.googleapis.com/v1beta/openai/chat/completions`
- **Model Default**: `gemini-1.5-flash` / `gemini-2.0-flash`
- **Output Strict**: JSON biner (`sesuai`, `tidak_sesuai`, `perlu_cek_manual`).

### 5.2. Aturan Sanitasi Bahasa Natural Teknisi (`cleanTechnicianReason`)
- **Strict 1 Kalimat Fakta Lapangan**: Alasan AI dibatasi maksimal 1 kalimat tunggal (maksimal 95 karakter) langsung ke inti fisik.
- **Pembersihan Otomatis Basa-Basi & Salam**: Menghapus otomatis salam pembuka (*Halo*, *Selamat Pagi*, *Terima Kasih*, *Berdasarkan observasi*) dan penutup klise.
- **Normalisasi Istilah**:
  - *"degradasi fisik"* ➔ *"kerusakan fisik"*
  - *"mengalami deteriorasi"* ➔ *"mulai rusak"*
  - *"ditemukan adanya ketidaksesuaian"* ➔ *"terdapat temuan"*
  - *"tidak terorganisir dengan rapi"* ➔ *"tidak tertata rapi"*
  - *"memiliki integritas struktural"* ➔ *"terpasang dengan kokoh"*

---

## 📲 6. Modul Pelaporan & Share WhatsApp / Telegram

### 6.1. Format Pesan Otomatis (WhatsAppReportService)
- Salam dinamis berbasis jam operasional:
  - `03:00 - 10:59`: Selamat Pagi
  - `11:00 - 14:59`: Selamat Siang
  - `15:00 - 17:59`: Selamat Sore
  - `18:00 - 02:59`: Selamat Malam
- **Struktur Laporan Maintenance**:
  ```text
  [Salam Waktu]
  
  Izin melaporkan hasil [Jenis Maintenance]
  
  Lokasi : [Nama Lokasi & Kode]
  Gate / Pos : [Nomor Unit]
  Tanggal : [Tanggal Format Indonesia]
  IT Support : [Nama Teknisi]
  
  HASIL MAINTENANCE :
  ✅ Sesuai: X
  ⚠️ Tidak Sesuai: Y
  Total Point: Z
  
  Note :
  1. *[Nama Poin]* :
     ✅ / ⚠️ [Alasan 1 Kalimat Fakta]
  
  Terima kasih 🙏
  ```

### 6.2. Kompatibilitas Format Bold Telegram (`ShareHelper`)
- Pada saat share ke Telegram, tanda asteris (`*`) dikonversi secara otomatis menggunakan **Mathematical Bold Unicode Characters** (contoh: `𝗣𝗲𝗺𝗯𝗲𝗿𝘀𝗶𝗵𝗮𝗻 𝘁𝗼𝘁𝗮𝗹 𝗽𝗿𝗶𝗻𝘁𝗲𝗿`), sehingga judul tetap tebal tanpa merusak format rendering aplikasi Telegram.

---

## 🔄 7. Daily Task Service & Integrasi PocketBase
- **Realtime Listener**: Terhubung ke PocketBase SSE & periodic poller 25 detik ke `https://bssparking.trakingduit.my.id`.
- **Notifikasi**: Menampilkan badge hitungan tugas pending teknisi di sidebar drawer dan notifikasi bar Android saat SPV memberikan tugas baru.

---

*Dokumen ini merupakan referensi resmi codebase BssparkingTimeMark dan disinkronkan secara konsisten dengan knowledge graph proyek.*
