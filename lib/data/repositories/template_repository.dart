import 'package:flutter/foundation.dart';
import '../models/template_model.dart';
import '../services/storage_service.dart';

class TemplateRepository extends ChangeNotifier {
  static final TemplateRepository instance = TemplateRepository._internal();
  TemplateRepository._internal();

  List<TemplateModel> _templates = [];
  List<TemplateModel> get templates => List.unmodifiable(_templates);

  static final List<TemplateModel> defaultTemplates = [
    // 1. ABSENSI — kriteria ringkas, klasifikasi seragam di AI Vision
    TemplateModel(
      id: 'tpl_absensi_01',
      nama: 'Absensi',
      deskripsi: 'Dokumentasi absensi masuk & pulang shift — verifikasi seragam resmi BSS Parking.',
      jenis: TemplateCategory.absensi,
      wajibLokasi: true,
      sopCriteria: [
        'Seragam resmi BSS Parking bersih, rapi, terkancing & dimasukkan dalam celana',
        'ID Card / Name Tag terpasang jelas di saku kiri (tali lanyard / yoyo lanyard sah)',
        'Rambut rapi / jilbab rapi sesuai standar grooming BSS',
        'Sepatu Hitam bersih',
        'Wajah terlihat jelas tanpa masker / kacamata',
        'Peluit & Topi untuk petugas SPL laki-laki',
        'Pin smile terpasang di dada sebelah kanan',
      ],
      aiMode: AiMode.singleFoto,
      requiredRole: TemplateRole.all,
      contohFotoDescriptions: [
        'Foto full body tegap menghadap kamera',
        'Seragam resmi BSS Parking rapi',
      ],
      createdBy: 'HO BSS Parking Pusat',
      updatedAt: DateTime.now(),
    ),
    // 2. MAINTENANCE POS PARKIR (7 Poin Representatif)
    TemplateModel(
      id: 'tpl_maint_pos',
      nama: 'Maintenance: Pos Parkir',
      deskripsi: 'Pembersihan & perapihan pos parkir. Wajib 1 point 1 foto per pos.',
      jenis: TemplateCategory.maintPos,
      wajibLokasi: true,
      requiredRole: TemplateRole.teknisi,
      aiMode: AiMode.perPoint,
      sopCriteria: [
        'Pembersihan total printer pos (head printer, roller karet, dan tempat kertas bersih)',
        'Kerapian jalur kabel terikat Spiral Flexibel/kabel ties dan colokan stopkontak kencang',
        'Standarisasi item dalam pos (monitor, keyboard, mouse, scanner, kipas angin) tanpa barang pribadi',
        'Fungsi sistem aplikasi kasir ready online',
        'Kunci pintu pos (grendel pintu terpasang baik dan berfungsi normal)',
        'Stiker logo BSS Parking di depan (hanya 1 stiker) & stiker Parkways di sisi kiri/kanan body pos rapih tidak robek/pudar',
        'Kondisi pulau parkir (warna cat kuning-hitam rapi, tidak retak, dan tidak ada kabel yang terlihat)',
      ],
      sopPoints: [
        SopPoint(
          id: 'pos_01',
          label: 'Pembersihan Total Printer Pos',
          deskripsi: 'Head printer bersih, roller karet bersih, dan serbuk robekan kertas dibersihkan',
          checkpoints: [
            'Buka penutup printer thermal kasir',
            'Head printer bersih dari kotoran atau sisa kerak',
            'Roller karet penarik kertas bersih dan bebas debu',
            'Ruang tempat kertas bersih, bebas dari serbuk robekan kertas',
            'Kabel power dan kabel data terpasang kencang',
          ],
          panduanFoto: 'Buka penutup printer, ambil foto dari atas agar head printer, roller karet, dan tempat kertas terlihat jelas.',
        ),
        SopPoint(
          id: 'pos_02',
          label: 'Kerapian Jalur Kabel & Stopkontak',
          deskripsi: 'Kabel terikat rapi menggunakan Spiral Flexibel/kabel ties, colokan adaptor kencang',
          checkpoints: [
            'Kabel terikat rapi menggunakan kabel ties atau Spiral Flexibel',
            'Tidak ada kabel terkelupas atau sambungan terbuka',
            'Colokan adaptor terpasang kencang dan tidak longgar atau goyang',
          ],
          panduanFoto: 'Foto area stopkontak dan jalur kabel bawah meja, pastikan ikatan kabel rapi dan colokan terpasang kencang.',
        ),
        SopPoint(
          id: 'pos_03',
          label: 'Standarisasi Item dalam Pos',
          deskripsi: 'Monitor, Keyboard, Mouse, Scanner, Kipas Angin tertata rapi tanpa barang pribadi',
          checkpoints: [
            'Perangkat tertata rapi: Monitor, Keyboard, Mouse, Scanner, Kipas Angin meja, dan Tap Reader',
            'Kipas angin meja tersedia dan berfungsi dengan baik',
            'Tidak ada barang pribadi (makanan, minuman, pakaian) berserakan di atas meja pos',
          ],
          panduanFoto: 'Foto seluruh area meja kasir memperlihatkan monitor, keyboard, scanner, dan kipas angin tertata rapi.',
        ),
        SopPoint(
          id: 'pos_04',
          label: 'Fungsi Sistem Aplikasi Kasir',
          deskripsi: 'Foto layar aplikasi kasir status ready online, tanpa cashbox',
          checkpoints: [
            'Aplikasi kasir BSS dalam status Ready / Online / Siap Transaksi terlihat jelas di layar monitor',
            'Jika layar menampilkan di luar aplikasi kasir (desktop, browser lain) → beri warning merah, jika di dalam aplikasi kasir ready → hijau',
          ],
          panduanFoto: 'Foto layar monitor menampilkan aplikasi kasir BSS dalam status Ready/Online.',
        ),
        SopPoint(
          id: 'pos_05',
          label: 'Kunci Pintu Pos (Grendel Pintu)',
          deskripsi: 'Grendel pintu pos terpasang dengan baik dan berfungsi normal',
          checkpoints: [
            'Kunci grendel pintu pos terpasang kuat pada daun pintu',
            'Grendel pintu berfungsi normal (dapat dikunci dan dibuka dengan lancar)',
          ],
          panduanFoto: 'Foto kunci grendel pintu pos memperlihatkan posisi terpasang kuat dan berfungsi normal.',
        ),
        SopPoint(
          id: 'pos_06',
          label: 'Stiker Logo BSS Parking — Sisi Depan',
          deskripsi: 'Stiker body depan hanya tampil logo BSS Parking (hanya 1 stiker, bukan stiker kuning Parkways)',
          checkpoints: [
            'Stiker body depan hanya menampilkan 1 stiker yaitu logo BSS Parking (tulisan/logo putih resmi)',
            'Bukan stiker kuning Parkways (stiker Parkways P kuning hanya ada di sisi kiri dan kanan)',
            'Stiker logo BSS Parking di body depan menempel rapih tidak terkelupas/robek/pudar',
          ],
          panduanFoto: 'Foto close-up stiker logo BSS Parking di sisi depan body pos (pastikan hanya ada 1 stiker logo BSS Parking, bukan stiker kuning).',
        ),
        SopPoint(
          id: 'pos_07',
          label: 'Stiker BSS Parking & Parkways — Sisi Kiri',
          deskripsi: 'Stiker body kiri (BSS Parking putih & Parkways P kuning) rapih',
          checkpoints: [
            'Stiker BSS Parking di body kiri menempel rapih tidak terkelupas/robek/pudar',
            'Stiker Parkways di body kiri menempel rapih tidak terkelupas/robek/pudar',
          ],
          panduanFoto: 'Foto close-up stiker BSS Parking & Parkways di sisi kiri body pos.',
        ),
        SopPoint(
          id: 'pos_08',
          label: 'Stiker BSS Parking & Parkways — Sisi Kanan',
          deskripsi: 'Stiker body kanan (BSS Parking putih & Parkways P kuning) rapih',
          checkpoints: [
            'Stiker BSS Parking di body kanan menempel rapih tidak terkelupas/robek/pudar',
            'Stiker Parkways di body kanan menempel rapih tidak terkelupas/robek/pudar',
          ],
          panduanFoto: 'Foto close-up stiker BSS Parking & Parkways di sisi kanan body pos.',
        ),
        SopPoint(
          id: 'pos_09',
          label: 'Kondisi Pulau Parkir',
          deskripsi: 'Warna cat kuning-hitam rapi, tidak retak, dan tidak ada kabel yang terlihat',
          checkpoints: [
            'Warna cat marka kuning-hitam pada pulau parkir terlihat jelas dan rapi',
            'Kondisi fisik beton pulau utuh, tidak ada bagian yang retak atau pecah',
            'Tidak ada kabel yang terlihat di atas permukaan pulau parkir',
          ],
          panduanFoto: 'Foto permukaan pulau parkir memperlihatkan warna cat kuning-hitam, beton bebas retak, dan tidak ada kabel terlihat.',
        ),
      ],
      contohFotoDescriptions: ['Foto per-point sesuai checklist'],
      createdBy: 'Teknisi BSS',
      updatedAt: DateTime.now(),
    ),
    // 4. MAINTENANCE BARRIER GATE (9 Poin Representatif)
    TemplateModel(
      id: 'tpl_maint_barrier',
      nama: 'Maintenance: Barrier Gate',
      deskripsi: 'Pengecekan mesin barrier, palang, sensor loop, CCTV. Wajib 1 point 1 foto per gate.',
      jenis: TemplateCategory.maintBarrier,
      wajibLokasi: true,
      requiredRole: TemplateRole.teknisi,
      aiMode: AiMode.perPoint,
      sopCriteria: [
        'Dudukan mesin barrier kokoh & baut dynabolt kencang',
        'Fisik palang posisi tertutup 0° lurus horizontal & baut kencang',
        'Fisik palang posisi terbuka 90° tegak lurus lancar tanpa macet',
        'Pelumasan per spring penyeimbang & bearing grease baru',
        'Sensor loop detector berfungsi aktif mendeteksi kendaraan (LED Detect aktif)',
        'Jalur coran aspal kabel sensor loop tertutup rata rapi',
        'Stiker receiver barrier gate (kuning gambar orang hampir terkena palang) utuh dan jelas',
        'Tiang CCTV kokoh tegak lurus & housing kamera bersih bening',
        'Karet speed bump terpasang kuat di lajur gate lengkap dengan dynabolt',
      ],
      sopPoints: [
        SopPoint(
          id: 'bar_01',
          label: 'Dudukan Mesin & Baut Dynabolt',
          deskripsi: 'Cek kekencangan baut baseplate ke beton pulau, pastikan tidak goyang',
          checkpoints: [
            'Baut dynabolt baseplate terpasang lengkap dan kencang ke beton pulau',
            'Dudukan mesin kokoh, tidak goyang atau bergetar abnormal saat beroperasi',
          ],
          panduanFoto: 'Foto jarak dekat kaki baseplate mesin barrier gate memperlihatkan baut dynabolt yang tertanam kuat.',
        ),
        SopPoint(
          id: 'bar_02',
          label: 'Fisik Palang Tertutup Lurus',
          deskripsi: 'Palang saat posisi tertutup 0° lurus horizontal, baut pengikat kencang',
          checkpoints: [
            'Palang saat menutup lurus horizontal 180° / 0° sejajar jalan',
            'Baut pengikat pangkal palang kencang dan kokoh',
          ],
          panduanFoto: 'Foto palang dalam posisi tertutup penuh dari arah samping lajur.',
        ),
        SopPoint(
          id: 'bar_03',
          label: 'Fisik Palang Terbuka',
          deskripsi: 'Palang terbuka tegak lurus 90° sempurna dan pergerakan lancar tanpa macet',
          checkpoints: [
            'Palang terbuka tegak lurus sempurna 90°',
            'Limit switch atas aktif normal, palang tidak menggantung di tengah lajur',
          ],
          panduanFoto: 'Foto palang saat posisi terbuka penuh 90° tegak lurus.',
        ),
        SopPoint(
          id: 'bar_04',
          label: 'Pelumas (Spring/Bearing)',
          deskripsi: 'Per penyeimbang (spring) dan bearing mekanikal internal terlumasi grease baru',
          checkpoints: [
            'Buka pintu casing mesin barrier gate',
            'Per spring penyeimbang dan bearing as terlumasi grease/gemuk baru bebas karat',
          ],
          panduanFoto: 'Buka pintu mesin barrier gate, foto bagian per spring penyeimbang dan bearing yang diberi grease.',
        ),
        SopPoint(
          id: 'bar_05',
          label: 'Sensor Loop Detector',
          deskripsi: 'Modul sensor loop detector aktif mendeteksi logam kendaraan (LED Detect aktif)',
          checkpoints: [
            'Lampu indikator LED DETECT/SENSE pada modul loop menyala aktif saat kendaraan melintas',
            'Relay loop merespon keberadaan kendaraan di atas loop',
          ],
          panduanFoto: 'Foto modul kotak Loop Detector di dalam mesin saat lampu LED DETECT menyala (merah/hijau).',
        ),
        SopPoint(
          id: 'bar_06',
          label: 'Jalur Kabel Sensor',
          deskripsi: 'Garis coran aspal jalur kabel sensor loop tertutup rata dan tidak ada kabel yang terlihat',
          checkpoints: [
            'Garis potongan coran aspal kabel sensor loop tertutup semen/sealant rata rapi',
            'Tidak ada kabel sensor yang mengelupas keluar ke atas permukaan aspal',
          ],
          panduanFoto: 'Foto permukaan garis coran kabel sensor loop di aspal depan/belakang gate.',
        ),
        SopPoint(
          id: 'bar_07',
          label: 'Stiker Receiver Barrier Gate',
          deskripsi: 'Stiker receiver kuning gambar orang hampir terkena palang',
          checkpoints: [
            'Stiker receiver kuning gambar orang hampir terkena palang terlihat jelas',
            'Kondisi stiker utuh, tidak retak, tidak buram, dan tidak terkelupas',
          ],
          panduanFoto: 'Foto close-up stiker receiver warna kuning bergambar orang hampir terkena palang.',
        ),
        SopPoint(
          id: 'bar_08',
          label: 'Tiang CCTV & Housing',
          deskripsi: 'Tiang CCTV kokoh tegak lurus, housing kamera bersih dan kaca depan bening',
          checkpoints: [
            'Tiang CCTV kokoh tegak lurus, bracket kencang dan tidak berkarat',
            'Housing pelindung CCTV bersih dari kotoran/sarang laba-laba dan kaca kamera bening',
          ],
          panduanFoto: 'Foto tiang CCTV dan housing kamera di area barrier gate.',
        ),
        SopPoint(
          id: 'bar_09',
          label: 'Speedbump Gate',
          deskripsi: 'Karet speed bump terpasang kuat di lajur gate dengan baut dynabolt lengkap',
          checkpoints: [
            'Karet speed bump terpasang kuat, rata, dan utuh di permukaan lajur barrier gate',
            'Baut dynabolt pengikat speed bump lengkap dan kencang ke jalan',
          ],
          panduanFoto: 'Foto karet speed bump di area lajur barrier gate.',
        ),
      ],
      contohFotoDescriptions: ['Foto per-point barrier gate'],
      createdBy: 'Teknisi BSS',
      updatedAt: DateTime.now(),
    ),
    // 5. MAINTENANCE MANLESS & PULAU GATE (8 Poin Representatif)
    TemplateModel(
      id: 'tpl_maint_manless',
      nama: 'Maintenance: Manless & Pulau Gate',
      deskripsi: 'Pengecekan dispenser manless & pulau gate in/out. Wajib 1 point 1 foto per dispenser.',
      jenis: TemplateCategory.maintManless,
      wajibLokasi: true,
      requiredRole: TemplateRole.teknisi,
      aiMode: AiMode.perPoint,
      sopCriteria: [
        'Pembersihan total printer tiket (head, roller, ruang kertas, LAN)',
        'Kebersihan dalam manless & kerapihan kabel dalam manless',
        'Fungsi tombol & pengeluaran struk karcis tiket normal',
        'Sensor loop kendaraan manless aktif (layar LCD / LED)',
        'Kebersihan luar manless & stiker panduan terbaca jelas',
        'Dudukan bawah manless kokoh ke pulau beton',
        'Kondisi fisik lantai beton pulau gate bersih rapi',
        'Kunci manless & gembok berfungsi normal, tidak berkarat atau rusak',
      ],
      sopPoints: [
        SopPoint(
          id: 'man_01',
          label: 'Pembersihan Total Printer Tiket',
          deskripsi: 'Head thermal bersih, roller karet bersih, ruang tempat kertas bersih',
          checkpoints: [
            'Buka pintu/modul printer dispenser tiket manless',
            'Head thermal printer bersih dari residu',
            'Karet roller bersih dan tidak licin/kotor',
            'Ruang tempat kertas bersih dari serbuk potongan kertas',
            'Kabel LAN & daya terpasang kencang',
          ],
          panduanFoto: 'Foto dari atas modul printer tiket manless yang terbuka memperlihatkan head dan ruang kertas.',
        ),
        SopPoint(
          id: 'man_02',
          label: 'Kebersihan Dalam Manless & Kerapihan Kabel Dalam Manless',
          deskripsi: 'Ruang dalam bersih, kabel rapi, adaptor terpasang kencang',
          checkpoints: [
            'Ruang dalam manless bersih dari debu/sarang serangga',
            'Kabel dalam tertata rapi, tidak semrawut, adaptor terpasang kencang',
          ],
          panduanFoto: 'Buka pintu belakang manless, foto ruang dalam yang bersih dan kabel yang rapi.',
        ),
        SopPoint(
          id: 'man_03',
          label: 'Fungsi Tombol & Struk Tiket Keluar',
          deskripsi: 'Fungsi tombol tiket normal dan struk karcis tercetak keluar dengan baik',
          checkpoints: [
            'Tombol tiket merespon normal saat ditekan',
            'Struk karcis tiket parkir berhasil dicetak keluar dengan tanggal/jam hari ini',
          ],
          panduanFoto: 'Foto struk karcis yang baru keluar dari mulut dispenser tiket.',
        ),
        SopPoint(
          id: 'man_04',
          label: 'Sensor Loop Kendaraan (Layar/LED Aktif)',
          deskripsi: 'Layar LCD menampilkan instruksi ambil tiket atau LED loop aktif',
          checkpoints: [
            'Layar LCD/LED manless merespon saat ada mobil (muncul "Silakan Tekan Tombol")',
            'Lampu indikator loop detector di dalam dispenser menyala',
          ],
          panduanFoto: 'Foto layar display LCD dispenser manless atau LED modul loop yang menyala aktif.',
        ),
        SopPoint(
          id: 'man_05',
          label: 'Kebersihan Luar Manless & Stiker Panduan',
          deskripsi: 'Body luar bersih, cat mulus, stiker panduan jelas',
          checkpoints: [
            'Body luar manless bersih, cat tidak karat atau kusam',
            'Stiker petunjuk cara ambil tiket / tap kartu masih terbaca jelas',
          ],
          panduanFoto: 'Foto tampak depan manless secara keseluruhan dari luar.',
        ),
        SopPoint(
          id: 'man_06',
          label: 'Dudukan Bawah Manless ke Pulau',
          deskripsi: 'Kaki dudukan bawah kokoh tidak goyang',
          checkpoints: [
            'Baut dudukan bawah ke lantai beton pulau kencang dan tidak goyang',
          ],
          panduanFoto: 'Foto bagian kaki bawah manless yang menempel di beton pulau.',
        ),
        SopPoint(
          id: 'man_07',
          label: 'Kondisi Fisik Beton Pulau Gate',
          deskripsi: 'Bebas ceceran oli, cat pulau rapi',
          checkpoints: [
            'Permukaan beton pulau bersih dari ceceran oli/sampah',
            'Cat batas pulau gate terlihat jelas',
          ],
          panduanFoto: 'Foto permukaan beton pulau gate in/out.',
        ),
        SopPoint(
          id: 'man_08',
          label: 'Kunci Manless & Gembok',
          deskripsi: 'Kunci pintu manless dan gembok berfungsi normal, tidak berkarat, dan tidak rusak',
          checkpoints: [
            'Kunci pintu/gembok manless terpasang dan berfungsi (bisa dikunci/buka normal)',
            'Kunci tidak berkarat, tidak macet, tidak patah atau hilang',
            'Jika berkarat/rusak/hilang -> foto close-up kunci yang perlu diganti',
          ],
          panduanFoto: 'Foto close-up kunci/gembok pintu manless dari jarak dekat, terlihat jelas kondisi kunci.',
        ),
      ],
      contohFotoDescriptions: ['Foto per-point manless'],
      createdBy: 'Teknisi BSS',
      updatedAt: DateTime.now(),
    ),
    // 6. MAINTENANCE PC SERVER & KASIR (6 Poin Representatif)
    TemplateModel(
      id: 'tpl_maint_server',
      nama: 'Maintenance: Server & Kasir',
      deskripsi: 'Pemeriksaan PC server dan kasir. Foto layar monitor sebagai bukti status (wajib 1 foto per poin).',
      jenis: TemplateCategory.maintServer,
      wajibLokasi: true,
      requiredRole: TemplateRole.teknisi,
      aiMode: AiMode.perPoint,
      sopCriteria: [
        'Pembersihan storage Drive C: >20GB & file temp kosong',
        'Windows Update, Antivirus, dan Windows Firewall dalam status nonaktif (OFF)',
        'Fungsi keyboard & mouse kasir (bukti ketikan Notepad)',
        'Pembersihan debu motherboard CPU & pasta pendingin prosesor baru',
        'Kerapian jalur kabel & port USB scanner belakang CPU',
        'Koneksi jaringan server stabil tanpa RTO (ping loss 0%)',
      ],
      sopPoints: [
        SopPoint(
          id: 'srv_01',
          label: 'Pembersihan Storage & File Temp',
          deskripsi: 'Foto layar Windows Explorer Drive C: >20GB & folder temp kosong',
          checkpoints: [
            'Sisa kapasitas Drive C: aman (indikator biru, >20 GB)',
            'Folder temp dan %temp% sudah dikosongkan/dihapus',
          ],
          panduanFoto: 'Foto layar monitor Windows Explorer memperlihatkan kapasitas Drive C: dan folder temp.',
        ),
        SopPoint(
          id: 'srv_02',
          label: 'Matikan Windows Update, Antivirus & Firewall',
          deskripsi: 'Bukti foto ke-3 tab/jendela: Windows Update, Antivirus & Firewall status OFF',
          checkpoints: [
            'Windows Update dalam status Paused / Disabled',
            'Windows Security Real-time Protection status OFF',
            'Windows Defender Firewall status OFF (wajib ketiga tab terbukti mati)',
          ],
          panduanFoto: 'Foto layar monitor memperlihatkan ke-3 jendela: Windows Update, Antivirus, dan Firewall status OFF.',
        ),
        SopPoint(
          id: 'srv_03',
          label: 'Fungsi Keyboard & Mouse (KeyTest / Notepad)',
          deskripsi: 'Test di keytest.com (semua tuts putih aktif) atau Notepad lengkap huruf angka F1-F12',
          checkpoints: [
            'Opsi A: Buka keytest.com di browser, uji tuts keyboard hingga layar putih & tombol aktif',
            'Opsi B: Buka Notepad, ketikkan: 1234567890qwertyuiopasdfghjklzxcvbnm serta fungsi F1-F12',
            'Kursor pointer mouse terlihat aktif di layar monitor',
          ],
          panduanFoto: 'Foto layar monitor hasil keytest.com (tuts aktif) atau Notepad tes ketikan lengkap & kursor.',
        ),
        SopPoint(
          id: 'srv_04',
          label: 'Pembersihan Debu CPU & Pasta Processor',
          deskripsi: 'Pasta pendingin prosesor baru sudah dioleskan (tidak kering) dan kipas CPU bersih dari debu',
          checkpoints: [
            'Buka penutup casing CPU komputer',
            'Kipas, motherboard, dan power supply bersih dari debu',
            'Pasta pendingin prosesor baru dioleskan di atas heatsink (tidak kering)',
          ],
          panduanFoto: 'Foto bagian dalam casing CPU memperlihatkan kebersihan motherboard & pasta processor.',
        ),
        SopPoint(
          id: 'srv_05',
          label: 'Port USB & Kerapian Kabel Belakang CPU',
          deskripsi: 'Kabel terikat cable ties/Spiral Flexibel, port USB scanner terhubung kencang',
          checkpoints: [
            'Jalur kabel belakang CPU (power, LAN, VGA/HDMI) terikat rapi',
            'Perangkat USB (scanner, tap reader) terhubung kencang di port USB',
          ],
          panduanFoto: 'Foto panel belakang CPU memperlihatkan kerapian ikatan kabel & port USB.',
        ),
        SopPoint(
          id: 'srv_06',
          label: 'Koneksi Jaringan Server Bebas RTO',
          deskripsi: 'Foto layar CMD ping antar server 0% loss tanpa RTO',
          checkpoints: [
            'Jalankan Command Prompt (CMD): ping [IP Server/Gateway] -t',
            'Hasil ping stabil (time < 5ms) dan Loss = 0% tanpa RTO',
          ],
          panduanFoto: 'Foto layar monitor CMD yang menampilkan hasil ping lancar 0% loss.',
        ),
      ],
      contohFotoDescriptions: ['Foto per-point server/kasir'],
      createdBy: 'Teknisi BSS',
      updatedAt: DateTime.now(),
    ),
  ];

