import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/theme_service.dart';
import '../../../data/models/submission_model.dart';
import '../../../data/services/absensi_setup_service.dart';
import '../../../data/services/storage_service.dart';
import '../../../data/services/whatsapp_report_service.dart';
import '../../../data/services/location_service.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/services/branch_service.dart';

class AbsensiKategoriDialog extends StatefulWidget {
  final VoidCallback? onSaved;

  const AbsensiKategoriDialog({super.key, this.onSaved});

  static Future<void> show(BuildContext context, {VoidCallback? onSaved}) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => AbsensiKategoriDialog(onSaved: onSaved),
    );
  }

  @override
  State<AbsensiKategoriDialog> createState() => _AbsensiKategoriDialogState();
}

class _AbsensiKategoriDialogState extends State<AbsensiKategoriDialog> {
  final setup = AbsensiSetupService.instance;
  late TextEditingController _teknisiCtrl;
  late TextEditingController _customShiftCtrl;
  late TextEditingController _customShiftJamCtrl;
  bool _isCustomShift = false;
  late String _selectedShift;
  late String _tipeLaporan;
  late String _jamPulang;

  // Lokasi standby manual (Bali bisa isi sendiri, tidak dikunci ke PBKD)
  late TextEditingController _lokasiCtrl;
  late String _lokasiStandby;

  // Toggle & input state untuk Laporan Pulang
  bool _adaShiftSelanjutnya = false;
  late TextEditingController _petugasNextShiftCtrl;
  late TextEditingController _pekerjaanSelesaiCtrl;
  bool _semuaPekerjaanSelesai = true;
  late TextEditingController _pekerjaanBelumCtrl;

  // Validation & saving state
  String? _teknisiError;
  bool _isSaving = false;

  static const List<Map<String, String>> _manadoShiftCards = [
    {
      'title': 'Shift 1',
      'full': 'Shift 1 (03:00 - 11:00)',
      'hours': '03:00 - 11:00 WITA',
      'period': 'Pagi • 8 Jam',
    },
    {
      'title': 'Shift 1.1',
      'full': 'Shift 1.1 (06:00 - 14:00)',
      'hours': '06:00 - 14:00 WITA',
      'period': 'Pagi • 8 Jam',
    },
    {
      'title': 'Shift 2',
      'full': 'Shift 2 (10:00 - 18:00)',
      'hours': '10:00 - 18:00 WITA',
      'period': 'Siang • 8 Jam',
    },
    {
      'title': 'Shift 2.2',
      'full': 'Shift 2.2 (10:00 - 14:00)',
      'hours': '10:00 - 14:00 WITA',
      'period': 'Paruh Waktu • 4 Jam',
    },
    {
      'title': 'Shift 3',
      'full': 'Shift 3 (14:00 - 22:00)',
      'hours': '14:00 - 22:00 WITA',
      'period': 'Sore-Malam • 8 Jam',
    },
  ];

  static const List<Map<String, String>> _baliShiftCards = [
    {
      'title': 'Shift 1',
      'full': 'Shift 1 (06.00 - 14.00)',
      'hours': '06:00 - 14:00 WITA',
      'period': 'Pagi • 8 Jam',
    },
    {
      'title': 'Shift 2',
      'full': 'Shift 2 (14.00 - 22.00)',
      'hours': '14:00 - 22:00 WITA',
      'period': 'Siang • 8 Jam',
    },
    {
      'title': 'Shift 3',
      'full': 'Shift 3 (22.00 - 06.00)',
      'hours': '22:00 - 06:00 WITA',
      'period': 'Malam • 8 Jam',
    },
    {
      'title': 'Shift 4',
      'full': 'Shift 4 (08.30 - 16.30)',
      'hours': '08:30 - 16:30 WITA',
      'period': 'Normal • 8 Jam',
    },
    {
      'title': 'Shift 2.2',
      'full': 'Shift 2.2 (18.00 - 22.00)',
      'hours': '18:00 - 22:00 WITA',
      'period': 'Malam • 4 Jam',
    },
    {
      'title': 'Shift 4.1',
      'full': 'Shift 4.1 (08.00 - 12.00)',
      'hours': '08:00 - 12:00 WITA',
      'period': 'Pagi • 4 Jam',
    },
  ];

