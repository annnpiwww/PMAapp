# Panduan Manja Fitur Maintenance Teknisi - BSS Parking TimeMark

> Halo kakak teknisi yang paling hebat dan paling imut! Buku ini khusus untuk kakak yang tugasnya cek-cek barang di lapangan ya. Bahasanya bayi, sopan, tidak kaku, tapi isinya detail banget biar kakak gak bingung lagi. Yuk dibaca pelan-pelan sambil ngemil!

---

## 1. Apa Itu Fitur Maintenance Teknisi Kak?

Fitur ini adalah buku checklist ajaib kakak untuk merawat semua alat parkir BSS. Jadi kakak gak perlu lagi bawa kertas yang gampang hilang atau ngetik laporan panjang di WhatsApp.

Tugas kakak di fitur ini simpel:
1. Pilih mau cek apa hari ini (Barrier, Manless, Pos, atau Server)
2. Fotoin satu per satu poinnya (1 poin = 1 foto + 1 stempel watermark)
3. Kalau ada yang rusak, tulis catatan manjanya
4. Pencet satu tombol, laporan cantik 8 baris + 90 foto langsung jadi dan siap kirim ke bos!

Semua data kakak disimpan aman di HP, ada stempel jam, tanggal, dan GPS biar gak bisa dibohongin.

---

## 2. Siapa Yang Boleh Pakai Kak?

Fitur ini khusus untuk akun **Teknisi** ya kak.

Kalau kakak mau buka menu maintenance, kadang bakal muncul jendela **PIN Teknisi** yang lucu. PIN bawaannya adalah:

```
123321
```

Jangan kasih tau orang lain ya kak! Kalau kakak mau ganti PIN biar lebih rahasia, bisa ke:

`Menu Samping (garis tiga) -> Profil -> Ubah PIN Teknisi`

Di sana kakak juga bisa ganti **Nama IT Support** yang nanti muncul di laporan WhatsApp (contoh: Raldy sangkop).

---

## 3. Kenalan Sama 4 Jenis Maintenance Ya Kak

### A. Barrier Gate (Palang Parkir) - 9 Poin Per Gate
Ini untuk cek palang yang naik turun itu lho kak. Satu gate ada 9 foto wajib:

1.  `Dudukan Mesin & Baut Dinabolt` - cek bautnya kencang gak ke beton
2.  `Fisik Palang Tertutup (0° Lurus)` - palang pas nutup harus lurus, stikernya masih bagus gak
3.  `Fisik Palang Terbuka (90° Lancar)` - pas buka harus tegak 90 derajat, gak nyangkut
4.  `Pelumasan Mekanikal (Spring/Bearing)` - per dan bearingnya sudah dikasih grease belum
5.  `Sensor Loop Detector (LED Detect Aktif)` - lampu LED sensornya nyala gak pas ada mobil
6.  `Jalur Coran Aspal Sensor Loop` - garis coran di aspalnya rapi gak, ada kabel nongol gak
7.  `Pengukuran Voltase Listrik (Avometer)` - voltasenya normal gak 220V/24V
8.  `Casing Sensor Receiver Anti Air` - kotaknya rapat gak, nanti kalau hujan bocor gak (poin ini juga yang dipakai untuk laporan `kunci BG` ya kak)
9.  `Tiang CCTV & Speed Bump Gate` - tiang CCTV kokoh gak, arah sorotnya pas gak, polisi tidurnya kepasang kuat gak

> Catatan bayi: Poin kunci eksplisit belum ada untuk Barrier ya kak. Jadi kalau ada kunci berkarat atau hilang, kakak tulis aja catatannya di poin nomor 8 ya!

### B. Manless (Mesin Tiket Otomatis) - 7 Poin Per Unit
Ini untuk mesin yang keluarin karcis otomatis itu lho kak:

