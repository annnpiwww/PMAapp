import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/theme_service.dart';
import '../../../data/models/template_model.dart';
import '../../../data/services/location_service.dart';
import '../../../data/services/storage_service.dart';
import '../../../data/repositories/auth_repository.dart';
import '../screens/maintenance_checklist_screen.dart';

class MaintenanceSetupDialog extends StatefulWidget {
  final TemplateModel initialTemplate;

  const MaintenanceSetupDialog({super.key, required this.initialTemplate});

  @override
  State<MaintenanceSetupDialog> createState() => _MaintenanceSetupDialogState();
}

class _MaintenanceSetupDialogState extends State<MaintenanceSetupDialog> {
  late PosLocation _selectedLocation;
  late TextEditingController _supportNameController;
  int _startUnit = 1;
  int _endUnit = 1;
  bool _isOnlyKasir = false;
  bool _isServerKasirTerpisah = true; // ON = Terpisah, OFF = Gabung (1 Komputer)
  bool get _isServerKasirGabung => !_isServerKasirTerpisah;
  int _kasirCount = 1;
  String _serverOs = 'linux'; // 'linux' | 'windows'

  @override
  void initState() {
    super.initState();
    _selectedLocation = LocationService.currentPos;

    // Pre-fill nama teknisi dari histori terakhir atau akun yang sedang aktif
    final lastTech = StorageService.getLastTechnicianName().trim();
    final currentUserName = AuthRepository.instance.currentUser?.nama.trim() ?? '';
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
        return 'Pos';
      case TemplateCategory.maintBarrier:
        return 'Gate';
      case TemplateCategory.maintManless:
        return 'Manless';
      default:
        return 'Unit';
    }
  }

  String get _unitTitle {
    switch (widget.initialTemplate.jenis) {
      case TemplateCategory.maintBarrier:
        return 'Pilih Barrier Gate';
      case TemplateCategory.maintManless:
        return 'Pilih Dispenser Manless (In)';
      case TemplateCategory.maintPos:
        return 'Pilih Pos yang Dikerjakan';
      case TemplateCategory.maintServer:
        return _isOnlyKasir ? 'Maintenance: Kasir' : 'Maintenance: Server & Kasir';
      default:
        return 'Pilih Unit yang Dikerjakan';
    }
  }

  String get _unitSubtitle {
    switch (widget.initialTemplate.jenis) {
      case TemplateCategory.maintBarrier:
        return 'Tentukan nomor gate yang dikerjakan (9 foto poin/gate)';
      case TemplateCategory.maintManless:
        return 'Tentukan nomor manless yang dikerjakan (8 foto poin/unit)';
      case TemplateCategory.maintPos:
        return 'Tentukan nomor pos yang dikerjakan (9 foto poin/pos)';
      case TemplateCategory.maintServer:
        return _isOnlyKasir
            ? 'Pemeriksaan Unit PC Kasir'
            : 'Pemeriksaan PC Server dan PC Kasir';
      default:
        return 'Tentukan nomor unit yang dikerjakan';
    }
  }

  IconData get _unitIcon {
    switch (widget.initialTemplate.jenis) {
      case TemplateCategory.maintBarrier:
        return Icons.fence_outlined;
      case TemplateCategory.maintManless:
        return Icons.point_of_sale_outlined;
      case TemplateCategory.maintPos:
        return Icons.home_repair_service_outlined;
      case TemplateCategory.maintServer:
        return _isOnlyKasir ? Icons.point_of_sale_rounded : Icons.computer_outlined;
      default:
        return Icons.build_rounded;
    }
  }

  int get _pointsPerUnit {
    switch (widget.initialTemplate.jenis) {
      case TemplateCategory.maintBarrier:
        return 9;
      case TemplateCategory.maintManless:
        return 8;
      case TemplateCategory.maintPos:
        return widget.initialTemplate.sopPoints.isNotEmpty
            ? widget.initialTemplate.sopPoints.length
            : 9;
      case TemplateCategory.maintServer:
        return 6;
      default:
        return widget.initialTemplate.sopPoints.isNotEmpty
            ? widget.initialTemplate.sopPoints.length
            : 5;
    }
  }

  int get _totalPoints {
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
    Navigator.pop(context);
    final isServer = widget.initialTemplate.jenis == TemplateCategory.maintServer;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MaintenanceChecklistScreen(
          template: widget.initialTemplate,
          location: _selectedLocation,
          unitCount: isServer
              ? (_isOnlyKasir ? _kasirCount : (_isServerKasirGabung ? 1 : 1 + _kasirCount))
              : _unitNumbers.length,
          unitNumbers: isServer ? null : _unitNumbers,
          isServerKasirGabung: _isOnlyKasir ? false : _isServerKasirGabung,
          isOnlyKasir: _isOnlyKasir,
          kasirCount: _kasirCount,
          serverOs: _isOnlyKasir ? 'windows' : _serverOs,
          supportName: supportName.isNotEmpty ? supportName : 'Teknisi BSS',
        ),
      ),
    );
  }

  Widget _buildStepperButton({
    required IconData icon,
    required VoidCallback? onPressed,
    double size = 44,
    double iconSize = 22,
  }) {
    final isEnabled = onPressed != null;
    return Material(
      color: isEnabled ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isEnabled ? AppColors.primary.withValues(alpha: 0.3) : const Color(0xFFE2E8F0),
              width: 1.2,
            ),
          ),
          child: Icon(
            icon,
            color: isEnabled ? AppColors.primary : const Color(0xFF94A3B8),
            size: iconSize,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locations = LocationService.availablePosList;
    final isDark = ThemeService.isDarkMode(context);
    final dialogBg = isDark ? const Color(0xFF0F172A) : Colors.white;

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
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(_unitIcon, color: AppColors.primary, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.initialTemplate.jenis == TemplateCategory.maintServer
                              ? _unitTitle
                              : widget.initialTemplate.nama,
                          style: const TextStyle(
                            fontFamily: 'PlusJakartaSans', 
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.initialTemplate.jenis == TemplateCategory.maintServer
                              ? _unitSubtitle
                              : 'Atur Pengecekan Pos',
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Input Nama Teknisi / Support
              TextFormField(
                controller: _supportNameController,
                decoration: InputDecoration(
                  labelText: 'Nama Teknisi / Support',
                  hintText: 'Contoh: Farhan Lakoro',
                  prefixIcon: const Icon(Icons.person_rounded, size: 20, color: AppColors.primary),
                  isDense: true,
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.cardBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                        color: AppColors.primary, width: 1.5),
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
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),

              // Dropdown Lokasi (Affordance ditingkatkan: icon chevron besar kontras, area tap luas)
              DropdownButtonFormField<PosLocation>(
                initialValue: _selectedLocation,
                isExpanded: true,
                icon: const Icon(
                  Icons.arrow_drop_down_circle_outlined,
                  size: 20,
                  color: AppColors.primary,
                ),
                decoration: InputDecoration(
                  labelText: 'Lokasi Parkir',
                  labelStyle: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                  prefixIcon: const Icon(Icons.location_on_rounded, size: 20, color: AppColors.primary),
                  isDense: true,
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.cardBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                        color: AppColors.primary, width: 1.5),
                  ),
                ),
                items: locations.map((loc) {
                  return DropdownMenuItem(
                    value: loc,
                    child: Text(
                      '${loc.locationTag} • ${loc.posName}',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (loc) {
                  if (loc != null) {
                    setState(() {
                      _selectedLocation = loc;
                      LocationService.setCurrentPos(loc);
                      LocationService.clearLocationCache();
                    });
                  }
                },
              ),
              const SizedBox(height: 14),

              // Section Setup Unit / Server & Kasir
              if (widget.initialTemplate.jenis == TemplateCategory.maintServer) ...[
                Text(
                  _unitTitle,
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _unitSubtitle,
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Pilihan Ruang Lingkup Maintenance: Server & Kasir vs Hanya Kasir
                      const Text(
                        'Cakupan Pemeriksaan',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'Pilih apakah maintenance mencakup Server atau khusus unit Kasir',
                        style: TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _isOnlyKasir = false),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
                                decoration: BoxDecoration(
                                  color: !_isOnlyKasir
                                      ? AppColors.primary.withValues(alpha: 0.1)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: !_isOnlyKasir
                                        ? AppColors.primary
                                        : AppColors.cardBorder,
                                    width: !_isOnlyKasir ? 1.6 : 1.0,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.dns_rounded,
                                      size: 16,
                                      color: !_isOnlyKasir
                                          ? AppColors.primary
                                          : AppColors.textSecondary,
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        'Server & Kasir',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontFamily: 'PlusJakartaSans',
                                          fontSize: 12,
                                          fontWeight: !_isOnlyKasir
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                          color: !_isOnlyKasir
                                              ? AppColors.primary
                                              : AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _isOnlyKasir = true),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
                                decoration: BoxDecoration(
                                  color: _isOnlyKasir
                                      ? AppColors.primary.withValues(alpha: 0.1)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: _isOnlyKasir
                                        ? AppColors.primary
                                        : AppColors.cardBorder,
                                    width: _isOnlyKasir ? 1.6 : 1.0,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.point_of_sale_rounded,
                                      size: 16,
                                      color: _isOnlyKasir
                                          ? AppColors.primary
                                          : AppColors.textSecondary,
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        'Hanya Kasir',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontFamily: 'PlusJakartaSans',
                                          fontSize: 12,
                                          fontWeight: _isOnlyKasir
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                          color: _isOnlyKasir
                                              ? AppColors.primary
                                              : AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Divider(height: 1),
                      const SizedBox(height: 14),

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
                                  const Text(
                                    'PC Server & PC Kasir Terpisah',
                                    maxLines: 2,
                                    style: TextStyle(
                                      fontFamily: 'PlusJakartaSans',
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                    decoration: BoxDecoration(
                                      color: _isServerKasirTerpisah
                                          ? AppColors.primary.withValues(alpha: 0.12)
                                          : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: _isServerKasirTerpisah
                                            ? AppColors.primary.withValues(alpha: 0.3)
                                            : const Color(0xFFCBD5E1),
                                      ),
                                    ),
                                    child: Text(
                                      _isServerKasirTerpisah
                                          ? 'ON: Terpisah (Komputer Berbeda)'
                                          : 'OFF: Gabung (1 Komputer)',
                                      style: TextStyle(
                                        fontFamily: 'PlusJakartaSans',
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: _isServerKasirTerpisah
                                            ? AppColors.primary
                                            : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    _isServerKasirTerpisah
                                        ? 'Komputer berbeda (PC Server & PC Kasir terpisah)'
                                        : '1 Komputer merangkap PC Server sekaligus PC Kasir',
                                    style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Switch(
                              value: _isServerKasirTerpisah,
                              activeThumbColor: Colors.white,
                              activeTrackColor: AppColors.primary,
                              inactiveThumbColor: Colors.white,
                              inactiveTrackColor: const Color(0xFFCBD5E1),
                              trackOutlineColor: WidgetStateProperty.resolveWith((states) {
                                if (states.contains(WidgetState.selected)) {
                                  return AppColors.primary;
                                }
                                return const Color(0xFF94A3B8);
                              }),
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
                          const Divider(height: 20),
                          // Penjelasan PC Server Mandiri
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(Icons.dns_rounded, size: 16, color: AppColors.primary),
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  '1 PC Server (Wajib 6 foto)',
                                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE2E8F0),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text('1 Unit', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Jumlah PC Kasir',
                                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                                    ),
                                    Text(
                                      'PC Kasir 1, PC Kasir 2, dst (6 foto / unit)',
                                      style: TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  _buildStepperButton(
                                    icon: Icons.remove_rounded,
                                    onPressed: _kasirCount > 1
                                        ? () => setState(() => _kasirCount--)
                                        : null,
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    child: Container(
                                      constraints: const BoxConstraints(minWidth: 44),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: AppColors.cardBorder),
                                      ),
                                      child: Text(
                                        '$_kasirCount',
                                        style: TextStyle(fontFamily: 'PlusJakartaSans', 
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                  ),
                                  _buildStepperButton(
                                    icon: Icons.add_rounded,
                                    onPressed: _kasirCount < 10
                                        ? () => setState(() => _kasirCount++)
                                        : null,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],

                        const Divider(height: 18),
                        // Selector OS PC Server
                        const Text(
                          'Sistem Operasi PC Server',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _isServerKasirGabung
                              ? 'Pilih OS untuk PC Server & PC Kasir All-in-One'
                              : 'Pilih OS untuk PC Server (PC Kasir otomatis Windows)',
                          style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => setState(() => _serverOs = 'linux'),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                                  decoration: BoxDecoration(
                                    color: _serverOs == 'linux'
                                        ? AppColors.primary.withValues(alpha: 0.1)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: _serverOs == 'linux'
                                          ? AppColors.primary
                                          : AppColors.cardBorder,
                                      width: _serverOs == 'linux' ? 1.6 : 1.0,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.terminal_rounded,
                                        size: 16,
                                        color: _serverOs == 'linux'
                                            ? AppColors.primary
                                            : AppColors.textSecondary,
                                      ),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          'Linux Server',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontFamily: 'PlusJakartaSans',
                                            fontSize: 12,
                                            fontWeight: _serverOs == 'linux'
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                            color: _serverOs == 'linux'
                                                ? AppColors.primary
                                                : AppColors.textPrimary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: InkWell(
                                onTap: () => setState(() => _serverOs = 'windows'),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                                  decoration: BoxDecoration(
                                    color: _serverOs == 'windows'
                                        ? AppColors.primary.withValues(alpha: 0.1)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: _serverOs == 'windows'
                                          ? AppColors.primary
                                          : AppColors.cardBorder,
                                      width: _serverOs == 'windows' ? 1.6 : 1.0,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.desktop_windows_rounded,
                                        size: 16,
                                        color: _serverOs == 'windows'
                                            ? AppColors.primary
                                            : AppColors.textSecondary,
                                      ),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          'Windows',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontFamily: 'PlusJakartaSans',
                                            fontSize: 12,
                                            fontWeight: _serverOs == 'windows'
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                            color: _serverOs == 'windows'
                                                ? AppColors.primary
                                                : AppColors.textPrimary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        // Tampilan Khusus: Hanya Maintenance PC Kasir
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Jumlah PC Kasir',
                                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                                  ),
                                  Text(
                                    'PC Kasir 1, PC Kasir 2, dst (6 foto / unit)',
                                    style: TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                _buildStepperButton(
                                  icon: Icons.remove_rounded,
                                  onPressed: _kasirCount > 1
                                      ? () => setState(() => _kasirCount--)
                                      : null,
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: Container(
                                    constraints: const BoxConstraints(minWidth: 44),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: AppColors.cardBorder),
                                    ),
                                    child: Text(
                                      '$_kasirCount',
                                      style: TextStyle(
                                        fontFamily: 'PlusJakartaSans',
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ),
                                _buildStepperButton(
                                  icon: Icons.add_rounded,
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
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.info_outline_rounded, size: 14, color: AppColors.textSecondary),
                              SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'PC Kasir otomatis menggunakan checklist OS Windows',
                                  style: TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 12),
                      // Baris Ringkasan Hijau Real-time
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.check_circle_rounded, size: 15, color: Color(0xFF059669)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _isOnlyKasir
                                        ? 'Total Wajib: $_totalPoints Foto ($_kasirCount PC Kasir)'
                                        : (_isServerKasirGabung
                                            ? 'Total Wajib: 6 Foto (1 Unit PC Server & Kasir Gabung)'
                                            : 'Total Wajib: $_totalPoints Foto (1 PC Server + $_kasirCount PC Kasir)'),
                                    style: const TextStyle(
                                      fontFamily: 'PlusJakartaSans',
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF065F46),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _isOnlyKasir
                                        ? '$_totalPoints foto SOP PC Kasir ($_kasirCount unit × 6 foto)'
                                        : (_isServerKasirGabung
                                            ? '6 foto SOP PC Server & PC Kasir gabung (1 komputer)'
                                            : '6 foto PC Server + ${_kasirCount * 6} foto PC Kasir ($_kasirCount unit × 6 foto)'),
                                    style: const TextStyle(
                                      fontFamily: 'PlusJakartaSans',
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF047857),
                                    ),
                                  ),
                                ],
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
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(_unitIcon,
                                color: AppColors.primary, size: 20),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _unitTitle,
                                  style: TextStyle(fontFamily: 'PlusJakartaSans', 
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13.5,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _unitSubtitle,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Stepper Rentang Unit: Dari Pos [ 1 ] s/d Sampai Pos [ 3 ]
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.8)),
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
                                    style: const TextStyle(
                                      fontFamily: 'PlusJakartaSans',
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      _buildStepperButton(
                                        icon: Icons.remove_rounded,
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
                                          margin: const EdgeInsets.symmetric(horizontal: 4),
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF8FAFC),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: AppColors.cardBorder),
                                          ),
                                          child: Text(
                                            '$_startUnit',
                                            style: TextStyle(
                                              fontFamily: 'PlusJakartaSans',
                                              fontSize: 14,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ),
                                      ),
                                      _buildStepperButton(
                                        icon: Icons.add_rounded,
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
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: Icon(
                                Icons.arrow_forward_rounded,
                                size: 16,
                                color: AppColors.textSecondary.withValues(alpha: 0.6),
                              ),
                            ),

                            // Sampai Unit
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Sampai $_unitNoun:',
                                    style: const TextStyle(
                                      fontFamily: 'PlusJakartaSans',
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      _buildStepperButton(
                                        icon: Icons.remove_rounded,
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
                                          margin: const EdgeInsets.symmetric(horizontal: 4),
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF8FAFC),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: AppColors.cardBorder),
                                          ),
                                          child: Text(
                                            '$_endUnit',
                                            style: TextStyle(
                                              fontFamily: 'PlusJakartaSans',
                                              fontSize: 14,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ),
                                      ),
                                      _buildStepperButton(
                                        icon: Icons.add_rounded,
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
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.check_circle_rounded, size: 15, color: Color(0xFF059669)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _startUnit == _endUnit
                                        ? 'Mengerjakan $_unitNoun $_startUnit saja (Total ${_unitNumbers.length} $_unitNoun)'
                                        : 'Mengerjakan ${_unitNumbers.length} $_unitNoun: $_unitNoun $_startUnit s/d $_unitNoun $_endUnit',
                                    style: TextStyle(
                                      fontFamily: 'PlusJakartaSans',
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF065F46),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Wajib diambil: $_totalPoints Foto (${_unitNumbers.length} $_unitNoun × $_pointsPerUnit foto poin)',
                                    style: TextStyle(
                                      fontFamily: 'PlusJakartaSans',
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF047857),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // Action Buttons (Batal & Mulai Checklist Unit Berdampingan Horizontal)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        side: const BorderSide(color: AppColors.cardBorder, width: 1.2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Batal',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _generateAndOpenChecklist,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Mulai Pemeriksaan',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
