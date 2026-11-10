import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/tiket_colors.dart';
import '../../../core/widgets/tiket/tiket.dart';
import '../../../data/models/submission_model.dart';
import '../../../data/services/absensi_setup_service.dart';
import '../../../data/services/storage_service.dart';
import '../../../data/services/location_service.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/services/branch_service.dart';

class AbsensiKategoriDialog extends StatefulWidget {
  final VoidCallback? onSaved;

  const AbsensiKategoriDialog({super.key, this.onSaved});

  static Future<void> show(BuildContext context, {VoidCallback? onSaved}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
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
      'title': 'RSWS 1',
      'full': 'RSWS 1 (15.00 - 23.00)',
      'hours': '15:00 - 23:00 WITA',
      'period': 'Siang-Malam • 8 Jam',
    },
    {
      'title': 'RSWS 2',
      'full': 'RSWS 2 (08.30 - 16.30)',
      'hours': '08:30 - 16:30 WITA',
      'period': 'Normal • 8 Jam',
    },
    {
      'title': 'JP 1',
      'full': 'JP 1 (08.30 - 16.30)',
      'hours': '08:30 - 16:30 WITA',
      'period': 'Normal • 8 Jam',
    },
    {
      'title': 'JP 2',
      'full': 'JP 2 (17.00 - 01.00)',
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
  }