1.  `Pembersihan Total Printer Tiket`
2.  `Kebersihan Interior & Adaptor Manless`
3.  `Fungsi Tombol Struk & Tiket Keluar`
4.  `Sensor Loop Kendaraan (Layar/LED Aktif)`
5.  `Eksterior Casing & Stiker Panduan`
6.  `Dudukan Baseplate Manless Pulau`
7.  `Kondisi Fisik Beton Pulau Gate`

> Sama kayak Barrier, untuk Manless juga belum ada poin kunci terpisah ya kak. Kalau ada kunci manless yang hilang, tulis di catatan poin `Dudukan Baseplate` atau `Eksterior Casing` ya!

### C. Pos Kasir - 7 Poin Per Pos
Ini untuk rumah kecil tempat kakak kasir duduk:

1.  `Pembersihan Total Printer Pos`
2.  `Kerapian Jalur Kabel Stopkontak`
3.  `Kelengkapan Standarisasi Meja Pos`
4.  `Fungsi Sistem (Layar Kasir Ready & Cashbox)`
5.  `Fisik Kunci Pintu Pos (Bebas Bocor)` - **Nah ini baru ada poin kunci beneran ya kak!**
6.  `Jarak Pos Ujung Pulau (10-15 cm)`
7.  `Kondisi Fisik Pulau Parkir`

### D. Server & Komputer Kasir - 6 Poin Per Unit
Ini untuk cek komputer di belakang layar:

1.  `Pembersihan Storage & File Temp`
2.  `Nonaktifkan Update, Antivirus & Firewall`
3.  `Fungsi Keyboard & Mouse (Notepad Test)`
4.  `Pembersihan Debu CPU & Pasta Processor`
5.  `Port USB & Kerapian Kabel Belakang CPU`
6.  `Koneksi Jaringan Server Bebas RTO`

---

## 4. Cara Pakai Langkah Bayi (Step by Step)

### Langkah 1: Buka Pintu Maintenance
1.  Buka aplikasi **BSS Parking TimeMark**
2.  Di halaman utama, cari dan pencet menu **Maintenance** atau **Checklist Teknisi**
3.  Pilih deh kak mau cek apa hari ini, misal `Maintenance: Barrier Gate`

### Langkah 2: Atur Dulu di Jendela Setup (Penting Banget!)
Nanti muncul jendela imut `Maintenance Setup Dialog`:

*   **Jumlah Unit:** Pencet tombol `+` dan `-` ya kak. Misal kakak mau cek 10 gate, pilih `10`. Nanti checklistnya langsung jadi `10 x 9 = 90` poin otomatis. Keren kan?
    *   Di bawahnya ada tulisan kecil `9 foto poin / unit` biar kakak gak lupa
*   **Lokasi Pos:** Pilih lokasinya kak, misal `PBM`, `NBM`, `Mega Mall`
*   **Nama IT Support:** Tulis nama kakak ya, misal `Raldy sangkop`. Nama ini yang nanti muncul di laporan WA sebagai `IT Support : Raldy sangkop`
*   Kalau sudah semua, pencet tombol biru **"Mulai Checklist"**

### Langkah 3: Fotoin Satu Per Satu Ya Kak (1 Poin 1 Foto)

Sekarang kakak lihat daftar panjang, misal `Barrier Gate 1 - Dudukan Mesin...`. Warnanya masih abu-abu artinya belum difoto.

1.  **Pencet kartunya**, nanti muncul jendela detail dari bawah (bottom sheet)
2.  Di dalam jendela itu ada:
    *   **Judul poin** dan deskripsi manja
    *   **CHECKPOINT WAJIB DIPERIKSA:** daftar centang apa aja yang harus kakak lihat
    *   **Panduan Foto:** kasih tau kakak harus foto dari sudut mana (kotak biru)
    *   **Status:** masih `Belum Foto`
3.  Pencet tombol biru besar **"Buka Kamera & Verifikasi AI"**

