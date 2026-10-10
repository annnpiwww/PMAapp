# Panduan Checklist Maintenance Teknisi — PMAapp

Panduan operasional perawatan berkala perangkat parkir BSS Parking untuk Teknisi Lapangan.

---

## 1. Fungsi Fitur Maintenance

Fitur ini menyediakan checklist digital untuk merawat seluruh perangkat parkir BSS (Barrier Gate, Manless, Pos Kasir, dan Server).
- Menggantikan checklist kertas manual.
- Setiap titik pemeriksaan wajib dilampiri foto aktual dengan cap waktu dan lokasi.
- Laporan langsung dirangkum otomatis ke format WhatsApp ringkas saat checklist selesai.

---

## 2. Hak Akses & PIN Teknisi

Menu maintenance dapat dibuka oleh akun **Teknisi**. Jika muncul permintaan PIN, masukkan PIN default:

```text
123321
```

PIN dapat diubah melalui menu: `Menu Samping (☰) -> Profil -> Ubah PIN Teknisi`.

---

## 3. Empat Kategori Maintenance

### A. Barrier Gate (Palang Parkir) — 9 Poin per Unit
1. `Dudukan Mesin & Baut Dinabolt` — Kekencangan baut mesin ke pondasi beton.
2. `Fisik Palang Tertutup (0° Lurus)` — Posisi palang tertutup rata dan kondisi stiker.
3. `Fisik Palang Terbuka (90° Lancar)` — Kelancaran palang terbuka tegak lurus 90°.
4. `Pelumasan Mekanikal (Spring/Bearing)` — Kondisi pelumasan pegas dan bearing.
5. `Sensor Loop Detector (LED Detect Aktif)` — Respons sensor saat mendeteksi kendaraan.
6. `Jalur Coran Aspal Sensor Loop` — Kerapian permukaan coran kabel loop di aspal.
7. `Pengukuran Voltase Listrik (Avometer)` — Kestabilan tegangan listrik masuk (220V/24V).
8. `Casing Sensor Receiver Anti Air` — Kerapian kotak receiver dan proteksi air hujan.
9. `Tiang CCTV & Speed Bump Gate` — Kekokohan tiang CCTV, arah sorot, dan karet polisi tidur.

### B. Manless (Dispenser Tiket Mandiri) — 8 Poin per Unit
1. `Pembersihan Total Printer Tiket` — Kebersihan head dan roller thermal.
2. `Kebersihan Interior & Adaptor Manless` — Kerapian kabel dan adaptor di dalam bodi.
3. `Fungsi Tombol Struk & Tiket Keluar` — Tombol tiket responsif dan struk keluar lancar.
4. `Sensor Loop Kendaraan (Layar/LED Aktif)` — Sensor kendaraan aktif memicu layar.
5. `Eksterior Casing & Stiker Panduan` — Kebersihan bodi luar dan keutuhan stiker petunjuk.
6. `Dudukan Baseplate Manless Pulau` — Kekencangan baut dudukan ke beton pulau.
7. `Kondisi Fisik Beton Pulau Gate` — Kebersihan dan keutuhan beton pulau.
8. `Kunci Pintu Manless` — Kunci pintu bodi berfungsi normal dan tidak berkarat.

### C. Pos Kasir — 9 Poin per Pos
1. `Pembersihan Total Printer Pos` — Roller dan head printer kasir bebas debu kertas.
2. `Kerapian Jalur Kabel Stopkontak` — Jalur kabel terikat rapi dan stopkontak aman.
3. `Kelengkapan Standarisasi Meja Pos` — Kerapian meja kerja dan kelengkapan operasional kasir.
4. `Fungsi Sistem Kasir & Cashbox` — Aplikasi kasir online responsif dan laci uang normal.
5. `Fisik Kunci Pintu Pos` — Kunci pintu dan grendel berfungsi baik.
6. `Jarak Pos ke Ujung Pulau (10–15 cm)` — Posisi bodi pos sesuai batas aman.
7. `Kondisi Fisik Pulau Parkir` — Cat pulau bersih dan bebas retak.
8. `Kebersihan Kaca & Ventilasi Pos` — Kaca pos bersih dan sirkulasi udara baik.
9. `Penerangan & Kelistrikan Pos` — Lampu pos menyala terang dan sakelar berfungsi.

