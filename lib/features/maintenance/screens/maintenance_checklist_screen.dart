import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/theme_service.dart';
import '../../../core/widgets/app_file_image.dart';
import '../../../data/models/template_model.dart';
import '../../../data/models/maintenance_submission.dart';
import '../../../data/services/storage_service.dart';
import '../../../data/services/location_service.dart';
import '../../../data/services/google_sheets_service.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/services/whatsapp_report_service.dart';
import '../../../data/services/daily_task_service.dart';
import '../widgets/photo_preview_dialog.dart';
import 'point_camera_view.dart';
import 'maintenance_history_screen.dart';

class MaintenanceChecklistScreen extends StatefulWidget {
  final TemplateModel template;
  final int? unitCount; // null jika dari saved submission
  final List<int>? unitNumbers; // nomor pos/unit spesifik, misal [1, 2, 3] atau [3, 4, 5, 6]
  final PosLocation? location;
  final String? supportName;
  final MaintenanceSubmission? existingSubmission;
  final bool isServerKasirGabung;
  final bool isOnlyKasir;
  final int? kasirCount;
  final String? serverOs;
  final String? dailyTaskId;

  const MaintenanceChecklistScreen({
    super.key,
    required this.template,
    this.unitCount,
    this.unitNumbers,
    this.location,
    this.supportName,
    this.existingSubmission,
    this.isServerKasirGabung = false,
    this.isOnlyKasir = false,
    this.kasirCount,
    this.serverOs,
    this.dailyTaskId,
  });

  @override
  State<MaintenanceChecklistScreen> createState() =>
      _MaintenanceChecklistScreenState();
}

