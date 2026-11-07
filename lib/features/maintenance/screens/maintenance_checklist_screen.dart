import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
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
import '../../../data/services/maintenance_log_service.dart';
import '../widgets/photo_preview_dialog.dart';
import '../widgets/maintenance_point_card.dart';
import '../widgets/maintenance_share_report_card.dart';
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
        tagColor: const Color(0xFF0284C7),
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
                      ? const Color(0xFF64748B)
                      : AppColors.danger),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _buildTacticalChip({
    required IconData icon,
    required String label,
    required bool isDark,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.2 : 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// Card "Kondisi Item": 3 pilihan sejajar, ikon di atas label.
  Widget _buildKondisiItemCard({
    required TingkatUrgensi tingkat,
    required bool isActive,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final (Color accent, IconData icon) = switch (tingkat) {
      TingkatUrgensi.ringan => (
        const Color(0xFF16A34A),
        Icons.check_circle_rounded,
      ),
      TingkatUrgensi.sedang => (
        const Color(0xFFD97706),
        Icons.warning_amber_rounded,
      ),
      TingkatUrgensi.urgent => (
        const Color(0xFFDC2626),
        Icons.autorenew_rounded,
      ),
      TingkatUrgensi.normal => (
        const Color(0xFF64748B),
        Icons.remove_circle_outline_rounded,
      ),
    };
    const neutral = Color(0xFF64748B);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 82,
        decoration: BoxDecoration(
          color: isActive
              ? accent.withValues(alpha: isDark ? 0.26 : 0.10)
              : (isDark ? const Color(0xFF0F172A) : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive
                ? accent
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            width: isActive ? 1.5 : 1.0,
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 19, color: isActive ? accent : neutral),
                    const SizedBox(height: 5),
                    Text(
                      tingkat.label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        height: 1.2,
                        fontWeight: FontWeight.w800,
                        color: isActive
                            ? accent
                            : (isDark
                                  ? const Color(0xFFE2E8F0)
                                  : const Color(0xFF334155)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (isActive)
              Positioned(
                top: 4,
                right: 4,
                child: Icon(Icons.done_rounded, size: 13, color: accent),
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        Color statusBg;
        Color statusBorder;
        Color statusColor;
        IconData statusIcon;
        String statusLabelText;

        if (result.status == PointStatus.sesuai) {
          statusBg = isDark
              ? const Color(0xFF064E3B).withValues(alpha: 0.3)
              : const Color(0xFFF0FDF4);
          statusBorder = isDark
              ? const Color(0xFF059669).withValues(alpha: 0.5)
              : const Color(0xFFBBF7D0);
          statusColor = isDark
              ? const Color(0xFF4ADE80)
              : const Color(0xFF16A34A);
          statusIcon = Icons.check_circle_rounded;
          statusLabelText = 'SESUAI';
        } else if (result.status == PointStatus.tidakSesuai) {
          statusBg = isDark
              ? const Color(0xFF7F1D1D).withValues(alpha: 0.3)
              : const Color(0xFFFEF2F2);
          statusBorder = isDark
              ? const Color(0xFFDC2626).withValues(alpha: 0.5)
              : const Color(0xFFFECACA);
          statusColor = isDark
              ? const Color(0xFFF87171)
              : const Color(0xFFDC2626);
          statusIcon = Icons.cancel_rounded;
          statusLabelText = 'TIDAK SESUAI';
        } else if (result.status == PointStatus.tidakTerpasang) {
          statusBg = isDark
              ? const Color(0xFF334155).withValues(alpha: 0.3)
              : const Color(0xFFF1F5F9);
          statusBorder = isDark
              ? const Color(0xFF64748B).withValues(alpha: 0.5)
              : const Color(0xFFCBD5E1);
          statusColor = isDark
              ? const Color(0xFF94A3B8)
              : const Color(0xFF475569);
          statusIcon = Icons.do_not_disturb_alt_rounded;
          statusLabelText = 'BARANG TIDAK TERPASANG';
        } else {
          // Perlu Cek Manual / Belum Foto
          statusBg = isDark
              ? const Color(0xFF78350F).withValues(alpha: 0.3)
              : const Color(0xFFFFFBEB);
          statusBorder = isDark
              ? const Color(0xFFD97706).withValues(alpha: 0.5)
              : const Color(0xFFFDE68A);
          statusColor = isDark
              ? const Color(0xFFFBBF24)
              : const Color(0xFFD97706);
          statusIcon = Icons.info_rounded;
          statusLabelText = result.status.label.toUpperCase();
        }

        final butuhPerbaikan =
            result.status == PointStatus.tidakSesuai ||
            result.status == PointStatus.perluCekManual;

        // Deteksi masalah dari alasan AI -> dipakai untuk chip pelanggaran
        // SEKALIGUS saran perbaikan (biar tidak ada dua logika terpisah).
        // Hanya dijalankan untuk poin bermasalah, supaya alasan "sesuai" seperti
        // "kipas bebas debu" tidak salah muncul jadi chip temuan.
        final masalah = butuhPerbaikan
            ? MaintenanceChecklistScreen.detectAiIssues(result.alasan)
            : <({String label, IconData icon, String saran})>[];

        final List<Widget> aiChips = masalah
            .map(
              (m) => _buildTacticalChip(
                icon: m.icon,
                label: m.label,
                isDark: isDark,
                color: statusColor,
              ),
            )
            .toList();
        if (result.status == PointStatus.tidakSesuai && aiChips.isEmpty) {
          aiChips.add(
            _buildTacticalChip(
              icon: Icons.error_outline_rounded,
              label: 'Poin Belum Sesuai',
              isDark: isDark,
              color: statusColor,
            ),
          );
          aiChips.add(
            _buildTacticalChip(
              icon: Icons.handyman_outlined,
              label: 'Perlu Cek Fisik',
              isDark: isDark,
              color: statusColor,
            ),
          );
        } else if (result.status == PointStatus.sesuai && aiChips.isEmpty) {
          aiChips.add(
            _buildTacticalChip(
              icon: Icons.check_circle_outline_rounded,
              label: 'SOP Terpenuhi',
              isDark: isDark,
              color: statusColor,
            ),
          );
        }

        // Kartu "Cara memperbaiki" hanya untuk poin yang perlu diperbaiki.
        final teksSaran = masalah.isEmpty
            ? 'Periksa lagi item ini sesuai standar SOP, lalu ambil foto ulang sampai hasilnya sesuai.'
            : masalah.take(2).map((m) => m.saran).join(' ');

        // Progres foto checkpoint (mis. "Checkpoint maintenance • 1/9 foto").
        final fotoTerisi = _submission.points
            .where((p) => (p.imagePath ?? '').trim().isNotEmpty)
            .length;
        final totalPoin = _submission.points.length;

        bool isCheckpointsExpanded = false;
        var urgensiTerpilih = result.urgensi;

        return StatefulBuilder(
          builder: (bottomSheetCtx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 18,
                right: 18,
                top: 18,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Modal dengan Tombol Close Bulat
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(
                              alpha: isDark ? 0.25 : 0.1,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.checklist_rtl_rounded,
                            color: isDark
                                ? const Color(0xFF38BDF8)
                                : AppColors.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                point.label,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13.5,
                                  color: textTitle,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Checkpoint maintenance • $fotoTerisi/$totalPoin foto',
                                style: TextStyle(fontSize: 11, color: textSub),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1E293B)
                                : const Color(0xFFF1F5F9),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: textSub,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Hero Status Card (Tactical HUD Verdict)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: statusBorder, width: 1.5),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(statusIcon, color: statusColor, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  statusLabelText,
                                  style: TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    color: statusColor,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF1E293B)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: statusBorder),
                                ),
                                child: Text(
                                  result.confidence > 0
                                      ? 'AI Vision • ${(result.confidence * 100).toInt()}%'
                                      : 'AI Vision',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: statusColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            result.alasan.isNotEmpty
                                ? result.alasan
                                : (result.status == PointStatus.sesuai
                                      ? 'Hasil foto sesuai dengan standar SOP pemeliharaan.'
                                      : 'Foto perlu diperiksa kembali sebelum disetujui.'),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? const Color(0xFFF1F5F9)
                                  : const Color(0xFF1E293B),
                              height: 1.35,
                            ),
                          ),
                          if (aiChips.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Wrap(spacing: 6, runSpacing: 6, children: aiChips),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Cara memperbaiki (panduan singkat sesuai masalah yang terdeteksi)
                    if (butuhPerbaikan) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E293B)
                              : const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDark
                                ? const Color(0xFF334155)
                                : const Color(0xFFBFDBFE),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF0F172A)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: const Icon(
                                Icons.camera_alt_rounded,
                                size: 16,
                                color: Color(0xFF2563EB),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Cara memperbaiki',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF2563EB),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    teksSaran,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      height: 1.35,
                                      color: isDark
                                          ? const Color(0xFFE2E8F0)
                                          : const Color(0xFF1E293B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Tingkat Keparahan Temuan (diisi teknisi, dipakai supervisor
                    // untuk memprioritaskan perbaikan)
                    if (result.status == PointStatus.tidakSesuai ||
                        result.status == PointStatus.perluCekManual) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E293B)
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: cardBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.assignment_outlined,
                                  size: 15,
                                  color: textSub,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Kondisi Item',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: textTitle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '(Pilih salah satu)',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: textSub,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                for (final u in TingkatUrgensi.values.where(
                                  (u) => u != TingkatUrgensi.normal,
                                )) ...[
                                  if (u != TingkatUrgensi.ringan)
                                    const SizedBox(width: 6),
                                  Expanded(
                                    child: _buildKondisiItemCard(
                                      tingkat: u,
                                      isActive: urgensiTerpilih == u,
                                      isDark: isDark,
                                      onTap: () async {
                                        HapticFeedback.selectionClick();
                                        final baru = urgensiTerpilih == u
                                            ? TingkatUrgensi.normal
                                            : u;
                                        setSheetState(() {
                                          urgensiTerpilih = baru;
                                        });
                                        await _setPointUrgensi(
                                          point,
                                          result,
                                          baru,
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Panduan Sudut Foto (Kompak & Elegan)
                    if (point.panduanFoto.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E293B)
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark
                                ? const Color(0xFF334155)
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.camera_alt_outlined,
                              size: 16,
                              color: isDark
                                  ? const Color(0xFF60A5FA)
                                  : const Color(0xFF2563EB),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Tips: ${point.panduanFoto}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: isDark
                                      ? const Color(0xFFCBD5E1)
                                      : const Color(0xFF334155),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],

                    // Collapsible Checkpoint Accordion (Hemat Layar)
                    if (point.checkpoints.isNotEmpty) ...[
                      Container(
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E293B)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark
                                ? const Color(0xFF334155)
                                : const Color(0xFFCBD5E1),
                          ),
                        ),
                        child: Column(
                          children: [
                            InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () {
                                setSheetState(() {
                                  isCheckpointsExpanded =
                                      !isCheckpointsExpanded;
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? const Color(0xFF0F172A)
                                            : const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        Icons.checklist_rounded,
                                        size: 15,
                                        color: isDark
                                            ? const Color(0xFF94A3B8)
                                            : const Color(0xFF475569),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Standar SOP',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                              color: isDark
                                                  ? const Color(0xFFE2E8F0)
                                                  : const Color(0xFF334155),
                                            ),
                                          ),
                                          Text(
                                            '${point.checkpoints.length} checkpoint • Ketuk untuk melihat detail',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: isDark
                                                  ? const Color(0xFF94A3B8)
                                                  : AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      isCheckpointsExpanded
                                          ? Icons.keyboard_arrow_up_rounded
                                          : Icons.keyboard_arrow_down_rounded,
                                      size: 18,
                                      color: isDark
                                          ? const Color(0xFF94A3B8)
                                          : const Color(0xFF64748B),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (isCheckpointsExpanded) ...[
                              Divider(
                                height: 1,
                                color: isDark
                                    ? const Color(0xFF334155)
                                    : const Color(0xFFE2E8F0),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  10,
                                  8,
                                  10,
                                  8,
                                ),
                                child: Column(
                                  children: point.checkpoints
                                      .map(
                                        (cp) => Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 6,
                                          ),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Icon(
                                                Icons
                                                    .radio_button_checked_rounded,
                                                size: 13,
                                                color: isDark
                                                    ? const Color(0xFF38BDF8)
                                                    : AppColors.primary,
                                              ),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  cp,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: isDark
                                                        ? const Color(
                                                            0xFFCBD5E1,
                                                          )
                                                        : AppColors.textPrimary,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],

                    // Tampilan status kendala fisik jika sudah ditandai sebelumnya
                    if (result.kendalaFisik != null &&
                        result.kendalaFisik!.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(
                            alpha: isDark ? 0.2 : 0.12,
                          ),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.orange.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.handyman_rounded,
                              color: Colors.orange,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Kendala Fisik Terlapor: ${result.kendalaFisik}',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.orange,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],

                    const SizedBox(height: 6),

                    // Primary CTA: Buka Kamera / Foto Ulang
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _openCameraForPoint(point);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: butuhPerbaikan
                              ? const Color(
                                  0xFF059669,
                                ) // hijau: ajakan memperbaiki foto
                              : AppColors.primary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.camera_alt_rounded,
                                  size: 17,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  result.status == PointStatus.belumFoto
                                      ? 'Buka Kamera & Verifikasi AI'
                                      : (butuhPerbaikan
                                            ? 'Foto Ulang'
                                            : 'Foto Ulang & Verifikasi AI'),
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            if (butuhPerbaikan) ...[
                              const SizedBox(height: 2),
                              const Text(
                                'Pastikan seluruh bagian terlihat jelas.',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Secondary Row (50:50 Grid: Kendala Fisik & Catatan)
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(ctx);
                              _showDisposisiKendalaDialog(point, result);
                            },
                            icon: const Icon(
                              Icons.handyman_rounded,
                              size: 15,
                              color: Color(0xFFD97706),
                            ),
                            label: const Text(
                              'Kendala Fisik',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFD97706),
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: isDark
                                    ? const Color(
                                        0xFFD97706,
                                      ).withValues(alpha: 0.5)
                                    : const Color(0xFFFDE68A),
                                width: 1.2,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              final noteController = TextEditingController(
                                text: result.alasan,
                              );
                              showDialog(
                                context: context,
                                builder: (dlgCtx) => AlertDialog(
                                  backgroundColor: isDark
                                      ? const Color(0xFF0F172A)
                                      : Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    side: BorderSide(color: cardBorder),
                                  ),
                                  title: Text(
                                    'Catatan Poin: ${point.label}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: textTitle,
                                    ),
                                  ),
                                  content: TextField(
                                    controller: noteController,
                                    maxLines: 3,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: isDark
                                          ? Colors.white
                                          : AppColors.textPrimary,
                                    ),
                                    decoration: InputDecoration(
                                      hintText:
                                          'Misal: Palang bengkok tersenggol truk, stiker diganti baru, dll.',
                                      hintStyle: TextStyle(
                                        fontSize: 12,
                                        color: isDark
                                            ? const Color(0xFF64748B)
                                            : Colors.grey,
                                      ),
                                      filled: true,
                                      fillColor: isDark
                                          ? const Color(0xFF1E293B)
                                          : Colors.grey.shade50,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide(
                                          color: cardBorder,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide(
                                          color: cardBorder,
                                        ),
                                      ),
                                      focusedBorder: const OutlineInputBorder(
                                        borderRadius: BorderRadius.all(
                                          Radius.circular(10),
                                        ),
                                        borderSide: BorderSide(
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(dlgCtx),
                                      child: Text(
                                        'Batal',
                                        style: TextStyle(color: textSub),
                                      ),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                      onPressed: () {
                                        final updated = result.copyWith(
                                          alasan: noteController.text.trim(),
                                        );
                                        final idx = _submission.points
                                            .indexWhere(
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
                                      child: const Text('Simpan Catatan'),
                                    ),
                                  ],
                                ),
                              );
                            },
                            icon: Icon(
                              Icons.edit_note_rounded,
                              size: 17,
                              color: isDark
                                  ? const Color(0xFF60A5FA)
                                  : const Color(0xFF2563EB),
                            ),
                            label: Text(
                              'Ubah Catatan',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? const Color(0xFF60A5FA)
                                    : const Color(0xFF2563EB),
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: isDark
                                    ? const Color(
                                        0xFF2563EB,
                                      ).withValues(alpha: 0.5)
                                    : const Color(0xFFBFDBFE),
                                width: 1.2,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Poin sengaja dilewati: barang tidak terpasang / tidak ada di lokasi
                    if (result.status != PointStatus.tidakTerpasang) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () async {
                            HapticFeedback.selectionClick();
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (dlgCtx) => AlertDialog(
                                backgroundColor: isDark
                                    ? const Color(0xFF0F172A)
                                    : Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(color: cardBorder),
                                ),
                                title: Text(
                                  'Barang tidak terpasang?',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: textTitle,
                                  ),
                                ),
                                content: Text(
                                  '"${point.label}" akan ditandai TIDAK TERPASANG / tidak ada di lokasi, tanpa perlu foto.',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: textSub,
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(dlgCtx, false),
                                    child: Text(
                                      'Batal',
                                      style: TextStyle(color: textSub),
                                    ),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF64748B),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    onPressed: () =>
                                        Navigator.pop(dlgCtx, true),
                                    child: const Text('Ya, Tidak Terpasang'),
                                  ),
                                ],
                              ),
                            );
                            if (ok == true && ctx.mounted) {
                              Navigator.pop(ctx);
                              await _setPointTidakTerpasang(point, result);
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            backgroundColor: isDark
                                ? const Color(0xFF1E293B)
                                : const Color(0xFFF8FAFC),
                            side: BorderSide(
                              color: isDark
                                  ? const Color(0xFF334155)
                                  : const Color(0xFFCBD5E1),
                              width: 1.0,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.do_not_disturb_alt_rounded,
                                size: 17,
                                color: isDark
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF475569),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Barang Tidak Terpasang / Tidak Ada',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? const Color(0xFF94A3B8)
                                        : const Color(0xFF475569),
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                size: 18,
                                color: isDark
                                    ? const Color(0xFF64748B)
                                    : const Color(0xFF94A3B8),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
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
      text:
          (result.kendalaFisik != null &&
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
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: cardBorder),
          ),
          title: Row(
            children: [
              const Icon(
                Icons.handyman_rounded,
                color: Colors.orange,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tandai Kendala Fisik',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: textTitle,
                  ),
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
                  'Pilih opsi ini jika alat rusak fisik atau perlu penggantian sparepart.',
                  style: TextStyle(fontSize: 11, color: textSub, height: 1.3),
                ),
                const SizedBox(height: 12),
                Text(
                  'PILIH JENIS KENDALA:',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isDark ? const Color(0xFF38BDF8) : AppColors.primary,
                  ),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.orange.withValues(
                                alpha: isDark ? 0.25 : 0.12,
                              )
                            : (isDark
                                  ? const Color(0xFF1E293B)
                                  : Colors.grey.shade50),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? Colors.orange : cardBorder,
                          width: isSelected ? 1.5 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSelected
                                ? Icons.radio_button_checked_rounded
                                : Icons.radio_button_off_rounded,
                            size: 16,
                            color: isSelected ? Colors.orange : textSub,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              reason,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isSelected
                                    ? (isDark ? Colors.white : Colors.black87)
                                    : (isDark
                                          ? const Color(0xFFCBD5E1)
                                          : Colors.black87),
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
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Tulis rincian kendala...',
                      hintStyle: TextStyle(fontSize: 11.5, color: textSub),
                      filled: true,
                      fillColor: isDark
                          ? const Color(0xFF1E293B)
                          : Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: cardBorder),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (result.kendalaFisik != null &&
                    result.kendalaFisik!.isNotEmpty) {
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
              child: Text(
                (result.kendalaFisik != null && result.kendalaFisik!.isNotEmpty)
                    ? 'Hapus Kendala'
                    : 'Batal',
                style: TextStyle(
                  color:
                      (result.kendalaFisik != null &&
                          result.kendalaFisik!.isNotEmpty)
                      ? AppColors.danger
                      : textSub,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
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
        materialTapTargetSize: MaterialTapTargetSize.padded,
        label: Text('$label ($count)'),
        labelStyle: TextStyle(
          fontSize: 11,
          fontFamily: 'PlusJakartaSans',
          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          color: isSelected
              ? Colors.white
              : (isDark
                    ? AppColors.textDarkSecondary
                    : AppColors.textSecondary),
        ),
        selected: isSelected,
        selectedColor: AppColors.primary,
        backgroundColor: isDark ? AppColors.darkSurfaceContainer : Colors.white,
        side: BorderSide(
          color: isSelected
              ? Colors.transparent
              : (isDark ? AppColors.darkBorderMuted : AppColors.cardBorder),
          width: 1.1,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        showCheckmark: true,
        checkmarkColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
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

  Widget _buildFilterStatusChip(
    String statusKey,
    String label,
    int count,
    Color activeColor,
  ) {
    final isDark = ThemeService.isDarkMode(context);
    final isSelected = _selectedStatusFilter == statusKey;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        materialTapTargetSize: MaterialTapTargetSize.padded,
        label: Text('$label ($count)'),
        labelStyle: TextStyle(
          fontSize: 10.5,
          fontFamily: 'PlusJakartaSans',
          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          color: isSelected
              ? Colors.white
              : (isDark
                    ? AppColors.textDarkSecondary
                    : AppColors.textSecondary),
        ),
        selected: isSelected,
        selectedColor: activeColor,
        backgroundColor: isDark ? AppColors.darkSurfaceContainer : Colors.white,
        side: BorderSide(
          color: isSelected
              ? Colors.transparent
              : (isDark ? AppColors.darkBorderMuted : AppColors.cardBorder),
          width: 1.1,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        showCheckmark: true,
        checkmarkColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
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
        // Maintenance Lengkap: saring per area pakai awalan id poin.
        final area = _selectedUnitFilter.replaceAll('AREA_', '');
        if (!_isPointInArea(p.pointId, area)) return false;
      } else if (_selectedUnitFilter != 'ALL') {
        final unitIdx = _selectedUnitFilter.replaceAll('UNIT_', '');
        if (!p.pointId.contains('_${unitIdx}_')) return false;
      }
      if (_selectedStatusFilter == 'BELUM') return p.status == PointStatus.belumFoto;
      if (_selectedStatusFilter == 'SESUAI') return p.status == PointStatus.sesuai;
      if (_selectedStatusFilter == 'CEK') return p.status == PointStatus.tidakSesuai || p.status == PointStatus.perluCekManual;
      if (_selectedStatusFilter == 'TIDAK_ADA') return p.status == PointStatus.tidakTerpasang;
      return true;
    }).toList();

    // Kalau teknisi sedang menyaring per area (khusus Maintenance Lengkap),
    // header ikut menampilkan progres area itu biar tidak bingung.
    final areaFilterKey = _selectedUnitFilter.startsWith('AREA_')
        ? _selectedUnitFilter.replaceAll('AREA_', '')
        : null;
    final areaFilterPoints = areaFilterKey == null
        ? const <MaintenancePointResult>[]
        : _submission.points
              .where((p) => p.pointId.split('_').first == areaFilterKey)
              .toList();

    final isDark = ThemeService.isDarkMode(context);
    final bgScaffold = isDark
        ? const Color(0xFF0B1120)
        : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF334155) : AppColors.cardBorder;
    final textTitle = isDark ? const Color(0xFFF8FAFC) : AppColors.textPrimary;
    final textSub = isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary;

    final fullAppBarTitle =
        widget.template.jenis == TemplateCategory.maintServer
        ? (_isEffectiveOnlyKasir
              ? 'Maintenance: Kasir'
              : 'Maintenance: Server & Kasir')
        : (widget.template.jenis == TemplateCategory.maintManless
              ? '${widget.template.nama}$_manlessRoleSuffix'
              : widget.template.nama);
    final strippedTitle = fullAppBarTitle
        .replaceFirst(
          RegExp(
            r'^(?:Checklist\s+)?Maintenance\s*[:\-–—]?\s*',
            caseSensitive: false,
          ),
          '',
        )
        .trim();
    final shortAppBarTitle = strippedTitle.isEmpty
        ? fullAppBarTitle
        : strippedTitle;

    return Scaffold(
      backgroundColor: bgScaffold,
      appBar: AppBar(
        titleSpacing: 4,
        title: Semantics(
          label: fullAppBarTitle,
          child: Tooltip(
            message: fullAppBarTitle,
            excludeFromSemantics: true,
            child: Text(
              shortAppBarTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Riwayat Maintenance',
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: cardBorder,
            color: AppColors.accent,
            minHeight: 4,
          ),
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
                    color: AppColors.primary.withValues(
                      alpha: isDark ? 0.25 : 0.1,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withValues(
                        alpha: isDark ? 0.35 : 0.15,
                      ),
                    ),
                  ),
                  child: const Icon(
                    Icons.build_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
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
                          color: textTitle,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Builder(
                        builder: (_) {
                          if (widget.template.jenis ==
                              TemplateCategory.maintLengkap) {
                            if (areaFilterKey != null) {
                              return Text(
                                '${_lengkapAreaLabels[areaFilterKey]} • ${areaFilterPoints.where((p) => p.isDone).length}/${areaFilterPoints.length} foto selesai',
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 11,
                                  color: textSub,
                                ),
                              );
                            }
                            return Text(
                              'Semua area: Barrier Gate + Manless + Pos Kasir${widget.includeServer ? ' + PC Server' : ''} • $done/$total foto selesai (${(progress * 100).toInt()}%)',
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 11,
                                color: textSub,
                              ),
                            );
                          }
                          final String unitNoun;
                          if (widget.template.jenis ==
                              TemplateCategory.maintPos) {
                            unitNoun = _isBoothMode ? 'Booth' : 'Pos';
                          } else if (widget.template.jenis ==
                              TemplateCategory.maintBarrier) {
                            unitNoun = 'Gate';
                          } else if (widget.template.jenis ==
                              TemplateCategory.maintManless) {
                            unitNoun = 'Manless';
                          } else if (widget.template.jenis ==
                              TemplateCategory.maintServer) {
                            unitNoun = _isEffectiveOnlyKasir
                                ? 'PC Kasir'
                                : (widget.isServerKasirGabung
                                      ? 'Server & Kasir'
                                      : 'Perangkat');
                          } else {
                            unitNoun = 'Unit';
                          }
                          final String unitDesc = _effectiveUnits.length == 1
                              ? '$unitNoun ${_effectiveUnits.first}${_roleSuffix(_effectiveUnits.first)} dicek'
                              : '${_effectiveUnits.length} $unitNoun ($unitNoun ${_effectiveUnits.first}${_roleSuffix(_effectiveUnits.first)} - $unitNoun ${_effectiveUnits.last}${_roleSuffix(_effectiveUnits.last)}) dicek';
                          return Text(
                            '$unitDesc • $done/$total foto selesai (${(progress * 100).toInt()}%)',
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 11,
                              color: textSub,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _submission.isAllSesuai
                        ? AppColors.success
                        : AppColors.accent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _submission.isComplete
                        ? (_submission.isAllSesuai ? 'SELESAI' : 'SELESAI CEK')
                        : 'PROSES',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'monospace',
                      letterSpacing: 0.5,
                      color: Colors.white,
                    ),
                  ),
                ),
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
                _buildFilterStatusChip(
                  'ALL',
                  'Semua',
                  total,
                  AppColors.primary,
                ),
                _buildFilterStatusChip(
                  'BELUM',
                  'Belum Foto',
                  belumCount,
                  const Color(0xFF64748B),
                ),
                _buildFilterStatusChip(
                  'SESUAI',
                  'Sesuai',
                  sesuaiCount,
                  AppColors.success,
                ),
                _buildFilterStatusChip(
                  'CEK',
                  'Perlu Cek',
                  perluCekCount,
                  AppColors.warning,
                ),
                if (tidakAdaCount > 0)
                  _buildFilterStatusChip(
                    'TIDAK_ADA',
                    'Tidak Ada',
                    tidakAdaCount,
                    const Color(0xFF64748B),
                  ),
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
                  Builder(
                    builder: (_) {
                      final String allLabel;
                      if (widget.template.jenis == TemplateCategory.maintLengkap) {
                        allLabel = 'Semua Area';
                      } else if (widget.template.jenis == TemplateCategory.maintPos) {
                        allLabel =
                            'Semua ${_isBoothMode ? 'Booth' : 'Pos'} (${_effectiveUnits.first} - ${_effectiveUnits.last})';
                      } else if (widget.template.jenis ==
                          TemplateCategory.maintBarrier) {
                        allLabel =
                            'Semua Gate (${_effectiveUnits.first} - ${_effectiveUnits.last})';
                      } else if (widget.template.jenis ==
                          TemplateCategory.maintManless) {
                        allLabel =
                            'Semua Manless (${_effectiveUnits.first} - ${_effectiveUnits.last})';
                      } else if (widget.template.jenis ==
                          TemplateCategory.maintServer) {
                        allLabel = _isEffectiveOnlyKasir
                            ? 'Semua PC Kasir'
                            : 'Semua PC Perangkat';
                      } else {
                        allLabel = 'Semua Unit';
                      }
                      return _buildFilterUnitChip('ALL', allLabel, total);
                    },
                  ),
                  if (widget.template.jenis ==
                      TemplateCategory.maintServer) ...[
                    if (_isEffectiveOnlyKasir) ...[
                      // Hanya Kasir: Unit 1..N adalah PC Kasir 1..N
                      for (
                        int k = 1;
                        k <= (widget.kasirCount ?? _effectiveUnits.length);
                        k++
                      )
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
                      for (
                        int k = 1;
                        k <=
                            (widget.kasirCount ?? (_effectiveUnits.length - 1));
                        k++
                      )
                        _buildFilterUnitChip(
                          'UNIT_${k + 1}',
                          'PC Kasir $k',
                          _submission.points
                              .where((p) => p.pointId.contains('_${k + 1}_'))
                              .length,
                        ),
                    ],
                  ] else if (widget.template.jenis ==
                      TemplateCategory.maintLengkap) ...[
                    // Maintenance Lengkap: arah kerja per area, bukan per nomor unit
                    // (nomor unit tidak lagi mewakili satu perangkat di tugas gabungan).
                    for (final entry in _lengkapAreaLabels.entries)
                      if (_submission.points.any(
                        (p) => _isPointInArea(p.pointId, entry.key),
                      ))
                        _buildFilterUnitChip(
                          'AREA_${entry.key}',
                          entry.value,
                          _submission.points
                              .where(
                                (p) => _isPointInArea(p.pointId, entry.key),
                              )
                              .length,
                        ),
                  ] else ...[
                    for (final i in _effectiveUnits)
                      Builder(
                        builder: (_) {
                          final String unitLabel;
                          if (widget.template.jenis ==
                              TemplateCategory.maintPos) {
                            unitLabel = _isBoothMode ? 'Booth $i' : 'Pos $i';
                          } else if (widget.template.jenis ==
                              TemplateCategory.maintBarrier) {
                            unitLabel = 'Gate $i${_roleSuffix(i)}';
                          } else if (widget.template.jenis ==
                              TemplateCategory.maintManless) {
                            unitLabel = 'Manless $i$_manlessRoleSuffix';
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
                        },
                      ),
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
                    orElse: () =>
                        SopPoint(id: result.pointId, label: result.label),
                  ),
                );

                return MaintenancePointCard(
                  result: result,
                  point: point,
                  isDark: isDark,
                  onRetakePhoto: () => _openCameraForPoint(point),
                  onPreviewPhoto: () {
                    PhotoPreviewDialog.show(
                      context,
                      imagePath: result.imagePath!,
                      title: result.label,
                      pointResult: result,
                      // Analisa ulang foto point ini, lalu simpan hasilnya
                      // supaya laporan yang dibagikan ikut ter-update.
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
                  onTapCard: () {
                    if (result.status == PointStatus.belumFoto) {
                      _openCameraForPoint(point);
                    } else {
                      _showPointAction(point, result);
                    }
                  },
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
                MaintenanceShareReportCard(
                  submission: _submission,
                  category: widget.template.jenis,
                  effectiveUnits: _effectiveUnits,
                  onSave: _save,
                ),

                // Tombol Simpan Laporan
                SizedBox(
                  width: double.infinity,
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

                            // Selesaikan Daily Task jika dihubungkan dengan Daily Task
                            final effectiveTaskId =
                                widget.dailyTaskId ?? _submission.taskId;
                            if (effectiveTaskId != null &&
                                effectiveTaskId.isNotEmpty) {
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

                              // Update cache lokal seketika agar status & strikethrough langsung aktif
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

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '✓ Laporan ${_submission.templateName} tersimpan & disinkronkan ke Google Sheet SPV',
                                  ),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                              Navigator.pop(context, true);
                            }
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _submission.isComplete
                          ? AppColors.accent
                          : AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: _submission.isComplete ? 3 : 0,
                      shadowColor: AppColors.accent.withValues(alpha: 0.4),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      _submission.isComplete
                          ? 'Simpan & Selesaikan Laporan (${_submission.sesuaiCount}/${total - tidakAdaCount} Lolos)'
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
