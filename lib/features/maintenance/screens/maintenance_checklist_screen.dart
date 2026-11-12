import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/tiket_colors.dart';
import '../../../core/widgets/tiket/tiket.dart';
import '../../../core/services/theme_service.dart';
import '../../../data/models/template_model.dart';
import '../../../data/models/maintenance_submission.dart';
import '../../../data/models/submission_model.dart';
import '../../../data/services/storage_service.dart';
import '../../../data/services/ai_vision_service.dart';
import '../../../data/services/location_service.dart';
import '../../../data/services/google_sheets_service.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/template_repository.dart';
import '../../../data/services/daily_task_service.dart';
import '../../../data/services/whatsapp_report_service.dart';
import '../../../data/services/maintenance_log_service.dart';
import '../widgets/photo_preview_dialog.dart';
import 'point_camera_view.dart';
import 'maintenance_history_screen.dart';

class MaintenanceChecklistScreen extends StatefulWidget {
  final TemplateModel template;
  final int? unitCount; // null jika dari saved submission
  final List<int>?
  unitNumbers; // nomor pos/unit spesifik, misal [1, 2, 3] atau [3, 4, 5, 6]
  final Map<int, String>?
  unitRoles; // arah gate, mis. {2: 'OUT'} -> "Barrier Gate 2 (OUT)"
  final PosLocation? location;
  final String? supportName;
  final MaintenanceSubmission? existingSubmission;
  final bool isServerKasirGabung;
  final bool isOnlyKasir;
  final int? kasirCount;
  final String? serverOs;
  final String? dailyTaskId;
  final List<int>?
  manlessUnits; // khusus Maintenance Lengkap: unit manless yang dicek
  final List<int>? posUnits; // khusus Maintenance Lengkap: unit pos yang dicek
  final bool
  includeServer; // khusus Maintenance Lengkap: ikut cek 1 PC Server (cakupan 4 area)
  final String?
  posMode; // khusus Pos Parkir & Booth: 'pos' (default) atau 'booth'
  final String
  manlessRole; // khusus Manless: 'IN' (default) | 'OUT' | 'PEP'

  const MaintenanceChecklistScreen({
    super.key,
    required this.template,
    this.unitCount,
    this.unitNumbers,
    this.unitRoles,
    this.location,
    this.supportName,
    this.existingSubmission,
    this.isServerKasirGabung = false,
    this.isOnlyKasir = false,
    this.kasirCount,
    this.serverOs,
    this.dailyTaskId,
    this.manlessUnits,
    this.posUnits,
    this.includeServer = false,
    this.posMode,
    this.manlessRole = 'IN',
  });

  static List<({String label, IconData icon, String saran})> detectAiIssues(
    String alasan,
  ) {
    final alasanLower = alasan.toLowerCase();
    final masalah = <({String label, IconData icon, String saran})>[];

    bool isMatchNegated(String fullText, Match match, String kw) {
      final before = fullText.substring(0, match.start);
      final clauseBefore = before
          .split(RegExp(r'[,;.!]|(?:\b(?:namun|tetapi|tapi)\b)'))
          .last;
      final words = clauseBefore
          .trim()
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty)
          .toList();

      for (int i = 0; i < words.length; i++) {
        final w = words[i];
        if ((w == 'tanpa' || w == 'bebas') && (words.length - (i + 1)) <= 3) {
          return true;
        }
        if (w == 'tidak' &&
            i + 1 < words.length &&
            words[i + 1] == 'ada' &&
            (words.length - (i + 2)) <= 3) {
          return true;
        }
      }

      if (kw == 'tidak ada') {
        final after = fullText.substring(match.end);
        final clauseAfter = after
            .split(RegExp(r'[,;.!]|(?:\b(?:namun|tetapi|tapi)\b)'))
            .first;
        if (RegExp(
          r'^\s*(?:[^\s,;.]+\s+){0,2}(?:karat|rusak|kerusakan|debu|kotor|kotoran|noda|sampah|berlumut|kelupas|robek|pecah|retak|patah|kendor|longgar|bocor|penyok|masalah|kendala|temuan)\b',
        ).hasMatch(clauseAfter)) {
          return true;
        }
      }
      if (kw == 'sudut' || kw == 'posisi') {
        if (RegExp(r'\b(?:di|pada|area|bagian)\s+$').hasMatch(before)) {
          return true;
        }
      }
      return false;
    }

    void deteksi(
      String kataKunci,
      String label,
      IconData icon,
      String saran,
    ) {
      for (final kw in kataKunci.split('|')) {
        for (final m in RegExp(RegExp.escape(kw)).allMatches(alasanLower)) {
          if (!isMatchNegated(alasanLower, m, kw)) {
            masalah.add((label: label, icon: icon, saran: saran));
            return;
          }
        }
      }
    }

    deteksi(
      'kelupas|robek|pecah|retak|patah|kendor|longgar|karat|bocor|rusak|penyok',
      'Ada Kerusakan Fisik',
      Icons.build_circle_outlined,
      'Foto dari dekat bagian yang rusak, lalu catat di Kendala Fisik dan tandai perlu diganti.',
    );
    deteksi(
      'tidak ada|hilang|belum terpasang|tidak lengkap|kurang lengkap|jumlah tidak sesuai',
      'Barang Tidak Lengkap',
      Icons.inventory_2_outlined,
      'Pastikan posisi barangnya, kalau memang tidak ada tandai Barang Tidak Terpasang.',
    );
    deteksi(
      'kotor|debu|serbuk|noda|berlumut|sampah',
      'Perlu Pembersihan',
      Icons.cleaning_services_outlined,
      'Bersihkan dulu bagian yang berdebu atau kotor, lalu ambil foto ulang.',
    );
    deteksi(
      'blur|fokus|buram|goyang|kabur',
      'Foto Kurang Fokus',
      Icons.error_outline_rounded,
      'Tahan HP dengan mantap dan tap layar agar fokus, lalu foto ulang.',
    );
    deteksi(
      'gelap|cahaya|redup|silau|sorot',
      'Pencahayaan Kurang',
      Icons.wb_sunny_outlined,
      'Cari pencahayaan yang cukup atau nyalakan lampu agar seluruh bagian terlihat jelas.',
    );
    deteksi(
      'jarak|jauh|dekat',
      'Jarak Terlalu Jauh',
      Icons.straighten_rounded,
      'Atur jarak foto supaya seluruh bagian masuk frame, jangan terlalu jauh atau dekat.',
    );
    deteksi(
      'posisi|sudut|miring|terpotong',
      'Sudut Belum Pas',
      Icons.crop_rotate_rounded,
      'Ambil dari sudut yang pas (depan atau atas) agar bagian penting terlihat penuh.',
    );
    return masalah;
  }

  @override
  State<MaintenanceChecklistScreen> createState() =>
      _MaintenanceChecklistScreenState();
}