### D. Server & Komputer Kasir — 6 Poin per Unit
1. `Pembersihan Storage & File Temp` — Ruang disk cukup dan file temporary bersih.
2. `Nonaktifkan Update, Antivirus & Firewall` — Konfigurasi sistem stabil untuk aplikasi kasir.
3. `Fungsi Keyboard & Mouse` — Input perangkat keras merespons normal.
4. `Pembersihan Debu CPU & Pasta Processor` — Kipas pendingin bersih dan suhu prosesor normal.
5. `Port USB & Kerapian Kabel Belakang CPU` — Sambungan kabel perifer kokoh terpasang.
6. `Koneksi Jaringan Server Bebas RTO` — Ping server stabil tanpa packet loss.

---

## 4. Langkah Penggunaan di Lapangan

### Langkah 1: Buka Modul Maintenance
1. Buka aplikasi **PMAapp**.
2. Ketuk menu **Maintenance** dari menu samping atau pintasan di layar kamera.
3. Pilih jenis modul yang akan diperiksa (contoh: `Barrier Gate`).

### Langkah 2: Atur Unit & Pos Pemeriksaan
Pada dialog setup:
- **Jumlah Unit:** Ketuk `+` atau `-` untuk menentukan rentang unit yang diperiksa (contoh: 1 s/d 10). Jumlah total foto wajib otomatis dihitung.
- **Lokasi Pos:** Pilih pos aktif (contoh: `PBM`, `NBM`, `TBM`).
- **Nama Teknisi:** Pastikan nama teknisi sesuai penanggung jawab.
- Ketuk **"Mulai Checklist"**.

### Langkah 3: Ambil Foto Tiap Titik Pemeriksaan
1. Ketuk kartu poin pemeriksaan yang masih berstatus belum selesai.
2. Periksa instruksi dan sudut foto yang diwajibkan.
3. Ketuk tombol **"Buka Kamera"** dan ambil foto objek nyata alat.
4. Pastikan objek terlihat jelas di bawah pencahayaan yang cukup.

### Langkah 4: Tambahkan Catatan Temuan Rusak
Jika menemukan kerusakan fisik atau alat butuh perbaikan:
1. Ketuk kembali kartu poin yang bersangkutan.
2. Ketuk tombol **"Tambah Catatan Temuan"**.
3. Tulis detail kendala secara konkret (contoh: `stiker palang robek di Gate 2`, `baut dudukan kendor`).
4. Ketuk **"Simpan Catatan"**. Catatan otomatis muncul pada laporan rekap WhatsApp.

### Langkah 5: Kirim Laporan ke WhatsApp
Setelah seluruh target foto terpenuhi (100%):
1. Gulir ke bagian bawah layar checklist.
2. Ketuk tombol **"Bagikan Laporan ke WhatsApp"**.
3. Aplikasi otomatis menyusun ringkasan laporan 8 baris terstandarisasi beserta seluruh lampiran foto.
4. Kirim laporan ke grup koordinasi cabang.

---

## 5. Tips & Penanganan Kendala

- **Sinyal Lemah di Pos:** Nyalakan mode simpan cepat jika sinyal internet tidak stabil. Data foto tetap tersimpan aman di penyimpanan ponsel.
- **Filter per Unit:** Gunakan tombol filter unit di bagian atas layar untuk memfokuskan daftar pada gate tertentu.
- **Pembersihan Otomatis:** Foto yang tersimpan lebih dari 7 hari otomatis dibersihkan dari memori ponsel untuk menjaga ruang penyimpanan tetap lega.
- **Foto Ulang:** Jika hasil foto kurang jelas, buka kembali kartu poin tersebut lalu pilih **"Foto Ulang"**.
