import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/tiket_colors.dart';
import '../../../core/services/theme_service.dart';
import '../../../core/widgets/tiket/tiket.dart';
import '../../../data/models/template_model.dart';
import '../../../data/services/location_service.dart';
import '../../../data/services/branch_service.dart';
import '../../../data/services/storage_service.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/template_repository.dart';
import '../screens/maintenance_checklist_screen.dart';

class MaintenanceSetupDialog extends StatefulWidget {
  final TemplateModel initialTemplate;
  final String? dailyTaskId;
  final PosLocation? initialLocation;
  final VoidCallback? onChecklistFinished;

  const MaintenanceSetupDialog({
    super.key,
    required this.initialTemplate,
    this.dailyTaskId,
    this.initialLocation,
    this.onChecklistFinished,
  });

  @override
  State<MaintenanceSetupDialog> createState() => _MaintenanceSetupDialogState();
}

class _MaintenanceSetupDialogState extends State<MaintenanceSetupDialog> {
  late PosLocation _selectedLocation;
  late TextEditingController _supportNameController;
  int _startUnit = 1;
  int _endUnit = 1;
  final Map<int, String> _gateRoles =
      {}; // {1: 'IN', 2: 'OUT'} — opsional, khusus barrier gate
  String _manlessRole = 'IN'; // 'IN' | 'OUT' | 'PEP' — khusus Maintenance Manless
  bool _isOnlyKasir = false;
  bool _isBooth = false; // Khusus Pos Parkir & Booth: false = POS Kasir, true = Booth
  bool _isServerKasirTerpisah =
      true; // ON = Terpisah, OFF = Gabung (1 Komputer)
  bool get _isServerKasirGabung => !_isServerKasirTerpisah;
  int _kasirCount = 1;
  String _serverOs = 'linux'; // 'linux' | 'windows'

  // Khusus Maintenance Lengkap: cakupan area + unit per area
  final Set<int> _manlessUnitsSel = {1, 2};
  final Set<int> _posUnitsSel = {1};
  bool _includeServer = false;

  bool get _isLengkap =>
      widget.initialTemplate.jenis == TemplateCategory.maintLengkap;
  List<int> get _manlessUnits => _manlessUnitsSel.toList()..sort();
  List<int> get _posUnits => _posUnitsSel.toList()..sort();

  @override
  void initState() {
    super.initState();
    final available = LocationService.availablePosList;
    if (widget.initialLocation != null) {
      final found = available
          .where((p) => p.posId == widget.initialLocation!.posId)
          .firstOrNull;
      _selectedLocation = found ?? LocationService.currentPos;
    } else {
      _selectedLocation = LocationService.currentPos;
    }
    // Sinkronkan lokasi aktif ke LocationService
    LocationService.setCurrentPos(_selectedLocation);
    LocationService.clearLocationCache();

    // Pre-fill nama teknisi dari histori terakhir atau akun yang sedang aktif
    final lastTech = StorageService.getLastTechnicianName().trim();
    final currentUserName =
        AuthRepository.instance.currentUser?.nama.trim() ?? '';
    final initialName = lastTech.isNotEmpty
        ? lastTech
        : (currentUserName.isNotEmpty ? currentUserName : '');
    _supportNameController = TextEditingController(text: initialName);

    // Default hitungan wajar awal
    final cat = widget.initialTemplate.jenis;
    if (cat == TemplateCategory.maintBarrier) {
      _startUnit = 1;
      _endUnit = 2;
    } else if (cat == TemplateCategory.maintManless) {
      _startUnit = 1;
      _endUnit = 1;
    } else if (cat == TemplateCategory.maintPos) {
      _startUnit = 1;
      _endUnit = 3;
    } else if (cat == TemplateCategory.maintServer) {
      _startUnit = 1;
      _endUnit = 1;
      _isOnlyKasir = false;
      _isServerKasirTerpisah = true;
      _kasirCount = 1;
    } else if (cat == TemplateCategory.maintLengkap) {
      // Default wajar: 2 gate + 2 manless + 1 pos, PC Server opsional
      _startUnit = 1;
      _endUnit = 2;
    }
  }

  @override
  void dispose() {
    _supportNameController.dispose();
    super.dispose();
  }

  List<int> get _unitNumbers {
    if (widget.initialTemplate.jenis == TemplateCategory.maintServer) {
      if (_isOnlyKasir) {
        return List.generate(_kasirCount, (i) => i + 1);
      }
      if (_isServerKasirGabung) {
        return [1];
      } else {
        return List.generate(1 + _kasirCount, (i) => i + 1);
      }
    }
    return [for (int i = _startUnit; i <= _endUnit; i++) i];
  }

  String get _unitNoun {
    switch (widget.initialTemplate.jenis) {
      case TemplateCategory.maintPos:
        return _isBooth ? 'Booth' : 'Pos';
      case TemplateCategory.maintBarrier:
        return 'Gate';
      case TemplateCategory.maintManless:
        return 'Manless';
      case TemplateCategory.maintLengkap:
        return 'Gate';
      default:
        return 'Unit';
    }
  }

