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
        'Printer pos bersih (head, roller, dan tempat kertas)',
        'Kabel terikat rapi dan colokan stopkontak kencang',
        'Item dalam pos lengkap (monitor, keyboard, mouse, scanner, printer, kipas angin)',
        'Aplikasi kasir ready online',
        'Kunci grendel pintu pos berfungsi normal',
        'Stiker logo BSS Parking dan Parkways rapi',
        'Pulau parkir rapi, cat jelas, dan tidak ada kabel terlihat',
      ],
      sopPoints: [
        SopPoint(
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
        SopPoint(
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
        SopPoint(
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
        SopPoint(
          id: 'pos_04',
          label: 'Fungsi Sistem Aplikasi Kasir',
          deskripsi: 'Layar aplikasi kasir ready online',
          checkpoints: [
            'Aplikasi kasir BSS di layar monitor status ready online',
            'Layar aktif di aplikasi kasir, bukan desktop atau aplikasi lain',
          ],
          panduanFoto: 'Foto layar monitor menampilkan aplikasi kasir BSS status ready online.',
        ),
        SopPoint(
          id: 'pos_05',
          label: 'Kunci Pintu Pos (Grendel Pintu)',
          deskripsi: 'Grendel pintu pos terpasang kuat dan berfungsi normal',
          checkpoints: [
            'Grendel pintu terpasang kuat di daun pintu',
            'Bisa dikunci dan dibuka dengan lancar',
          ],
          panduanFoto: 'Foto kunci grendel pintu pos terpasang kuat dan berfungsi normal.',
        ),
        SopPoint(
          id: 'pos_06',
          label: 'Stiker Logo BSS Parking — Sisi Depan',
          deskripsi: 'Stiker bodi depan tampil logo BSS Parking rapi',
          checkpoints: [
            'Bodi depan menampilkan stiker logo resmi BSS Parking',
            'Stiker menempel rapi, tidak terkelupas atau pudar',
          ],
          panduanFoto: 'Foto stiker logo BSS Parking di bodi depan pos.',
        ),
        SopPoint(
          id: 'pos_07',
          label: 'Stiker BSS Parking & Parkways — Sisi Kiri',
          deskripsi: 'Stiker BSS Parking dan Parkways di bodi kiri rapi',
          checkpoints: [
            'Stiker BSS Parking di bodi kiri menempel rapi',
            'Stiker Parkways di bodi kiri menempel rapi',
          ],
          panduanFoto: 'Foto stiker BSS Parking dan Parkways di sisi kiri pos.',
        ),
        SopPoint(
          id: 'pos_08',
          label: 'Stiker BSS Parking & Parkways — Sisi Kanan',
          deskripsi: 'Stiker BSS Parking dan Parkways di bodi kanan rapi',
          checkpoints: [
            'Stiker BSS Parking di bodi kanan menempel rapi',
            'Stiker Parkways di bodi kanan menempel rapi',
          ],
          panduanFoto: 'Foto stiker BSS Parking dan Parkways di sisi kanan pos.',
        ),
        SopPoint(
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
        'Pelumasan per spring dan bearing grease baru',
        'Sensor loop detector aktif (LED Detect menyala)',
        'Jalur kabel sensor tertanam rapi di aspal atau paving block',
        'Stiker receiver barrier gate utuh dan jelas',
        'Tiang CCTV kokoh dan housing kamera bersih',
        'Speed bump lajur gate terpasang kuat dengan baut dynabolt',
      ],
      sopPoints: [
        SopPoint(
          id: 'bar_01',
          label: 'Dudukan Mesin & Baut Dynabolt',
          deskripsi: 'Dudukan mesin kokoh ke beton pulau dan baut dynabolt kencang',
          checkpoints: [
            'Baut dynabolt baseplate terpasang lengkap dan kencang',
            'Dudukan mesin kokoh dan tidak goyang saat beroperasi',
          ],
          panduanFoto: 'Foto kaki baseplate mesin barrier gate memperlihatkan baut dynabolt kencang.',
        ),
        SopPoint(
          id: 'bar_02',
          label: 'Fisik Palang Tertutup Lurus',
          deskripsi: 'Palang tertutup posisi 0° lurus horizontal dan baut kencang',
          checkpoints: [
            'Palang menutup lurus horizontal sejajar jalan',
            'Baut pengikat pangkal palang kencang',
          ],
          panduanFoto: 'Foto palang posisi tertutup penuh dari arah samping lajur.',
        ),
        SopPoint(
          id: 'bar_03',
          label: 'Fisik Palang Terbuka',
          deskripsi: 'Palang terbuka 90° tegak lurus dan gerak lancar tanpa macet',
          checkpoints: [
            'Palang terbuka tegak lurus 90°',
            'Gerakan palang lancar dan tidak macet di tengah',
          ],
          panduanFoto: 'Foto palang saat terbuka penuh 90° tegak lurus.',
        ),
        SopPoint(
          id: 'bar_04',
          label: 'Pelumas (Spring/Bearing)',
          deskripsi: 'Per spring dan bearing terlumasi grease baru bebas karat',
          checkpoints: [
            'Buka pintu casing mesin barrier gate',
            'Per spring dan bearing as terlumasi grease baru',
          ],
          panduanFoto: 'Buka pintu mesin barrier gate, foto per spring dan bearing yang diberi grease.',
        ),
        SopPoint(
          id: 'bar_05',
          label: 'Sensor Loop Detector',
          deskripsi: 'Modul loop detector aktif mendeteksi kendaraan (LED Detect aktif)',
          checkpoints: [
            'Lampu indikator LED DETECT pada modul loop menyala saat ada kendaraan',
            'Relay loop merespon deteksi kendaraan dengan normal',
          ],
          panduanFoto: 'Foto modul Loop Detector di dalam mesin saat LED DETECT menyala.',
        ),
        SopPoint(
          id: 'bar_06',
          label: 'Jalur Kabel Sensor',
          deskripsi: 'Jalur kabel sensor tertanam rapi di bawah aspal/beton atau paving block, dan tidak ada kabel yang mencuat keluar',
          checkpoints: [
            'Permukaan aspal/coran atau susunan paving block tertutup rata dan rapi',
            'Kabel sensor tertanam di bawah permukaan dan tidak ada kabel yang mencuat/terkelupas ke atas',
          ],
          panduanFoto: 'Foto permukaan jalur kabel sensor loop (aspal coran atau paving block) di depan/belakang gate.',
        ),
        SopPoint(
          id: 'bar_07',
          label: 'Stiker Receiver Barrier Gate',
          deskripsi: 'Stiker receiver kuning terlihat jelas, utuh, dan tidak rusak',
          checkpoints: [
            'Stiker receiver kuning terlihat jelas',
            'Kondisi stiker utuh, tidak retak, dan tidak terkelupas',
          ],
          panduanFoto: 'Foto stiker receiver kuning bergambar peringatan palang.',
        ),
        SopPoint(
          id: 'bar_08',
          label: 'Tiang CCTV & Housing',
          deskripsi: 'Tiang CCTV kokoh tegak lurus dan housing kamera bersih bening',
          checkpoints: [
            'Tiang CCTV kokoh dan bracket kencang',
            'Housing pelindung CCTV bersih dan kaca depan bening',
          ],
          panduanFoto: 'Foto tiang CCTV dan housing kamera di area barrier gate.',
        ),
        SopPoint(
          id: 'bar_09',
          label: 'Speedbump Gate',
          deskripsi: 'Karet speed bump terpasang kuat di lajur gate dengan baut dynabolt lengkap',
          checkpoints: [
            'Karet speed bump terpasang kuat dan rata di lajur gate',
            'Baut dynabolt pengikat lengkap dan kencang ke jalan',
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
        SopPoint(
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
        SopPoint(
          id: 'man_02',
          label: 'Kebersihan Dalam Manless & Kerapihan Kabel Dalam Manless',
          deskripsi: 'Ruang dalam manless bersih dan kabel tertata rapi',
          checkpoints: [
            'Ruang dalam manless bersih dari debu dan kotoran',
            'Kabel di dalam tertata rapi dan adaptor terpasang kencang',
          ],
          panduanFoto: 'Buka pintu belakang manless, foto ruang dalam yang bersih dan kabel yang rapi.',
        ),
        SopPoint(
          id: 'man_03',
          label: 'Fungsi Tombol & Struk Tiket Keluar',
          deskripsi: 'Tombol tiket normal dan struk karcis tercetak keluar dengan baik',
          checkpoints: [
            'Tombol tiket merespon normal saat ditekan',
            'Struk karcis tiket parkir tercetak jelas dengan tanggal/jam hari ini',
          ],
          panduanFoto: 'Foto struk karcis yang baru keluar dari mulut dispenser tiket.',
        ),
        SopPoint(
          id: 'man_04',
          label: 'Sensor Loop Kendaraan (Layar/LED Aktif)',
          deskripsi: 'Layar display menampilkan petunjuk tiket atau LED loop aktif',
          checkpoints: [
            'Layar display dispenser merespon saat ada kendaraan',
            'Lampu indikator modul loop di dalam dispenser menyala',
          ],
          panduanFoto: 'Foto layar display dispenser manless atau LED modul loop yang menyala aktif.',
        ),
        SopPoint(
          id: 'man_05',
          label: 'Kebersihan Luar Manless & Stiker Panduan',
          deskripsi: 'Bodi luar bersih dan stiker petunjuk terbaca jelas',
          checkpoints: [
            'Bodi luar manless bersih dan tidak kusam',
            'Stiker panduan ambil tiket / tap kartu terbaca jelas',
          ],
          panduanFoto: 'Foto tampak depan dispenser manless dari luar.',
        ),
        SopPoint(
          id: 'man_06',
          label: 'Dudukan Bawah Manless ke Pulau',
          deskripsi: 'Dudukan bawah manless kokoh ke pulau beton dan tidak goyang',
          checkpoints: [
            'Baut dudukan ke lantai beton pulau kencang dan kokoh',
          ],
          panduanFoto: 'Foto bagian kaki bawah manless yang menempel di beton pulau.',
        ),
        SopPoint(
          id: 'man_07',
          label: 'Kondisi Fisik Beton Pulau Gate',
          deskripsi: 'Permukaan beton pulau bersih dan cat pembatas rapi',
          checkpoints: [
            'Permukaan beton pulau bersih dari oli atau sampah',
            'Cat batas pulau gate terlihat jelas dan rapi',
          ],
          panduanFoto: 'Foto permukaan beton pulau gate in/out.',
        ),
        SopPoint(
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
        SopPoint(
          id: 'srv_01',
          label: 'Pembersihan Storage & File Temp',
          deskripsi: 'Kapasitas Drive C: >20GB (indikator biru) dan folder temp bersih',
          checkpoints: [
            'Sisa kapasitas Drive C: aman (indikator biru, >20 GB)',
            'Folder temp sudah dikosongkan',
          ],
          panduanFoto: 'Foto layar monitor Windows Explorer memperlihatkan kapasitas Drive C: dan folder temp.',
        ),
        SopPoint(
          id: 'srv_02',
          label: 'Matikan Windows Update, Antivirus & Firewall',
          deskripsi: 'Tiga jendela: Windows Update, Antivirus, dan Firewall status OFF',
          checkpoints: [
            'Windows Update status Paused atau Disabled',
            'Windows Security Real-time Protection status OFF',
            'Windows Defender Firewall status OFF',
          ],
          panduanFoto: 'Foto layar monitor memperlihatkan ketiga jendela: Update, Antivirus, dan Firewall status OFF.',
        ),
        SopPoint(
          id: 'srv_03',
          label: 'Fungsi Keyboard & Mouse (KeyTest / Notepad)',
          deskripsi: 'Keyboard merespon normal dan kursor mouse aktif di layar',
          checkpoints: [
            'Uji tuts keyboard via keytest.com atau ketik huruf/angka di Notepad',
            'Kursor mouse bergerak aktif di layar monitor',
          ],
          panduanFoto: 'Foto layar monitor hasil keytest.com atau Notepad tes ketikan & kursor mouse.',
        ),
        SopPoint(
          id: 'srv_04',
          label: 'Pembersihan Debu CPU & Pasta Processor',
          deskripsi: 'Motherboard dan kipas bersih dari debu, pasta processor baru',
          checkpoints: [
            'Buka penutup casing CPU komputer',
            'Kipas, motherboard, dan power supply bersih dari debu',
            'Pasta pendingin processor baru teroles di heatsink (tidak kering)',
          ],
          panduanFoto: 'Foto bagian dalam casing CPU memperlihatkan motherboard bersih & pasta processor.',
        ),
        SopPoint(
          id: 'srv_05',
          label: 'Port USB & Kerapian Kabel Belakang CPU',
          deskripsi: 'Kabel belakang CPU terikat rapi dan port USB terpasang kencang',
          checkpoints: [
            'Kabel belakang CPU (power, LAN, monitor) terikat rapi',
            'Kabel USB scanner dan reader terpasang kencang di port USB',
          ],
          panduanFoto: 'Foto panel belakang CPU memperlihatkan kerapian kabel & colokan USB.',
        ),
        SopPoint(
          id: 'srv_06',
          label: 'Koneksi Jaringan Server Bebas RTO',
          deskripsi: 'Hasil ping CMD stabil time < 5ms dan Loss 0% tanpa RTO',
          checkpoints: [
            'Jalankan CMD: ping IP Server atau Gateway',
            'Hasil ping stabil time < 5ms dan Loss = 0% tanpa RTO',
          ],
          panduanFoto: 'Foto layar monitor CMD menampilkan hasil ping lancar 0% loss.',
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