  static const List<Map<String, String>> _hoShiftCards = [
    {
      'title': 'Shift 1',
      'full': 'Shift 1 (08.00 - 16.00)',
      'hours': '08:00 - 16:00 WITA',
      'period': 'Pagi • 8 Jam',
    },
    {
      'title': 'Shift 2',
      'full': 'Shift 2 (16.00 - 24.00)',
      'hours': '16:00 - 24:00 WITA',
      'period': 'Siang • 8 Jam',
    },
    {
      'title': 'Shift 3',
      'full': 'Shift 3 (24.00 - 08.00)',
      'hours': '24:00 - 08:00 WITA',
      'period': 'Malam • 8 Jam',
    },
    {
      'title': 'Shift 1.1',
      'full': 'Shift 1.1 (08.00 - 12.00)',
      'hours': '08:00 - 12:00 WITA',
      'period': 'Pagi • 4 Jam',
    },
    {
      'title': 'HO.1',
      'full': 'HO.1 (08.30 - 12.30)',
      'hours': '08:30 - 12:30 WITA',
      'period': 'Pagi • 4 Jam',
    },
    {
      'title': 'GMM 1',
      'full': 'GMM 1 (09.00 - 17.00)',
      'hours': '09:00 - 17:00 WITA',
      'period': 'Normal • 8 Jam',
    },
    {
      'title': 'GMM 2',
      'full': 'GMM 2 (15.00 - 23.00)',
      'hours': '15:00 - 23:00 WITA',
      'period': 'Siang-Malam • 8 Jam',
    },
    {
      'title': 'RSWS',
      'full': 'RSWS (15.00 - 23.00)',
      'hours': '15:00 - 23:00 WITA',
      'period': 'Siang-Malam • 8 Jam',
    },
    {
      'title': 'RSWS',
      'full': 'RSWS (08.30 - 16.30)',
      'hours': '08:30 - 16:30 WITA',
      'period': 'Normal • 8 Jam',
    },
    {
      'title': 'JP',
      'full': 'JP (08.30 - 16.30)',
      'hours': '08:30 - 16:30 WITA',
      'period': 'Normal • 8 Jam',
    },
    {
      'title': 'JP',
      'full': 'JP (17.00 - 01.00)',
      'hours': '17:00 - 01:00 WITA',
      'period': 'Sore-Malam • 8 Jam',
    },
  ];

  List<Map<String, String>> get _shiftCards {
    switch (BranchService.instance.currentBranch) {
      case AppBranch.manado:
        return _manadoShiftCards;
      case AppBranch.bali:
        return _baliShiftCards;
      case AppBranch.ho:
        return _hoShiftCards;
    }
  }

  List<String> get _rekanItOptions => BranchService.instance.getTechnicians();

  @override
  void initState() {
    super.initState();
    // Kunci kategori permanen ke Teknisi
    setup.updateKategori(AbsensiKategori.teknisi);

    _teknisiCtrl = TextEditingController(text: StorageService.getLastTechnicianName());
    _selectedShift = setup.effectiveJadwalShift;
    if (_selectedShift.contains('11:00 - 18:00')) {
      _selectedShift = 'Shift 2 (10:00 - 18:00)';
    }

    final isPredefined = _shiftCards.any((s) => s['full'] == _selectedShift);
    _isCustomShift = !isPredefined;
    _customShiftCtrl = TextEditingController();
    _customShiftJamCtrl = TextEditingController();
    _lokasiStandby = setup.effectiveLokasiStandby.toUpperCase();
    _lokasiCtrl = TextEditingController(text: _lokasiStandby);
    if (_isCustomShift) _prefillCustomShift();

    _tipeLaporan = setup.tipeLaporan;
    final lastCheck = StorageService.getLastCheckInTime();
    if (lastCheck != null &&
        AbsensiSetupService.isEligibleForAutoPulang(
          shift: _selectedShift,
          checkInTime: lastCheck,
        )) {
      _tipeLaporan = 'Pulang';
    }
    _jamPulang = setup.effectiveJamPulang;

    // Shift selanjutnya
    _adaShiftSelanjutnya = setup.shiftSelanjutnya.trim().isNotEmpty &&
        setup.shiftSelanjutnya.trim() != '-' &&
        !setup.shiftSelanjutnya.toLowerCase().contains('tidak ada');
    _petugasNextShiftCtrl = TextEditingController(
      text: _adaShiftSelanjutnya ? setup.shiftSelanjutnya : '',
    );

    // Form manual pekerjaan selesai (auto numbering jika ada teks tersimpan)
    final rawSelesai = setup.pekerjaanSelesai.trim();
    final initialSelesai = rawSelesai.isNotEmpty && rawSelesai != '-'
        ? (rawSelesai.contains('1.') ? rawSelesai : WhatsAppReportService.formatAutoNumberedList(rawSelesai))
        : '';
    _pekerjaanSelesaiCtrl = TextEditingController(text: initialSelesai);

    _semuaPekerjaanSelesai = setup.pekerjaanBelum.trim().isEmpty ||
        setup.pekerjaanBelum.trim() == '-';
    _pekerjaanBelumCtrl = TextEditingController(
      text: _semuaPekerjaanSelesai ? '' : setup.pekerjaanBelum,
    );
  }