  String get _unitTitle {
    switch (widget.initialTemplate.jenis) {
      case TemplateCategory.maintBarrier:
        return 'Pilih Barrier Gate';
      case TemplateCategory.maintManless:
        return 'Pilih Dispenser Manless';
      case TemplateCategory.maintPos:
        return _isBooth ? 'Pilih Booth Maintenance' : 'Pilih Pos Maintenance';
      case TemplateCategory.maintLengkap:
        return 'Pilih Barrier Gate (area 1 dari Maintenance Lengkap)';
      case TemplateCategory.maintServer:
        return _isOnlyKasir
            ? 'Maintenance: Kasir'
            : 'Maintenance: Server & Kasir';
      default:
        return 'Pilih Unit Maintenance';
    }
  }

  String get _unitSubtitle {
    switch (widget.initialTemplate.jenis) {
      case TemplateCategory.maintBarrier:
        return 'Pilih gate yang dicek (9 foto/gate)';
      case TemplateCategory.maintManless:
        return 'Pilih manless yang dicek ($_pointsPerUnit foto/unit)';
      case TemplateCategory.maintPos:
        return _isBooth
            ? 'Pilih booth yang dicek (5 foto/booth)'
            : 'Pilih pos yang dicek (9 foto/pos)';
      case TemplateCategory.maintLengkap:
        return 'Cek gate dulu (9 foto/gate), lalu atur Manless & Pos di bawah';
      case TemplateCategory.maintServer:
        return _isOnlyKasir ? 'Cek PC Kasir' : 'Cek PC Server & PC Kasir';
      default:
        return 'Pilih unit yang dicek';
    }
  }

  IconData get _unitIcon {
    switch (widget.initialTemplate.jenis) {
      case TemplateCategory.maintBarrier:
        return Icons.fence_outlined;
      case TemplateCategory.maintManless:
        return Icons.point_of_sale_outlined;
      case TemplateCategory.maintPos:
        return _isBooth
            ? Icons.storefront_outlined
            : Icons.home_repair_service_outlined;
      case TemplateCategory.maintLengkap:
        return Icons.cleaning_services_rounded;
      case TemplateCategory.maintServer:
        return _isOnlyKasir
            ? Icons.point_of_sale_rounded
            : Icons.computer_outlined;
      default:
        return Icons.build_rounded;
    }
  }

  int get _pointsPerUnit {
    switch (widget.initialTemplate.jenis) {
      case TemplateCategory.maintBarrier:
        return 9;
      case TemplateCategory.maintManless:
        return _manlessPointsPerUnit;
      case TemplateCategory.maintPos:
        return _isBooth
            ? TemplateRepository.boothParkirPoints.length
            : (widget.initialTemplate.sopPoints.isNotEmpty
                  ? widget.initialTemplate.sopPoints.length
                  : 9);
      case TemplateCategory.maintLengkap:
        return 9; // 9 poin per gate; total lengkap dihitung di _totalPoints
      case TemplateCategory.maintServer:
        return 6;
      default:
        return widget.initialTemplate.sopPoints.isNotEmpty
            ? widget.initialTemplate.sopPoints.length
            : 5;
    }
  }

  /// Jumlah foto per unit manless sesuai SOP yang dipilih (IN / OUT / PEP).
  int get _manlessPointsPerUnit {
    int base = 8;
    if (widget.initialTemplate.jenis == TemplateCategory.maintManless &&
        widget.initialTemplate.sopPoints.isNotEmpty) {
      base = widget.initialTemplate.sopPoints.length;
    } else {
      final master = TemplateRepository.defaultTemplates
          .where((t) => t.id == 'tpl_maint_manless')
          .firstOrNull;
      if (master != null && master.sopPoints.isNotEmpty) {
        base = master.sopPoints.length;
      }
    }
    if (_manlessRole == 'OUT') {
      return base + TemplateRepository.manlessOutExtraPoints.length;
    }
    if (_manlessRole == 'PEP') {
      return TemplateRepository.manlessPepPoints.length;
    }
    return base;
  }

  int get _totalPoints {
    // Maintenance Lengkap: jumlah poin = gate*9 + manless*SOP + pos*9 (+ server 6)
    if (_isLengkap) {
      return _unitNumbers.length * 9 +
          _manlessUnits.length * _manlessPointsPerUnit +
          _posUnits.length * 9 +
          (_includeServer ? 6 : 0);
    }
    if (widget.initialTemplate.jenis == TemplateCategory.maintServer) {
      if (_isOnlyKasir) {
        return _kasirCount * 6;
      }
      if (_isServerKasirGabung) {
        return 6;
      } else {
        return 6 + (_kasirCount * 6);
      }
    }
    return _unitNumbers.length * _pointsPerUnit;
  }