#### Di Dalam Kamera:
*   **Tombol Flash:** di atas, bisa diganti `Off -> Auto -> On -> Torch`. Torch itu senter terang benderang untuk tempat gelap ya kak!
*   **Tombol Awan (Offline Mode):** di pojok kanan atas. Kalau kakak di basement gak ada sinyal, pencet awannya sampai jadi `cloud_off` (ada garis miring). Nanti fotonya kesimpan super cepat `0,1 detik` tanpa nunggu AI. Kalau sinyal bagus, biarin `cloud_done` aja.
*   **Tombol Jepret:** tombol bulat besar di tengah bawah. Pasin dulu objeknya, terus pencet!
*   Tunggu tulisan **"Tunggu sebentar"** (tanpa titik-titik ya kak) sampai selesai.

Habis foto, kakak akan balik ke daftar. Kartunya sekarang jadi agak redup dan ada icon `check` hijau plus tulisan `Terverifikasi AI`. Artinya sudah selesai!

### Langkah 4: Kalau Ada Temuan Rusak, Wajib Tulis Catatan Ya Kak!

Ini bagian paling penting biar laporan WA kakak jadi pintar!

Misal kakak lihat `Stiker palang hilang di Gate Ojek` atau `Kunci berkarat di Gate 4`:

1.  Pencet lagi kartu poin yang tadi sudah difoto
2.  Di jendela detail, sekarang ada tombol putih **"Tambah Catatan Temuan"** atau **"Edit Catatan Temuan"**
3.  Pencet tombol itu, nanti muncul kotak tulis
4.  Tulis dengan bahasa manusia yang jujur ya kak, contoh yang bagus:
    *   `belum ada stiker`
    *   `bracket sedikit berkarat`
    *   `tidak ada kunci, berkarat`
    *   `palang sedikit miring 5 derajat`
5.  Pencet **"Simpan Catatan"**

> Tips bayi: Jangan tulis `mode offline` atau `foto tersimpan` ya kak, itu nanti dianggap bukan temuan dan gak akan muncul di laporan WA.

### Langkah 5: Kirim Laporan Ajaib ke WhatsApp (Cuma 1 Klik!)

Kalau semua sudah difoto (misal `90/90 foto selesai (100%)`):

1.  Lihat bagian paling bawah layar, ada tombol hijau besar:
    **"Bagikan Laporan ke WhatsApp (90 Foto)"**
2.  Pencet tombol itu ya kak!
3.  Aplikasi langsung bikinin teks laporan yang super rapi. Ajaibnya, walau kakak foto 90 kali, teksnya **cuma jadi 8 baris** aja lho! Gak jadi spam 90 baris yang bikin bos pusing.

#### Rahasia 8 Baris Ajaib untuk Barrier Gate:

Aplikasi akan mengelompokkan 90 poin kakak jadi 8 tema besar sesuai format lapangan asli:

1.  `item barrier gate in dan out berfungsi normal`
2.  `dynabolt semua gate kuat`
3.  `cat body BG bagus`
4.  `stiker palang bagus`
5.  `IPCAM berfungsi normal dan sesuai arah sorot`
6.  `bracket IPCAM tidak berkarat`
7.  `kunci BG tidak berkarat dan lengkap`
8.  `Sensor semua normal`

*   Kalau semua normal, semua dapat `✅`
*   Kalau ada yang rusak di gate tertentu, baris itu otomatis jadi `⚠️` plus nama gate-nya!