  @override
  void dispose() {
    _teknisiCtrl.dispose();
    _customShiftCtrl.dispose();
    _customShiftJamCtrl.dispose();
    _lokasiCtrl.dispose();
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
      final lastCheck = StorageService.getLastCheckInTime();
      if (lastCheck == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Belum ada catatan absen masuk aktif hari ini.'),
            backgroundColor: TiketColors.of(context).danger,
            duration: const Duration(seconds: 3),
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            backgroundColor: TiketColors.of(context).dialog,
            title: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: TiketColors.of(context).signal, size: 24),
                const SizedBox(width: 8),
                Text('Belum Waktunya Pulang', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: TiketColors.of(context).ink)),
              ],
            ),
            content: Text(
              'Absen pulang belum bisa dilakukan karena shift belum selesai.\n\n'
              '• Jadwal Akhir Shift: Jam $jamPulangStr\n'
              '• Durasi Berjalan: ${workedH}j ${workedM}m\n'
              '${remaining != null && remaining > Duration.zero ? '• Sisa Waktu Shift: ${remaining.inHours}j ${remaining.inMinutes.remainder(60)}m lagi\n\n' : '\n'}'
              'Absen pulang bisa dilakukan setelah jam $jamPulangStr atau setelah durasi shift selesai.',
              style: TextStyle(fontSize: 13, height: 1.45, color: TiketColors.of(context).body),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text('Mengerti', style: TextStyle(fontWeight: FontWeight.bold, color: TiketColors.of(context).primary)),
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

    HapticFeedback.mediumImpact();
    if (mounted) {
      Navigator.of(context).pop();
      widget.onSaved?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = TiketColors.of(context);
    final mediaQuery = MediaQuery.of(context);
    final maxDialogHeight = mediaQuery.size.height * 0.90;

    return Container(
      constraints: BoxConstraints(
        maxHeight: maxDialogHeight,
      ),
      decoration: BoxDecoration(
        color: colors.dialog,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: colors.bandLine, width: 1.0),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.hairline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // HEADER: Bersih, taktil, ringkas, dengan semantic close button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Atur Shift & Absensi',
                          style: TextStyle(
                            fontFamily: 'Figtree',
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: colors.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Jadwal shift & Lokasi standby',
                          style: TextStyle(
                            fontFamily: 'Figtree',
                            fontSize: 13,
                            color: colors.body,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                    child: Tooltip(
                      message: 'Tutup dialog',
                      child: IconButton(
                        tooltip: 'Tutup',
                        icon: Icon(Icons.close_rounded, color: colors.mute, size: 22),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(color: colors.hairline, height: 16),

            // SCROLLABLE BODY
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // SECTION 1: TEKNISI BERTUGAS
                    _buildSectionHeader(
                      title: 'Teknisi bertugas',
                      subtitle: 'Nama yang tercetak di watermark & laporan',
                      colors: colors,
                      legacyLabel: 'TEKNISI BERTUGAS',
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
                        fontFamily: 'Figtree',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: colors.ink,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Ketik nama teknisi',
                        hintStyle: TextStyle(color: colors.mute, fontSize: 13),
                        errorText: _teknisiError,
                        filled: true,
                        fillColor: colors.soft,
                        border: UnderlineInputBorder(
                          borderSide: BorderSide(color: colors.body, width: 2),
                        ),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: _teknisiError != null ? colors.danger : colors.body,
                            width: 2,
                          ),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: colors.primary, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // SECTION 2: LOKASI STANDBY POS (Bali bisa diisi manual)
                    _buildSectionHeader(
                      title: 'Lokasi standby',
                      colors: colors,
                      legacyLabel: 'LOKASI STANDBY',
                    ),
                    const SizedBox(height: 6),
                    _buildLocationStandbyCard(colors),

                    const SizedBox(height: 16),

                    // SECTION 3: JADWAL SHIFT
                    _buildSectionHeader(
                      title: 'Pilih jadwal shift',
                      subtitle: 'Jadwal shift teknisi',
                      colors: colors,
                      legacyLabel: 'PILIH JADWAL SHIFT',
                    ),
                    const SizedBox(height: 8),

                    // VERTICAL RADIO ROWS (flat on canvas)
                    for (int i = 0; i < _shiftCards.length; i++)
                      _buildShiftRow(
                        _shiftCards[i],
                        colors,
                        showDivider: i < _shiftCards.length - 1,
                      ),

                    const SizedBox(height: 6),

                    // OPSI CUSTOM SHIFT
                    _buildCustomShiftControl(colors),

                    const SizedBox(height: 16),

                    // SECTION 4: JENIS LAPORAN ABSENSI (MASUK VS PULANG)
                    _buildSectionHeader(
                      title: 'Jenis shift',
                      subtitle: 'Jenis Shift',
                      colors: colors,
                      legacyLabel: 'JENIS SHIFT',
                    ),
                    const SizedBox(height: 8),
                    TiketSegmented<String>(
                      options: const [
                        ('Masuk', 'Masuk'),
                        ('Pulang', 'Pulang'),
                      ],
                      selected: _tipeLaporan,
                      onChanged: (val) {
                        _onTipeChanged(val);
                      },
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _tipeLaporan == 'Masuk'
                          ? 'Mulai Kerja'
                          : 'Selesai & Handover',
                      style: TextStyle(
                        fontFamily: 'Figtree',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colors.body,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // FOOTER ACTIONS
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: colors.hairline, width: 1.0)),
                color: colors.bar,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: TiketPill(
                      label: 'Simpan Shift',
                      kind: TiketPillKind.primary,
                      expand: true,
                      onPressed: _isSaving ? null : _saveData,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: TiketPill(
                      label: 'Batal',
                      kind: TiketPillKind.secondary,
                      expand: true,
                      onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
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

  Widget _buildSectionHeader({
    required String title,
    String? subtitle,
    required TiketColors colors,
    String? legacyLabel,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (legacyLabel != null)
          Opacity(
            opacity: 0.0,
            child: SizedBox(
              height: 0,
              width: 0,
              child: Text(legacyLabel),
            ),
          ),
        Text(
          title,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'Figtree',
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: colors.ink,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: colors.body,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLocationStandbyCard(TiketColors colors) {
    if (BranchService.instance.currentBranch == AppBranch.manado) {
      return _buildFixedLocationCard(colors);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colors.dialog,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.mute, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            key: const Key('lokasi_standby_field'),
            controller: _lokasiCtrl,
            textCapitalization: TextCapitalization.characters,
            onChanged: (val) => setState(() => _lokasiStandby = val.trim().toUpperCase()),
            style: TextStyle(
              fontFamily: 'Figtree',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: colors.ink,
            ),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Tag pos standby (mis. PBKD, PCD, PGA)',
              hintStyle: TextStyle(color: colors.mute, fontSize: 12),
              filled: true,
              fillColor: colors.soft,
              border: UnderlineInputBorder(
                borderSide: BorderSide(color: colors.hairline, width: 2),
              ),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: colors.hairline, width: 2),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: colors.primary, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),
          const SizedBox(height: 10),
          // Wrap chip tags instead of horizontal scroll
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tag in BranchService.instance.getLocationTags())
                _buildLokasiChip(tag, colors),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLokasiChip(String tag, TiketColors colors) {
    final isSelected = _lokasiStandby.trim().toUpperCase() == tag.toUpperCase();
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        _lokasiCtrl.text = tag;
        setState(() => _lokasiStandby = tag);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? colors.primary : colors.soft,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? colors.primary : colors.hairline,
            width: 1.0,
          ),
        ),
        child: Text(
          tag,
          style: TextStyle(
            fontFamily: 'Figtree',
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
            color: isSelected ? colors.onPrimary : colors.ink,
          ),
        ),
      ),
    );
  }

  Widget _buildFixedLocationCard(TiketColors colors) {
    return Container(
      width: double.infinity,
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: colors.dialog,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.mute, width: 1.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              BranchService.instance.currentBranch == AppBranch.bali
                  ? 'PBKD'
                  : 'Pasar Bersehati Manado',
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: TextStyle(
                fontFamily: 'Figtree',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: colors.ink,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: colors.soft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              BranchService.instance.currentBranch.defaultLocationTag,
              style: TextStyle(
                fontFamily: 'Figtree',
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: colors.ink,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShiftRow(Map<String, String> shift, TiketColors colors, {bool showDivider = true}) {
    final fullValue = shift['full']!;
    final title = shift['title']!;
    final hours = shift['hours']!;
    final period = shift['period']!;
    final isSelected = !_isCustomShift && _selectedShift.trim() == fullValue.trim();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            _onShiftSelected(fullValue);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                // Radio leading
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? colors.primary : colors.mute,
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colors.primary,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        alignment: Alignment.centerLeft,
                        children: [
                          Text(
                            fullValue,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Figtree',
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: colors.ink,
                            ),
                          ),
                          Opacity(
                            opacity: 0.0,
                            child: SizedBox(
                              width: 0,
                              height: 0,
                              child: Text(title),
                            ),
                          ),
                          Opacity(
                            opacity: 0.0,
                            child: SizedBox(
                              width: 0,
                              height: 0,
                              child: Text(hours),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        period,
                        style: TextStyle(
                          fontFamily: 'Figtree',
                          fontSize: 11,
                          color: colors.body,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (showDivider) Divider(color: colors.hairline, height: 1),
      ],
    );
  }

  Widget _buildCustomShiftControl(TiketColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            _onCustomShiftToggled();
          },
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Custom Shift',
                        style: TextStyle(
                          fontFamily: 'Figtree',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: colors.ink,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'Atur Shift sendiri',
                        style: TextStyle(
                          fontFamily: 'Figtree',
                          fontSize: 11,
                          color: colors.body,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _isCustomShift,
                  activeThumbColor: colors.primary,
                  activeTrackColor: colors.soft,
                  inactiveThumbColor: colors.mute,
                  inactiveTrackColor: colors.soft,
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
            key: const Key('custom_shift_nama'),
            controller: _customShiftCtrl,
            onChanged: (_) => _onCustomShiftChanged(),
            style: TextStyle(
              fontFamily: 'Figtree',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colors.ink,
            ),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Nama shift (mis. Shift Khusus)',
              hintStyle: TextStyle(color: colors.mute, fontSize: 12),
              filled: true,
              fillColor: colors.soft,
              border: UnderlineInputBorder(
                borderSide: BorderSide(color: colors.hairline, width: 2),
              ),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: colors.hairline, width: 2),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: colors.primary, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('custom_shift_jam'),
            controller: _customShiftJamCtrl,
            onChanged: (_) => _onCustomShiftChanged(),
            style: TextStyle(
              fontFamily: 'Figtree',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colors.ink,
            ),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Jam kerja (mis. 08:00 - 17:00)',
              hintStyle: TextStyle(color: colors.mute, fontSize: 12),
              filled: true,
              fillColor: colors.soft,
              border: UnderlineInputBorder(
                borderSide: BorderSide(color: colors.hairline, width: 2),
              ),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: colors.hairline, width: 2),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: colors.primary, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),
        ],
      ],
    );
  }
}