  Future<void> _generateAndOpenChecklist() async {
    final supportName = _supportNameController.text.trim();
    if (supportName.isNotEmpty) {
      await StorageService.saveLastTechnicianName(supportName);
      await AuthRepository.instance.syncTechnicianName(supportName);
    }

    // Sinkronkan lokasi aktif yang dipilih teknisi saat setup maintenance
    LocationService.setCurrentPos(_selectedLocation);
    LocationService.clearLocationCache();

    if (!mounted) return;
    final nav = Navigator.of(context);
    final onFinished = widget.onChecklistFinished;
    nav.pop();
    final isServer =
        widget.initialTemplate.jenis == TemplateCategory.maintServer;
    final isLengkap = _isLengkap;
    await nav.push(
      MaterialPageRoute(
        builder: (_) => MaintenanceChecklistScreen(
          template: widget.initialTemplate,
          location: _selectedLocation,
          unitCount: isServer
              ? (_isOnlyKasir
                    ? _kasirCount
                    : (_isServerKasirGabung ? 1 : 1 + _kasirCount))
              : (isLengkap ? null : _unitNumbers.length),
          unitNumbers: isServer ? null : _unitNumbers,
          unitRoles: {
            for (final i in _unitNumbers)
              if (_gateRoles[i] != null) i: _gateRoles[i]!,
          },
          manlessUnits: isLengkap ? _manlessUnits : null,
          posUnits: isLengkap ? _posUnits : null,
          includeServer: isLengkap && _includeServer,
          isServerKasirGabung: _isOnlyKasir ? false : _isServerKasirGabung,
          isOnlyKasir: _isOnlyKasir,
          kasirCount: _kasirCount,
          serverOs: _isOnlyKasir ? 'windows' : _serverOs,
          manlessRole: _manlessRole,
          supportName: supportName.isNotEmpty ? supportName : 'Teknisi BSS',
          dailyTaskId: widget.dailyTaskId,
          posMode: _isBooth ? 'booth' : 'pos',
        ),
      ),
    );
    onFinished?.call();
  }