  @override
  void dispose() {
    _teknisiCtrl.dispose();
    _customShiftCtrl.dispose();
    _customShiftJamCtrl.dispose();
    _lokasiCtrl.dispose();
    _petugasNextShiftCtrl.dispose();
    _pekerjaanSelesaiCtrl.dispose();
    _pekerjaanBelumCtrl.dispose();
    super.dispose();
  }

  void _onShiftSelected(String shift) {
    setState(() {
      _isCustomShift = false;
      _selectedShift = shift;
      _jamPulang = AbsensiSetupService.autoDetectJamPulang(shift: shift);
    });
  }

  /// Pola jam rentang di dalam nama shift, mis. "08:00 - 17:00".
  static final RegExp _jamRangePattern =
      RegExp(r'(\d{1,2}[:.]\d{2}\s*[-–]\s*\d{1,2}[:.]\d{2})');

  /// Gabungkan nama + jam jadi satu nama shift, mis. "Shift Khusus (08:00 - 17:00)".
  void _syncCustomShift() {
    final nama = _customShiftCtrl.text.trim();
    final jam = _customShiftJamCtrl.text.trim();
    if (nama.isEmpty && jam.isEmpty) {
      _selectedShift = 'Shift Khusus';
      _jamPulang = '18:00';
      return;
    }
    final namaShift = nama.isEmpty ? 'Shift Khusus' : nama;
    _selectedShift = jam.isEmpty ? namaShift : '$namaShift ($jam)';
    _jamPulang = AbsensiSetupService.autoDetectJamPulang(shift: _selectedShift);
  }

