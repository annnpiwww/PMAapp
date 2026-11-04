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
        'Tanpa jaket / hoodie / sweater atau baju luar di atas seragam (kemeja rapi & baju polo sah)',
        'ID Card / Name Tag terpasang jelas di saku kiri (tali lanyard / yoyo lanyard sah)',
        'Wajah terlihat jelas tanpa masker / kacamata',
        'Sepatu Hitam bersih',
      ],
      aiMode: AiMode.singleFoto,
      requiredRole: TemplateRole.all,
      contohFotoDescriptions: [
        'Foto full body tegap menghadap kamera',
        'Seragam resmi BSS Parking rapi',
        'Foto jelas, tidak blur dan tidak miring',
      ],
      createdBy: 'HO BSS Parking Pusat',
      updatedAt: DateTime.now(),
    ),
    // 2. MAINTENANCE POS PARKIR & BOOTH (10 Poin Pos / 5 Poin Booth)
    TemplateModel(
      id: 'tpl_maint_pos',
      nama: 'Maintenance: Pos Parkir & Booth',
      deskripsi: 'Pembersihan & perapihan pos parkir serta booth. Wajib 1 point 1 foto per pos/booth.',
      jenis: TemplateCategory.maintPos,
      wajibLokasi: true,
      requiredRole: TemplateRole.teknisi,
      aiMode: AiMode.perPoint,
      sopCriteria: [
        'Printer pos bersih (head, roller, dan tempat kertas)',
        'Kabel terikat rapi dan colokan stopkontak kencang',
        'Item dalam pos lengkap (monitor, keyboard, mouse, scanner, printer, kipas angin)',
        'Aplikasi kasir ready online',
        'Baling-baling dan cover penutup kipas angin bersih',
        'Kunci grendel pintu pos berfungsi normal',
        'Stiker logo BSS Parking dan Parkways rapi',
        'Pulau parkir rapi, cat jelas, dan tidak ada kabel terlihat',
      ],
      sopPoints: [
        const SopPoint(
          id: 'pos_01',
          label: 'Pembersihan Total Printer Pos',
          deskripsi: 'Head printer, roller karet, dan tempat kertas bersih',
          checkpoints: [
            'Buka penutup printer thermal kasir',
            'Head printer dan roller karet bersih',
            'Tempat kertas bersih dari serbuk potongan kertas',
            'Kabel power dan data terpasang kencang',
          ],
          panduanFoto: 'Buka penutup printer, foto dari atas agar head, roller, dan tempat kertas terlihat jelas.',
        ),
        const SopPoint(
          id: 'pos_02',
          label: 'Kerapian Jalur Kabel & Stopkontak',
          deskripsi: 'Kabel terikat rapi dan colokan adaptor kencang',
          checkpoints: [
            'Kabel terikat rapi pakai spiral flexibel atau kabel ties',
            'Tidak ada kabel terkelupas atau sambungan terbuka',
            'Colokan adaptor kencang dan tidak goyang',
          ],
          panduanFoto: 'Foto area stopkontak dan kabel bawah meja, pastikan kabel terikat rapi dan colokan kencang.',
        ),
        const SopPoint(
          id: 'pos_03',
          label: 'Standarisasi Item dalam Pos',
          deskripsi: 'Item dalam pos lengkap: monitor, keyboard, mouse, scanner, printer, dan kipas angin',
          checkpoints: [
            'Item di meja pos lengkap: monitor, keyboard, mouse, barcode scanner, dan printer',
            'Kipas angin meja tersedia di dalam pos',
            'Semua item terpasang rapi di area meja',
          ],
          panduanFoto: 'Foto meja pos memperlihatkan monitor, keyboard, scanner, printer, dan kipas angin.',
        ),
        const SopPoint(
          id: 'pos_04',
          label: 'Fungsi Sistem Aplikasi Kasir',
          deskripsi: 'Layar aplikasi kasir ready online',
          checkpoints: [
            'Aplikasi kasir BSS di layar monitor status ready online',
            'Layar aktif di aplikasi kasir, bukan desktop atau aplikasi lain',
          ],
          panduanFoto: 'Foto layar monitor menampilkan aplikasi kasir BSS status ready online.',
        ),
        const SopPoint(
          id: 'pos_10',
          label: 'Pembersihan Kipas Angin',
          deskripsi: 'Baling-baling dan cover penutup kipas angin harus bersih',
          checkpoints: [
            'Baling-baling kipas angin bersih dari debu',
            'Cover penutup kipas angin bersih dan terpasang',
          ],
          panduanFoto: 'Foto kipas angin dari depan agar baling-baling dan cover penutupnya terlihat jelas.',
        ),
        const SopPoint(
          id: 'pos_05',
          label: 'Kunci Pintu Pos (Grendel Pintu)',
          deskripsi: 'Grendel pintu pos terpasang kuat dan berfungsi normal',
          checkpoints: [
            'Grendel pintu terpasang kuat di daun pintu',
            'Bisa dikunci dan dibuka dengan lancar',
          ],
          panduanFoto: 'Foto kunci grendel pintu pos terpasang kuat dan berfungsi normal.',
        ),
        const SopPoint(
          id: 'pos_06',
          label: 'Stiker Logo BSS Parking - Sisi Depan',
          deskripsi: 'Stiker bodi depan tampil logo BSS Parking rapi',
          checkpoints: [
            'Bodi depan menampilkan stiker logo resmi BSS Parking',
            'Stiker menempel rapi, tidak terkelupas atau pudar',
          ],
          panduanFoto: 'Foto stiker logo BSS Parking di bodi depan pos.',
        ),
        const SopPoint(
          id: 'pos_07',
          label: 'Stiker BSS Parking & Parkways — Sisi Kiri',
          deskripsi: 'Stiker BSS Parking dan Parkways di bodi kiri rapi',
          checkpoints: [
            'Stiker BSS Parking di bodi kiri menempel rapi',
            'Stiker Parkways di bodi kiri menempel rapi',
          ],
          panduanFoto: 'Foto stiker BSS Parking dan Parkways di sisi kiri pos.',
        ),
        const SopPoint(
          id: 'pos_08',
          label: 'Stiker BSS Parking & Parkways — Sisi Kanan',
          deskripsi: 'Stiker BSS Parking dan Parkways di bodi kanan rapi',
          checkpoints: [
            'Stiker BSS Parking di bodi kanan menempel rapi',
            'Stiker Parkways di bodi kanan menempel rapi',
          ],
          panduanFoto: 'Foto stiker BSS Parking dan Parkways di sisi kanan pos.',
        ),
        const SopPoint(
          id: 'pos_09',
          label: 'Kondisi Pulau Parkir',
          deskripsi: 'Cat pulau parkir rapi, beton utuh, dan tidak ada kabel terlihat',
          checkpoints: [
            'Cat marka kuning-hitam di pulau parkir jelas dan rapi',
            'Beton pulau utuh dan bebas retak parah',
            'Tidak ada kabel terlihat di permukaan pulau parkir',
          ],
          panduanFoto: 'Foto pulau parkir memperlihatkan cat marka rapi, beton utuh, dan tanpa kabel terlihat.',
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
        'Dudukan mesin barrier kokoh dan baut dynabolt kencang',
        'Palang posisi tertutup 0° lurus dan baut kencang',
        'Palang posisi terbuka 90° tegak lurus dan lancar',
        'Fisik per spring dan bearing mekanik terpasang baik',
        'Sensor loop detector aktif (LED Detect menyala)',
        'Jalur kabel sensor tertanam rapi di aspal atau paving block',
        'Stiker receiver barrier gate utuh dan jelas',
        'Tiang CCTV kokoh dan housing kamera bersih',
        'Karet speed bump terpasang utuh dan rata di lajur gate',
      ],
      sopPoints: [
        const SopPoint(
          id: 'bar_01',
          label: 'Dudukan Mesin & Baut Dynabolt',
          deskripsi: 'Dudukan mesin kokoh ke beton pulau dan baut dynabolt kencang',
          checkpoints: [
            'Baut dynabolt baseplate terpasang lengkap dan kencang',
            'Plat baseplate kokoh dan tidak goyang saat beroperasi',
          ],
          panduanFoto: 'Foto kaki baseplate mesin barrier gate memperlihatkan baut dynabolt kokoh.',
        ),
        const SopPoint(
          id: 'bar_02',
          label: 'Fisik Palang Tertutup Lurus',
          deskripsi: 'Palang tertutup posisi 0° lurus horizontal dan baut kencang',
          checkpoints: [
            'Palang menutup lurus horizontal sejajar jalan',
            'Baut pengikat pangkal palang kencang',
          ],
          panduanFoto: 'Foto palang posisi tertutup penuh dari arah samping lajur.',
        ),
        const SopPoint(
          id: 'bar_03',
          label: 'Fisik Palang Terbuka',
          deskripsi: 'Palang terbuka 90° tegak lurus dan gerak lancar tanpa macet',
          checkpoints: [
            'Palang terbuka tegak lurus 90°',
            'Gerakan palang lancar dan tidak macet di tengah',
          ],
          panduanFoto: 'Foto palang saat terbuka penuh 90° tegak lurus.',
        ),
        const SopPoint(
          id: 'bar_04',
          label: 'Pelumas (Spring/Bearing)',
          deskripsi: 'Fisik per spring dan bearing mekanik di dalam bodi mesin barrier gate',
          checkpoints: [
            'Buka pintu casing mesin barrier gate',
            'Per spring dan bearing mekanik terlihat jelas di dalam mesin',
          ],
          panduanFoto: 'Buka pintu mesin barrier gate, foto per spring dan bearing mekanik di dalam bodi mesin.',
        ),
        const SopPoint(
          id: 'bar_05',
          label: 'Sensor Loop Detector',
          deskripsi: 'Modul loop detector aktif mendeteksi kendaraan (LED Detect aktif)',
          checkpoints: [
            'Lampu indikator LED DETECT pada modul loop menyala saat ada kendaraan',
            'Relay loop merespon deteksi kendaraan dengan normal',
          ],
          panduanFoto: 'Foto modul Loop Detector di dalam mesin saat LED DETECT menyala.',
        ),
        const SopPoint(
          id: 'bar_06',
          label: 'Jalur Kabel Sensor',
          deskripsi: 'Jalur kabel sensor tertanam rapi di bawah aspal/beton atau paving block, dan tidak ada kabel yang mencuat keluar',
          checkpoints: [
            'Permukaan aspal/coran atau susunan paving block tertutup rata dan rapi',
            'Kabel sensor tertanam di bawah permukaan dan tidak ada kabel yang mencuat/terkelupas ke atas',
          ],
          panduanFoto: 'Foto permukaan jalur kabel sensor loop (aspal coran atau paving block) di depan/belakang gate.',
        ),
        const SopPoint(
          id: 'bar_07',
          label: 'Stiker Receiver Barrier Gate',
          deskripsi: 'Stiker receiver kuning terlihat jelas, utuh, dan tidak rusak',
          checkpoints: [
            'Stiker receiver kuning terlihat jelas',
            'Kondisi stiker utuh, tidak retak, dan tidak terkelupas',
          ],
          panduanFoto: 'Foto stiker receiver kuning bergambar peringatan palang.',
        ),
        const SopPoint(
          id: 'bar_08',
          label: 'Tiang CCTV & Housing',
          deskripsi: 'Tiang CCTV kokoh tegak lurus dan housing kamera bersih bening',
          checkpoints: [
            'Tiang CCTV kokoh dan bracket kencang',
            'Housing pelindung CCTV bersih dan kaca depan bening',
          ],
          panduanFoto: 'Foto tiang CCTV dan housing kamera di area barrier gate.',
        ),
        const SopPoint(
          id: 'bar_09',
          label: 'Speedbump Gate',
          deskripsi: 'Karet speed bump terpasang utuh di lajur gate, bebas robek atau hancur',
          checkpoints: [
            'Karet speed bump terpasang rata di lajur gate',
            'Fisik karet utuh, tidak sobek, tidak pecah, atau hancur',
          ],
          panduanFoto: 'Foto karet speed bump di area lajur barrier gate memperlihatkan kondisi fisik karet.',
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
        'Printer tiket bersih (head thermal, roller, dan ruang kertas)',
        'Ruang dalam manless bersih dan kabel tertata rapi',
        'Tombol tiket normal dan struk karcis keluar lancar',
        'Sensor loop dispenser manless aktif (layar/LED)',
        'Bodi luar manless bersih dan stiker panduan terbaca jelas',
        'Dudukan bawah manless kokoh ke pulau beton',
        'Lantai beton pulau gate bersih dan rapi',
        'Kunci pintu manless dan gembok berfungsi normal',
      ],
      sopPoints: [
        const SopPoint(
          id: 'man_01',
          label: 'Pembersihan Total Printer Tiket',
          deskripsi: 'Head thermal, roller karet, dan tempat kertas bersih',
          checkpoints: [
            'Buka pintu modul printer tiket manless',
            'Head thermal dan karet roller bersih',
            'Ruang tempat kertas bersih dari serbuk potongan kertas',
            'Kabel LAN dan power terpasang kencang',
          ],
          panduanFoto: 'Foto dari atas modul printer tiket yang terbuka memperlihatkan head dan ruang kertas.',
        ),
        const SopPoint(
          id: 'man_02',
          label: 'Kebersihan Dalam Manless & Kerapihan Kabel Dalam Manless',
          deskripsi: 'Ruang dalam manless bersih dan kabel tertata rapi',
          checkpoints: [
            'Ruang dalam manless bersih dari debu dan kotoran',
            'Kabel di dalam tertata rapi dan adaptor terpasang kencang',
          ],
          panduanFoto: 'Buka pintu belakang manless, foto ruang dalam yang bersih dan kabel yang rapi.',
        ),
        const SopPoint(
          id: 'man_03',
          label: 'Fungsi Tombol & Struk Tiket Keluar',
          deskripsi: 'Tombol tiket normal dan struk karcis tercetak keluar dengan baik',
          checkpoints: [
            'Tombol tiket merespon normal saat ditekan',
            'Struk karcis tiket parkir tercetak jelas dengan tanggal/jam hari ini',
          ],
          panduanFoto: 'Foto struk karcis yang baru keluar dari mulut dispenser tiket.',
        ),
        const SopPoint(
          id: 'man_04',
          label: 'Sensor Loop Kendaraan (Layar/LED Aktif)',
          deskripsi: 'Layar display menampilkan petunjuk tiket atau LED loop aktif',
          checkpoints: [
            'Layar display dispenser merespon saat ada kendaraan',
            'Lampu indikator modul loop di dalam dispenser menyala',
          ],
          panduanFoto: 'Foto layar display dispenser manless atau LED modul loop yang menyala aktif.',
        ),
        const SopPoint(
          id: 'man_05',
          label: 'Kebersihan Luar Manless & Stiker Panduan',
          deskripsi: 'Bodi luar bersih dan stiker petunjuk terbaca jelas',
          checkpoints: [
            'Bodi luar manless bersih dan tidak kusam',
            'Stiker panduan ambil tiket / tap kartu terbaca jelas',
          ],
          panduanFoto: 'Foto tampak depan dispenser manless dari luar.',
        ),
        const SopPoint(
          id: 'man_06',
          label: 'Dudukan Bawah Manless ke Pulau',
          deskripsi: 'Dudukan bawah manless kokoh ke pulau beton dan tidak goyang',
          checkpoints: [
            'Baut dudukan ke lantai beton pulau kencang dan kokoh',
          ],
          panduanFoto: 'Foto bagian kaki bawah manless yang menempel di beton pulau.',
        ),
        const SopPoint(
          id: 'man_07',
          label: 'Kondisi Fisik Beton Pulau Gate',
          deskripsi: 'Permukaan beton pulau bersih dan cat pembatas rapi',
          checkpoints: [
            'Permukaan beton pulau bersih dari oli atau sampah',
            'Cat batas pulau gate terlihat jelas dan rapi',
          ],
          panduanFoto: 'Foto permukaan beton pulau gate in/out.',
        ),
        const SopPoint(
          id: 'man_08',
          label: 'Kunci Manless & Gembok',
          deskripsi: 'Kunci pintu manless dan gembok berfungsi normal dan bebas karat',
          checkpoints: [
            'Kunci pintu dan gembok manless bisa dikunci dan dibuka normal',
            'Kunci tidak berkarat, tidak macet, dan tidak rusak',
          ],
          panduanFoto: 'Foto kunci atau gembok pintu manless memperlihatkan kondisi kunci.',
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
        'Storage Drive C: >20GB dan folder temp bersih',
        'Windows Update, Antivirus, dan Windows Firewall status OFF',
        'Fungsi keyboard dan mouse normal (bukti tes Notepad / KeyTest)',
        'Debu casing CPU bersih dan pasta processor baru',
        'Kabel belakang CPU rapi dan port USB terhubung kencang',
        'Koneksi jaringan server stabil tanpa RTO (ping loss 0%)',
      ],
      sopPoints: [
        const SopPoint(
          id: 'srv_01',
          label: 'Pembersihan Storage & File Temp',
          deskripsi: 'Kapasitas Drive C: >20GB (bar biru) atau df -h root <80%, temp bersih',
          checkpoints: [
            'Sisa kapasitas Drive C: aman (indikator bar biru >20GB) atau df -h Use% <80%',
            'Folder temp / cache sudah dikosongkan/dibersihkan',
          ],
          panduanFoto: 'Foto layar monitor Windows Explorer kapasitas Drive C: atau terminal df -h.',
        ),
        const SopPoint(
          id: 'srv_02',
          label: 'Matikan Windows Update, Antivirus & Firewall',
          deskripsi: 'Proteksi Windows Security, Firewall, atau Auto-update status OFF',
          checkpoints: [
            'Windows Security Real-time Protection status OFF atau silang merah',
            'Windows Defender Firewall atau UFW Linux status OFF / Inactive',
          ],
          panduanFoto: 'Foto layar monitor jendela Windows Security / Firewall / UFW status nonaktif/OFF.',
        ),
        const SopPoint(
          id: 'srv_03',
          label: 'Fungsi Keyboard & Mouse (KeyTest / Notepad)',
          deskripsi: 'Keyboard merespon normal dan kursor mouse aktif di layar',
          checkpoints: [
            'Uji tuts keyboard via teks di Notepad / Terminal Console atau web keytest.com',
            'Kursor mouse aktif dan bergerak lancar di layar monitor',
          ],
          panduanFoto: 'Foto layar monitor hasil ketikan teks di Notepad/terminal atau tuts aktif di keytest.com.',
        ),
        const SopPoint(
          id: 'srv_04',
          label: 'Pembersihan Debu CPU & Pasta Processor',
          deskripsi: 'Bagian dalam casing CPU bersih, kipas dan motherboard bebas debu tebal',
          checkpoints: [
            'Buka penutup samping casing CPU komputer',
            'Kipas processor, motherboard, dan heatsink bersih dari tumpukan debu',
          ],
          panduanFoto: 'Foto bagian dalam casing CPU memperlihatkan kipas dan motherboard bersih dari debu.',
        ),
        const SopPoint(
          id: 'srv_05',
          label: 'Port USB & Kerapian Kabel Belakang CPU',
          deskripsi: 'Kabel belakang CPU terikat rapi dan port USB terpasang kencang',
          checkpoints: [
            'Kabel belakang CPU (power, LAN, monitor) terikat rapi pakai cable tie/spiral',
            'Kabel USB scanner, reader, dan printer terpasang kencang di port USB',
          ],
          panduanFoto: 'Foto panel belakang CPU memperlihatkan kerapian kabel terikat & colokan USB.',
        ),
        const SopPoint(
          id: 'srv_06',
          label: 'Koneksi Jaringan Server Bebas RTO',
          deskripsi: 'Hasil ping CMD stabil time < 10ms dan Loss 0% tanpa RTO',
          checkpoints: [
            'Jalankan CMD / terminal: ping IP Server, Gateway, atau Pos',
            'Hasil ping stabil (0% loss) lancar tanpa Request Timed Out (RTO)',
          ],
          panduanFoto: 'Foto layar monitor CMD / terminal menampilkan hasil ping lancar 0% loss.',
        ),
      ],
      contohFotoDescriptions: ['Foto per-point server/kasir'],
      createdBy: 'Teknisi BSS',
      updatedAt: DateTime.now(),
    ),
    // 7. MAINTENANCE LENGKAP — 1 tugas cover semua area.
    // sopPoints sengaja KOSONG: poin diturunkan saat runtime dari template area
    // di atas (barrier + manless + pos [+ server]) supaya SOP tetap satu sumber.
    // Lihat MaintenanceChecklistScreen._generateLengkapPoints().
    TemplateModel(
      id: 'tpl_maint_lengkap',
      nama: 'Maintenance: Lengkap',
      deskripsi: 'Maintenance penuh dalam 1 tugas: Barrier Gate + Manless + Pos Kasir (+ PC Server).',
      jenis: TemplateCategory.maintLengkap,
      wajibLokasi: true,
      requiredRole: TemplateRole.teknisi,
      aiMode: AiMode.perPoint,
      sopCriteria: [
        'Barrier Gate: mesin, palang, sensor loop, jalur kabel, tiang CCTV & speed bump sesuai SOP barrier',
        'Manless & Pulau: printer tiket, kebersihan luar-dalam, tombol, sensor loop, kunci & gembok sesuai SOP manless',
        'Pos Kasir: printer pos, kerapian kabel, item pos, aplikasi kasir, kunci & stiker sesuai SOP pos',
        'PC Server: storage, firewall, input test, debu CPU, kabel & koneksi jaringan sesuai SOP server',
      ],
      sopPoints: [],
      contohFotoDescriptions: ['Foto per-point sesuai checklist tiap area'],
      createdBy: 'Teknisi BSS',
      updatedAt: DateTime.now(),
    ),
  ];

  /// Poin khusus mode Booth Parkir (dipilih teknisi di setup Pos Parkir & Booth).
  /// Disimpan terpisah supaya template Pos Kasir tetap 9 poin.
  static const List<SopPoint> boothParkirPoints = [
    SopPoint(
      id: 'booth_01',
      label: 'Pembersihan Printer',
      deskripsi: 'Head printer, roller karet, dan tempat kertas bersih',
      checkpoints: [
        'Buka penutup printer thermal booth',
        'Head printer dan roller karet bersih',
        'Tempat kertas bersih dari serbuk potongan kertas',
        'Kabel power dan data terpasang kencang',
      ],
      panduanFoto: 'Buka penutup printer, foto dari atas agar head, roller, dan tempat kertas terlihat jelas.',
    ),
    SopPoint(
      id: 'booth_02',
      label: 'Pembersihan Booth',
      deskripsi: 'Booth dalam keadaan bersih',
      checkpoints: [
        'Area dalam dan luar booth bersih dari sampah dan debu',
        'Meja serta peralatan booth tertata rapi',
      ],
      panduanFoto: 'Foto keseluruhan area booth dari depan, pastikan bersih dan rapi.',
    ),
    SopPoint(
      id: 'booth_03',
      label: 'Standarisasi Item Booth',
      deskripsi: 'Item di atas booth lengkap, ada printer, tab/device Harvard',
      checkpoints: [
        'Printer tersedia dan terpasang di atas booth',
        'Tab/device Harvard tersedia dan berfungsi',
      ],
      panduanFoto: 'Foto meja booth memperlihatkan printer dan tab/device Harvard lengkap.',
    ),
    SopPoint(
      id: 'booth_04',
      label: 'Tiket Printer Gate Out',
      deskripsi: 'Tiket tercetak dengan baik, tanpa barcode yang memudar',
      checkpoints: [
        'Cetak tiket uji dari printer gate out',
        'Barcode tercetak jelas dan bisa dipindai',
        'Tidak ada barcode yang memudar',
      ],
      panduanFoto: 'Foto tiket hasil cetakan printer gate out, pastikan barcode terbaca jelas.',
    ),
    SopPoint(
      id: 'booth_05',
      label: 'Aplikasi Payment',
      deskripsi: 'Aplikasi payment POS terbuka dengan baik dan sistem berjalan dengan normal',
      checkpoints: [
        'Aplikasi payment POS terbuka di layar',
        'Sistem payment berjalan normal tanpa error',
      ],
      panduanFoto: 'Foto layar PC booth menampilkan aplikasi payment POS terbuka.',
    ),
  ];

  /// Poin tambahan mode Manless OUT (SOP IN + pembersihan perangkat luar).
  /// Dipakai Bali & HO; Manado tidak punya mode OUT.
  static const List<SopPoint> manlessOutExtraPoints = [
    SopPoint(
      id: 'mout_01',
      label: 'Pembersihan Item Mini PC',
      deskripsi: 'Mini pc dalam keadaan bersih dan tidak berdebu',
      checkpoints: [
        'Mini pc dalam keadaan bersih dan tidak berdebu',
      ],
      panduanFoto: 'Foto mini PC di dalam manless memperlihatkan permukaan bersih dan bebas debu.',
    ),
    SopPoint(
      id: 'mout_02',
      label: 'Pembersihan AINO',
      deskripsi: 'AINO dalam keadaan bersih dan tidak berdebu',
      checkpoints: [
        'AINO dalam keadaan bersih dan tidak berdebu',
      ],
      panduanFoto: 'Foto perangkat AINO memperlihatkan layar dan bodi bersih tanpa debu.',
    ),
    SopPoint(
      id: 'mout_03',
      label: 'Pembersihan Scanner',
      deskripsi: 'Scanner dalam keadaan bersih dan tidak berdebu',
      checkpoints: [
        'Scanner dalam keadaan bersih dan tidak berdebu',
      ],
      panduanFoto: 'Foto scanner manless memperlihatkan permukaan bersih dan bebas debu.',
    ),
    SopPoint(
      id: 'mout_04',
      label: 'Pembersihan Layar Monitor',
      deskripsi: 'Layar monitor dalam keadaan bersih dan tidak berdebu',
      checkpoints: [
        'Layar monitor dalam keadaan bersih dan tidak berdebu',
      ],
      panduanFoto: 'Foto layar monitor manless memperlihatkan layar bersih dan terbaca jelas.',
    ),
  ];

  /// Poin mode Manless PEP (pengecekan fisik pulau & kunci, semua cabang).
  static const List<SopPoint> manlessPepPoints = [
    SopPoint(
      id: 'mpep_01',
      label: 'Kebersihan & Kerapihan Kabel dalam Manless',
      deskripsi: 'Bagian dalam manless bersih dan perkabelan rapih',
      checkpoints: [
        'Bagian dalam manless bersih dan perkabelan rapih',
      ],
      panduanFoto: 'Buka pintu manless, foto bagian dalam memperlihatkan ruang bersih dan kabel rapi.',
    ),
    SopPoint(
      id: 'mpep_02',
      label: 'Kebersihan Body Luar Manless & Stiker',
      deskripsi: 'Body luar manless bersih dan stiker petunjuk terbaca jelas',
      checkpoints: [
        'Body luar manless bersih dan stiker petunjuk terbaca jelas',
      ],
      panduanFoto: 'Foto tampak depan manless memperlihatkan body bersih dan stiker terbaca.',
    ),
    SopPoint(
      id: 'mpep_03',
      label: 'Dudukan Dynabolt Manless',
      deskripsi: 'Dudukan dynabolt kuat dan kokoh, tidak goyang',
      checkpoints: [
        'Dudukan dynabolt kuat dan kokoh, tidak goyang',
      ],
      panduanFoto: 'Foto dudukan dynabolt manless ke pulau, pastikan baut kencang dan tidak goyang.',
    ),
    SopPoint(
      id: 'mpep_04',
      label: 'Kondisi Fisik Pulau Manless',
      deskripsi: 'Pulau kokoh, tidak hancur dan cat pulau masih jelas',
      checkpoints: [
        'Pulau kokoh, tidak hancur dan cat pulau masih jelas',
      ],
      panduanFoto: 'Foto keseluruhan pulau manless memperlihatkan beton kokoh dan cat masih jelas.',
    ),
    SopPoint(
      id: 'mpep_05',
      label: 'Kunci Manless',
      deskripsi: 'Kunci pintu manless berfungsi normal dan tidak berkarat',
      checkpoints: [
        'Kunci pintu manless berfungsi normal dan tidak berkarat',
      ],
      panduanFoto: 'Foto kunci pintu manless memperlihatkan kondisi kunci dan gembok.',
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
          if (_templates[i].id == 'tpl_maint_pos') {
            final def = defaultTemplates.firstWhere((d) => d.id == 'tpl_maint_pos');
            // Rename template lama "Pos Parkir" -> "Pos Parkir & Booth" (tanpa menimpa nama custom)
            if (_templates[i].nama == 'Maintenance: Pos Parkir') {
              _templates[i] = _templates[i].copyWith(nama: def.nama, deskripsi: def.deskripsi);
              needSave = true;
            }
            // Cache lama belum punya poin Pembersihan Kipas Angin (pos_10)
            if (!_templates[i].sopPoints.any((pt) => pt.id == 'pos_10')) {
              _templates[i] = _templates[i].copyWith(sopPoints: def.sopPoints, sopCriteria: def.sopCriteria);
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
        // Pastikan tpl_maint_lengkap ada untuk install lama (fitur Maintenance Lengkap)
        if (!_templates.any((t) => t.id == 'tpl_maint_lengkap')) {
          final lengkapDef = defaultTemplates.firstWhere((d) => d.id == 'tpl_maint_lengkap');
          _templates.add(lengkapDef);
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