  /// Chip pemilih unit (multi-pilih) untuk area Manless / Pos di Maintenance Lengkap.
  Widget _buildAreaUnitChips({
    required String noun,
    required Set<int> selected,
    required int maxUnit,
    required bool isDark,
    required Color textTitle,
    required Color textSub,
    required ValueChanged<Set<int>> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$noun yang dicek:',
          style: TextStyle(
            fontFamily: 'Figtree',
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: textSub,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (int i = 1; i <= maxUnit; i++)
              Material(
                color: selected.contains(i)
                    ? AppColors.primary.withValues(alpha: isDark ? 0.35 : 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    final next = Set<int>.from(selected);
                    if (!next.remove(i)) next.add(i);
                    if (next.isEmpty) return; // minimal 1 unit
                    onChanged(next);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: selected.contains(i)
                            ? AppColors.primary
                            : textSub.withValues(alpha: 0.4),
                        width: selected.contains(i) ? 1.6 : 1.0,
                      ),
                    ),
                    child: Text(
                      '$noun $i',
                      style: TextStyle(
                        fontFamily: 'Figtree',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: selected.contains(i)
                            ? (isDark ? Colors.white : AppColors.primary)
                            : textTitle,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  /// Chip kecil IN/OUT untuk satu gate; ketuk chip yang sama lagi untuk membatalkan.
  Widget _buildGateRoleChip({
    required int unit,
    required String role,
    required bool isDark,
    required Color textSub,
  }) {
    final colors = TiketColors.of(context);
    final selected = _gateRoles[unit] == role;
    final accent = role == 'IN' ? AppColors.success : AppColors.accent;
    return Material(
      color: selected
          ? accent.withValues(alpha: isDark ? 0.35 : 0.15)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: () => setState(() {
          if (selected) {
            _gateRoles.remove(unit);
          } else {
            _gateRoles[unit] = role;
          }
        }),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? colors.primary : colors.soft,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? colors.primary : colors.hairline,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Text(
            role,
            style: TextStyle(
              fontFamily: TiketType.fontFamily,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: selected ? colors.onPrimary : textSub,
            ),
          ),
        ),
      ),
    );
  }

  /// Kartu pilihan mode Pos Parkir & Booth: POS Kasir atau Booth.
  Widget _buildPosModeTile({
    required IconData icon,
    required String label,
    required bool selected,
    required bool isDark,
    required Color textTitle,
    required VoidCallback onTap,
  }) {
    final colors = TiketColors.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
        decoration: BoxDecoration(
          color: selected
              ? colors.primary.withValues(alpha: isDark ? 0.25 : 0.1)
              : colors.canvas,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? colors.primary : colors.hairline,
            width: selected ? 1.6 : 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: selected ? colors.primary : textTitle),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: TiketType.fontFamily,
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? colors.primary : textTitle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Pemilih SOP Manless (IN / OUT / PEP). OUT hanya untuk Bali & HO.
  /// Dipakai template Manless tunggal dan Maintenance Lengkap.
  Widget _buildManlessRolePicker({
    required bool isDark,
    required Color textTitle,
    required Color textSub,
    Color? dividerColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pilih SOP Manless',
          style: TextStyle(
            fontFamily: TiketType.fontFamily,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: textTitle,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          'IN = cek rutin • OUT = IN + 4 perangkat • PEP = fisik pulau',
          style: TextStyle(
            fontFamily: TiketType.fontFamily,
            fontSize: 10.5,
            color: textSub,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: KeyedSubtree(
                key: const ValueKey('manless_role_IN'),
                child: _buildPosModeTile(
                  icon: Icons.login_rounded,
                  label: 'IN',
                  selected: _manlessRole == 'IN',
                  isDark: isDark,
                  textTitle: textTitle,
                  onTap: () => setState(() => _manlessRole = 'IN'),
                ),
              ),
            ),
            if (BranchService.instance.currentBranch != AppBranch.manado) ...[
              const SizedBox(width: 8),
              Expanded(
                child: KeyedSubtree(
                  key: const ValueKey('manless_role_OUT'),
                  child: _buildPosModeTile(
                    icon: Icons.logout_rounded,
                    label: 'OUT',
                    selected: _manlessRole == 'OUT',
                    isDark: isDark,
                    textTitle: textTitle,
                    onTap: () => setState(() => _manlessRole = 'OUT'),
                  ),
                ),
              ),
            ],
            const SizedBox(width: 8),
            Expanded(
              child: KeyedSubtree(
                key: const ValueKey('manless_role_PEP'),
                child: _buildPosModeTile(
                  icon: Icons.fact_check_outlined,
                  label: 'PEP',
                  selected: _manlessRole == 'PEP',
                  isDark: isDark,
                  textTitle: textTitle,
                  onTap: () => setState(() => _manlessRole = 'PEP'),
                ),
              ),
            ),
          ],
        ),
        if (dividerColor != null) ...[
          const SizedBox(height: 14),
          Divider(height: 1, color: dividerColor),
          const SizedBox(height: 14),
        ],
      ],
    );
  }

  Widget _buildStepperButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required bool isDark,
    double size = 44,
    double iconSize = 20,
  }) {
    final colors = TiketColors.of(context);
    final isEnabled = onPressed != null;
    final btnBorder = isEnabled ? colors.primary : colors.hairline;
    final iconColor = isEnabled ? colors.primary : colors.mute;

    return Semantics(
      button: true,
      enabled: isEnabled,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: Container(
              width: size,
              height: size,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: btnBorder, width: 1.5),
              ),
              child: Icon(icon, color: iconColor, size: iconSize),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locations = LocationService.availablePosList;
    final isDark = ThemeService.isDarkMode(context);
    final colors = TiketColors.of(context);
    final dialogBg = colors.dialog;
    final textTitle = colors.ink;
    final textSub = colors.mute;
    final cardBg = colors.soft;
    final cardBorder = colors.hairline;
    final inputFill = colors.soft;
    final innerCardBg = colors.canvas;
    final innerCardBorder = colors.hairline;
    final stepperBoxBg = colors.soft;
    final stepperBoxBorder = colors.hairline;
    final stepperNumberColor = colors.ink;

    return Dialog(
      backgroundColor: dialogBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: colors.hairline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.initialTemplate.jenis ==
                                  TemplateCategory.maintServer
                              ? _unitTitle
                              : widget.initialTemplate.nama,
                          style: TextStyle(
                            fontFamily: TiketType.fontFamily,
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                            color: textTitle,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.initialTemplate.jenis ==
                                  TemplateCategory.maintServer
                              ? _unitSubtitle
                              : (_isLengkap
                                    ? 'Atur cakupan: Gate + Manless + Pos (+ Server)'
                                    : 'Atur Pengecekan $_unitNoun'),
                          style: TextStyle(
                            fontFamily: TiketType.fontFamily,
                            fontSize: 13,
                            color: textSub,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: textTitle),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Input Nama Teknisi / Support
              Text(
                'Nama Teknisi / Support',
                style: TextStyle(
                  fontFamily: TiketType.fontFamily,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: textTitle,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _supportNameController,
                decoration: InputDecoration(
                  hintText: 'Contoh: Farhan Lakoro',
                  hintStyle: TextStyle(
                    fontFamily: TiketType.fontFamily,
                    color: textSub,
                    fontSize: 14,
                  ),
                  isDense: true,
                  filled: true,
                  fillColor: inputFill,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  border: UnderlineInputBorder(
                    borderSide: BorderSide(color: colors.body, width: 2.0),
                  ),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: colors.body, width: 2.0),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: colors.primary, width: 2.0),
                  ),
                ),
                onTap: () {
                  if (_supportNameController.text.isNotEmpty) {
                    _supportNameController.selection = TextSelection(
                      baseOffset: 0,
                      extentOffset: _supportNameController.text.length,
                    );
                  }
                },
                style: TextStyle(
                  fontFamily: TiketType.fontFamily,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: textTitle,
                ),
              ),
              const SizedBox(height: 16),

              // Dropdown Lokasi
              Text(
                'Lokasi Parkir',
                style: TextStyle(
                  fontFamily: TiketType.fontFamily,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: textTitle,
                ),
              ),
              const SizedBox(height: 6),
              Semantics(
                button: true,
                label: 'Lokasi Parkir: ${_selectedLocation.posName}',
                child: Material(
                  color: inputFill,
                  child: InkWell(
                    splashColor: colors.primaryPressed.withValues(alpha: 0.12),
                    highlightColor: colors.primaryPressed.withValues(alpha: 0.06),
                    onTap: () async {
                      final picked = await showTiketPickerDialog<PosLocation>(
                        context: context,
                        title: 'Lokasi Parkir',
                        selected: _selectedLocation,
                        options: locations
                            .map(
                              (loc) => TiketOption<PosLocation>(
                                value: loc,
                                label: loc.posName,
                                trailingText: loc.locationTag,
                              ),
                            )
                            .toList(),
                      );
                      if (picked != null) {
                        setState(() {
                          _selectedLocation = picked;
                          LocationService.setCurrentPos(picked);
                          LocationService.clearLocationCache();
                        });
                      }
                    },
                    child: Container(
                      height: 52.0,
                      padding: const EdgeInsets.symmetric(horizontal: 14.0),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: colors.body,
                            width: 2.0,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _selectedLocation.posName,
                              style: TextStyle(
                                fontFamily: TiketType.fontFamily,
                                fontSize: 14.0,
                                fontWeight: FontWeight.w600,
                                color: textTitle,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            _selectedLocation.locationTag,
                            style: TextStyle(
                              fontFamily: TiketType.fontFamily,
                              fontSize: 13.0,
                              fontWeight: FontWeight.w600,
                              color: textSub,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.keyboard_arrow_down,
                            size: 20.0,
                            color: colors.body,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Section Setup Unit / Server & Kasir
              if (widget.initialTemplate.jenis ==
                  TemplateCategory.maintServer) ...[
                const SizedBox(height: 16),
                Text(
                  'Pilih Perangkat',
                  style: TextStyle(
                    fontFamily: TiketType.fontFamily,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: textTitle,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Pilih cek Server & Kasir atau khusus PC Kasir saja',
                  style: TextStyle(
                    fontFamily: TiketType.fontFamily,
                    fontSize: 11,
                    color: textSub,
                  ),
                ),
                const SizedBox(height: 10),
                TiketSegmented<bool>(
                  options: const [
                    (false, 'Server & Kasir'),
                    (true, 'Hanya Kasir'),
                  ],
                  selected: _isOnlyKasir,
                  onChanged: (val) => setState(() => _isOnlyKasir = val),
                ),
                const SizedBox(height: 16),

                if (!_isOnlyKasir) ...[
                  // Toggle: PC Server & PC Kasir Terpisah
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PC Server & PC Kasir Terpisah',
                              style: TextStyle(
                                fontFamily: TiketType.fontFamily,
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                                color: textTitle,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _isServerKasirTerpisah
                                  ? 'Komputer berbeda (PC Server & PC Kasir terpisah)'
                                  : '1 Komputer merangkap PC Server sekaligus PC Kasir',
                              style: TextStyle(
                                fontFamily: TiketType.fontFamily,
                                fontSize: 11,
                                color: textSub,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Switch.adaptive(
                        value: _isServerKasirTerpisah,
                        activeTrackColor: colors.primary,
                        inactiveThumbColor: Colors.white,
                        inactiveTrackColor: colors.hairline,
                        onChanged: (val) {
                          setState(() {
                            _isServerKasirTerpisah = val;
                          });
                        },
                      ),
                    ],
                  ),

                  // Jika Terpisah: Tampilkan 1 PC Server + Stepper Jumlah PC Kasir
                  if (!_isServerKasirGabung) ...[
                    const SizedBox(height: 12),
                    Divider(height: 1, thickness: 1, color: colors.hairline),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '1 PC Server (6 foto)',
                            style: TextStyle(
                              fontFamily: TiketType.fontFamily,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: textTitle,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: colors.soft,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '1 Unit',
                            style: TextStyle(
                              fontFamily: TiketType.fontFamily,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: colors.body,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Jumlah PC Kasir',
                                style: TextStyle(
                                  fontFamily: TiketType.fontFamily,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: textTitle,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'PC Kasir 1, PC Kasir 2, dst (6 foto / unit)',
                                style: TextStyle(
                                  fontFamily: TiketType.fontFamily,
                                  fontSize: 11,
                                  color: textSub,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            _buildStepperButton(
                              icon: Icons.remove,
                              isDark: isDark,
                              onPressed: _kasirCount > 1
                                  ? () => setState(() => _kasirCount--)
                                  : null,
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Text(
                                '$_kasirCount',
                                style: TextStyle(
                                  fontFamily: TiketType.fontFamily,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: textTitle,
                                ),
                              ),
                            ),
                            _buildStepperButton(
                              icon: Icons.add,
                              isDark: isDark,
                              onPressed: _kasirCount < 10
                                  ? () => setState(() => _kasirCount++)
                                  : null,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 14),
                  Divider(height: 1, thickness: 1, color: colors.hairline),
                  const SizedBox(height: 14),
                  // Selector OS PC Server
                  Text(
                    'Sistem Operasi PC Server',
                    style: TextStyle(
                      fontFamily: TiketType.fontFamily,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: textTitle,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _isServerKasirGabung
                        ? 'Pilih OS untuk PC Server & PC Kasir All-in-One'
                        : 'Pilih OS untuk PC Server (PC Kasir otomatis Windows)',
                    style: TextStyle(
                      fontFamily: TiketType.fontFamily,
                      fontSize: 11,
                      color: textSub,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TiketSegmented<String>(
                    options: const [
                      ('linux', 'Linux Server'),
                      ('windows', 'Windows'),
                    ],
                    selected: _serverOs,
                    onChanged: (val) => setState(() => _serverOs = val),
                  ),
                ] else ...[
                  // Tampilan Khusus: Hanya Maintenance PC Kasir
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Jumlah PC Kasir',
                              style: TextStyle(
                                fontFamily: TiketType.fontFamily,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: textTitle,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'PC Kasir 1, PC Kasir 2, dst (6 foto / unit)',
                              style: TextStyle(
                                fontFamily: TiketType.fontFamily,
                                fontSize: 11,
                                color: textSub,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          _buildStepperButton(
                            icon: Icons.remove,
                            isDark: isDark,
                            onPressed: _kasirCount > 1
                                ? () => setState(() => _kasirCount--)
                                : null,
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                            ),
                            child: Text(
                              '$_kasirCount',
                              style: TextStyle(
                                fontFamily: TiketType.fontFamily,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: textTitle,
                              ),
                            ),
                          ),
                          _buildStepperButton(
                            icon: Icons.add,
                            isDark: isDark,
                            onPressed: _kasirCount < 10
                                ? () => setState(() => _kasirCount++)
                                : null,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: colors.soft,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: colors.hairline),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 14,
                          color: textSub,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'PC Kasir otomatis menggunakan checklist OS Windows',
                            style: TextStyle(
                              fontFamily: TiketType.fontFamily,
                              fontSize: 10.5,
                              color: textSub,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 14),
                // Baris Ringkasan Real-time
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: colors.soft,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colors.hairline),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        size: 16,
                        color: colors.ok,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isOnlyKasir
                                  ? 'Target: $_totalPoints Foto ($_kasirCount PC Kasir)'
                                  : (_isServerKasirGabung
                                        ? 'Target: 6 Foto (1 PC Server & Kasir All-in-One)'
                                        : 'Target: $_totalPoints Foto (1 PC Server + $_kasirCount PC Kasir)'),
                              style: TextStyle(
                                fontFamily: TiketType.fontFamily,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: colors.ink,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _isOnlyKasir
                                  ? '$_totalPoints foto PC Kasir ($_kasirCount unit × 6 foto)'
                                  : (_isServerKasirGabung
                                        ? '6 foto PC Server & Kasir (1 komputer)'
                                        : '6 foto PC Server + ${_kasirCount * 6} foto PC Kasir ($_kasirCount unit × 6 foto)'),
                              style: TextStyle(
                                fontFamily: TiketType.fontFamily,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: textSub,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Card Gabungan Pos Parkir / Gate / Manless (Pilihan Rentang Unit + Pilihan Cepat + Baris kalkulasi hijau)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _unitIcon,
                            color: colors.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _unitTitle,
                                  style: TextStyle(
                                    fontFamily: 'Figtree',
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13.5,
                                    color: textTitle,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _unitSubtitle,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: textSub,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Khusus Manless: pilih SOP IN / OUT / PEP. OUT hanya
                      // tersedia untuk Bali & HO (Manado tanpa manless OUT).
                      if (widget.initialTemplate.jenis ==
                          TemplateCategory.maintManless) ...[
                        _buildManlessRolePicker(
                          isDark: isDark,
                          textTitle: textTitle,
                          textSub: textSub,
                          dividerColor: innerCardBorder,
                        ),
                      ],

                      // Khusus Pos Parkir & Booth: pilih target pengecekan
                      if (widget.initialTemplate.jenis ==
                          TemplateCategory.maintPos) ...[
                        Text(
                          'Pilih Jenis Maintenance',
                          style: TextStyle(
                            fontFamily: 'Figtree',
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: textTitle,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Pilih pengecekan POS Kasir atau Booth Parkir',
                          style: TextStyle(fontSize: 10.5, color: textSub),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _buildPosModeTile(
                                icon: Icons.point_of_sale_rounded,
                                label: 'POS Kasir',
                                selected: !_isBooth,
                                isDark: isDark,
                                textTitle: textTitle,
                                onTap: () => setState(() {
                                  _isBooth = false;
                                  _startUnit = 1;
                                  _endUnit = 3;
                                }),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildPosModeTile(
                                icon: Icons.storefront_outlined,
                                label: 'Booth',
                                selected: _isBooth,
                                isDark: isDark,
                                textTitle: textTitle,
                                onTap: () => setState(() {
                                  _isBooth = true;
                                  _startUnit = 1;
                                  _endUnit = 1;
                                }),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Divider(height: 1, color: innerCardBorder),
                        const SizedBox(height: 14),
                      ],

                      // Stepper Rentang Unit: Dari Pos [ 1 ] s/d Sampai Pos [ 3 ]
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: innerCardBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: innerCardBorder),
                        ),
                        child: Row(
                          children: [
                            // Dari Unit
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Dari $_unitNoun:',
                                    style: TextStyle(
                                      fontFamily: 'Figtree',
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: textSub,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      _buildStepperButton(
                                        icon: Icons.remove_rounded,
                                        isDark: isDark,
                                        size: 36,
                                        iconSize: 18,
                                        onPressed: _startUnit > 1
                                            ? () {
                                                setState(() {
                                                  _startUnit--;
                                                });
                                              }
                                            : null,
                                      ),
                                      Expanded(
                                        child: Container(
                                          margin: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 8,
                                          ),
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: stepperBoxBg,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: stepperBoxBorder,
                                            ),
                                          ),
                                          child: Text(
                                            '$_startUnit',
                                            style: TextStyle(
                                              fontFamily: 'Figtree',
                                              fontSize: 14,
                                              fontWeight: FontWeight.w800,
                                              color: stepperNumberColor,
                                            ),
                                          ),
                                        ),
                                      ),
                                      _buildStepperButton(
                                        icon: Icons.add_rounded,
                                        isDark: isDark,
                                        size: 36,
                                        iconSize: 18,
                                        onPressed: _startUnit < 20
                                            ? () {
                                                setState(() {
                                                  _startUnit++;
                                                  if (_endUnit < _startUnit) {
                                                    _endUnit = _startUnit;
                                                  }
                                                });
                                              }
                                            : null,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Separator Arrow
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              child: Icon(
                                Icons.arrow_forward_rounded,
                                size: 16,
                                color: textSub.withValues(alpha: 0.6),
                              ),
                            ),

                            // Sampai Unit
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Sampai $_unitNoun:',
                                    style: TextStyle(
                                      fontFamily: 'Figtree',
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: textSub,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      _buildStepperButton(
                                        icon: Icons.remove_rounded,
                                        isDark: isDark,
                                        size: 36,
                                        iconSize: 18,
                                        onPressed: _endUnit > 1
                                            ? () {
                                                setState(() {
                                                  _endUnit--;
                                                  if (_startUnit > _endUnit) {
                                                    _startUnit = _endUnit;
                                                  }
                                                });
                                              }
                                            : null,
                                      ),
                                      Expanded(
                                        child: Container(
                                          margin: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 8,
                                          ),
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: stepperBoxBg,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: stepperBoxBorder,
                                            ),
                                          ),
                                          child: Text(
                                            '$_endUnit',
                                            style: TextStyle(
                                              fontFamily: 'Figtree',
                                              fontSize: 14,
                                              fontWeight: FontWeight.w800,
                                              color: stepperNumberColor,
                                            ),
                                          ),
                                        ),
                                      ),
                                      _buildStepperButton(
                                        icon: Icons.add_rounded,
                                        isDark: isDark,
                                        size: 36,
                                        iconSize: 18,
                                        onPressed: _endUnit < 20
                                            ? () {
                                                setState(() {
                                                  _endUnit++;
                                                });
                                              }
                                            : null,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Baris Kecil Hasil Kalkulasi Otomatis (Warna Hijau Konfirmasi)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: colors.soft,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: colors.hairline,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              size: 15,
                              color: colors.ok,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _isLengkap
                                        ? 'Cek: ${_unitNumbers.length} Gate + ${_manlessUnits.length} Manless + ${_posUnits.length} Pos${_includeServer ? ' + 1 PC Server' : ''}'
                                        : (_startUnit == _endUnit
                                              ? 'Cek $_unitNoun $_startUnit saja (${_unitNumbers.length} $_unitNoun)'
                                              : 'Cek ${_unitNumbers.length} $_unitNoun: $_unitNoun $_startUnit s/d $_unitNoun $_endUnit'),
                                    style: TextStyle(
                                      fontFamily: TiketType.fontFamily,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: colors.ink,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _isLengkap
                                        ? 'Target: $_totalPoints Foto (gate×9 + manless×$_manlessPointsPerUnit + pos×9${_includeServer ? ' + server×6' : ''})'
                                        : 'Target: $_totalPoints Foto (${_unitNumbers.length} $_unitNoun × $_pointsPerUnit foto)',
                                    style: TextStyle(
                                      fontFamily: TiketType.fontFamily,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                      color: textSub,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Penanda arah gate (opsional) supaya manager tahu gate mana IN / OUT.
                      // Di Maintenance Lengkap, bagian ini khusus gate-nya.
                      if (widget.initialTemplate.jenis ==
                              TemplateCategory.maintBarrier ||
                          _isLengkap) ...[
                        const SizedBox(height: 10),
                        Text(
                          'Arah Gate (opsional):',
                          style: TextStyle(
                            fontFamily: 'Figtree',
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: textSub,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          children: [
                            for (final i in _unitNumbers)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '$_unitNoun $i',
                                    style: TextStyle(
                                      fontFamily: 'Figtree',
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: textTitle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  for (final role in const ['IN', 'OUT'])
                                    Padding(
                                      padding: const EdgeInsets.only(right: 4),
                                      child: _buildGateRoleChip(
                                        unit: i,
                                        role: role,
                                        isDark: isDark,
                                        textSub: textSub,
                                      ),
                                    ),
                                ],
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                      ],
                    ],
                  ),
                ),
                // Maintenance Lengkap: Area 2 - 4 (Manless, Pos Kasir, opsi PC Server)
                if (_isLengkap) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: cardBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.cleaning_services_rounded,
                              color: colors.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Area 2 - 4 Maintenance Lengkap',
                                    style: TextStyle(
                                      fontFamily: 'Figtree',
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13.5,
                                      color: textTitle,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Manless $_manlessPointsPerUnit foto/unit • Pos Kasir 9 foto/pos • Server 6 foto',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: textSub,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildAreaUnitChips(
                          noun: 'Manless',
                          selected: _manlessUnitsSel,
                          maxUnit: 6,
                          isDark: isDark,
                          textTitle: textTitle,
                          textSub: textSub,
                          onChanged: (next) => setState(() {
                            _manlessUnitsSel
                              ..clear()
                              ..addAll(next);
                          }),
                        ),
                        const SizedBox(height: 12),
                        _buildManlessRolePicker(
                          isDark: isDark,
                          textTitle: textTitle,
                          textSub: textSub,
                        ),
                        const SizedBox(height: 12),
                        _buildAreaUnitChips(
                          noun: 'Pos',
                          selected: _posUnitsSel,
                          maxUnit: 4,
                          isDark: isDark,
                          textTitle: textTitle,
                          textSub: textSub,
                          onChanged: (next) => setState(() {
                            _posUnitsSel
                              ..clear()
                              ..addAll(next);
                          }),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'PC Server (opsional)',
                                    style: TextStyle(
                                      fontFamily: 'Figtree',
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: textTitle,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _includeServer
                                        ? 'Ikut dicek: 1 PC Server (6 foto) · cakupan 4 area'
                                        : 'Tidak dicek · cakupan 3 area (Gate + Manless + Pos)',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: textSub,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch.adaptive(
                              value: _includeServer,
                              activeTrackColor: colors.primary,
                              inactiveThumbColor: Colors.white,
                              inactiveTrackColor: colors.hairline,
                              onChanged: (v) =>
                                  setState(() => _includeServer = v),
                            ),
                          ],
                        ),
                        if (_includeServer) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                'OS Server:',
                                style: TextStyle(
                                  fontFamily: 'Figtree',
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: textSub,
                                ),
                              ),
                              const SizedBox(width: 8),
                              for (final os in const [
                                ['linux', 'Linux'],
                                ['windows', 'Windows'],
                              ])
                                Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: Material(
                                    color: _serverOs == os[0]
                                        ? AppColors.primary.withValues(
                                            alpha: isDark ? 0.35 : 0.12,
                                          )
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(8),
                                      onTap: () => setState(
                                        () => _serverOs = os[0],
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: _serverOs == os[0]
                                                ? AppColors.primary
                                                : textSub.withValues(alpha: 0.4),
                                            width: _serverOs == os[0] ? 1.6 : 1.0,
                                          ),
                                        ),
                                        child: Text(
                                          os[1],
                                          style: TextStyle(
                                            fontFamily: 'Figtree',
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: _serverOs == os[0]
                                                ? (isDark
                                                      ? Colors.white
                                                      : AppColors.primary)
                                                : textTitle,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 20),

              // Action Buttons (Batal & Mulai Checklist Unit Berdampingan Horizontal)
              TiketPill(
                label: 'Mulai Checklist',
                kind: TiketPillKind.primary,
                height: 52,
                expand: true,
                onPressed: _generateAndOpenChecklist,
              ),
              const SizedBox(height: 10),
              TiketPill(
                label: 'Batal',
                kind: TiketPillKind.secondary,
                height: 52,
                expand: true,
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