  /// Isi ulang kolom nama & jam dari shift yang tersimpan (mis. dialog dibuka lagi).
  void _prefillCustomShift() {
    final match = _jamRangePattern.firstMatch(_selectedShift);
    if (match == null) {
      _customShiftCtrl.text = _selectedShift == 'Shift Khusus' ? '' : _selectedShift;
      _customShiftJamCtrl.text = '';
    } else {
      _customShiftJamCtrl.text = match.group(1)!;
      _customShiftCtrl.text = _selectedShift
          .replaceRange(match.start, match.end, '')
          .replaceAll(RegExp(r'[()]+'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
    }
    _syncCustomShift();
  }

  void _onCustomShiftToggled() {
    setState(() {
      _isCustomShift = !_isCustomShift;
      if (_isCustomShift) {
        _prefillCustomShift();
      } else {
        _customShiftCtrl.text = '';
        _customShiftJamCtrl.text = '';
        _selectedShift = _shiftCards[0]['full']!;
        _jamPulang = AbsensiSetupService.autoDetectJamPulang(shift: _selectedShift);
      }
    });
  }

  void _onCustomShiftChanged() {
    setState(_syncCustomShift);
  }

  void _onTipeChanged(String tipe) {
    if (tipe == 'Pulang') {
      final isBypass = StorageService.isSpvQaBypassActive();
      if (!isBypass) {
        final lastCheck = StorageService.getLastCheckInTime();
        if (lastCheck == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Belum ada catatan absen masuk aktif hari ini.'),
              backgroundColor: Color(0xFFEF4444),
              duration: Duration(seconds: 3),
            ),
          );
          return;
        }

        final isEligible = AbsensiSetupService.isEligibleForAutoPulang(
          shift: _selectedShift,
          checkInTime: lastCheck,
        );

        if (!isEligible) {
          final jamPulangStr = AbsensiSetupService.autoDetectJamPulang(shift: _selectedShift, time: lastCheck);
          final worked = DateTime.now().difference(lastCheck);
          final workedH = worked.inHours;
          final workedM = worked.inMinutes.remainder(60);
          final remaining = AbsensiSetupService.getRemainingWorkTime(
            shift: _selectedShift,
            checkInTime: lastCheck,
          );

          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 24),
                  SizedBox(width: 8),
                  Text('Belum Waktunya Pulang', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              content: Text(
                'Absen pulang belum bisa dilakukan karena shift belum selesai.\n\n'
                '• Jadwal Akhir Shift: Jam $jamPulangStr\n'
                '• Durasi Berjalan: ${workedH}j ${workedM}m\n'
                '${remaining != null && remaining > Duration.zero ? '• Sisa Waktu Shift: ${remaining.inHours}j ${remaining.inMinutes.remainder(60)}m lagi\n\n' : '\n'}'
                'Absen pulang bisa dilakukan setelah jam $jamPulangStr atau setelah durasi shift selesai.',
                style: const TextStyle(fontSize: 13, height: 1.45),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Mengerti', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
          return;
        }
      }
    }

    setState(() {
      _tipeLaporan = tipe;
      if (tipe == 'Pulang') {
        _jamPulang = AbsensiSetupService.autoDetectJamPulang(shift: _selectedShift);
      }
    });
  }

  Future<void> _saveData() async {
    final tech = _teknisiCtrl.text.trim();
    if (tech.isEmpty) {
      setState(() {
        _teknisiError = 'Nama teknisi wajib diisi';
      });
      HapticFeedback.heavyImpact();
      return;
    }

    setState(() {
      _teknisiError = null;
      _isSaving = true;
    });

    StorageService.saveLastTechnicianName(tech);
    AuthRepository.instance.syncTechnicianName(tech);

    // Lokasi standby: pakai isian teknisi (Bali bisa isi manual). Kosong baru pakai default cabang.
    final branch = BranchService.instance.currentBranch;
    final lokasiStandby = _lokasiStandby.trim().isEmpty
        ? branch.defaultLocationTag
        : _lokasiStandby.trim().toUpperCase();
    _lokasiStandby = lokasiStandby;
    _lokasiCtrl.text = lokasiStandby;
    setup.updateLokasi(lokasiStandby);

    // Sinkronkan pos ke LocationService kalau tag-nya dikenali (geo tetap akurat).
    final matchedPos = LocationService.findPosByTagOrName(lokasiStandby) ??
        LocationService.findPosByTagOrName(branch.defaultLocationTag);
    if (matchedPos != null) {
      LocationService.setCurrentPos(matchedPos);
      LocationService.clearLocationCache();
    }

    setup.updateShift(_selectedShift);

    // Double check agar tidak tersimpan tipe Pulang jika belum memenuhi syarat (kecuali QA bypass)
    if (_tipeLaporan == 'Pulang' && !StorageService.isSpvQaBypassActive()) {
      final lastCheck = StorageService.getLastCheckInTime();
      if (lastCheck != null &&
          !AbsensiSetupService.isEligibleForAutoPulang(
            shift: _selectedShift,
            checkInTime: lastCheck,
          )) {
        _tipeLaporan = 'Masuk';
      }
    }

    setup.updateTipe(_tipeLaporan);
    setup.updateJamPulang(_jamPulang);

    // Shift selanjutnya
    if (_adaShiftSelanjutnya) {
      final val = _petugasNextShiftCtrl.text.trim();
      setup.updateNextShift(val.isNotEmpty ? val : 'Petugas Shift Pengganti');
    } else {
      setup.updateNextShift('-');
    }

    // Pekerjaan selesai manual
    final selesaiManual = _pekerjaanSelesaiCtrl.text.trim();
    if (selesaiManual.isNotEmpty && selesaiManual != '-') {
      final autoNumbered = WhatsAppReportService.formatAutoNumberedList(selesaiManual);
      setup.updatePekerjaanSelesai(autoNumbered);
    } else {
      setup.updatePekerjaanSelesai('-');
    }

    // Pekerjaan belum selesai
    if (!_semuaPekerjaanSelesai) {
      final belum = _pekerjaanBelumCtrl.text.trim();
      setup.updatePekerjaanBelum(belum.isNotEmpty ? belum : '-');
    } else {
      setup.updatePekerjaanBelum('-');
    }

    HapticFeedback.mediumImpact();
    if (mounted) {
      Navigator.of(context).pop();
      widget.onSaved?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final maxDialogHeight = mediaQuery.size.height * 0.88;
    final isDark = ThemeService.isDarkMode(context);

    final dialogBg = isDark ? AppColors.darkSurface : Colors.white;
    final textTitle = isDark ? AppColors.textDarkPrimary : AppColors.textPrimary;
    final textSub = isDark ? AppColors.textDarkSecondary : AppColors.textSecondary;
    final headerBorder = isDark ? AppColors.darkBorder : AppColors.cardBorder;
    final inputBg = isDark ? AppColors.darkSurfaceContainer : AppColors.surfaceContainerLow;
    final inputBorderColor = isDark ? AppColors.darkBorderMuted : AppColors.cardBorder;
    final inputTextColor = isDark ? AppColors.textDarkPrimary : AppColors.textPrimary;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: dialogBg,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 440,
          maxHeight: maxDialogHeight,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // -----------------------------------------------------------------
            // HEADER: Bersih, taktil, ringkas, dengan semantic close button
            // -----------------------------------------------------------------
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 14),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: headerBorder, width: 1.5)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.schedule_rounded, color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Atur Shift & Absensi',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: textTitle,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Jadwal shift & Lokasi standby',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: textSub,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Tutup dialog',
                    constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                    icon: Icon(Icons.close_rounded, color: textSub, size: 22),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // -----------------------------------------------------------------
            // SCROLLABLE BODY
            // -----------------------------------------------------------------
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // SECTION 1: TEKNISI BERTUGAS
                    _buildSectionHeader(
                      icon: Icons.person_rounded,
                      title: 'TEKNISI BERTUGAS',
                      subtitle: 'Nama yang tercetak di watermark & laporan',
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _teknisiCtrl,
                      onChanged: (val) {
                        if (_teknisiError != null && val.trim().isNotEmpty) {
                          setState(() => _teknisiError = null);
                        }
                      },
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: inputTextColor,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Ketik nama teknisi',
                        errorText: _teknisiError,
                        prefixIcon: const Icon(Icons.badge_outlined, size: 20, color: AppColors.accent),
                        filled: true,
                        fillColor: inputBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: inputBorderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: _teknisiError != null ? AppColors.danger : const Color(0xFFF59E0B),
                            width: 1.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.accent, width: 2.0),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // SECTION 2: LOKASI STANDBY POS (Bali bisa diisi manual)
                    _buildLocationStandbyCard(),

                    const SizedBox(height: 16),

                    // SECTION 3: JADWAL SHIFT (FOKUS VISUAL UTAMA)
                    _buildSectionHeader(
                      icon: Icons.calendar_month_rounded,
                      title: 'PILIH JADWAL SHIFT',
                      subtitle: 'Jadwal shift teknisi',
                    ),
                    const SizedBox(height: 8),

                    // GRID SHIFT OPERASIONAL BSS (Responsive, scannable, dual-coding)
                    ...() {
                      final cards = _shiftCards;
                      final widgets = <Widget>[];
                      for (int i = 0; i < cards.length; i += 2) {
                        final c1 = cards[i];
                        final c2 = (i + 1 < cards.length) ? cards[i + 1] : null;
                        widgets.add(
                          Row(
                            children: [
                              Expanded(child: _buildShiftBentoCard(c1)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: c2 != null
                                    ? _buildShiftBentoCard(c2)
                                    : const SizedBox.shrink(),
                              ),
                            ],
                          ),
                        );
                        if (i + 2 < cards.length) {
                          widgets.add(const SizedBox(height: 8));
                        }
                      }
                      return widgets;
                    }(),

                    const SizedBox(height: 10),

                    // OPSI CUSTOM SHIFT (COMPACT SECONDARY CONTROL)
                    _buildCustomShiftControl(),

                    const SizedBox(height: 16),

                    // SECTION 4: JENIS LAPORAN ABSENSI (MASUK VS PULANG)
                    _buildSectionHeader(
                      icon: Icons.fact_check_outlined,
                      title: 'JENIS SHIFT',
                      subtitle: 'Jenis Shift',
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildAttendanceTypeCard(
                            label: 'Masuk',
                            sublabel: 'Mulai Kerja',
                            icon: Icons.login_rounded,
                            isSelected: _tipeLaporan == 'Masuk',
                            activeColor: AppColors.success,
                            onTap: () => _onTipeChanged('Masuk'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildAttendanceTypeCard(
                            label: 'Pulang',
                            sublabel: 'Selesai & Handover',
                            icon: Icons.logout_rounded,
                            isSelected: _tipeLaporan == 'Pulang',
                            activeColor: AppColors.accent,
                            onTap: () => _onTipeChanged('Pulang'),
                          ),
                        ),
                      ],
                    ),

                    // SECTION KHUSUS: LAPORAN PULANG & HANDOVER
                    if (_tipeLaporan == 'Pulang') ...[
                      const SizedBox(height: 14),
                      _buildPulangHandoverSection(),
                    ],
                  ],
                ),
              ),
            ),

            // -----------------------------------------------------------------
            // FOOTER ACTIONS (STICKY AT BOTTOM)
            // -----------------------------------------------------------------
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: headerBorder, width: 1.5)),
                color: dialogBg,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Tooltip(
                      message: 'Tutup tanpa menyimpan perubahan',
                      child: OutlinedButton(
                        onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(46),
                          side: const BorderSide(color: AppColors.cardBorder, width: 1.2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                        ),
                        child: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Batal',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Tooltip(
                      message: 'Simpan konfigurasi shift dan terapkan ke watermark',
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveData,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(46),
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 1.5,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                              )
                            : const FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check_rounded, size: 16),
                                    SizedBox(width: 4),
                                    Text(
                                      'Simpan Shift',
                                      style: TextStyle(
                                        fontFamily: 'PlusJakartaSans',
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // SUB-WIDGET BUILDERS & HELPERS
  // ===========================================================================

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final isDark = ThemeService.isDarkMode(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: isDark ? const Color(0xFF38BDF8) : AppColors.primary),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                color: isDark ? const Color(0xFFF8FAFC) : AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 1),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 10.5,
            color: isDark ? const Color(0xFF94A3B8) : AppColors.textMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  /// Kartu lokasi standby: hanya Manado yang dikunci ke pos default. Bali & HO
  /// bisa diisi manual karena teknisi sering standby di pos/lokasi lain.
  Widget _buildLocationStandbyCard() {
    if (BranchService.instance.currentBranch == AppBranch.manado) {
      return _buildFixedLocationCard();
    }

    final isDark = ThemeService.isDarkMode(context);
    final inputBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final inputBorderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: inputBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.storefront_outlined, size: 18, color: isDark ? const Color(0xFF38BDF8) : AppColors.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'LOKASI STANDBY',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: isDark ? const Color(0xFF94A3B8) : AppColors.textMuted,
                  ),
                ),
              ),
              Text(
                'Isi manual',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFF94A3B8) : AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('lokasi_standby_field'),
            controller: _lokasiCtrl,
            textCapitalization: TextCapitalization.characters,
            onChanged: (val) => setState(() => _lokasiStandby = val.trim().toUpperCase()),
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
            ),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Tag pos standby (mis. PBKD, PCD, PGA)',
              filled: true,
              fillColor: inputBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: inputBorderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: inputBorderColor),
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(10)),
                borderSide: BorderSide(color: AppColors.primary, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
          const SizedBox(height: 8),
          // Tap cepat tag pos cabang Bali; kolom tetap bisa diketik bebas.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final tag in BranchService.instance.getLocationTags())
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _buildLokasiChip(tag, isDark),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLokasiChip(String tag, bool isDark) {
    final isSelected = _lokasiStandby.trim().toUpperCase() == tag.toUpperCase();
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        _lokasiCtrl.text = tag;
        setState(() => _lokasiStandby = tag);
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: isDark ? 0.3 : 0.1)
              : (isDark ? const Color(0xFF0F172A) : Colors.white),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.primary : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          tag,
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
            color: isSelected
                ? (isDark ? const Color(0xFF93C5FD) : AppColors.primary)
                : (isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary),
          ),
        ),
      ),
    );
  }

  /// Compact, non-interactive fixed location card: LOKASI STANDBY -- PBM
  Widget _buildFixedLocationCard() {
    final isDark = ThemeService.isDarkMode(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.storefront_outlined, size: 18, color: isDark ? const Color(0xFF38BDF8) : AppColors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LOKASI STANDBY',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: isDark ? const Color(0xFF94A3B8) : AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  BranchService.instance.currentBranch == AppBranch.bali
                      ? 'PBKD'
                      : 'Pasar Bersehati Manado',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.5) : const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: isDark ? const Color(0xFF38BDF8) : const Color(0xFFBFDBFE)),
            ),
            child: Text(
              BranchService.instance.currentBranch.defaultLocationTag,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF1D4ED8),
                letterSpacing: 0.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShiftBentoCard(Map<String, String> shift) {
    final isDark = ThemeService.isDarkMode(context);
    final fullValue = shift['full']!;
    final isSelected = !_isCustomShift && _selectedShift.trim() == fullValue.trim();

    final unselectedBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    final selectedBg = isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.4) : const Color(0xFFEFF6FF);
    final borderColor = isSelected
        ? (isDark ? const Color(0xFF38BDF8) : AppColors.primary)
        : (isDark ? const Color(0xFF334155) : AppColors.cardBorder);
    final titleColor = isSelected
        ? (isDark ? const Color(0xFF38BDF8) : AppColors.primary)
        : (isDark ? const Color(0xFFF8FAFC) : AppColors.textPrimary);
    final hoursColor = isSelected
        ? (isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E3A8A))
        : (isDark ? const Color(0xFFCBD5E1) : AppColors.textSecondary);
    final periodColor = isSelected
        ? (isDark ? const Color(0xFF38BDF8) : AppColors.primary)
        : (isDark ? const Color(0xFF94A3B8) : AppColors.textMuted);

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        _onShiftSelected(fullValue);
      },
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        constraints: const BoxConstraints(minHeight: 68),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? selectedBg : unselectedBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: borderColor,
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    shift['title']!,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: titleColor,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                  size: 15,
                  color: isSelected ? (isDark ? const Color(0xFF38BDF8) : AppColors.primary) : (isDark ? const Color(0xFF64748B) : AppColors.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                shift['hours']!,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: hoursColor,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              shift['period']!,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w500,
                color: periodColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomShiftControl() {
    final isDark = ThemeService.isDarkMode(context);
    final cardBg = _isCustomShift
        ? (isDark ? const Color(0xFF78350F).withValues(alpha: 0.35) : const Color(0xFFFFFBEB))
        : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC));
    final cardBorder = _isCustomShift
        ? const Color(0xFFF59E0B)
        : (isDark ? const Color(0xFF334155) : AppColors.cardBorder);
    final titleColor = _isCustomShift
        ? const Color(0xFFF59E0B)
        : (isDark ? const Color(0xFFF8FAFC) : AppColors.textPrimary);
    final inputBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFFFFBEB);
    final inputBorder = isDark ? const Color(0xFF78350F) : const Color(0xFFFDE68A);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            _onCustomShiftToggled();
          },
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: cardBorder,
                width: _isCustomShift ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: _isCustomShift ? const Color(0xFFF59E0B) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.tune_rounded,
                    size: 13,
                    color: _isCustomShift ? Colors.white : (isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Custom Shift',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: titleColor,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'Atur Shift sendiri',
                        style: TextStyle(
                          fontSize: 10,
                          color: _isCustomShift ? const Color(0xFFF59E0B) : (isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _isCustomShift,
                  activeThumbColor: Colors.white,
                  activeTrackColor: const Color(0xFFF59E0B),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: (_) {
                    HapticFeedback.selectionClick();
                    _onCustomShiftToggled();
                  },
                ),
              ],
            ),
          ),
        ),
        if (_isCustomShift) ...[
          const SizedBox(height: 8),
          // Dua kolom isian manual: nama shift dan jamnya.
          _buildCustomShiftField(
            label: 'Shift :',
            fieldKey: const Key('custom_shift_nama'),
            controller: _customShiftCtrl,
            hint: 'Nama shift (mis. Shift Khusus)',
            isDark: isDark,
            inputBg: inputBg,
            inputBorder: inputBorder,
          ),
          const SizedBox(height: 6),
          _buildCustomShiftField(
            label: 'Jam :',
            fieldKey: const Key('custom_shift_jam'),
            controller: _customShiftJamCtrl,
            hint: 'Jam kerja (mis. 08:00 - 17:00)',
            isDark: isDark,
            inputBg: inputBg,
            inputBorder: inputBorder,
          ),
        ],
      ],
    );
  }

  Widget _buildCustomShiftField({
    required String label,
    required Key fieldKey,
    required TextEditingController controller,
    required String hint,
    required bool isDark,
    required Color inputBg,
    required Color inputBorder,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 52,
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: isDark ? const Color(0xFFF8FAFC) : AppColors.textPrimary,
            ),
          ),
        ),
        Expanded(
          child: TextField(
            key: fieldKey,
            controller: controller,
            onChanged: (_) => _onCustomShiftChanged(),
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : AppColors.primary,
            ),
            decoration: InputDecoration(
              isDense: true,
              hintText: hint,
              filled: true,
              fillColor: inputBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: inputBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: inputBorder),
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(10)),
                borderSide: BorderSide(color: Color(0xFFF59E0B), width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAttendanceTypeCard({
    required String label,
    required String sublabel,
    required IconData icon,
    required bool isSelected,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    final isDark = ThemeService.isDarkMode(context);
    final cardBg = isSelected
        ? activeColor.withValues(alpha: isDark ? 0.2 : 0.08)
        : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC));
    final cardBorder = isSelected
        ? activeColor
        : (isDark ? const Color(0xFF334155) : AppColors.cardBorder);
    final textColor = isSelected
        ? activeColor
        : (isDark ? const Color(0xFFF8FAFC) : AppColors.textPrimary);
    final iconBg = isSelected
        ? activeColor
        : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0));
    final iconColor = isSelected
        ? Colors.white
        : (isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary);

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: cardBorder,
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconBg,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 16,
                color: iconColor,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          label,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: textColor,
                          ),
                        ),
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: 4),
                        Icon(Icons.check_circle_rounded, size: 13, color: activeColor),
                      ],
                    ],
                  ),
                  const SizedBox(height: 1),
                  Text(
                    sublabel,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w500,
                      color: isSelected ? activeColor.withValues(alpha: 0.9) : (isDark ? const Color(0xFF94A3B8) : AppColors.textMuted),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPulangHandoverSection() {
    final isDark = ThemeService.isDarkMode(context);
    final sectionBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFFFFBEB);
    final sectionBorder = isDark ? const Color(0xFF334155) : const Color(0xFFFDE68A);
    final innerCardBg = isDark ? const Color(0xFF0B1120) : Colors.white;
    final innerCardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFFDE68A);
    final inputBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    final inputBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textHeader = isDark ? const Color(0xFFF59E0B) : const Color(0xFF92400E);
    final textTitle = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF1E293B);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: sectionBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: sectionBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.handshake_outlined, size: 16, color: isDark ? const Color(0xFFF59E0B) : const Color(0xFFB45309)),
              const SizedBox(width: 6),
              Text(
                'Handover & Laporan Pulang',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: textHeader,
                ),
              ),
              const Spacer(),
              Text(
                'Jam Pulang: $_jamPulang WITA',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: isDark ? const Color(0xFFF59E0B) : const Color(0xFFB45309),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // TOGGLE SHIFT SELANJUTNYA
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: innerCardBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: innerCardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Ada Rekan Shift Berikutnya?',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: textTitle),
                    ),
                    Switch(
                      value: _adaShiftSelanjutnya,
                      activeThumbColor: Colors.white,
                      activeTrackColor: const Color(0xFFD97706),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onChanged: (val) {
                        setState(() {
                          _adaShiftSelanjutnya = val;
                        });
                      },
                    ),
                  ],
                ),
                if (_adaShiftSelanjutnya) ...[
                  const Divider(height: 8),
                  const SizedBox(height: 4),
                  Text(
                    'Pilih / Ketik Nama Rekan Pengganti:',
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _petugasNextShiftCtrl,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Nama rekan shift berikutnya',
                      prefixIcon: const Icon(Icons.person_outline, size: 16, color: Color(0xFFD97706)),
                      filled: true,
                      fillColor: inputBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: inputBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: inputBorder),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: _rekanItOptions.map((name) {
                      final isSelected = _petugasNextShiftCtrl.text.trim().toLowerCase() == name.toLowerCase();
                      return InkWell(
                        onTap: () {
                          setState(() {
                            _petugasNextShiftCtrl.text = name;
                          });
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFFD97706)
                                : (isDark ? const Color(0xFF1E293B) : Colors.white),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFFD97706)
                                  : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                            ),
                          ),
                          child: Text(
                            name,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected
                                  ? Colors.white
                                  : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 4),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),

          // FORM PEKERJAAN SELESAI
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: innerCardBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: innerCardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.check_circle_outline, size: 14, color: AppColors.success),
                    const SizedBox(width: 4),
                    Text(
                      'Pekerjaan Selesai Hari Ini:',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: textTitle),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _pekerjaanSelesaiCtrl,
                  maxLines: 3,
                  style: TextStyle(fontSize: 11.5, height: 1.3, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Tulis ringkasan tugas selesai...\nTekan enter untuk penomoran otomatis (1. 2. 3.)',
                    hintStyle: TextStyle(fontSize: 10.5, color: isDark ? const Color(0xFF64748B) : AppColors.textMuted),
                    filled: true,
                    fillColor: inputBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: inputBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: inputBorder),
                    ),
                    contentPadding: const EdgeInsets.all(8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // TOGGLE & FORM PEKERJAAN BELUM SELESAI
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: innerCardBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: innerCardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Semua Tugas Beres?',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: textTitle),
                    ),
                    Switch(
                      value: _semuaPekerjaanSelesai,
                      activeThumbColor: Colors.white,
                      activeTrackColor: AppColors.success,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onChanged: (val) {
                        setState(() {
                          _semuaPekerjaanSelesai = val;
                          if (val) {
                            _pekerjaanBelumCtrl.clear();
                          }
                        });
                      },
                    ),
                  ],
                ),
                if (!_semuaPekerjaanSelesai) ...[
                  const Divider(height: 8),
                  const SizedBox(height: 4),
                  const Row(
                    children: [
                      Icon(Icons.pending_actions_outlined, size: 14, color: AppColors.danger),
                      SizedBox(width: 4),
                      Text(
                        'Pekerjaan Pending / PR:',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.danger),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _pekerjaanBelumCtrl,
                    maxLines: 2,
                    style: TextStyle(fontSize: 11.5, height: 1.3, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Tulis tugas pending untuk rekan berikutnya...',
                      hintStyle: TextStyle(fontSize: 10.5, color: isDark ? const Color(0xFF64748B) : AppColors.textMuted),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFFFF1F2),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFECDD3)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFECDD3)),
                      ),
                      contentPadding: const EdgeInsets.all(8),
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