**Contoh kalau ada temuan (persis kayak laporan asli kakak):**
```text
Selamat Siang
Izin melaporkan hasil Maintenance Barrier Gate in, out, palang, arah sorot cctv dan sensor

Lokasi : PBM
Tanggal : 19 Agustus 2026
IT Support : Raldy sangkop

Note :
1. ✅ item barrier gate in dan out berfungsi normal
2. ✅ dynabolt semua gate kuat
3. ✅ cat body BG bagus
4. ⚠️ stiker palang bagus dan ada beberapa yang belum ada stiker Gate Ojek, Gate Out 4
5. ✅ IPCAM berfungsi normal dan sesuai arah sorot
6. ⚠️ bracket IPCAM sedikit berkarat (Barrier Gate 5)
7. ⚠️ kunci BG berkarat dan yang tidak ada kunci Barrier Gate 4, Gate Ojek
8. ✅ Sensor semua normal

Terima kasih 🙏
```

Plus **semua 90 foto** ikut kelampir otomatis! Kakak tinggal pilih WhatsApp dan kirim ke grup bos. Beres!

### Langkah 6: Intip Riwayat Kalau Kangen

1.  Pencet garis tiga di pojok kiri atas (Drawer / Sidebar)
2.  Pilih **"Riwayat Foto Timemark"**
3.  Di sini kakak bisa lihat semua laporan yang pernah dibikin
4.  Pencet icon kaca pembesar `🔍` untuk **Zoom Foto** (bisa cubit layar untuk perbesar/perkecil)
5.  Bisa pencet tombol **"Bagikan ke WhatsApp"** lagi kalau bos minta dikirim ulang

> Catatan: Menu `Pengaturan Vision AI` dan `Keluar Akun Petugas` sudah dihilangkan dari sidebar biar kakak gak kepencet salah ya! Koneksi AI tetap jalan normal di belakang layar kok.

---

## 5. Fitur Manja Lainnya Yang Kakak Harus Tau

*   **Filter Per Unit:** Kalau kakak cek 10 gate, di atas daftar ada chip `Semua Unit`, `Unit 1`, `Unit 2` ... Pencet itu buat lihat cuma gate tertentu aja biar gak pusing.
*   **Progress Bar:** Di atas ada garis biru yang jalan. Kalau sudah `100%`, baru tombol `Simpan & Selesaikan Laporan` bisa dipencet.
*   **Auto-Clean Foto:** Foto yang sudah lebih dari 7 hari akan dibersihin otomatis pas buka aplikasi biar HP kakak gak penuh. Tenang, laporannya tetap aman!
*   **Watermark Cantik Anti Gepeng:** Logo BSS di foto sekarang sudah proporsional, gak gepeng lagi, pakai `BoxFit.contain` yang pintar.
*   **Akurasi AI:** Di detail poin, cuma muncul `Akurasi: 95%` aja ya kak, tulisan `Evaluator: ...` sudah dihilangkan biar gak bingung.

---

## 6. FAQ Bayi (Pertanyaan yang Sering Ditanyak Kakak)

**Q: Kak, kenapa teks Evaluator hilang?**
A: Biar kakak gak pusing lihat nama robot yang panjang itu kak! Sekarang cuma ada `Akurasi: 95%` aja yang penting. Robotnya tetap kerja di belakang kok.

**Q: Kak, kalau 10 gate x 9 poin = 90 foto, HP ku kentang kuat gak?**
A: Kuat kok kak! Teks laporannya sudah diringkas jadi 8 baris, jadi WhatsApp gak akan ngelag. Fotonya 90 memang banyak, tapi dikirim sekaligus via `share_plus`. Kalau sinyalnya jelek, pakai Mode Offline dulu ya kak!

**Q: Kak, gimana kalau mau foto ulang?**
A: Pencet lagi kartunya yang sudah selesai, terus pencet **"Foto Ulang & Verifikasi AI"** ya kak. Foto lama akan keganti yang baru.

---

Semangat terus ya kakak teknisi imut! Terima kasih sudah merawat parkiran BSS dengan cinta! Kalau masih bingung, tanya aja lagi ya kak, jangan dipendam sendiri! 🙏✨

*Dokumen ini dibuat dengan bahasa bayi yang sopan untuk kakak teknisi lapangan - BSS Parking TimeMark v1.2.0 - 31 Agustus 2026*
