import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/submission_model.dart';
import '../../../data/services/absensi_setup_service.dart';
import '../../../data/services/storage_service.dart';
import '../../../data/services/whatsapp_report_service.dart';
import '../../../data/services/location_service.dart';
import '../../../data/repositories/auth_repository.dart';

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
  bool _isCustomShift = false;
  late String _selectedShift;
  late String _tipeLaporan;
  late String _jamPulang;

  // Toggle & input state untuk Laporan Pulang
  bool _adaShiftSelanjutnya = false;
  late TextEditingController _petugasNextShiftCtrl;
  late TextEditingController _pekerjaanSelesaiCtrl;
  bool _semuaPekerjaanSelesai = true;
  late TextEditingController _pekerjaanBelumCtrl;

  // Validation & saving state
  String? _teknisiError;
  bool _isSaving = false;

  static const List<Map<String, String>> _shiftCards = [
    {
      'title': 'Shift 1',
      'full': 'Shift 1 (03:00 - 11:00)',
      'hours': '03:00 – 11:00 WITA',
      'period': 'Pagi • 8 Jam',
    },
    {
      'title': 'Shift 2',
      'full': 'Shift 2 (10:00 - 18:00)',
      'hours': '10:00 – 18:00 WITA',
      'period': 'Siang • 8 Jam',
    },
    {
      'title': 'Shift 2.2',
      'full': 'Shift 2.2 (10:00 - 14:00)',
      'hours': '10:00 – 14:00 WITA',
      'period': 'Paruh Waktu • 4 Jam',
    },
    {
      'title': 'Shift 3',
      'full': 'Shift 3 (14:00 - 22:00)',
      'hours': '14:00 – 22:00 WITA',
      'period': 'Sore-Malam • 8 Jam',
    },
  ];

  static const List<String> _rekanItOptions = [
    'Junifer Manua',
    'Ryan Lumasuge',
    'Alessandro Sulistyo',
    'Raldy Sangkop',
  ];

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
    _customShiftCtrl = TextEditingController(text: _isCustomShift ? _selectedShift : '');

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

  void _onCustomShiftToggled() {
    setState(() {
      _isCustomShift = !_isCustomShift;
      if (_isCustomShift) {
        if (_customShiftCtrl.text.trim().isNotEmpty) {
          _selectedShift = _customShiftCtrl.text.trim();
          _jamPulang = AbsensiSetupService.autoDetectJamPulang(shift: _selectedShift);
        } else {
          _selectedShift = 'Shift Khusus';
          _customShiftCtrl.text = 'Shift Khusus';
          _jamPulang = '18:00';
        }
      } else {
        _selectedShift = _shiftCards[0]['full']!;
        _jamPulang = AbsensiSetupService.autoDetectJamPulang(shift: _selectedShift);
      }
    });
  }

  void _onCustomShiftChanged(String val) {
    setState(() {
      _selectedShift = val.trim().isNotEmpty ? val.trim() : 'Shift Khusus';
      _jamPulang = AbsensiSetupService.autoDetectJamPulang(shift: _selectedShift);
    });
  }

  void _onTipeChanged(String tipe) {
    if (tipe == 'Pulang') {
      final lastCheck = StorageService.getLastCheckInTime();
      if (lastCheck == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Anda belum memiliki catatan absensi masuk aktif hari ini.'),
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
                Text('Belum Memenuhi Syarat Pulang', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Text(
              'Absensi kepulangan belum diizinkan karena shift belum berakhir.\n\n'
              '• Jadwal Akhir Shift: Jam $jamPulangStr\n'
              '• Durasi Berjalan: ${workedH}j ${workedM}m\n'
              '${remaining != null && remaining > Duration.zero ? '• Sisa Durasi Normal: ${remaining.inHours}j ${remaining.inMinutes.remainder(60)}m lagi\n\n' : '\n'}'
              'SOP BSS mewajibkan teknisi berada di pos hingga jam shift selesai ($jamPulangStr) atau durasi kerja terpenuhi.',
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

    // KUNCI LOKASI STANDBY PERMANEN KE PBM (POS-PBM-01)
    const fixedPosTag = 'PBM';
    setup.updateLokasi(fixedPosTag);

    // Sinkronkan ke LocationService menggunakan data resmi PBM
    final matchedPos = LocationService.findPosByTagOrName(fixedPosTag) ??
        LocationService.availablePosList.firstWhere(
          (p) => p.locationTag.toUpperCase() == fixedPosTag || p.posId == 'POS-PBM-01',
          orElse: () => LocationService.availablePosList.first,
        );
    LocationService.setCurrentPos(matchedPos);
    LocationService.clearLocationCache();

    setup.updateShift(_selectedShift);

    // Double check agar tidak tersimpan tipe Pulang jika belum memenuhi syarat
    if (_tipeLaporan == 'Pulang') {
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

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
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
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1.5)),
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
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Atur Shift & Absensi',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Jadwal kerja & status dinas teknisi',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Tutup dialog',
                    constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                    icon: const Icon(Icons.close_rounded, color: AppColors.textMuted, size: 22),
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
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Ketik nama teknisi',
                        errorText: _teknisiError,
                        prefixIcon: const Icon(Icons.badge_outlined, size: 20, color: AppColors.accent),
                        filled: true,
                        fillColor: const Color(0xFFFFFBEB),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFFDE68A)),
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

                    // SECTION 2: LOKASI STANDBY POS (PERMANEN PBM)
                    _buildFixedLocationCard(),

                    const SizedBox(height: 16),

                    // SECTION 3: JADWAL SHIFT (FOKUS VISUAL UTAMA)
                    _buildSectionHeader(
                      icon: Icons.calendar_month_rounded,
                      title: 'PILIH JADWAL SHIFT',
                      subtitle: 'Jadwal operasional BSS',
                    ),
                    const SizedBox(height: 8),

                    // GRID 2x2 SHIFT OPERASIONAL BSS (Responsive, scannable, dual-coding)
                    Row(
                      children: [
                        Expanded(child: _buildShiftBentoCard(_shiftCards[0])),
                        const SizedBox(width: 8),
                        Expanded(child: _buildShiftBentoCard(_shiftCards[1])),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: _buildShiftBentoCard(_shiftCards[2])),
                        const SizedBox(width: 8),
                        Expanded(child: _buildShiftBentoCard(_shiftCards[3])),
                      ],
                    ),

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
                            sublabel: 'Check In Awal Dinas',
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
                            sublabel: 'Check Out & Handover',
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
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFF1F5F9), width: 1.5)),
                color: Colors.white,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 1),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 10.5,
            color: AppColors.textMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  /// Compact, non-interactive fixed location card: LOKASI STANDBY -- PBM
  Widget _buildFixedLocationCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.storefront_outlined, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 10),
          const Expanded(
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
                    color: AppColors.textMuted,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Pasar Bersehati Manado',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: const Text(
              'PBM',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1D4ED8),
                letterSpacing: 0.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShiftBentoCard(Map<String, String> shift) {
    final fullValue = shift['full']!;
    final isSelected = !_isCustomShift && _selectedShift.trim() == fullValue.trim();

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
          color: isSelected ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.cardBorder,
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
                      color: isSelected ? AppColors.primary : AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                  size: 15,
                  color: isSelected ? AppColors.primary : AppColors.textMuted,
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
                  color: isSelected ? const Color(0xFF1E3A8A) : AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              shift['period']!,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w500,
                color: isSelected ? AppColors.primary : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomShiftControl() {
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
              color: _isCustomShift ? const Color(0xFFFFFBEB) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _isCustomShift ? const Color(0xFFF59E0B) : AppColors.cardBorder,
                width: _isCustomShift ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: _isCustomShift ? const Color(0xFFF59E0B) : const Color(0xFFE2E8F0),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.tune_rounded,
                    size: 13,
                    color: _isCustomShift ? Colors.white : AppColors.textSecondary,
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
                          color: _isCustomShift ? const Color(0xFF92400E) : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'Atur Shift sendiri',
                        style: TextStyle(
                          fontSize: 10,
                          color: _isCustomShift ? const Color(0xFFB45309) : AppColors.textSecondary,
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
          TextField(
            controller: _customShiftCtrl,
            onChanged: _onCustomShiftChanged,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Tulis nama shift & jam (contoh: Shift Khusus 08:00 - 17:00)',
              prefixIcon: const Icon(Icons.edit_calendar_rounded, size: 18, color: Color(0xFFF59E0B)),
              filled: true,
              fillColor: const Color(0xFFFFFBEB),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFFDE68A)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFFDE68A)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFF59E0B), width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ],
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
          color: isSelected ? activeColor.withValues(alpha: 0.08) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? activeColor : AppColors.cardBorder,
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected ? activeColor : const Color(0xFFE2E8F0),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : AppColors.textSecondary,
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
                            color: isSelected ? activeColor : AppColors.textPrimary,
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
                      color: isSelected ? activeColor.withValues(alpha: 0.9) : AppColors.textMuted,
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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.handshake_outlined, size: 16, color: Color(0xFFB45309)),
              const SizedBox(width: 6),
              const Text(
                'Laporan Kepulangan & Handover Pos',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF92400E),
                ),
              ),
              const Spacer(),
              Text(
                'Jam Pulang: $_jamPulang WITA',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFB45309),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // TOGGLE SHIFT SELANJUTNYA
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Ada IT Support Shift Selanjutnya?',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
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
                  const Text(
                    'Pilih atau Ketik Nama Petugas Pengganti:',
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _petugasNextShiftCtrl,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Nama rekan kerja pengganti shift',
                      prefixIcon: const Icon(Icons.person_outline, size: 16, color: Color(0xFFD97706)),
                      filled: true,
                      fillColor: const Color(0xFFFFFBEB),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFFDE68A)),
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
                            color: isSelected ? const Color(0xFFD97706) : Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isSelected ? const Color(0xFFD97706) : const Color(0xFFCBD5E1),
                            ),
                          ),
                          child: Text(
                            name,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? Colors.white : const Color(0xFF334155),
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
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.check_circle_outline, size: 14, color: AppColors.success),
                    SizedBox(width: 4),
                    Text(
                      'Pekerjaan Selesai Hari Ini:',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _pekerjaanSelesaiCtrl,
                  maxLines: 3,
                  style: const TextStyle(fontSize: 11.5, height: 1.3),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Tulis ringkasan tugas selesai...\nTekan enter untuk nomor baru otomatis (1. 2. 3.)',
                    hintStyle: const TextStyle(fontSize: 10.5, color: AppColors.textMuted),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
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
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Semua Pekerjaan Tuntas?',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
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
                        'Pekerjaan Belum Selesai (Pending/PR):',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.danger),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _pekerjaanBelumCtrl,
                    maxLines: 2,
                    style: const TextStyle(fontSize: 11.5, height: 1.3),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Tulis tugas tertunda untuk diserahterimakan...',
                      hintStyle: const TextStyle(fontSize: 10.5, color: AppColors.textMuted),
                      filled: true,
                      fillColor: const Color(0xFFFFF1F2),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFFECDD3)),
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