class _MaintenanceChecklistScreenState
    extends State<MaintenanceChecklistScreen> {
  late MaintenanceSubmission _submission;
  late final List<SopPoint> _cachedSopPoints;
  late final List<int> _effectiveUnits;
  String _selectedUnitFilter = 'ALL'; // 'ALL', 'UNIT_1', 'UNIT_2', dst.
  String _selectedStatusFilter = 'ALL'; // 'ALL', 'BELUM', 'SESUAI', 'CEK'

  PosLocation get _effectiveLocation {
    if (widget.location != null) return widget.location!;
    if (widget.existingSubmission != null) {
      for (final p in LocationService.availablePosList) {
        if (p.posId == widget.existingSubmission!.posId ||
            p.posName == widget.existingSubmission!.posName) {
          return p;
        }
      }
      return PosLocation(
        posId: widget.existingSubmission!.posId,
        posName: widget.existingSubmission!.posName,
        cabangName: widget.existingSubmission!.cabangName,
        fullAddress: widget.existingSubmission!.cabangName,
        locationTag: widget.existingSubmission!.posName,
        tagColor: const Color(0xFF0284C7),
        lat: LocationService.currentPos.lat,
        lng: LocationService.currentPos.lng,
      );
    }
    return LocationService.currentPos;
  }

  bool get _isEffectiveOnlyKasir {
    if (widget.isOnlyKasir) return true;
    if (widget.existingSubmission != null &&
        widget.template.jenis == TemplateCategory.maintServer) {
      return !_submission.points
          .any((p) => p.label.toLowerCase().contains('server'));
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _effectiveUnits = _resolveUnits();
    _cachedSopPoints = _generatePoinPerUnit();
    _initSubmission();
  }

  List<int> _resolveUnits() {
    if (widget.unitNumbers != null && widget.unitNumbers!.isNotEmpty) {
      return List<int>.from(widget.unitNumbers!);
    }
    if (widget.existingSubmission != null &&
        widget.existingSubmission!.points.isNotEmpty) {
      final set = <int>{};
      for (final p in widget.existingSubmission!.points) {
        final parts = p.pointId.split('_');
        if (parts.length >= 3) {
          final idx = int.tryParse(parts[1]);
          if (idx != null) set.add(idx);
        }
      }
      if (set.isNotEmpty) {
        final sorted = set.toList()..sort();
        return sorted;
      }
    }
    final count = widget.unitCount ?? 1;
    return List.generate(count, (i) => i + 1);
  }

  void _initSubmission() {
    // Jika dibuka langsung dengan submission spesifik (dari Riwayat atau Daily Task), langsung pakai itu!
    if (widget.existingSubmission != null) {
      if (widget.dailyTaskId != null && widget.existingSubmission!.taskId == null) {
        _submission = widget.existingSubmission!.copyWith(taskId: widget.dailyTaskId);
      } else {
        _submission = widget.existingSubmission!;
      }
      return;
    }

    final user = AuthRepository.instance.currentUser;
    final pos = _effectiveLocation;
    final repoList = StorageService.getMaintenanceSubmissions() ?? [];

    // Cari draft berjalan yang belum selesai
    final existing = repoList.where((s) {
      if (s.isComplete) return false;
      if (widget.dailyTaskId != null && s.taskId == widget.dailyTaskId) return true;
      if (s.templateId != widget.template.id) return false;
      final sameUser = s.userId == (user?.id ?? 'anon') || s.userName == (user?.nama ?? '');
      final samePos = s.posId == pos.posId || s.posName == LocationService.displayName(pos);
      return sameUser && samePos;
    }).toList();

    if (existing.isNotEmpty && widget.unitCount == null) {
      _submission = existing.first;
      if (widget.dailyTaskId != null && _submission.taskId == null) {
        _submission = _submission.copyWith(taskId: widget.dailyTaskId);
      }
    } else {
      final points = _cachedSopPoints;
      final effectiveName = widget.supportName ??
          (StorageService.getLastTechnicianName().isNotEmpty
              ? StorageService.getLastTechnicianName()
              : (user?.nama ?? 'Teknisi BSS'));

      _submission = MaintenanceSubmission(
        id: 'maint_${DateTime.now().millisecondsSinceEpoch}',
        templateId: widget.template.id,
        templateName: widget.template.nama,
        userId: user?.id ?? 'anon',
        userName: effectiveName,
        userNpp: user?.npp ?? '-',
        posId: pos.posId,
        posName: LocationService.displayName(pos),
        cabangName: pos.cabangName,
        points: points
            .map((p) =>
                MaintenancePointResult(pointId: p.id, label: p.label))
            .toList(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        taskId: widget.dailyTaskId,
      );
    }
  }

  List<SopPoint> _generatePoinPerUnit() {
    final count = widget.unitCount ?? 1;
    final cat = widget.template.jenis;
    final list = <SopPoint>[];

    // Khusus Server & Kasir: Dukung Server & Kasir Gabung vs Server Terpisah + Kasir xx vs Hanya Kasir
    if (cat == TemplateCategory.maintServer) {
      if (widget.isOnlyKasir) {
        final kCount = widget.kasirCount ?? (count > 0 ? count : 1);
        for (int k = 1; k <= kCount; k++) {
          list.addAll(_buildKasirPoints(k, kasirNumber: k));
        }
        return list;
      }
      final isLinux = (widget.serverOs ?? 'linux').toLowerCase() == 'linux';
      if (widget.isServerKasirGabung) {
        list.addAll(_buildServerPoints('PC Server & Kasir - ', isLinux: isLinux));
        return list;
      } else {
        // Terpisah: 1 PC Server (unit index 1) + N PC Kasir (unit index 2..N)
        list.addAll(_buildServerPoints('PC Server - ', isLinux: isLinux));

        final kCount = widget.kasirCount ?? (count > 1 ? count - 1 : 1);
        for (int k = 1; k <= kCount; k++) {
          final idx = k + 1;
          list.addAll(_buildKasirPoints(idx, kasirNumber: k));
        }
        return list;
      }
    }

    String unitPrefix(int i) {
      switch (cat) {
        case TemplateCategory.maintBarrier:
          return 'Barrier Gate $i';
        case TemplateCategory.maintManless:
          return 'Manless $i';
        case TemplateCategory.maintPos:
          return 'Pos $i';
        default:
          return 'Unit $i';
      }
    }

    // Jika template memiliki master sopPoints (dari TemplateRepository / seed), kita duplikasi per unit
    if (widget.template.sopPoints.isNotEmpty) {
      for (final i in _effectiveUnits) {
        final pfx = '${unitPrefix(i)} - ';
        for (final sp in widget.template.sopPoints) {
          list.add(SopPoint(
            id: '${sp.id.split('_').first}_${i}_${sp.id.split('_').last}',
            label: '$pfx${sp.label}',
            deskripsi: sp.deskripsi,
            checkpoints: sp.checkpoints,
            panduanFoto: sp.panduanFoto,
            wajibFoto: sp.wajibFoto,
            contohFoto: sp.contohFoto,
          ));
        }
      }
      return list;
    }

    for (final i in _effectiveUnits) {
      final pfx = '${unitPrefix(i)} - ';
      switch (cat) {
        case TemplateCategory.maintBarrier:
          list.addAll([
            SopPoint(id: 'bar_${i}_01', label: '${pfx}Dudukan Mesin & Baut Dinabolt', deskripsi: 'Cek kekencangan baut baseplate beton pulau'),
            SopPoint(id: 'bar_${i}_02', label: '${pfx}Fisik Palang Tertutup (0° Lurus)', deskripsi: 'Palang lurus horizontal 180°, baut kencang, stiker utuh'),
            SopPoint(id: 'bar_${i}_03', label: '${pfx}Fisik Palang Terbuka (90° Lancar)', deskripsi: 'Palang terbuka tegak lurus 90° dan pergerakan naik-turun lancar tanpa macet'),
            SopPoint(id: 'bar_${i}_04', label: '${pfx}Pelumasan Mekanikal (Spring/Bearing)', deskripsi: 'Per penyeimbang dan bearing sudah diberi pelumas atau grease baru'),
            SopPoint(id: 'bar_${i}_05', label: '${pfx}Sensor Loop Detector (LED Detect Aktif)', deskripsi: 'Foto lampu indikator LED modul loop menyala saat ada kendaraan'),
            SopPoint(id: 'bar_${i}_06', label: '${pfx}Jalur Coran Aspal Sensor Loop', deskripsi: 'Garis coran aspal sensor loop tertutup rata dan tidak ada kabel yang terlihat'),
            SopPoint(id: 'bar_${i}_07', label: '${pfx}Pengukuran Voltase Listrik (Avometer)', deskripsi: 'Foto avometer menunjukkan voltase normal 220V/24V'),
            SopPoint(id: 'bar_${i}_08', label: '${pfx}Casing Sensor Receiver Anti Air', deskripsi: 'Photocell rapat bebas celah masuknya air hujan'),
            SopPoint(id: 'bar_${i}_09', label: '${pfx}Tiang CCTV & Speed Bump Gate', deskripsi: 'Tiang CCTV kokoh & karet speed bump terpasang dinabolt kuat, tidak ada yang terlepas'),
          ]);
          break;

        case TemplateCategory.maintManless:
          list.addAll([
            SopPoint(id: 'man_${i}_01', label: '${pfx}Pembersihan Total Printer Tiket', deskripsi: 'Head thermal bersih, roller karet bersih, ruang tempat kertas bersih'),
            SopPoint(id: 'man_${i}_02', label: '${pfx}Kebersihan Dalam Manless & Kerapihan Kabel Dalam Manless', deskripsi: 'Ruang dalam bersih, kabel rapi, adaptor terpasang kencang'),
            SopPoint(id: 'man_${i}_03', label: '${pfx}Fungsi Tombol Struk & Tiket Keluar', deskripsi: 'Fungsi tombol tiket normal dan struk karcis tercetak keluar dengan baik'),
            SopPoint(id: 'man_${i}_04', label: '${pfx}Sensor Loop Kendaraan (Layar/LED Aktif)', deskripsi: 'Layar LCD menampilkan instruksi ambil tiket atau LED loop aktif'),
            SopPoint(id: 'man_${i}_05', label: '${pfx}Kebersihan Luar Manless & Stiker Panduan', deskripsi: 'Body luar bersih, cat mulus, stiker panduan jelas'),
            SopPoint(id: 'man_${i}_06', label: '${pfx}Dudukan Bawah Manless ke Pulau', deskripsi: 'Kaki dudukan bawah kokoh tidak goyang'),
            SopPoint(id: 'man_${i}_07', label: '${pfx}Kondisi Fisik Beton Pulau Gate', deskripsi: 'Bebas ceceran oli, cat pulau rapi'),
            SopPoint(id: 'man_${i}_08', label: '${pfx}Kunci Manless & Gembok', deskripsi: 'Kunci pintu manless dan gembok berfungsi normal, tidak berkarat, dan tidak rusak'),
          ]);
          break;

        case TemplateCategory.maintPos:
          list.addAll([
            SopPoint(id: 'pos_${i}_01', label: '${pfx}Pembersihan Total Printer Pos', deskripsi: 'Head printer bersih, roller karet bersih, dan serbuk robekan kertas dibersihkan'),
            SopPoint(id: 'pos_${i}_02', label: '${pfx}Kerapian Jalur Kabel Stopkontak', deskripsi: 'Kabel terikat rapi menggunakan Spiral Flexibel/kabel ties, colokan adaptor kencang'),
            SopPoint(id: 'pos_${i}_03', label: '${pfx}Standarisasi Item dalam Pos', deskripsi: 'Monitor, Keyboard, Mouse, Scanner, Kipas Angin meja tertata rapi tanpa barang pribadi'),
            SopPoint(id: 'pos_${i}_04', label: '${pfx}Fungsi Sistem Aplikasi Kasir', deskripsi: 'Foto layar aplikasi kasir status ready online, tanpa cashbox'),
            SopPoint(id: 'pos_${i}_05', label: '${pfx}Kunci Pintu Pos (Grendel Pintu)', deskripsi: 'Grendel pintu pos terpasang dengan baik dan berfungsi normal'),
            SopPoint(id: 'pos_${i}_06', label: '${pfx}Stiker Logo BSS Parking — Sisi Depan', deskripsi: 'Stiker body depan hanya tampil logo BSS Parking (hanya 1 stiker, bukan stiker kuning Parkways)'),
            SopPoint(id: 'pos_${i}_07', label: '${pfx}Stiker BSS Parking & Parkways — Sisi Kiri', deskripsi: 'Stiker body kiri (BSS Parking putih & Parkways P kuning) rapih'),
            SopPoint(id: 'pos_${i}_08', label: '${pfx}Stiker BSS Parking & Parkways — Sisi Kanan', deskripsi: 'Stiker body kanan (BSS Parking putih & Parkways P kuning) rapih'),
            SopPoint(id: 'pos_${i}_09', label: '${pfx}Kondisi Pulau Parkir', deskripsi: 'Warna cat kuning-hitam rapi, tidak retak, dan tidak ada kabel yang terlihat'),
          ]);
          break;

        default:
          list.add(SopPoint(id: 'pt_${i}_1', label: '${pfx}Pemeriksaan standar'));
      }
    }
    return list;
  }

  List<SopPoint> _buildServerPoints(String pfx, {required bool isLinux}) {
    if (isLinux) {
      return [
        SopPoint(
          id: 'srv_1_01',
          label: '${pfx}Pembersihan Storage & File Temp',
          deskripsi: 'Foto layar terminal df -h sisa >20GB & /tmp bersih',
          checkpoints: const [
            'Cek kapasitas partisi root via terminal: df -h / (Avail > 20GB atau Use% < 80%)',
            'Pembersihan cache & file temp: rm -rf /tmp/* atau journalctl --vacuum-time=7d',
          ],
          panduanFoto: 'Foto layar monitor terminal menampilkan hasil perintah df -h.',
        ),
        SopPoint(
          id: 'srv_1_02',
          label: '${pfx}Nonaktifkan Update, Antivirus & Firewall',
          deskripsi: 'Foto terminal ufw status (inactive) atau firewalld dead & update nonaktif',
          checkpoints: const [
            'Firewall nonaktif di jaringan lokal: sudo ufw status (Status: inactive) atau systemctl status firewalld (inactive)',
            'Auto-update nonaktif: service unattended-upgrades dalam status inactive',
          ],
          panduanFoto: 'Foto layar monitor terminal menampilkan status firewall inactive.',
        ),
        SopPoint(
          id: 'srv_1_03',
          label: '${pfx}Fungsi Keyboard & Mouse (Input Console Test)',
          deskripsi: 'Foto teks prompt shell terminal atau nano: TEST 1234567890 BSS OK',
          checkpoints: const [
            'Ketik teks tes di prompt terminal atau nano: TEST 1234567890 BSS OK',
            'Input keyboard dan navigasi kursor merespons lancar di console layar monitor',
          ],
          panduanFoto: 'Foto layar monitor terminal menampilkan teks tes yang diketik.',
        ),
        SopPoint(
          id: 'srv_1_04',
          label: '${pfx}Pembersihan Debu CPU & Pasta Processor',
          deskripsi: 'Pasta pendingin prosesor baru sudah dioleskan (tidak kering) dan kipas CPU bersih dari debu',
          checkpoints: const [
            'Buka penutup casing CPU komputer',
            'Kipas, motherboard, dan power supply bersih dari debu',
            'Pasta pendingin prosesor baru dioleskan di atas heatsink (tidak kering)',
          ],
          panduanFoto: 'Foto bagian dalam casing CPU memperlihatkan kebersihan motherboard & pasta processor.',
        ),
        SopPoint(
          id: 'srv_1_05',
          label: '${pfx}Port USB & Kerapian Kabel Belakang CPU',
          deskripsi: 'Kabel terikat cable ties/Spiral Flexibel, port USB scanner terhubung kencang',
          checkpoints: const [
            'Jalur kabel belakang CPU (power, LAN, VGA/HDMI) terikat rapi',
            'Perangkat USB (scanner, tap reader) terhubung kencang di port USB',
          ],
          panduanFoto: 'Foto panel belakang CPU memperlihatkan kerapian ikatan kabel & port USB.',
        ),
        SopPoint(
          id: 'srv_1_06',
          label: '${pfx}Koneksi Jaringan Server Bebas RTO',
          deskripsi: 'Foto layar terminal ping antar server/pos/gateway 0% loss tanpa RTO',
          checkpoints: const [
            'Jalankan ping di terminal: ping [IP Gateway/Pos] -c 50 atau ping -t',
            'Hasil ping stabil (time < 5ms) dan Loss = 0% tanpa RTO',
          ],
          panduanFoto: 'Foto layar monitor terminal yang menampilkan hasil ping lancar 0% loss.',
        ),
      ];
    } else {
      return [
        SopPoint(
          id: 'srv_1_01',
          label: '${pfx}Pembersihan Storage & File Temp',
          deskripsi: 'Foto layar Windows Explorer Drive C: >20GB & folder temp kosong',
          checkpoints: const [
            'Sisa kapasitas Drive C: aman (indikator biru, >20 GB)',
            'Folder temp dan %temp% sudah dikosongkan/dihapus',
          ],
          panduanFoto: 'Foto layar monitor Windows Explorer memperlihatkan kapasitas Drive C: dan folder temp.',
        ),
        SopPoint(
          id: 'srv_1_02',
          label: '${pfx}Matikan Windows Update, Antivirus & Firewall',
          deskripsi: 'Bukti foto ke-3 tab/jendela: Windows Update, Antivirus & Firewall status OFF',
          checkpoints: const [
            'Windows Update dalam status Paused / Disabled',
            'Windows Security Real-time Protection status OFF',
            'Windows Defender Firewall status OFF (wajib ketiga tab terbukti mati)',
          ],
          panduanFoto: 'Foto layar monitor memperlihatkan ke-3 jendela: Windows Update, Antivirus, dan Firewall status OFF.',
        ),
        SopPoint(
          id: 'srv_1_03',
          label: '${pfx}Fungsi Keyboard & Mouse (KeyTest / Notepad)',
          deskripsi: 'Test di keytest.com (semua tuts putih aktif) atau Notepad lengkap huruf angka F1-F12',
          checkpoints: const [
            'Opsi A: Buka keytest.com di browser, uji tuts keyboard hingga layar putih & tombol aktif',
            'Opsi B: Buka Notepad, ketikkan: 1234567890qwertyuiopasdfghjklzxcvbnm serta fungsi F1-F12',
            'Kursor pointer mouse terlihat aktif di layar monitor',
          ],
          panduanFoto: 'Foto layar monitor hasil keytest.com (tuts aktif) atau Notepad tes ketikan lengkap & kursor.',
        ),
        SopPoint(
          id: 'srv_1_04',
          label: '${pfx}Pembersihan Debu CPU & Pasta Processor',
          deskripsi: 'Pasta pendingin prosesor baru sudah dioleskan (tidak kering) dan kipas CPU bersih dari debu',
          checkpoints: const [
            'Buka penutup casing CPU komputer',
            'Kipas, motherboard, dan power supply bersih dari debu',
            'Pasta pendingin prosesor baru dioleskan di atas heatsink (tidak kering)',
          ],
          panduanFoto: 'Foto bagian dalam casing CPU memperlihatkan kebersihan motherboard & pasta processor.',
        ),
        SopPoint(
          id: 'srv_1_05',
          label: '${pfx}Port USB & Kerapian Kabel Belakang CPU',
          deskripsi: 'Kabel terikat cable ties/Spiral Flexibel, port USB scanner terhubung kencang',
          checkpoints: const [
            'Jalur kabel belakang CPU (power, LAN, VGA/HDMI) terikat rapi',
            'Perangkat USB (scanner, tap reader) terhubung kencang di port USB',
          ],
          panduanFoto: 'Foto panel belakang CPU memperlihatkan kerapian ikatan kabel & port USB.',
        ),
        SopPoint(
          id: 'srv_1_06',
          label: '${pfx}Koneksi Jaringan Server Bebas RTO',
          deskripsi: 'Foto layar CMD ping antar server/gateway 0% loss tanpa RTO',
          checkpoints: const [
            'Jalankan Command Prompt (CMD): ping [IP Server/Gateway] -t',
            'Hasil ping stabil (time < 5ms) dan Loss = 0% tanpa RTO',
          ],
          panduanFoto: 'Foto layar monitor CMD yang menampilkan hasil ping lancar 0% loss.',
        ),
      ];
    }
  }

  List<SopPoint> _buildKasirPoints(int idx, {int? kasirNumber}) {
    final kNum = kasirNumber ?? (idx - 1);
    final pfxKasir = 'PC Kasir $kNum - ';
    return [
      SopPoint(
        id: 'srv_${idx}_01',
        label: '${pfxKasir}Pembersihan Storage & File Temp',
        deskripsi: 'Foto layar Windows Explorer Drive C: >20GB & folder temp kosong',
        checkpoints: const [
          'Sisa kapasitas Drive C: aman (indikator biru, >20 GB)',
          'Folder temp dan %temp% sudah dikosongkan/dihapus',
        ],
        panduanFoto: 'Foto layar monitor Windows Explorer kasir memperlihatkan kapasitas Drive C: dan folder temp.',
      ),
      SopPoint(
        id: 'srv_${idx}_02',
        label: '${pfxKasir}Matikan Windows Update, Antivirus & Firewall',
        deskripsi: 'Bukti foto ke-3 tab/jendela: Windows Update, Antivirus & Firewall status OFF',
        checkpoints: const [
          'Windows Update dalam status Paused / Disabled',
          'Windows Security Real-time Protection status OFF',
          'Windows Defender Firewall status OFF (wajib ketiga tab terbukti mati)',
        ],
        panduanFoto: 'Foto layar monitor kasir memperlihatkan ke-3 jendela: Windows Update, Antivirus, dan Firewall status OFF.',
      ),
      SopPoint(
        id: 'srv_${idx}_03',
        label: '${pfxKasir}Fungsi Keyboard & Mouse (KeyTest / Notepad)',
        deskripsi: 'Test di keytest.com (semua tuts putih aktif) atau Notepad lengkap huruf angka F1-F12',
        checkpoints: const [
          'Opsi A: Buka keytest.com di browser, uji tuts keyboard hingga layar putih & tombol aktif',
          'Opsi B: Buka Notepad, ketikkan: 1234567890qwertyuiopasdfghjklzxcvbnm serta fungsi F1-F12',
          'Kursor pointer mouse terlihat aktif di layar monitor',
        ],
        panduanFoto: 'Foto layar monitor kasir hasil keytest.com atau Notepad tes ketikan lengkap & kursor.',
      ),
      SopPoint(
        id: 'srv_${idx}_04',
        label: '${pfxKasir}Pembersihan Debu CPU & Pasta Processor',
        deskripsi: 'Kebersihan motherboard CPU kasir dan kipas bebas debu',
        checkpoints: const [
          'Buka penutup casing CPU komputer kasir',
          'Kipas, motherboard, dan power supply bersih dari debu',
          'Pasta pendingin prosesor baru dioleskan jika kering',
        ],
        panduanFoto: 'Foto bagian dalam CPU kasir memperlihatkan kebersihan motherboard.',
      ),
      SopPoint(
        id: 'srv_${idx}_05',
        label: '${pfxKasir}Port USB & Kerapian Kabel Belakang CPU',
        deskripsi: 'Port USB printer/scanner kasir terpasang kencang & kabel rapi',
        checkpoints: const [
          'Kabel printer, scanner, LAN, dan power kasir terikat rapi',
          'Konektor USB perangkat kasir terhubung kencang tanpa longgar',
        ],
        panduanFoto: 'Foto panel belakang CPU kasir memperlihatkan kerapian ikatan kabel & port USB.',
      ),
      SopPoint(
        id: 'srv_${idx}_06',
        label: '${pfxKasir}Koneksi Jaringan Kasir ke Server Online',
        deskripsi: 'Koneksi komputer kasir ke database server lancar tanpa RTO',
        checkpoints: const [
          'Jalankan CMD di kasir: ping [IP Server] -t',
          'Hasil ping stabil (time < 5ms) dan Loss = 0% tanpa RTO',
        ],
        panduanFoto: 'Foto layar monitor CMD kasir menampilkan koneksi ke IP server lancar 0% loss.',
      ),
    ];
  }

  Future<void> _save() async {
    final list = StorageService.getMaintenanceSubmissions() ?? [];
    final idx = list.indexWhere((e) => e.id == _submission.id);
    if (idx >= 0) {
      list[idx] = _submission;
    } else {
      list.insert(0, _submission);
    }
    await StorageService.saveMaintenanceSubmissions(list);
  }

  Future<void> _openCameraForPoint(SopPoint point) async {
    final result = await Navigator.of(context).push<MaintenancePointResult>(
      MaterialPageRoute(
        builder: (_) =>
            PointCameraView(
              point: point,
              template: widget.template,
              location: _effectiveLocation,
            ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        final idx =
            _submission.points.indexWhere((p) => p.pointId == point.id || p.pointId == result.pointId);
        if (idx >= 0) {
          _submission.points[idx] = result;
        } else {
          // Fallback matching by exact label (aman untuk multi-unit, tidak menimpa unit lain)
          final altIdx = _submission.points.indexWhere(
              (p) => (p.label == point.label || p.label == result.label) && p.label.isNotEmpty);
          if (altIdx >= 0) {
            _submission.points[altIdx] = result;
          }
        }
        _submission = MaintenanceSubmission(
          id: _submission.id,
          templateId: _submission.templateId,
          templateName: _submission.templateName,
          userId: _submission.userId,
          userName: _submission.userName,
          userNpp: _submission.userNpp,
          posId: _submission.posId,
          posName: _submission.posName,
          cabangName: _submission.cabangName,
          points: List.from(_submission.points),
          createdAt: _submission.createdAt,
          updatedAt: DateTime.now(),
        );
      });
      await _save();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('${point.label} -> ${result.status.label}: ${result.alasan}'),
            backgroundColor: result.status == PointStatus.sesuai
                ? AppColors.success
                : AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showPointAction(SopPoint point, MaintenancePointResult result) {
    final isDark = ThemeService.isDarkMode(context);
    final sheetBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final textTitle = isDark ? const Color(0xFFF8FAFC) : AppColors.textPrimary;
    final textSub = isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary;
    final cardBorder = isDark ? const Color(0xFF334155) : AppColors.cardBorder;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: sheetBg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        Color statusBg;
        Color statusBorder;
        Color statusColor;
        IconData statusIcon;
        if (result.status == PointStatus.sesuai) {
          statusBg = isDark ? const Color(0xFF064E3B).withValues(alpha: 0.35) : AppColors.success.withValues(alpha: 0.08);
          statusBorder = isDark ? const Color(0xFF059669) : AppColors.success.withValues(alpha: 0.3);
          statusColor = isDark ? const Color(0xFF6EE7B7) : AppColors.success;
          statusIcon = Icons.check_circle_rounded;
        } else if (result.status == PointStatus.tidakSesuai) {
          statusBg = isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.35) : AppColors.danger.withValues(alpha: 0.08);
          statusBorder = isDark ? const Color(0xFFDC2626) : AppColors.danger.withValues(alpha: 0.3);
          statusColor = isDark ? const Color(0xFFFCA5A5) : AppColors.danger;
          statusIcon = Icons.cancel_rounded;
        } else {
          // Perlu Cek Manual / Belum Foto (Amber / Kuning)
          statusBg = isDark ? const Color(0xFF78350F).withValues(alpha: 0.35) : Colors.amber.withValues(alpha: 0.12);
          statusBorder = isDark ? const Color(0xFFD97706) : Colors.amber.withValues(alpha: 0.4);
          statusColor = isDark ? const Color(0xFFFDE68A) : Colors.amber.shade900;
          statusIcon = Icons.info_rounded;
        }

        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Modal
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: isDark ? 0.25 : 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.checklist_rtl_rounded,
                          color: isDark ? const Color(0xFF38BDF8) : AppColors.primary, size: 22),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            point.label,
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: textTitle,
                            ),
                          ),
                          if (point.deskripsi.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              point.deskripsi,
                              style: TextStyle(
                                  fontSize: 11, color: textSub),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Status Poin Saat Ini (Ditampilkan Langsung di Atas Header Modal)
                Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: statusBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            statusIcon,
                            size: 18,
                            color: statusColor,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Status: ${result.status.label}',
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: statusColor,
                              ),
                            ),
                          ),
                          if (result.isDone && result.confidence > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: cardBorder),
                              ),
                              child: Text(
                                'Akurasi ${(result.confidence * 100).toInt()}%',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: textSub,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (result.alasan.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          result.alasan,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? const Color(0xFFF1F5F9) : AppColors.textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Checklist Item Panduan
                if (point.checkpoints.isNotEmpty) ...[
                  Text(
                    'CHECKPOINT WAJIB DIPERIKSA:',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isDark ? const Color(0xFF38BDF8) : AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: cardBorder),
                    ),
                    child: Column(
                      children: point.checkpoints
                          .map(
                            (cp) => Padding(
                              padding: const EdgeInsets.only(bottom: 5),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.check_circle_outline,
                                      size: 14, color: isDark ? const Color(0xFF6EE7B7) : AppColors.success),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      cp,
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: isDark ? const Color(0xFFE2E8F0) : AppColors.textPrimary),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Panduan Sudut Foto
                if (point.panduanFoto.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.3) : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDark ? const Color(0xFF2563EB).withValues(alpha: 0.5) : Colors.blue.shade100),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.camera_alt_outlined,
                            size: 16, color: isDark ? const Color(0xFF60A5FA) : Colors.blue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Panduan Foto: ${point.panduanFoto}',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: isDark ? const Color(0xFFDBEAFE) : Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                const SizedBox(height: 12),

                // Banner Edukasi & Actionable Loop jika Poin Tidak Sesuai / Perlu Cek
                if (result.status == PointStatus.tidakSesuai || result.status == PointStatus.perluCekManual) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF78350F).withValues(alpha: 0.25) : const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isDark ? const Color(0xFFD97706) : const Color(0xFFF59E0B)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.tips_and_updates_rounded, size: 16, color: Color(0xFFD97706)),
                            const SizedBox(width: 6),
                            Text(
                              'PANDUAN TINDAKAN PERBAIKAN',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '• Rapikan atau bersihkan temuan di atas, lalu tekan Foto Ulang agar AI memvalidasi menjadi Sesuai (Hijau).\n'
                          '• Jika kerusakan fisik permanen (stiker kusam, beton retak, butuh part kantor), tekan tombol "Tandai Kendala Fisik" di bawah agar terlapor resmi ke SPV.',
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.4,
                            color: isDark ? const Color(0xFFFEF3C7) : const Color(0xFF78350F),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Tampilan status kendala fisik jika sudah ditandai sebelumnya
                if (result.kendalaFisik != null && result.kendalaFisik!.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.handyman_rounded, color: Colors.orange, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Kendala Fisik Terlapor: ${result.kendalaFisik}',
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.orange),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Tombol Buka Kamera / Foto Ulang
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _openCameraForPoint(point);
                    },
                    icon: const Icon(Icons.camera_alt_rounded, size: 18),
                    label: Text(
                      result.status == PointStatus.belumFoto
                          ? 'Buka Kamera & Verifikasi AI'
                          : (result.status == PointStatus.tidakSesuai || result.status == PointStatus.perluCekManual
                              ? 'Foto Ulang (Perbaiki Jadi Hijau)'
                              : 'Foto Ulang & Verifikasi AI'),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: (result.status == PointStatus.tidakSesuai || result.status == PointStatus.perluCekManual)
                          ? const Color(0xFF059669) // Emerald Green untuk memotivasi teknisi memperbaiki
                          : AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Tombol Tandai Kendala Fisik / Butuh SPV (Hanya muncul jika tidak sesuai / cek manual / sudah ada kendala)
                if (result.status == PointStatus.tidakSesuai ||
                    result.status == PointStatus.perluCekManual ||
                    (result.kendalaFisik != null && result.kendalaFisik!.isNotEmpty)) ...[
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showDisposisiKendalaDialog(point, result);
                      },
                      icon: const Icon(Icons.handyman_rounded, size: 18),
                      label: Text(
                        (result.kendalaFisik != null && result.kendalaFisik!.isNotEmpty)
                            ? 'Ubah Kendala Fisik / Butuh SPV'
                            : 'Tandai Kendala Fisik / Butuh SPV',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange.shade800,
                        side: BorderSide(color: Colors.orange.withValues(alpha: 0.6), width: 1.2),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                // Tombol Tambah / Edit Catatan Temuan Lapangan
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      final noteController = TextEditingController(text: result.alasan);
                      showDialog(
                        context: context,
                        builder: (dlgCtx) => AlertDialog(
                          backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: cardBorder)),
                          title: Text(
                            'Catatan Poin: ${point.label}',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textTitle),
                          ),
                          content: TextField(
                            controller: noteController,
                            maxLines: 3,
                            style: TextStyle(fontSize: 12.5, color: isDark ? Colors.white : AppColors.textPrimary),
                            decoration: InputDecoration(
                              hintText: 'Misal: Palang bengkok tersenggol truk, stiker diganti baru, dll.',
                              hintStyle: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF64748B) : Colors.grey),
                              filled: true,
                              fillColor: isDark ? const Color(0xFF1E293B) : Colors.grey.shade50,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: cardBorder)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: cardBorder)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary)),
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dlgCtx),
                              child: Text('Batal', style: TextStyle(color: textSub)),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () {
                                final updated = result.copyWith(alasan: noteController.text.trim());
                                final idx = _submission.points.indexWhere((p) => p.pointId == point.id);
                                if (idx >= 0) {
                                  setState(() {
                                    _submission.points[idx] = updated;
                                  });
                                  _save();
                                }
                                Navigator.pop(dlgCtx);
                                Navigator.pop(ctx);
                              },
                              child: const Text('Simpan Catatan'),
                            ),
                          ],
                        ),
                      );
                    },
                    icon: const Icon(Icons.edit_note_rounded, size: 18),
                    label: Text(result.alasan.isEmpty ? 'Tambah Catatan Temuan' : 'Edit Catatan Temuan'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark ? const Color(0xFF38BDF8) : AppColors.primary,
                      side: BorderSide(color: isDark ? const Color(0xFF0284C7) : AppColors.primaryLight),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: textSub,
                      side: BorderSide(color: cardBorder),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Tutup'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDisposisiKendalaDialog(SopPoint point, MaintenancePointResult result) {
    final isDark = ThemeService.isDarkMode(context);
    final cardBorder = isDark ? const Color(0xFF334155) : AppColors.cardBorder;
    final textTitle = isDark ? const Color(0xFFF8FAFC) : AppColors.textPrimary;
    final textSub = isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary;

    final quickReasons = [
      'Butuh Pengadaan Stiker / Akrilik Baru',
      'Kerusakan Fisik / Cor Pulau Retak (Butuh Sipil)',
      'Sparepart / Komponen Rusak (Butuh Part Kantor)',
      'Karat / Korosi Permanen (Butuh Cat / Semprot Karat)',
      'Kabel / Pipa Tertanam Rusak (Butuh Rekondisi)',
      'Lainnya (Tuliskan Keterangan Khusus)',
    ];

    String selectedReason = quickReasons.first;
    final customCtrl = TextEditingController(
      text: (result.kendalaFisik != null && !quickReasons.contains(result.kendalaFisik))
          ? result.kendalaFisik
          : '',
    );
    if (result.kendalaFisik != null && quickReasons.contains(result.kendalaFisik)) {
      selectedReason = result.kendalaFisik!;
    } else if (result.kendalaFisik != null && result.kendalaFisik!.isNotEmpty) {
      selectedReason = quickReasons.last;
    }

    showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: cardBorder),
          ),
          title: Row(
            children: [
              const Icon(Icons.handyman_rounded, color: Colors.orange, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tandai Kendala Fisik',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textTitle),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Gunakan opsi ini jika poin maintenance belum bisa dibuat hijau karena kerusakan fisik permanen atau membutuhkan pengadaan baru/part dari kantor.',
                  style: TextStyle(fontSize: 11, color: textSub, height: 1.3),
                ),
                const SizedBox(height: 12),
                Text(
                  'PILIH JENIS KENDALA:',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: isDark ? const Color(0xFF38BDF8) : AppColors.primary),
                ),
                const SizedBox(height: 6),
                ...quickReasons.map((reason) {
                  final isSelected = selectedReason == reason;
                  return InkWell(
                    onTap: () {
                      setDlgState(() {
                        selectedReason = reason;
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.orange.withValues(alpha: isDark ? 0.25 : 0.12)
                            : (isDark ? const Color(0xFF1E293B) : Colors.grey.shade50),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? Colors.orange : cardBorder,
                          width: isSelected ? 1.5 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                            size: 16,
                            color: isSelected ? Colors.orange : textSub,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              reason,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected
                                    ? (isDark ? Colors.white : Colors.black87)
                                    : (isDark ? const Color(0xFFCBD5E1) : Colors.black87),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                if (selectedReason == quickReasons.last) ...[
                  const SizedBox(height: 6),
                  TextField(
                    controller: customCtrl,
                    maxLines: 2,
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white : AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Tuliskan rincian kendala...',
                      hintStyle: TextStyle(fontSize: 11.5, color: textSub),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: cardBorder)),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (result.kendalaFisik != null && result.kendalaFisik!.isNotEmpty) {
                  final updated = result.copyWith(kendalaFisik: '');
                  final idx = _submission.points.indexWhere((p) => p.pointId == point.id);
                  if (idx >= 0) {
                    setState(() {
                      _submission.points[idx] = updated;
                    });
                    _save();
                  }
                }
                Navigator.pop(dlgCtx);
              },
              child: Text(
                (result.kendalaFisik != null && result.kendalaFisik!.isNotEmpty)
                    ? 'Hapus Kendala'
                    : 'Batal',
                style: TextStyle(color: (result.kendalaFisik != null && result.kendalaFisik!.isNotEmpty) ? AppColors.danger : textSub),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                final finalReason = (selectedReason == quickReasons.last)
                    ? (customCtrl.text.trim().isNotEmpty ? customCtrl.text.trim() : 'Kendala Fisik Belum Dirinci')
                    : selectedReason;

                final updated = result.copyWith(kendalaFisik: finalReason);
                final idx = _submission.points.indexWhere((p) => p.pointId == point.id);
                if (idx >= 0) {
                  setState(() {
                    _submission.points[idx] = updated;
                  });
                  _save();
                }
                Navigator.pop(dlgCtx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Kendala fisik ditandai: $finalReason'),
                    backgroundColor: Colors.orange.shade800,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: const Text('Simpan Kendala'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterUnitChip(String unitKey, String label, int count) {
    final isDark = ThemeService.isDarkMode(context);
    final isSelected = _selectedUnitFilter == unitKey;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text('$label ($count)'),
        labelStyle: TextStyle(
          fontSize: 11,
          fontFamily: 'PlusJakartaSans',
          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          color: isSelected ? Colors.white : (isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary),
        ),
        selected: isSelected,
        selectedColor: AppColors.primary,
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        side: BorderSide(
          color: isSelected ? Colors.transparent : (isDark ? const Color(0xFF334155) : AppColors.cardBorder),
          width: 1.1,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        showCheckmark: true,
        checkmarkColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        onSelected: (selected) {
          if (selected) {
            HapticFeedback.selectionClick();
            setState(() {
              _selectedUnitFilter = unitKey;
            });
          }
        },
      ),
    );
  }

  Widget _buildFilterStatusChip(String statusKey, String label, int count, Color activeColor) {
    final isDark = ThemeService.isDarkMode(context);
    final isSelected = _selectedStatusFilter == statusKey;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text('$label ($count)'),
        labelStyle: TextStyle(
          fontSize: 10.5,
          fontFamily: 'PlusJakartaSans',
          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          color: isSelected ? Colors.white : (isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary),
        ),
        selected: isSelected,
        selectedColor: activeColor,
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        side: BorderSide(
          color: isSelected ? Colors.transparent : (isDark ? const Color(0xFF334155) : AppColors.cardBorder),
          width: 1.1,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        showCheckmark: true,
        checkmarkColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        onSelected: (selected) {
          if (selected) {
            HapticFeedback.selectionClick();
            setState(() {
              _selectedStatusFilter = statusKey;
            });
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = _submission.totalPoints;
    final done = _submission.doneCount;
    final progress = _submission.progress;

    final belumCount = _submission.points.where((p) => p.status == PointStatus.belumFoto).length;
    final sesuaiCount = _submission.points.where((p) => p.status == PointStatus.sesuai).length;
    final perluCekCount = _submission.points.where((p) => p.status == PointStatus.tidakSesuai || p.status == PointStatus.perluCekManual).length;

    // Filter points based on selected unit tab and status filter
    final filteredResults = _submission.points.where((p) {
      if (_selectedUnitFilter != 'ALL') {
        final unitIdx = _selectedUnitFilter.replaceAll('UNIT_', '');
        if (!p.pointId.contains('_${unitIdx}_')) return false;
      }
      if (_selectedStatusFilter == 'BELUM') return p.status == PointStatus.belumFoto;
      if (_selectedStatusFilter == 'SESUAI') return p.status == PointStatus.sesuai;
      if (_selectedStatusFilter == 'CEK') return p.status == PointStatus.tidakSesuai || p.status == PointStatus.perluCekManual;
      return true;
    }).toList();

    final isDark = ThemeService.isDarkMode(context);
    final bgScaffold = isDark ? const Color(0xFF0B1120) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF334155) : AppColors.cardBorder;
    final textTitle = isDark ? const Color(0xFFF8FAFC) : AppColors.textPrimary;
    final textSub = isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary;

    return Scaffold(
      backgroundColor: bgScaffold,
      appBar: AppBar(
        title: Text(
          widget.template.jenis == TemplateCategory.maintServer
              ? (_isEffectiveOnlyKasir ? 'Maintenance: Kasir' : 'Maintenance: Server & Kasir')
              : widget.template.nama,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Riwayat Maintenance',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const MaintenanceHistoryScreen(),
                ),
              ).then((_) {
                if (mounted) {
                  setState(() {
                    _initSubmission();
                  });
                }
              });
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
              value: progress,
              backgroundColor: cardBorder,
              color: AppColors.accent,
              minHeight: 4),
        ),
      ),
      body: Column(
        children: [
          // Header Card
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cardBorder, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: isDark ? 0.25 : 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primary.withValues(alpha: isDark ? 0.35 : 0.15)),
                    ),
                    child: const Icon(Icons.build_rounded,
                        color: AppColors.primary, size: 20)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_submission.cabangName} • ${_submission.posName}',
                        style: TextStyle(
                            fontFamily: 'PlusJakartaSans', 
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: textTitle),
                      ),
                      const SizedBox(height: 2),
                      Builder(builder: (_) {
                        final String unitNoun;
                        if (widget.template.jenis == TemplateCategory.maintPos) {
                          unitNoun = 'Pos';
                        } else if (widget.template.jenis == TemplateCategory.maintBarrier) {
                          unitNoun = 'Gate';
                        } else if (widget.template.jenis == TemplateCategory.maintManless) {
                          unitNoun = 'Manless';
                        } else if (widget.template.jenis == TemplateCategory.maintServer) {
                          unitNoun = _isEffectiveOnlyKasir
                              ? 'PC Kasir'
                              : (widget.isServerKasirGabung ? 'Server & Kasir' : 'Perangkat');
                        } else {
                          unitNoun = 'Unit';
                        }
                        final String unitDesc = _effectiveUnits.length == 1
                            ? '$unitNoun ${_effectiveUnits.first} diperiksa'
                            : '${_effectiveUnits.length} $unitNoun ($unitNoun ${_effectiveUnits.first} - $unitNoun ${_effectiveUnits.last}) diperiksa';
                        return Text(
                          '$unitDesc • $done/$total foto selesai (${(progress * 100).toInt()}%)',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 11,
                            color: textSub,
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                        color: _submission.isAllSesuai
                            ? AppColors.success
                            : AppColors.accent,
                        borderRadius: BorderRadius.circular(10)),
                    child: Text(
                      _submission.isComplete
                          ? (_submission.isAllSesuai
                              ? 'SELESAI'
                              : 'SELESAI CEK')
                          : 'PROSES',
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'monospace',
                          letterSpacing: 0.5,
                          color: Colors.white),
                    )),
              ],
            ),
          ),

          // Filter Status Bar
          Container(
            height: 38,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildFilterStatusChip('ALL', 'Semua', total, AppColors.primary),
                _buildFilterStatusChip('BELUM', 'Belum Difoto', belumCount, const Color(0xFF64748B)),
                _buildFilterStatusChip('SESUAI', 'Sesuai', sesuaiCount, AppColors.success),
                _buildFilterStatusChip('CEK', 'Perlu Dicek', perluCekCount, AppColors.warning),
              ],
            ),
          ),

          // Filter Tab per-Unit (jika lebih dari 1 unit / perangkat)
          if (_effectiveUnits.length > 1)
            Container(
              height: 42,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  Builder(builder: (_) {
                    final String allLabel;
                    if (widget.template.jenis == TemplateCategory.maintPos) {
                      allLabel = 'Semua Pos (${_effectiveUnits.first} - ${_effectiveUnits.last})';
                    } else if (widget.template.jenis == TemplateCategory.maintBarrier) {
                      allLabel = 'Semua Gate (${_effectiveUnits.first} - ${_effectiveUnits.last})';
                    } else if (widget.template.jenis == TemplateCategory.maintManless) {
                      allLabel = 'Semua Manless (${_effectiveUnits.first} - ${_effectiveUnits.last})';
                    } else if (widget.template.jenis == TemplateCategory.maintServer) {
                      allLabel = _isEffectiveOnlyKasir
                          ? 'Semua PC Kasir'
                          : 'Semua PC Perangkat';
                    } else {
                      allLabel = 'Semua Unit';
                    }
                    return _buildFilterUnitChip('ALL', allLabel, total);
                  }),
                  if (widget.template.jenis == TemplateCategory.maintServer) ...[
                    if (_isEffectiveOnlyKasir) ...[
                      // Hanya Kasir: Unit 1..N adalah PC Kasir 1..N
                      for (int k = 1; k <= (widget.kasirCount ?? _effectiveUnits.length); k++)
                        _buildFilterUnitChip(
                          'UNIT_$k',
                          'PC Kasir $k',
                          _submission.points
                              .where((p) => p.pointId.contains('_${k}_'))
                              .length,
                        ),
                    ] else if (!widget.isServerKasirGabung) ...[
                      // Unit 1: PC Server
                      _buildFilterUnitChip(
                        'UNIT_1',
                        'PC Server',
                        _submission.points
                            .where((p) => p.pointId.contains('_1_'))
                            .length,
                      ),
                      // Unit 2+: PC Kasir
                      for (int k = 1;
                          k <=
                              (widget.kasirCount ??
                                  (_effectiveUnits.length - 1));
                          k++)
                        _buildFilterUnitChip(
                          'UNIT_${k + 1}',
                          'PC Kasir $k',
                          _submission.points
                              .where((p) => p.pointId.contains('_${k + 1}_'))
                              .length,
                        ),
                    ],
                  ] else ...[
                    for (final i in _effectiveUnits)
                      Builder(builder: (_) {
                        final String unitLabel;
                        if (widget.template.jenis == TemplateCategory.maintPos) {
                          unitLabel = 'Pos $i';
                        } else if (widget.template.jenis == TemplateCategory.maintBarrier) {
                          unitLabel = 'Gate $i';
                        } else if (widget.template.jenis == TemplateCategory.maintManless) {
                          unitLabel = 'Manless $i';
                        } else {
                          unitLabel = 'Unit $i';
                        }
                        return _buildFilterUnitChip(
                          'UNIT_$i',
                          unitLabel,
                          _submission.points
                              .where((p) => p.pointId.contains('_${i}_'))
                              .length,
                        );
                      }),
                  ],
                ],
              ),
            ),

          // List Poin Checklist
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: filteredResults.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final result = filteredResults[i];
                // Ambil info lengkap SopPoint dari cache list
                final point = _cachedSopPoints.firstWhere(
                  (p) => p.id == result.pointId,
                  orElse: () => widget.template.sopPoints.firstWhere(
                    (p) => p.id == result.pointId || p.label == result.label,
                    orElse: () => SopPoint(id: result.pointId, label: result.label),
                  ),
                );

                final isDone = result.status != PointStatus.belumFoto;
                IconData icon;
                Color col;
                switch (result.status) {
                  case PointStatus.sesuai:
                    icon = Icons.check_circle_rounded;
                    col = AppColors.success;
                    break;
                  case PointStatus.tidakSesuai:
                    icon = Icons.cancel_rounded;
                    col = AppColors.danger;
                    break;
                  case PointStatus.perluCekManual:
                    icon = Icons.help_rounded;
                    col = AppColors.warning;
                    break;
                  default:
                    icon = Icons.radio_button_unchecked_rounded;
                    col = AppColors.textMuted;
                }

                // Tampilan Kartu: Redup jika sudah selesai difoto
                final cardItemBg = isDark
                    ? (isDone ? const Color(0xFF162032) : const Color(0xFF1E293B))
                    : (isDone ? const Color(0xFFFBFBFB) : Colors.white);

                return Opacity(
                  opacity: isDone ? 0.82 : 1.0,
                  child: Card(
                    elevation: 0,
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4.5),
                    color: cardItemBg,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: isDone
                            ? col.withValues(alpha: 0.4)
                            : cardBorder,
                        width: isDone ? 1.2 : 1.0,
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      leading: (isDone && result.imagePath != null && File(result.imagePath!).existsSync())
                          ? GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                PhotoPreviewDialog.show(
                                  context,
                                  imagePath: result.imagePath!,
                                  title: result.label,
                                  pointResult: result,
                                );
                              },
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: AppFileImage(
                                      path: result.imagePath!,
                                      width: 44,
                                      height: 44,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: col.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Icon(icon, color: col, size: 24),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    right: -3,
                                    bottom: -3,
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        color: col,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 1.5),
                                      ),
                                      child: Icon(icon, color: Colors.white, size: 10),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: isDone ? col.withValues(alpha: 0.12) : AppColors.primary.withValues(alpha: isDark ? 0.25 : 0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                isDone ? icon : Icons.camera_alt_rounded,
                                color: isDone ? col : AppColors.primary,
                                size: 22,
                              ),
                            ),
                      title: Text(
                        result.label,
                        style: TextStyle(fontFamily: 'PlusJakartaSans', 
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDone
                              ? textSub
                              : textTitle,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (result.alasan.isNotEmpty) ...[
                            Text(
                              result.alasan,
                              style: TextStyle(
                                  fontSize: 10,
                                  color: textSub),
                            ),
                          ],
                          if (result.kendalaFisik != null && result.kendalaFisik!.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.handyman_rounded, size: 10, color: Colors.orange),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      'Kendala: ${result.kendalaFisik}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.orange,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                    color: col.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6)),
                                child: Text(
                                  result.status.label,
                                  style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: col),
                                ),
                              ),
                              if (isDone) ...[
                                const SizedBox(width: 6),
                                const Text(
                                  '• Terverifikasi AI',
                                  style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textMuted),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isDone && result.imagePath != null)
                            IconButton(
                              icon: const Icon(Icons.zoom_in_rounded, size: 22, color: Colors.blueAccent),
                              tooltip: 'Periksa & Zoom Foto',
                              onPressed: () {
                                PhotoPreviewDialog.show(
                                  context,
                                  imagePath: result.imagePath!,
                                  title: result.label,
                                  pointResult: result,
                                );
                              },
                            ),
                          IconButton(
                            icon: Icon(
                              isDone ? Icons.refresh_rounded : Icons.camera_alt_rounded,
                              color: isDone ? AppColors.textSecondary : AppColors.primary,
                              size: 20,
                            ),
                            tooltip: isDone ? 'Foto Ulang' : 'Buka Kamera',
                            onPressed: () => _openCameraForPoint(point),
                          ),
                        ],
                      ),
                      onTap: () {
                        HapticFeedback.lightImpact();
                        if (!isDone) {
                          _openCameraForPoint(point);
                        } else {
                          _showPointAction(point, result);
                        }
                      },
                    ),
                  ),
                );
              },
            ),
          ),

          // Bottom Action Buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Card Bagikan Laporan: Hanya muncul jika seluruh checkpoint foto telah lengkap
                if (_submission.isComplete)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.cardBorder),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(Icons.share_rounded, color: AppColors.primary, size: 14),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Bagikan Laporan (${_submission.doneCount} Foto Selesai)',
                              style: const TextStyle(
                                fontFamily: 'PlusJakartaSans', 
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${_submission.doneCount}/${_submission.totalPoints} Foto Lengkap',
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.success),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  final rangeNote = _effectiveUnits.length > 1
                                      ? 'Pos ${_effectiveUnits.first} - Pos ${_effectiveUnits.last}'
                                      : 'Pos ${_effectiveUnits.first}';
                                  await _save();
                                  // Proses 1: Sinkronisasi otomatis ke Google Sheet SPV di background
                                  unawaited(GoogleSheetsService.syncMaintenanceToGoogleSheet(
                                    submission: _submission,
                                    category: widget.template.jenis,
                                    unitCount: _effectiveUnits.length,
                                  ));
                                  // Proses 2: Kirim laporan teks & foto ke WhatsApp
                                  await WhatsAppReportService.shareToWhatsApp(
                                    submission: _submission,
                                    category: widget.template.jenis,
                                    unitCount: _effectiveUnits.length,
                                    gateOutNotes: widget.template.jenis == TemplateCategory.maintPos ? rangeNote : null,
                                  );
                                  if (context.mounted) {
                                    final fotoCount = _submission.points.where((p) => p.imagePath != null && p.imagePath!.isNotEmpty).length;
                                    final msg = fotoCount > 1
                                        ? '✓ $fotoCount foto dibuka di WhatsApp. Teks laporan telah disalin ke clipboard, silakan paste di chat!'
                                        : '✓ Laporan dibuka di WhatsApp & disinkronkan ke Google Sheet SPV!';
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(msg),
                                        backgroundColor: AppColors.success,
                                        behavior: SnackBarBehavior.floating,
                                        duration: const Duration(seconds: 4),
                                      ),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.chat_rounded, color: Color(0xFF25D366), size: 16),
                                label: Text(
                                  'WhatsApp',
                                  style: TextStyle(fontFamily: 'PlusJakartaSans', 
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11.5,
                                    color: const Color(0xFF15803D),
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: const Color(0xFFDCFCE7),
                                  side: const BorderSide(color: Color(0xFF86EFAC), width: 1.2),
                                  padding: const EdgeInsets.symmetric(vertical: 11),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  final rangeNote = _effectiveUnits.length > 1
                                      ? 'Pos ${_effectiveUnits.first} - Pos ${_effectiveUnits.last}'
                                      : 'Pos ${_effectiveUnits.first}';
                                  await _save();
                                  await WhatsAppReportService.shareToTelegram(
                                    submission: _submission,
                                    category: widget.template.jenis,
                                    unitCount: _effectiveUnits.length,
                                    gateOutNotes: widget.template.jenis == TemplateCategory.maintPos ? rangeNote : null,
                                  );
                                  if (context.mounted) {
                                    final fotoCount = _submission.points.where((p) => p.imagePath != null && p.imagePath!.isNotEmpty).length;
                                    final msg = fotoCount > 1
                                        ? '✓ $fotoCount foto dibuka di Telegram. Teks laporan telah disalin ke clipboard, silakan paste di chat!'
                                        : '✓ Laporan dibuka di Telegram!';
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(msg),
                                        backgroundColor: AppColors.success,
                                        behavior: SnackBarBehavior.floating,
                                        duration: const Duration(seconds: 4),
                                      ),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.send_rounded, color: Color(0xFF0088CC), size: 16),
                                label: Text(
                                  'Telegram',
                                  style: TextStyle(fontFamily: 'PlusJakartaSans', 
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11.5,
                                    color: const Color(0xFF0E6BA8),
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: const Color(0xFFE0F2FE),
                                  side: const BorderSide(color: Color(0xFF7DD3FC), width: 1.2),
                                  padding: const EdgeInsets.symmetric(vertical: 11),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                // Tombol Simpan Laporan
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submission.isComplete
                        ? () async {
                            HapticFeedback.mediumImpact();
                            await _save();
                            unawaited(GoogleSheetsService.syncMaintenanceToGoogleSheet(
                              submission: _submission,
                              category: widget.template.jenis,
                              unitCount: _effectiveUnits.length,
                            ));

                            // Selesaikan Daily Task jika dihubungkan dengan Daily Task
                            final effectiveTaskId = widget.dailyTaskId ?? _submission.taskId;
                            if (effectiveTaskId != null && effectiveTaskId.isNotEmpty) {
                              final photoUrls = _submission.points
                                  .where((p) => p.imagePath != null && p.imagePath!.isNotEmpty)
                                  .map((p) => p.imagePath!)
                                  .toList();
                              final now = DateTime.now();
                              final timeStr =
                                  '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
                              final catatanReport =
                                  'SOP Maintenance ${_submission.templateName} selesai (${_submission.sesuaiCount}/${_submission.totalPoints} poin sesuai)';
                              
                              // Update cache lokal seketika agar status & strikethrough langsung aktif
                              await DailyTaskService.markTaskCompletedLocally(
                                taskId: effectiveTaskId,
                                jamSelesai: timeStr,
                                catatan: catatanReport,
                              );

                              unawaited(DailyTaskService.completeTask(
                                taskId: effectiveTaskId,
                                jamSelesai: timeStr,
                                catatan: catatanReport,
                                localPhotoPaths: photoUrls,
                              ));
                            }

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                  content: Text(
                                      '✓ Laporan ${_submission.templateName} tersimpan & disinkronkan ke Google Sheet SPV!'),
                                  backgroundColor: AppColors.success));
                              Navigator.pop(context, true);
                            }
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: _submission.isComplete ? AppColors.accent : AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: _submission.isComplete ? 3 : 0,
                        shadowColor: AppColors.accent.withValues(alpha: 0.4),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14))),
                    child: Text(
                      _submission.isComplete
                          ? 'Simpan & Selesaikan Laporan (${_submission.sesuaiCount}/$total Lolos)'
                          : 'Lengkapi $done/$total Foto Dulu',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'PlusJakartaSans',
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