class _MaintenanceChecklistScreenState
    extends State<MaintenanceChecklistScreen> {
  late MaintenanceSubmission _submission;
  late final List<SopPoint> _cachedSopPoints;
  late final List<int> _effectiveUnits;
  String _selectedUnitFilter = 'ALL'; // 'ALL', 'UNIT_1', 'UNIT_2', 'AREA_bar', dst.
  String _selectedStatusFilter = 'ALL'; // 'ALL', 'BELUM', 'SESUAI', 'CEK'

  /// Chip filter per area khusus Maintenance Lengkap, urut sesuai alur kerja.
  /// Kunci = awalan id poin (bar_1_01, man_1_01, pos_1_01, srv_1_01).
  static const Map<String, String> _lengkapAreaLabels = {
    'bar': 'Barrier Gate',
    'man': 'Manless',
    'pos': 'Pos Kasir',
    'srv': 'PC Server',
  };

  /// Prefix id poin per area di Maintenance Lengkap. Poin manless SOP OUT/PEP
  /// punya prefix sendiri (mout_/mpep_) supaya tidak bentrok dengan man_01..08.
  static const Map<String, List<String>> _lengkapAreaPrefixes = {
    'bar': ['bar'],
    'man': ['man', 'mout', 'mpep'],
    'pos': ['pos'],
    'srv': ['srv'],
  };

  static bool _isPointInArea(String pointId, String area) {
    final prefixes = _lengkapAreaPrefixes[area] ?? [area];
    return prefixes.any((pfx) => pointId.startsWith('${pfx}_'));
  }

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
        tagColor: Colors.lightBlue,
        lat: LocationService.currentPos.lat,
        lng: LocationService.currentPos.lng,
      );
    }
    return LocationService.currentPos;
  }

  /// Mode Booth Parkir di template Pos Parkir & Booth. Draft lama dibaca dari
  /// prefix pointId supaya resume/history tetap menampilkan label Booth.
  bool get _isBoothMode {
    if (widget.template.jenis != TemplateCategory.maintPos) return false;
    if (widget.posMode == 'booth') return true;
    return widget.existingSubmission?.points.any(
          (p) => p.pointId.startsWith('booth_'),
        ) ??
        false;
  }

  bool get _isEffectiveOnlyKasir {
    if (widget.isOnlyKasir) return true;
    if (widget.existingSubmission != null &&
        widget.template.jenis == TemplateCategory.maintServer) {
      return !_submission.points.any(
        (p) => p.label.toLowerCase().contains('server'),
      );
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

  /// Penanda arah gate dari setup, mis. " (OUT)". Kosong kalau teknisi tidak menandai.
  String _roleSuffix(int unit) {
    final role = widget.unitRoles?[unit]?.trim() ?? '';
    return role.isEmpty ? '' : ' ($role)';
  }

  /// Role Manless: dari setup, atau dibaca dari label submission lama supaya
  /// riwayat OUT/PEP tidak tampil sebagai IN saat dibuka ulang.
  /// Hanya label manless yang dicek — label gate barrier juga bisa "(OUT)".
  String get _manlessRole {
    if (widget.manlessRole != 'IN') return widget.manlessRole;
    for (final p
        in widget.existingSubmission?.points ??
            const <MaintenancePointResult>[]) {
      final l = p.label.toLowerCase();
      if (!l.contains('manless')) continue;
      if (l.contains('(pep)')) return 'PEP';
      if (l.contains('(out)')) return 'OUT';
    }
    return 'IN';
  }

  String get _manlessRoleSuffix =>
      _manlessRole == 'IN' ? '' : ' ($_manlessRole)';

  /// Poin manless sesuai SOP yang dipilih. [master] dipakai untuk Maintenance
  /// Lengkap, di mana template utama bukan template manless.
  List<SopPoint> _manlessPointsForRole({TemplateModel? master}) {
    final base = master != null
        ? master.sopPoints
        : (widget.template.sopPoints.isNotEmpty
              ? widget.template.sopPoints
              : (_masterAreaTemplate('tpl_maint_manless')?.sopPoints ??
                    const []));
    if (base.isEmpty) return base;
    if (_manlessRole == 'OUT') {
      return [...base, ...TemplateRepository.manlessOutExtraPoints];
    }
    if (_manlessRole == 'PEP') {
      return TemplateRepository.manlessPepPoints;
    }
    return base;
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
      if (widget.dailyTaskId != null &&
          widget.existingSubmission!.taskId == null) {
        _submission = widget.existingSubmission!.copyWith(
          taskId: widget.dailyTaskId,
        );
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
      final sameUser =
          s.userId == (user?.id ?? 'anon') || s.userName == (user?.nama ?? '');
      final samePos =
          s.posId == pos.posId || s.posName == LocationService.displayName(pos);
      return sameUser && samePos;
    }).toList();

    if (existing.isNotEmpty && widget.unitCount == null) {
      _submission = existing.first;
      if (widget.dailyTaskId != null && _submission.taskId == null) {
        _submission = _submission.copyWith(taskId: widget.dailyTaskId);
      }
    } else {
      final points = _cachedSopPoints;
      final effectiveName =
          widget.supportName ??
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
            .map((p) => MaintenancePointResult(pointId: p.id, label: p.label))
            .toList(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        taskId: widget.dailyTaskId,
      );
    }
  }

  /// Poin Maintenance Lengkap: gabung SOP tiap area dari template masing-masing
  /// (barrier + manless + pos [+ 1 PC Server]) supaya SOP tetap satu sumber.
  List<SopPoint> _generateLengkapPoints() {
    final list = <SopPoint>[];

    void addArea(
      String templateId,
      List<int> units,
      String Function(int unit) prefix,
    ) {
      if (units.isEmpty) return;
      final master = _masterAreaTemplate(templateId);
      if (master == null) return;
      for (final i in units) {
        final pfx = '${prefix(i)} - ';
        for (final sp in master.sopPoints) {
          final parts = sp.id.split('_');
          list.add(
            SopPoint(
              id: '${parts.first}_${i}_${parts.last}',
              label: '$pfx${sp.label}',
              deskripsi: sp.deskripsi,
              checkpoints: sp.checkpoints,
              panduanFoto: sp.panduanFoto,
              wajibFoto: sp.wajibFoto,
              contohFoto: sp.contohFoto,
            ),
          );
        }
      }
    }

    addArea(
      'tpl_maint_barrier',
      widget.unitNumbers ?? const [1],
      (i) => 'Barrier Gate $i${_roleSuffix(i)}',
    );
    // Manless ikut SOP yang dipilih (IN / OUT / PEP), labelnya pakai suffix
    // role supaya manager tahu unit yang dicek itu bagian mana.
    final manlessMaster = _masterAreaTemplate('tpl_maint_manless');
    final manlessPoints = _manlessPointsForRole(master: manlessMaster);
    for (final i in (widget.manlessUnits ?? const [1])) {
      final pfx = 'Manless $i$_manlessRoleSuffix - ';
      for (final sp in manlessPoints) {
        final parts = sp.id.split('_');
        list.add(
          SopPoint(
            id: '${parts.first}_${i}_${parts.last}',
            label: '$pfx${sp.label}',
            deskripsi: sp.deskripsi,
            checkpoints: sp.checkpoints,
            panduanFoto: sp.panduanFoto,
            wajibFoto: sp.wajibFoto,
            contohFoto: sp.contohFoto,
          ),
        );
      }
    }
    addArea('tpl_maint_pos', widget.posUnits ?? const [1], (i) => 'Pos $i');

    if (widget.includeServer) {
      final isLinux = (widget.serverOs ?? 'linux').toLowerCase() == 'linux';
      list.addAll(_buildServerPoints('PC Server - ', isLinux: isLinux));
    }
    return list;
  }

  /// Master template area (cache user dulu, baru default bawaan).
  TemplateModel? _masterAreaTemplate(String id) {
    for (final t in TemplateRepository.instance.templates) {
      if (t.id == id && t.sopPoints.isNotEmpty) return t;
    }
    for (final t in TemplateRepository.defaultTemplates) {
      if (t.id == id && t.sopPoints.isNotEmpty) return t;
    }
    return null;
  }

  List<SopPoint> _generatePoinPerUnit() {
    final count = widget.unitCount ?? 1;
    final cat = widget.template.jenis;
    final list = <SopPoint>[];

    // Maintenance Lengkap: gabungan beberapa area, tiap area punya jumlah unit sendiri
    if (cat == TemplateCategory.maintLengkap) {
      return _generateLengkapPoints();
    }

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
        list.addAll(
          _buildServerPoints('PC Server & Kasir - ', isLinux: isLinux),
        );
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
          return 'Barrier Gate $i${_roleSuffix(i)}';
        case TemplateCategory.maintManless:
          return 'Manless $i$_manlessRoleSuffix';
        case TemplateCategory.maintPos:
          return _isBoothMode ? 'Booth $i' : 'Pos $i';
        default:
          return 'Unit $i';
      }
    }

    // Mode Booth memakai SOP booth; mode Pos Kasir tetap SOP pos.
    final sourcePoints = (cat == TemplateCategory.maintPos && _isBoothMode)
        ? TemplateRepository.boothParkirPoints
        : (cat == TemplateCategory.maintManless
              ? _manlessPointsForRole()
              : widget.template.sopPoints);

    // Jika template memiliki master sopPoints (dari TemplateRepository / seed), kita duplikasi per unit
    if (sourcePoints.isNotEmpty) {
      for (final i in _effectiveUnits) {
        final pfx = '${unitPrefix(i)} - ';
        for (final sp in sourcePoints) {
          list.add(
            SopPoint(
              id: '${sp.id.split('_').first}_${i}_${sp.id.split('_').last}',
              label: '$pfx${sp.label}',
              deskripsi: sp.deskripsi,
              checkpoints: sp.checkpoints,
              panduanFoto: sp.panduanFoto,
              wajibFoto: sp.wajibFoto,
              contohFoto: sp.contohFoto,
            ),
          );
        }
      }
      return list;
    }

    for (final i in _effectiveUnits) {
      final pfx = '${unitPrefix(i)} - ';
      switch (cat) {
        case TemplateCategory.maintBarrier:
          list.addAll([
            SopPoint(
              id: 'bar_${i}_01',
              label: '${pfx}Dudukan Mesin & Baut Dinabolt',
              deskripsi: 'Cek kekencangan baut baseplate beton pulau',
            ),
            SopPoint(
              id: 'bar_${i}_02',
              label: '${pfx}Fisik Palang Tertutup (0° Lurus)',
              deskripsi:
                  'Palang lurus horizontal 180°, baut kencang, stiker utuh',
            ),
            SopPoint(
              id: 'bar_${i}_03',
              label: '${pfx}Fisik Palang Terbuka (90° Lancar)',
              deskripsi:
                  'Palang terbuka tegak lurus 90° dan pergerakan naik-turun lancar tanpa macet',
            ),
            SopPoint(
              id: 'bar_${i}_04',
              label: '${pfx}Pelumasan Mekanikal (Spring/Bearing)',
              deskripsi:
                  'Per penyeimbang dan bearing sudah diberi pelumas atau grease baru',
            ),
            SopPoint(
              id: 'bar_${i}_05',
              label: '${pfx}Sensor Loop Detector (LED Detect Aktif)',
              deskripsi:
                  'Foto lampu indikator LED modul loop menyala saat ada kendaraan',
            ),
            SopPoint(
              id: 'bar_${i}_06',
              label: '${pfx}Jalur Coran Aspal Sensor Loop',
              deskripsi:
                  'Garis coran aspal sensor loop tertutup rata dan tidak ada kabel yang terlihat',
            ),
            SopPoint(
              id: 'bar_${i}_07',
              label: '${pfx}Stiker Receiver Barrier Gate',
              deskripsi:
                  'Stiker receiver barrier gate terlihat jelas, utuh, dan tidak rusak',
            ),
            SopPoint(
              id: 'bar_${i}_08',
              label: '${pfx}Tiang CCTV & Housing',
              deskripsi:
                  'Tiang CCTV kokoh, housing kamera bersih, dan bracket kencang',
            ),
            SopPoint(
              id: 'bar_${i}_09',
              label: '${pfx}Speedbump Gate',
              deskripsi:
                  'Karet speed bump terpasang kuat dan tidak ada yang terlepas',
            ),
          ]);
          break;

        case TemplateCategory.maintManless:
          list.addAll([
            SopPoint(
              id: 'man_${i}_01',
              label: '${pfx}Pembersihan Total Printer Tiket',
              deskripsi:
                  'Head thermal bersih, roller karet bersih, ruang tempat kertas bersih',
            ),
            SopPoint(
              id: 'man_${i}_02',
              label:
                  '${pfx}Kebersihan Dalam Manless & Kerapihan Kabel Dalam Manless',
              deskripsi:
                  'Ruang dalam bersih, kabel rapi, adaptor terpasang kencang',
            ),
            SopPoint(
              id: 'man_${i}_03',
              label: '${pfx}Fungsi Tombol Struk & Tiket Keluar',
              deskripsi:
                  'Fungsi tombol tiket normal dan struk karcis tercetak keluar dengan baik',
            ),
            SopPoint(
              id: 'man_${i}_04',
              label: '${pfx}Sensor Loop Kendaraan (Layar/LED Aktif)',
              deskripsi:
                  'Layar LCD menampilkan instruksi ambil tiket atau LED loop aktif',
            ),
            SopPoint(
              id: 'man_${i}_05',
              label: '${pfx}Kebersihan Luar Manless & Stiker Panduan',
              deskripsi: 'Body luar bersih, cat mulus, stiker panduan jelas',
            ),
            SopPoint(
              id: 'man_${i}_06',
              label: '${pfx}Dudukan Bawah Manless ke Pulau',
              deskripsi: 'Kaki dudukan bawah kokoh tidak goyang',
            ),
            SopPoint(
              id: 'man_${i}_07',
              label: '${pfx}Kondisi Fisik Beton Pulau Gate',
              deskripsi: 'Bebas ceceran oli, cat pulau rapi',
            ),
            SopPoint(
              id: 'man_${i}_08',
              label: '${pfx}Kunci Manless & Gembok',
              deskripsi:
                  'Kunci pintu manless dan gembok berfungsi normal, tidak berkarat, dan tidak rusak',
            ),
          ]);
          break;

        case TemplateCategory.maintPos:
          list.addAll([
            SopPoint(
              id: 'pos_${i}_01',
              label: '${pfx}Pembersihan Total Printer Pos',
              deskripsi:
                  'Head printer bersih, roller karet bersih, dan serbuk robekan kertas dibersihkan',
            ),
            SopPoint(
              id: 'pos_${i}_02',
              label: '${pfx}Kerapian Jalur Kabel Stopkontak',
              deskripsi:
                  'Jalur kabel tertata rapi, tidak semrawut, dan colokan adaptor kencang',
            ),
            SopPoint(
              id: 'pos_${i}_03',
              label: '${pfx}Standarisasi Item dalam Pos',
              deskripsi:
                  'Monitor, Keyboard, Mouse, Scanner, Kipas Angin meja tertata rapi tanpa barang pribadi',
            ),
            SopPoint(
              id: 'pos_${i}_04',
              label: '${pfx}Fungsi Sistem Aplikasi Kasir',
              deskripsi:
                  'Foto layar aplikasi kasir status ready online, tanpa cashbox',
            ),
            SopPoint(
              id: 'pos_${i}_10',
              label: '${pfx}Pembersihan Kipas Angin',
              deskripsi:
                  'Baling-baling dan cover penutup kipas angin harus bersih',
            ),
            SopPoint(
              id: 'pos_${i}_05',
              label: '${pfx}Kunci Pintu Pos (Grendel Pintu)',
              deskripsi:
                  'Grendel pintu pos terpasang dengan baik dan berfungsi normal',
            ),
            SopPoint(
              id: 'pos_${i}_06',
              label: '${pfx}Stiker Logo BSS Parking - Sisi Depan',
              deskripsi:
                  'Stiker body depan hanya tampil logo BSS Parking (hanya 1 stiker, bukan stiker kuning Parkways)',
            ),
            SopPoint(
              id: 'pos_${i}_07',
              label: '${pfx}Stiker BSS Parking & Parkways - Sisi Kiri',
              deskripsi:
                  'Stiker body kiri (BSS Parking putih & Parkways P kuning) rapih',
            ),
            SopPoint(
              id: 'pos_${i}_08',
              label: '${pfx}Stiker BSS Parking & Parkways - Sisi Kanan',
              deskripsi:
                  'Stiker body kanan (BSS Parking putih & Parkways P kuning) rapih',
            ),
            SopPoint(
              id: 'pos_${i}_09',
              label: '${pfx}Kondisi Pulau Parkir',
              deskripsi:
                  'Warna cat kuning-hitam rapi, tidak retak, dan tidak ada kabel yang terlihat',
            ),
          ]);
          break;

        default:
          list.add(
            SopPoint(id: 'pt_${i}_1', label: '${pfx}Pemeriksaan standar'),
          );
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
          panduanFoto:
              'Foto layar monitor terminal menampilkan hasil perintah df -h.',
        ),
        SopPoint(
          id: 'srv_1_02',
          label: '${pfx}Nonaktifkan Update, Antivirus & Firewall',
          deskripsi:
              'Foto terminal ufw status (inactive) atau firewalld dead & update nonaktif',
          checkpoints: const [
            'Firewall nonaktif di jaringan lokal: sudo ufw status (Status: inactive) atau systemctl status firewalld (inactive)',
            'Auto-update nonaktif: service unattended-upgrades dalam status inactive',
          ],
          panduanFoto:
              'Foto layar monitor terminal menampilkan status firewall inactive.',
        ),
        SopPoint(
          id: 'srv_1_03',
          label: '${pfx}Fungsi Keyboard & Mouse (Input Console Test)',
          deskripsi:
              'Foto teks prompt shell terminal atau nano: TEST 1234567890 BSS OK',
          checkpoints: const [
            'Ketik teks tes di prompt terminal atau nano: TEST 1234567890 BSS OK',
            'Input keyboard dan navigasi kursor merespons lancar di console layar monitor',
          ],
          panduanFoto:
              'Foto layar monitor terminal menampilkan teks tes yang diketik.',
        ),
        SopPoint(
          id: 'srv_1_04',
          label: '${pfx}Pembersihan Debu CPU & Kipas Heatsink',
          deskripsi:
              'Kipas dan heatsink bersih dari debu serta motherboard bersih',
          checkpoints: const [
            'Buka penutup casing CPU komputer',
            'Kipas dan heatsink bersih dari debu',
            'Motherboard dan power supply bersih dari debu',
          ],
          panduanFoto:
              'Foto bagian dalam casing CPU memperlihatkan kipas, heatsink, dan motherboard bersih dari debu.',
        ),
        SopPoint(
          id: 'srv_1_05',
          label: '${pfx}Port USB & Kerapian Kabel Belakang CPU',
          deskripsi:
              'Kabel belakang CPU tertata rapi, tidak semrawut, port USB scanner terhubung kencang',
          checkpoints: const [
            'Jalur kabel belakang CPU (power, LAN, VGA/HDMI) tertata rapi, tidak semrawut',
            'Perangkat USB (scanner, tap reader) terhubung kencang di port USB',
          ],
          panduanFoto:
              'Foto panel belakang CPU memperlihatkan kerapian jalur kabel & port USB.',
        ),
        SopPoint(
          id: 'srv_1_06',
          label: '${pfx}Koneksi Jaringan Server Bebas RTO',
          deskripsi:
              'Foto layar terminal ping antar server/pos/gateway 0% loss tanpa RTO',
          checkpoints: const [
            'Jalankan ping di terminal: ping [IP Gateway/Pos] -c 50 atau ping -t',
            'Hasil ping stabil (time < 5ms) dan Loss = 0% tanpa RTO',
          ],
          panduanFoto:
              'Foto layar monitor terminal yang menampilkan hasil ping lancar 0% loss.',
        ),
      ];
    } else {
      return [
        SopPoint(
          id: 'srv_1_01',
          label: '${pfx}Pembersihan Storage & File Temp',
          deskripsi:
              'Foto layar Windows Explorer Drive C: >20GB & folder temp kosong',
          checkpoints: const [
            'Sisa kapasitas Drive C: aman (indikator biru, >20 GB)',
            'Folder temp dan %temp% sudah dikosongkan/dihapus',
          ],
          panduanFoto:
              'Foto layar monitor Windows Explorer memperlihatkan kapasitas Drive C: dan folder temp.',
        ),
        SopPoint(
          id: 'srv_1_02',
          label: '${pfx}Matikan Windows Update, Antivirus & Firewall',
          deskripsi:
              'Bukti jendela Windows Security, Antivirus, atau Firewall status OFF',
          checkpoints: const [
            'Windows Update dalam status Paused / Disabled',
            'Windows Security Real-time Protection status OFF atau silang merah',
            'Windows Defender Firewall status OFF / Inactive',
          ],
          panduanFoto:
              'Foto layar monitor memperlihatkan jendela Windows Security / Firewall / Update status OFF.',
        ),
        SopPoint(
          id: 'srv_1_03',
          label: '${pfx}Fungsi Keyboard & Mouse (KeyTest / Notepad)',
          deskripsi:
              'Test di keytest.com (semua tuts putih aktif) atau Notepad lengkap huruf angka F1-F12',
          checkpoints: const [
            'Opsi A: Buka keytest.com di browser, uji tuts keyboard hingga layar putih & tombol aktif',
            'Opsi B: Buka Notepad, ketikkan: 1234567890qwertyuiopasdfghjklzxcvbnm serta fungsi F1-F12',
            'Kursor pointer mouse terlihat aktif di layar monitor',
          ],
          panduanFoto:
              'Foto layar monitor hasil keytest.com (tuts aktif) atau Notepad tes ketikan lengkap & kursor.',
        ),
        SopPoint(
          id: 'srv_1_04',
          label: '${pfx}Pembersihan Debu CPU & Kipas Heatsink',
          deskripsi:
              'Kipas dan heatsink bersih dari debu serta motherboard bebas debu',
          checkpoints: const [
            'Buka penutup casing CPU komputer',
            'Kipas dan heatsink bersih dari debu',
            'Motherboard dan power supply bersih dari debu',
          ],
          panduanFoto:
              'Foto bagian dalam casing CPU memperlihatkan kipas, heatsink, dan motherboard bersih dari debu.',
        ),
        SopPoint(
          id: 'srv_1_05',
          label: '${pfx}Port USB & Kerapian Kabel Belakang CPU',
          deskripsi:
              'Kabel belakang CPU tertata rapi, tidak semrawut, port USB scanner terhubung kencang',
          checkpoints: const [
            'Jalur kabel belakang CPU (power, LAN, VGA/HDMI) tertata rapi, tidak semrawut',
            'Perangkat USB (scanner, tap reader) terhubung kencang di port USB',
          ],
          panduanFoto:
              'Foto panel belakang CPU memperlihatkan kerapian jalur kabel & port USB.',
        ),
        SopPoint(
          id: 'srv_1_06',
          label: '${pfx}Koneksi Jaringan Server Bebas RTO',
          deskripsi:
              'Foto layar CMD ping antar server/gateway 0% loss tanpa RTO',
          checkpoints: const [
            'Jalankan Command Prompt (CMD): ping [IP Server/Gateway] -t',
            'Hasil ping stabil (time < 5ms) dan Loss = 0% tanpa RTO',
          ],
          panduanFoto:
              'Foto layar monitor CMD yang menampilkan hasil ping lancar 0% loss.',
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
        deskripsi:
            'Foto layar Windows Explorer Drive C: >20GB & folder temp kosong',
        checkpoints: const [
          'Sisa kapasitas Drive C: aman (indikator biru, >20 GB)',
          'Folder temp dan %temp% sudah dikosongkan/dihapus',
        ],
        panduanFoto:
            'Foto layar monitor Windows Explorer kasir memperlihatkan kapasitas Drive C: dan folder temp.',
      ),
      SopPoint(
        id: 'srv_${idx}_02',
        label: '${pfxKasir}Matikan Windows Update, Antivirus & Firewall',
        deskripsi:
            'Bukti jendela Windows Security, Antivirus, atau Firewall status OFF',
        checkpoints: const [
          'Windows Update dalam status Paused / Disabled',
          'Windows Security Real-time Protection status OFF atau silang merah',
          'Windows Defender Firewall status OFF / Inactive',
        ],
        panduanFoto:
            'Foto layar monitor kasir memperlihatkan jendela Windows Security / Firewall / Update status OFF.',
      ),
      SopPoint(
        id: 'srv_${idx}_03',
        label: '${pfxKasir}Fungsi Keyboard & Mouse (KeyTest / Notepad)',
        deskripsi:
            'Test di keytest.com (semua tuts putih aktif) atau Notepad lengkap huruf angka F1-F12',
        checkpoints: const [
          'Opsi A: Buka keytest.com di browser, uji tuts keyboard hingga layar putih & tombol aktif',
          'Opsi B: Buka Notepad, ketikkan: 1234567890qwertyuiopasdfghjklzxcvbnm serta fungsi F1-F12',
          'Kursor pointer mouse terlihat aktif di layar monitor',
        ],
        panduanFoto:
            'Foto layar monitor kasir hasil keytest.com atau Notepad tes ketikan lengkap & kursor.',
      ),
      SopPoint(
        id: 'srv_${idx}_04',
        label: '${pfxKasir}Pembersihan Debu CPU & Kipas Heatsink',
        deskripsi: 'Kipas dan heatsink bersih dari debu serta motherboard bersih',
        checkpoints: const [
          'Buka penutup casing CPU komputer kasir',
          'Kipas dan heatsink bersih dari debu',
          'Motherboard dan power supply bersih dari debu',
        ],
        panduanFoto:
            'Foto bagian dalam CPU kasir memperlihatkan kipas, heatsink, dan motherboard bersih dari debu.',
      ),
      SopPoint(
        id: 'srv_${idx}_05',
        label: '${pfxKasir}Port USB & Kerapian Kabel Belakang CPU',
        deskripsi:
            'Port USB printer/scanner kasir terpasang kencang & jalur kabel tertata rapi, tidak semrawut',
        checkpoints: const [
          'Kabel printer, scanner, LAN, dan power kasir tertata rapi, tidak semrawut',
          'Konektor USB perangkat kasir terhubung kencang tanpa longgar',
        ],
        panduanFoto:
            'Foto panel belakang CPU kasir memperlihatkan kerapian jalur kabel & port USB.',
      ),
      SopPoint(
        id: 'srv_${idx}_06',
        label: '${pfxKasir}Koneksi Jaringan Kasir ke Server Online',
        deskripsi: 'Koneksi komputer kasir ke database server lancar tanpa RTO',
        checkpoints: const [
          'Jalankan CMD di kasir: ping [IP Server] -t',
          'Hasil ping stabil (time < 5ms) dan Loss = 0% tanpa RTO',
        ],
        panduanFoto:
            'Foto layar monitor CMD kasir menampilkan koneksi ke IP server lancar 0% loss.',
      ),
    ];
  }

  Future<void> _save() async {
    await StorageService.upsertMaintenanceSubmission(_submission);
    if (_submission.isComplete) unawaited(MaintenanceLogService.syncLocal());
  }

  /// Tawarkan bagikan laporan ke grup (WhatsApp/Telegram) setelah tersimpan.
  Future<void> _askShare(BuildContext context) {
    final colors = TiketColors.of(context);
    final units = _effectiveUnits;
    final unitWord = _submission.points.any((p) => p.pointId.startsWith('booth_')) ? 'Booth' : 'Pos';
    final gateOutNotes = widget.template.jenis == TemplateCategory.maintPos && units.isNotEmpty
        ? (units.length > 1 ? '$unitWord ${units.first} - $unitWord ${units.last}' : '$unitWord ${units.first}')
        : null;
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: colors.dialog,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) {
        Future<void> share(bool telegram) async {
          final send = telegram ? WhatsAppReportService.shareToTelegram : WhatsAppReportService.shareToWhatsApp;
          await send(submission: _submission, category: widget.template.jenis, unitCount: units.length, gateOutNotes: gateOutNotes);
          if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Laporan tersimpan', style: TextStyle(fontFamily: 'Figtree', fontSize: 18, fontWeight: FontWeight.w700, color: colors.ink)),
                const SizedBox(height: 4),
                Text('Bagikan ke grup?', style: TextStyle(fontFamily: 'Figtree', fontSize: 14, color: colors.body)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: TiketPill(label: 'WhatsApp', icon: Icons.chat_rounded, kind: TiketPillKind.secondary, expand: true, onPressed: () => share(false))),
                    const SizedBox(width: 10),
                    Expanded(child: TiketPill(label: 'Telegram', icon: Icons.send_rounded, kind: TiketPillKind.secondary, expand: true, onPressed: () => share(true))),
                  ],
                ),
                const SizedBox(height: 10),
                TiketPill(label: 'Selesai', kind: TiketPillKind.primary, expand: true, onPressed: () => Navigator.of(sheetCtx).pop()),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openCameraForPoint(SopPoint point) async {
    final result = await Navigator.of(context).push<MaintenancePointResult>(
      MaterialPageRoute(
        builder: (_) => PointCameraView(
          point: point,
          template: widget.template,
          location: _effectiveLocation,
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        final idx = _submission.points.indexWhere(
          (p) => p.pointId == point.id || p.pointId == result.pointId,
        );
        if (idx >= 0) {
          _submission.points[idx] = result;
        } else {
          // Fallback matching by exact label (aman untuk multi-unit, tidak menimpa unit lain)
          final altIdx = _submission.points.indexWhere(
            (p) =>
                (p.label == point.label || p.label == result.label) &&
                p.label.isNotEmpty,
          );
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
            content: Text(
              '${point.label} -> ${result.status.label}: ${result.alasan}',
            ),
            backgroundColor: result.status == PointStatus.sesuai
                ? AppColors.success
                : (result.status == PointStatus.tidakTerpasang
                      ? TiketColors.light.body
                      : AppColors.danger),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Card "Kondisi Item": 3 pilihan sejajar, status marker + label.
  Widget _buildKondisiItemCard({
    required TingkatUrgensi tingkat,
    required bool isActive,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final colors = TiketColors.of(context);
    final status = switch (tingkat) {
      TingkatUrgensi.ringan => TiketStatus.ok,
      TingkatUrgensi.sedang => TiketStatus.attention,
      TingkatUrgensi.urgent => TiketStatus.danger,
      _ => TiketStatus.notStarted,
    };

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 72,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isActive ? colors.primary : colors.canvas,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? colors.primary : colors.hairline,
            width: 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            StatusMarker(status: status, size: 16),
            Text(
              tingkat.label,
              style: TextStyle(
                fontFamily: TiketType.fontFamily,
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                color: isActive ? colors.onPrimary : colors.ink,
                height: 1.2,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  /// Ganti satu hasil poin di dalam submission lalu simpan (dipakai untuk
  /// update urgensi & tandai tidak terpasang).
  Future<void> _updatePointResult(
    SopPoint point,
    MaintenancePointResult result,
    MaintenancePointResult updated,
  ) async {
    final idx = _submission.points.indexWhere(
      (p) => p.pointId == point.id || p.pointId == result.pointId,
    );
    final target = idx >= 0
        ? idx
        : _submission.points.indexWhere(
            (p) =>
                (p.label == point.label || p.label == result.label) &&
                p.label.isNotEmpty,
          );
    if (target < 0) return;

    setState(() {
      _submission.points[target] = updated;
      _submission = _submission.copyWith(
        points: List.from(_submission.points),
        updatedAt: DateTime.now(),
      );
    });
    await _save();
  }

  Future<void> _setPointUrgensi(
    SopPoint point,
    MaintenancePointResult result,
    TingkatUrgensi urgensi,
  ) => _updatePointResult(point, result, result.copyWith(urgensi: urgensi));

  /// Tandai poin sebagai tidak terpasang/tidak ada di lokasi (tanpa foto).
  Future<void> _setPointTidakTerpasang(
    SopPoint point,
    MaintenancePointResult result,
  ) => _updatePointResult(
    point,
    result,
    result.copyWith(
      status: PointStatus.tidakTerpasang,
      alasan: 'Ditandai teknisi: barang tidak terpasang di lokasi.',
      urgensi: TingkatUrgensi.normal,
    ),
  );

  void _showPointAction(SopPoint point, MaintenancePointResult result) {
    final colors = TiketColors.of(context);
    final hasImage = result.imagePath != null && result.imagePath!.isNotEmpty;
    final file = hasImage ? File(result.imagePath!) : null;
    final fileExists = file != null && file.existsSync();

    final TiketChipKind chipKind = switch (result.status) {
      PointStatus.sesuai => TiketChipKind.ok,
      PointStatus.tidakSesuai => TiketChipKind.danger,
      PointStatus.perluCekManual => TiketChipKind.attention,
      _ => TiketChipKind.neutral,
    };

    final String statusLabel = switch (result.status) {
      PointStatus.sesuai => 'Sesuai',
      PointStatus.tidakSesuai => 'Tidak sesuai',
      PointStatus.perluCekManual => 'Perlu cek',
      PointStatus.tidakTerpasang => 'Tidak terpasang',
      _ => 'Belum foto',
    };

    var urgensiTerpilih = result.urgensi;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.dialog,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (bottomSheetCtx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 12,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colors.hairline,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      point.label,
                      style: TextStyle(
                        fontFamily: TiketType.fontFamily,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: colors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.template.nama} · ${_effectiveLocation.posName}',
                      style: TextStyle(
                        fontFamily: TiketType.fontFamily,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: colors.body,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: 96,
                            height: 96,
                            color: colors.soft,
                            child: fileExists
                                ? InkWell(
                                    onTap: () {
                                      PhotoPreviewDialog.show(
                                        context,
                                        imagePath: result.imagePath!,
                                        title: result.label,
                                        pointResult: result,
                                      );
                                    },
                                    child: Image.file(
                                      file,
                                      fit: BoxFit.cover,
                                      width: 96,
                                      height: 96,
                                    ),
                                  )
                                : Center(
                                    child: Icon(
                                      Icons.camera_alt_rounded,
                                      size: 32,
                                      color: colors.mute,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              StatusChip(
                                label: statusLabel,
                                kind: chipKind,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                result.alasan.isNotEmpty
                                    ? 'AI: ${result.alasan}'
                                    : (result.status == PointStatus.sesuai
                                        ? 'Hasil foto sesuai dengan standar SOP pemeliharaan.'
                                        : 'Foto perlu diperiksa kembali sebelum disetujui.'),
                                style: TextStyle(
                                  fontFamily: TiketType.fontFamily,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: colors.ink,
                                  height: 1.3,
                                ),
                              ),
                              if (point.deskripsi.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  point.deskripsi,
                                  style: TextStyle(
                                    fontFamily: TiketType.fontFamily,
                                    fontSize: 12,
                                    color: colors.body,
                                    height: 1.3,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Kondisi Item',
                      style: TextStyle(
                        fontFamily: TiketType.fontFamily,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: colors.ink,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        for (final u in [
                          TingkatUrgensi.ringan,
                          TingkatUrgensi.sedang,
                          TingkatUrgensi.urgent,
                        ]) ...[
                          if (u != TingkatUrgensi.ringan) const SizedBox(width: 8),
                          Expanded(
                            child: _buildKondisiItemCard(
                              tingkat: u,
                              isActive: urgensiTerpilih == u,
                              isDark: ThemeService.isDarkMode(context),
                              onTap: () async {
                                HapticFeedback.selectionClick();
                                final baru = urgensiTerpilih == u
                                    ? TingkatUrgensi.normal
                                    : u;
                                setSheetState(() => urgensiTerpilih = baru);
                                await _setPointUrgensi(point, result, baru);
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                    TiketDropdownField(
                      label: 'Kendala fisik',
                      value: (result.kendalaFisik != null && result.kendalaFisik!.isNotEmpty)
                          ? result.kendalaFisik!
                          : 'Kendala Fisik Belum Dirinci',
                      onTap: () {
                        _showDisposisiKendalaDialog(point, result);
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              final noteController = TextEditingController(
                                text: result.alasan,
                              );
                              showDialog(
                                context: context,
                                builder: (dlgCtx) => Dialog(
                                  backgroundColor: colors.dialog,
                                  surfaceTintColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        Text(
                                          'Catatan Poin: ${point.label}',
                                          style: TextStyle(
                                            fontFamily: TiketType.fontFamily,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: colors.ink,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        TextField(
                                          controller: noteController,
                                          maxLines: 3,
                                          style: TextStyle(
                                            fontFamily: TiketType.fontFamily,
                                            fontSize: 13,
                                            color: colors.ink,
                                          ),
                                          decoration: InputDecoration(
                                            hintText: 'Misal: Palang bengkok tersenggol truk, stiker diganti baru, dll.',
                                            hintStyle: TextStyle(
                                              fontFamily: TiketType.fontFamily,
                                              fontSize: 12,
                                              color: colors.mute,
                                            ),
                                            filled: true,
                                            fillColor: colors.soft,
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              borderSide: BorderSide(color: colors.hairline),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              borderSide: BorderSide(color: colors.hairline),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              borderSide: BorderSide(color: colors.primary, width: 1.5),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: TiketPill(
                                                label: 'Batal',
                                                kind: TiketPillKind.secondary,
                                                height: 40,
                                                expand: true,
                                                onPressed: () => Navigator.pop(dlgCtx),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: TiketPill(
                                                label: 'Simpan & keluar',
                                                kind: TiketPillKind.primary,
                                                height: 40,
                                                expand: true,
                                                onPressed: () {
                                                  final updated = result.copyWith(
                                                    alasan: noteController.text.trim(),
                                                  );
                                                  final idx = _submission.points.indexWhere(
                                                    (p) => p.pointId == point.id,
                                                  );
                                                  if (idx >= 0) {
                                                    setState(() {
                                                      _submission.points[idx] = updated;
                                                    });
                                                    _save();
                                                  }
                                                  Navigator.pop(dlgCtx);
                                                  Navigator.pop(ctx);
                                                },
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.edit_note_rounded, size: 16, color: colors.body),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Ubah Catatan',
                                    style: TextStyle(
                                      fontFamily: TiketType.fontFamily,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: colors.body,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (result.status != PointStatus.tidakTerpasang) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                HapticFeedback.selectionClick();
                                final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (dlgCtx) => Dialog(
                                    backgroundColor: colors.dialog,
                                    surfaceTintColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(20),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          Text(
                                            'Barang tidak terpasang?',
                                            style: TextStyle(
                                              fontFamily: TiketType.fontFamily,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                              color: colors.ink,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            '"${point.label}" akan ditandai TIDAK TERPASANG / tidak ada di lokasi, tanpa perlu foto.',
                                            style: TextStyle(
                                              fontFamily: TiketType.fontFamily,
                                              fontSize: 13,
                                              color: colors.body,
                                              height: 1.35,
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: TiketPill(
                                                  label: 'Batal',
                                                  kind: TiketPillKind.secondary,
                                                  height: 40,
                                                  expand: true,
                                                  onPressed: () => Navigator.pop(dlgCtx, false),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: TiketPill(
                                                  label: 'Reset semua',
                                                  kind: TiketPillKind.primary,
                                                  height: 40,
                                                  expand: true,
                                                  onPressed: () => Navigator.pop(dlgCtx, true),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                                if (ok == true && ctx.mounted) {
                                  Navigator.pop(ctx);
                                  await _setPointTidakTerpasang(point, result);
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.do_not_disturb_alt_rounded, size: 16, color: colors.body),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Tidak Terpasang',
                                      style: TextStyle(
                                        fontFamily: TiketType.fontFamily,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: colors.body,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _openCameraForPoint(point);
                        },
                        icon: const Icon(Icons.camera_alt_rounded, size: 18),
                        label: Text(
                          result.status == PointStatus.belumFoto
                              ? 'Buka Kamera'
                              : 'Foto Ulang',
                          style: const TextStyle(
                            fontFamily: TiketType.fontFamily,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.primary,
                          foregroundColor: colors.onPrimary,
                          elevation: 0,
                          shape: const StadiumBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: TextButton.styleFrom(
                          shape: const StadiumBorder(),
                          foregroundColor: colors.primary,
                        ),
                        child: const Text(
                          'Tutup',
                          style: TextStyle(
                            fontFamily: TiketType.fontFamily,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showDisposisiKendalaDialog(
    SopPoint point,
    MaintenancePointResult result,
  ) {
    final colors = TiketColors.of(context);
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
      text: (result.kendalaFisik != null &&
              !quickReasons.contains(result.kendalaFisik))
          ? result.kendalaFisik
          : '',
    );
    if (result.kendalaFisik != null &&
        quickReasons.contains(result.kendalaFisik)) {
      selectedReason = result.kendalaFisik!;
    } else if (result.kendalaFisik != null && result.kendalaFisik!.isNotEmpty) {
      selectedReason = quickReasons.last;
    }

    showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          final isExisting = result.kendalaFisik != null && result.kendalaFisik!.isNotEmpty;

          return Dialog(
            backgroundColor: colors.dialog,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Tandai Kendala Fisik',
                        style: TextStyle(
                          fontFamily: TiketType.fontFamily,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: colors.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Pilih opsi ini jika alat rusak fisik atau perlu penggantian sparepart.',
                        style: TextStyle(
                          fontFamily: TiketType.fontFamily,
                          fontSize: 13,
                          color: colors.body,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Pilih jenis kendala',
                        style: TextStyle(
                          fontFamily: TiketType.fontFamily,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: colors.ink,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...quickReasons.map((reason) {
                        final isSelected = selectedReason == reason;
                        return InkWell(
                          onTap: () {
                            setDlgState(() => selectedReason = reason);
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                            child: Row(
                              children: [
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected ? colors.primary : colors.mute,
                                      width: isSelected ? 2.0 : 1.5,
                                    ),
                                  ),
                                  child: isSelected
                                      ? Center(
                                          child: Container(
                                            width: 10,
                                            height: 10,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: colors.primary,
                                            ),
                                          ),
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    reason,
                                    style: TextStyle(
                                      fontFamily: TiketType.fontFamily,
                                      fontSize: 13,
                                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                      color: colors.ink,
                                      height: 1.25,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                      if (selectedReason == quickReasons.last) ...[
                        const SizedBox(height: 8),
                        TextField(
                          controller: customCtrl,
                          maxLines: 2,
                          style: TextStyle(
                            fontFamily: TiketType.fontFamily,
                            fontSize: 13,
                            color: colors.ink,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Tulis rincian kendala...',
                            hintStyle: TextStyle(
                              fontFamily: TiketType.fontFamily,
                              fontSize: 12,
                              color: colors.mute,
                            ),
                            filled: true,
                            fillColor: colors.soft,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: colors.hairline),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: colors.hairline),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: colors.primary, width: 1.5),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: TiketPill(
                              label: isExisting ? 'Hapus kendala' : 'Batal',
                              kind: TiketPillKind.secondary,
                              height: 40,
                              expand: true,
                              onPressed: () {
                                if (isExisting) {
                                  final updated = result.copyWith(kendalaFisik: '');
                                  final idx = _submission.points.indexWhere(
                                    (p) => p.pointId == point.id,
                                  );
                                  if (idx >= 0) {
                                    setState(() {
                                      _submission.points[idx] = updated;
                                    });
                                    _save();
                                  }
                                }
                                Navigator.pop(dlgCtx);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TiketPill(
                              label: 'Simpan kendala',
                              kind: TiketPillKind.primary,
                              height: 40,
                              expand: true,
                              onPressed: () {
                                final finalReason = (selectedReason == quickReasons.last)
                                    ? (customCtrl.text.trim().isNotEmpty
                                        ? customCtrl.text.trim()
                                        : 'Kendala Fisik Belum Dirinci')
                                    : selectedReason;

                                final updated = result.copyWith(kendalaFisik: finalReason);
                                final idx = _submission.points.indexWhere(
                                  (p) => p.pointId == point.id,
                                );
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
                                    backgroundColor: colors.signal,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _statusFilterDisplayLabel(
    int total,
    int belumCount,
    int sesuaiCount,
    int perluCekCount,
    int tidakAdaCount,
  ) {
    switch (_selectedStatusFilter) {
      case 'BELUM':
        return 'Belum difoto · $belumCount';
      case 'SESUAI':
        return 'Sesuai · $sesuaiCount';
      case 'CEK':
        return 'Perlu cek · $perluCekCount';
      case 'TIDAK_ADA':
        return 'Tidak ada · $tidakAdaCount';
      case 'ALL':
      default:
        return 'Semua status';
    }
  }

  void _openStatusFilterDialog(
    int total,
    int belumCount,
    int sesuaiCount,
    int perluCekCount,
    int tidakAdaCount,
  ) {
    showTiketPickerDialog<String>(
      context: context,
      title: 'Status Poin',
      options: [
        TiketOption(value: 'ALL', label: 'Semua status', trailingText: '$total'),
        TiketOption(value: 'SESUAI', label: 'Sesuai', trailingText: '$sesuaiCount'),
        TiketOption(value: 'CEK', label: 'Perlu cek', trailingText: '$perluCekCount'),
        TiketOption(value: 'BELUM', label: 'Belum difoto', trailingText: '$belumCount'),
        if (tidakAdaCount > 0)
          TiketOption(value: 'TIDAK_ADA', label: 'Tidak ada', trailingText: '$tidakAdaCount'),
      ],
      selected: _selectedStatusFilter,
    ).then((val) {
      if (val != null && mounted) {
        setState(() => _selectedStatusFilter = val);
      }
    });
  }

  List<TiketOption<String>> _getUnitOptions(int total) {
    final list = <TiketOption<String>>[];
    final String allLabel;
    if (widget.template.jenis == TemplateCategory.maintLengkap) {
      allLabel = 'Semua Area';
    } else if (widget.template.jenis == TemplateCategory.maintPos) {
      allLabel = _isBoothMode ? 'Semua booth' : 'Semua pos';
    } else if (widget.template.jenis == TemplateCategory.maintBarrier) {
      allLabel = 'Semua gate';
    } else if (widget.template.jenis == TemplateCategory.maintManless) {
      allLabel = 'Semua manless';
    } else if (widget.template.jenis == TemplateCategory.maintServer) {
      allLabel = _isEffectiveOnlyKasir ? 'Semua PC Kasir' : 'Semua perangkat';
    } else {
      allLabel = 'Semua unit';
    }
    list.add(TiketOption(value: 'ALL', label: allLabel, trailingText: '$total'));

    if (widget.template.jenis == TemplateCategory.maintServer) {
      if (_isEffectiveOnlyKasir) {
        final count = widget.kasirCount ?? _effectiveUnits.length;
        for (int k = 1; k <= count; k++) {
          final c = _submission.points.where((p) => p.pointId.contains('_${k}_')).length;
          list.add(TiketOption(value: 'UNIT_$k', label: 'PC Kasir $k', trailingText: '$c'));
        }
      } else if (!widget.isServerKasirGabung) {
        final srvCount = _submission.points.where((p) => p.pointId.contains('_1_')).length;
        list.add(TiketOption(value: 'UNIT_1', label: 'PC Server', trailingText: '$srvCount'));
        final count = widget.kasirCount ?? (_effectiveUnits.length - 1);
        for (int k = 1; k <= count; k++) {
          final c = _submission.points.where((p) => p.pointId.contains('_${k + 1}_')).length;
          list.add(TiketOption(value: 'UNIT_${k + 1}', label: 'PC Kasir $k', trailingText: '$c'));
        }
      }
    } else if (widget.template.jenis == TemplateCategory.maintLengkap) {
      for (final entry in _lengkapAreaLabels.entries) {
        final c = _submission.points.where((p) => _isPointInArea(p.pointId, entry.key)).length;
        if (c > 0) {
          list.add(TiketOption(value: 'AREA_${entry.key}', label: entry.value, trailingText: '$c'));
        }
      }
    } else {
      for (final i in _effectiveUnits) {
        final String label;
        if (widget.template.jenis == TemplateCategory.maintPos) {
          label = _isBoothMode ? 'Booth $i' : 'Pos $i';
        } else if (widget.template.jenis == TemplateCategory.maintBarrier) {
          label = 'Gate $i${_roleSuffix(i)}';
        } else if (widget.template.jenis == TemplateCategory.maintManless) {
          label = 'Manless $i$_manlessRoleSuffix';
        } else {
          label = 'Unit $i';
        }
        final c = _submission.points.where((p) => p.pointId.contains('_${i}_')).length;
        list.add(TiketOption(value: 'UNIT_$i', label: label, trailingText: '$c'));
      }
    }
    return list;
  }

  String _unitFilterDisplayLabel(int total) {
    final options = _getUnitOptions(total);
    final opt = options.firstWhere(
      (o) => o.value == _selectedUnitFilter,
      orElse: () => options.first,
    );
    return opt.label;
  }

  void _openUnitFilterDialog(int total) {
    showTiketPickerDialog<String>(
      context: context,
      title: 'Filter unit',
      options: _getUnitOptions(total),
      selected: _selectedUnitFilter,
    ).then((val) {
      if (val != null && mounted) {
        setState(() => _selectedUnitFilter = val);
      }
    });
  }

  Widget _buildDashProgressBar(TiketColors colors) {
    final total = _submission.totalPoints;
    if (total <= 0) return const SizedBox.shrink();

    final points = _submission.points;
    final int dashCount = total <= 24 ? total : 24;

    return Row(
      children: List.generate(dashCount, (idx) {
        Color dashColor;
        if (total <= 24) {
          final p = points[idx];
          if (p.status == PointStatus.sesuai) {
            dashColor = colors.white;
          } else if (p.status == PointStatus.tidakSesuai ||
              p.status == PointStatus.perluCekManual) {
            dashColor = colors.signal;
          } else {
            dashColor = colors.bandRaise;
          }
        } else {
          final ratio = idx / dashCount;
          final pointIdx = (ratio * total).floor();
          final p = points[pointIdx];
          if (p.status == PointStatus.sesuai) {
            dashColor = colors.white;
          } else if (p.status == PointStatus.tidakSesuai ||
              p.status == PointStatus.perluCekManual) {
            dashColor = colors.signal;
          } else {
            dashColor = colors.bandRaise;
          }
        }

        return Expanded(
          child: Container(
            height: 8,
            margin: EdgeInsets.only(
              left: idx == 0 ? 0 : 3,
              right: idx == dashCount - 1 ? 0 : 3,
            ),
            decoration: BoxDecoration(
              color: dashColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildPointRow(
    SopPoint point,
    MaintenancePointResult result,
    TiketColors colors,
  ) {
    final hasImage = result.imagePath != null && result.imagePath!.isNotEmpty;
    final file = hasImage ? File(result.imagePath!) : null;
    final fileExists = file != null && file.existsSync();

    Widget leadingWidget;
    if (fileExists) {
      leadingWidget = ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () {
            PhotoPreviewDialog.show(
              context,
              imagePath: result.imagePath!,
              title: result.label,
              pointResult: result,
              onAnalyze: (base64) async {
                final res = await AiVisionService.verifyMaintenancePoint(
                  point: point,
                  template: widget.template,
                  imageBase64: base64,
                );
                final updated = result.copyWith(
                  status: res.status == VerificationStatus.sesuai
                      ? PointStatus.sesuai
                      : res.status == VerificationStatus.tidakSesuai
                          ? PointStatus.tidakSesuai
                          : PointStatus.perluCekManual,
                  alasan: res.alasan,
                  confidence: res.confidenceScore,
                  providerName: res.providerName,
                );
                await _updatePointResult(point, result, updated);
                return res;
              },
            );
          },
          child: Image.file(
            file,
            width: 56,
            height: 56,
            fit: BoxFit.cover,
          ),
        ),
      );
    } else {
      leadingWidget = Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: colors.soft,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          Icons.camera_alt_outlined,
          size: 24,
          color: colors.body,
        ),
      );
    }

    Widget trailingWidget;
    if (result.status == PointStatus.belumFoto) {
      trailingWidget = TiketPill(
        label: 'Foto',
        icon: Icons.camera_alt_rounded,
        kind: TiketPillKind.primary,
        height: 38,
        expand: false,
        onPressed: () => _openCameraForPoint(point),
      );
    } else if (result.status == PointStatus.sesuai) {
      trailingWidget = InkWell(
        onTap: () => _showPointAction(point, result),
        child: const IntrinsicWidth(
          child: StatusChip(
            label: 'Sesuai',
            kind: TiketChipKind.ok,
          ),
        ),
      );
    } else if (result.status == PointStatus.tidakSesuai) {
      trailingWidget = InkWell(
        onTap: () => _showPointAction(point, result),
        child: const IntrinsicWidth(
          child: StatusChip(
            label: 'Tidak sesuai',
            kind: TiketChipKind.danger,
          ),
        ),
      );
    } else if (result.status == PointStatus.tidakTerpasang) {
      trailingWidget = InkWell(
        onTap: () => _showPointAction(point, result),
        child: const IntrinsicWidth(
          child: StatusChip(
            label: 'Tidak ada',
            kind: TiketChipKind.neutral,
          ),
        ),
      );
    } else {
      trailingWidget = InkWell(
        onTap: () => _showPointAction(point, result),
        child: const IntrinsicWidth(
          child: StatusChip(
            label: 'Perlu cek',
            kind: TiketChipKind.attention,
          ),
        ),
      );
    }

    final String subtitleText = result.alasan.isNotEmpty
        ? 'AI: ${result.alasan}'
        : (point.deskripsi.isNotEmpty ? point.deskripsi : '');

    return Container(
      decoration: BoxDecoration(
        color: colors.canvas,
        border: Border(
          bottom: BorderSide(
            color: colors.hairline,
            width: 1.0,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          leadingWidget,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  point.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: TiketType.fontFamily,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: colors.ink,
                  ),
                ),
                if (subtitleText.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitleText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: TiketType.fontFamily,
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: colors.body,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          trailingWidget,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = TiketColors.of(context);
    final total = _submission.totalPoints;
    final done = _submission.doneCount;

    final belumCount = _submission.points
        .where((p) => p.status == PointStatus.belumFoto)
        .length;
    final sesuaiCount = _submission.points
        .where((p) => p.status == PointStatus.sesuai)
        .length;
    final tidakAdaCount = _submission.tidakTerpasangCount;
    final perluCekCount = _submission.points
        .where(
          (p) =>
              p.status == PointStatus.tidakSesuai ||
              p.status == PointStatus.perluCekManual,
        )
        .length;

    // Filter points based on selected unit tab and status filter
    final filteredResults = _submission.points.where((p) {
      if (_selectedUnitFilter.startsWith('AREA_')) {
        final area = _selectedUnitFilter.replaceAll('AREA_', '');
        if (!_isPointInArea(p.pointId, area)) return false;
      } else if (_selectedUnitFilter != 'ALL') {
        final unitIdx = _selectedUnitFilter.replaceAll('UNIT_', '');
        if (!p.pointId.contains('_${unitIdx}_')) return false;
      }
      if (_selectedStatusFilter == 'BELUM') return p.status == PointStatus.belumFoto;
      if (_selectedStatusFilter == 'SESUAI') return p.status == PointStatus.sesuai;
      if (_selectedStatusFilter == 'CEK') {
        return p.status == PointStatus.tidakSesuai || p.status == PointStatus.perluCekManual;
      }
      if (_selectedStatusFilter == 'TIDAK_ADA') return p.status == PointStatus.tidakTerpasang;
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: colors.canvas,
      body: Column(
        children: [
          TiketBand(
            leading: TiketIconButton(
              icon: Icons.arrow_back_rounded,
              semanticLabel: 'Kembali',
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              TiketPill(
                label: 'Riwayat',
                icon: Icons.schedule_rounded,
                kind: TiketPillKind.band,
                onPressed: () {
                  Navigator.of(context)
                      .push(
                        MaterialPageRoute(
                          builder: (_) => const MaintenanceHistoryScreen(),
                        ),
                      )
                      .then((_) {
                        if (mounted) {
                          setState(() {
                            _initSubmission();
                          });
                        }
                      });
                },
              ),
            ],
            caption: '${widget.template.nama} · ${_effectiveLocation.posName}',
            hero: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '$done/$total',
                      style: TextStyle(
                        fontFamily: TiketType.fontFamily,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'foto masuk',
                      style: TextStyle(
                        fontFamily: TiketType.fontFamily,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildDashProgressBar(colors),
                const SizedBox(height: 8),
                Text(
                  '$sesuaiCount sesuai · $perluCekCount perlu cek · $belumCount belum difoto',
                  style: TextStyle(
                    fontFamily: TiketType.fontFamily,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: colors.bandCaption,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TiketDropdownField(
                    label: 'Status',
                    value: _statusFilterDisplayLabel(
                      total,
                      belumCount,
                      sesuaiCount,
                      perluCekCount,
                      tidakAdaCount,
                    ),
                    onTap: () => _openStatusFilterDialog(
                      total,
                      belumCount,
                      sesuaiCount,
                      perluCekCount,
                      tidakAdaCount,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TiketDropdownField(
                    label: 'Unit',
                    value: _unitFilterDisplayLabel(total),
                    onTap: () => _openUnitFilterDialog(total),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: filteredResults.length,
              itemBuilder: (ctx, i) {
                final result = filteredResults[i];
                final point = _cachedSopPoints.firstWhere(
                  (p) => p.id == result.pointId,
                  orElse: () => widget.template.sopPoints.firstWhere(
                    (p) => p.id == result.pointId || p.label == result.label,
                    orElse: () => SopPoint(id: result.pointId, label: result.label),
                  ),
                );
                return _buildPointRow(point, result, colors);
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: TiketBottomBar(
        helper: belumCount > 0 ? '$belumCount poin belum difoto' : null,
        primary: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _submission.isComplete
                ? () async {
                    HapticFeedback.mediumImpact();
                    await _save();
                    unawaited(
                      GoogleSheetsService.syncMaintenanceToGoogleSheet(
                        submission: _submission,
                        category: widget.template.jenis,
                        unitCount: _effectiveUnits.length,
                      ),
                    );

                    final effectiveTaskId =
                        widget.dailyTaskId ?? _submission.taskId;
                    if (effectiveTaskId != null && effectiveTaskId.isNotEmpty) {
                      final photoUrls = _submission.points
                          .where(
                            (p) =>
                                p.imagePath != null &&
                                p.imagePath!.isNotEmpty,
                          )
                          .map((p) => p.imagePath!)
                          .toList();
                      final now = DateTime.now();
                      final timeStr =
                          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
                      final catatanReport =
                          'SOP Maintenance ${_submission.templateName} selesai (${_submission.sesuaiCount}/${_submission.totalPoints} poin sesuai${_submission.tidakTerpasangCount > 0 ? ", ${_submission.tidakTerpasangCount} tidak terpasang" : ""})';

                      await DailyTaskService.markTaskCompletedLocally(
                        taskId: effectiveTaskId,
                        jamSelesai: timeStr,
                        catatan: catatanReport,
                      );

                      unawaited(
                        DailyTaskService.completeTask(
                          taskId: effectiveTaskId,
                          jamSelesai: timeStr,
                          catatan: catatanReport,
                          localPhotoPaths: photoUrls,
                        ),
                      );
                    }

                    if (context.mounted) await _askShare(context);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '✓ Laporan ${_submission.templateName} tersimpan & disinkronkan ke Google Sheet SPV',
                          ),
                          backgroundColor: colors.ok,
                        ),
                      );
                      Navigator.pop(context, true);
                    }
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _submission.isComplete ? colors.primary : colors.soft,
              foregroundColor: _submission.isComplete ? colors.onPrimary : colors.mute,
              disabledBackgroundColor: colors.soft,
              disabledForegroundColor: colors.mute,
              elevation: 0,
              shape: const StadiumBorder(),
            ),
            child: const Text(
              'Simpan & Selesaikan Laporan',
              style: TextStyle(
                fontFamily: TiketType.fontFamily,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