  Future<void> init() async {
    final saved = StorageService.getTemplates();
    if (saved != null && saved.isNotEmpty) {
      // Filter out template briefing jika pernah tersimpan di cache
      final cleanedSaved = saved.where((t) => t.id != 'tpl_briefing_02' && t.jenis != TemplateCategory.briefing).toList();
      // Migrasi: jika template lama (<6) atau ada id lama, merge dengan default baru
      final hasNew = cleanedSaved.any((t) => t.id.startsWith('tpl_maint_'));
      if (!hasNew) {
        // simpan absensi custom user, tambah maintenance baru
        final merged = List<TemplateModel>.from(cleanedSaved);
        for (final def in defaultTemplates) {
          if (!merged.any((m) => m.id == def.id)) merged.add(def);
        }
        // update absensi ke nama/criteria baru jika masih pakai nama lama
        for (int i = 0; i < merged.length; i++) {
          if (merged[i].id == 'tpl_absensi_01') {
            final def = defaultTemplates.firstWhere((d) => d.id == 'tpl_absensi_01');
            merged[i] = merged[i].copyWith(nama: def.nama, sopCriteria: def.sopCriteria, aiMode: def.aiMode);
          }
        }
        _templates = merged;
        await StorageService.saveTemplates(_templates);
      } else {
        _templates = cleanedSaved;
        // Migrasi manless 7 -> 8 poin (tambah Kunci Manless & Gembok) + update label Dalam/Luar/Bawah
        bool needSave = false;
        for (int i = 0; i < _templates.length; i++) {
          if (_templates[i].id == 'tpl_maint_manless') {
            final def = defaultTemplates.firstWhere((d) => d.id == 'tpl_maint_manless');
            // Jika masih 7 poin atau label masih pakai kata lama Interior/Eksterior/Baseplate, update ke 8 poin baru
            final hasOldLabel = _templates[i].sopPoints.any((pt) => pt.label.contains('Interior') || pt.label.contains('Eksterior') || pt.label.contains('Baseplate'));
            if (_templates[i].sopPoints.length != def.sopPoints.length || hasOldLabel || _templates[i].sopCriteria.length != def.sopCriteria.length) {
              _templates[i] = def;
              needSave = true;
            }
          }
          if (_templates[i].id == 'tpl_maint_barrier') {
            final def = defaultTemplates.firstWhere((d) => d.id == 'tpl_maint_barrier');
            final hasOldPoints = _templates[i].sopPoints.any((pt) => pt.label.contains('Avometer') || pt.label.contains('Receiver') || pt.label.contains('0° Lurus'));
            if (hasOldPoints || _templates[i].sopPoints.length != def.sopPoints.length) {
              _templates[i] = def;
              needSave = true;
            }
          }
        }
        // Pastikan tpl_maint_server selalu ada jika user sudah punya cache lama
        if (!_templates.any((t) => t.id == 'tpl_maint_server')) {
          final serverDef = defaultTemplates.firstWhere((d) => d.id == 'tpl_maint_server');
          _templates.add(serverDef);
          needSave = true;
        }
        if (needSave) {
          await StorageService.saveTemplates(_templates);
        }
      }
    } else {
      _templates = List.from(defaultTemplates);
      await StorageService.saveTemplates(_templates);
    }
    notifyListeners();
  }

  TemplateModel? getById(String id) {
    try {
      return _templates.firstWhere((t) => t.id == id);
    } catch (_) {
      return _templates.isNotEmpty ? _templates.first : null;
    }
  }

  Future<void> addTemplate(TemplateModel template) async {
    _templates.insert(0, template);
    await StorageService.saveTemplates(_templates);
    notifyListeners();
  }

  Future<void> updateTemplate(TemplateModel template) async {
    final index = _templates.indexWhere((t) => t.id == template.id);
    if (index != -1) {
      _templates[index] = template.copyWith(updatedAt: DateTime.now());
      await StorageService.saveTemplates(_templates);
      notifyListeners();
    }
  }

  Future<void> deleteTemplate(String id) async {
    _templates.removeWhere((t) => t.id == id);
    await StorageService.saveTemplates(_templates);
    notifyListeners();
  }

  Future<void> resetToDefaults() async {
    _templates = List.from(defaultTemplates);
    await StorageService.saveTemplates(_templates);
    notifyListeners();
  }
}
