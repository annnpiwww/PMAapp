import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/theme_service.dart';
import '../../../data/models/daily_task_model.dart';
import '../../../data/models/user_model.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/services/daily_task_service.dart';
import '../../../data/services/branch_service.dart';
import '../../../data/services/storage_service.dart';
import '../widgets/spv_task_card.dart';

class SpvTaskDispatcherScreen extends StatefulWidget {
  const SpvTaskDispatcherScreen({super.key});

  @override
  State<SpvTaskDispatcherScreen> createState() => _SpvTaskDispatcherScreenState();
}

class _SpvTaskDispatcherScreenState extends State<SpvTaskDispatcherScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  List<DailyTaskModel> _tasksToday = [];

  // Filter States
  DateTime _selectedDate = DateTime.now();
  DateTime _targetDispatchDate = DateTime.now();
  String _selectedStatusFilter = 'ALL'; // 'ALL', 'PENDING', 'COMPLETED'
  String _selectedTechFilter = 'SEMUA';
  final Set<String> _expandedTaskIds = <String>{};

  late List<String> _technicians;
  late String _selectedTech;
  String? _shift1ManadoTech;
  late final TextEditingController _lokasiCtrl;
  final _pekerjaanCtrl = TextEditingController();
  final _catatanCtrl = TextEditingController();
  String _taskCategory = 'khusus'; // 'khusus' atau 'maintenance'
  String? _selectedTemplateId = 'tpl_maint_pos';

  final List<Map<String, String>> _templates = [
    {'id': 'tpl_maint_pos', 'nama': 'Maintenance Pos Kasir'},
    {'id': 'tpl_maint_manless', 'nama': 'Maintenance Manless Gate'},
    {'id': 'tpl_maint_barrier', 'nama': 'Maintenance Barrier Gate'},
    {'id': 'tpl_maint_server', 'nama': 'Maintenance PC Server & Kasir'},
  ];

  @override
  void initState() {
    super.initState();
    final currentUser = AuthRepository.instance.currentUser;
    if (currentUser != null && currentUser.role != UserRole.ho) {
      final userBranch = BranchService.parseBranchFromName(currentUser.cabangName);
      if (BranchService.instance.currentBranch != userBranch) {
        BranchService.instance.setBranch(userBranch);
      }
    }
    _technicians = List.from(BranchService.instance.getTechnicians());
    _selectedTech = _technicians.isNotEmpty ? _technicians.first : 'Teknisi';
    _shift1ManadoTech = _technicians.isNotEmpty ? _technicians.first : null;
    _lokasiCtrl = TextEditingController(text: BranchService.instance.currentBranch.defaultLocationTag);
    _tabController = TabController(length: 2, vsync: this);
    _loadTasks();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _lokasiCtrl.dispose();
    _pekerjaanCtrl.dispose();
    _catatanCtrl.dispose();
    super.dispose();
  }

  String _formatDateToKey(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatDateDisplay(DateTime dt) {
    final now = DateTime.now();
    final tomorrow = now.add(const Duration(days: 1));
    final yesterday = now.subtract(const Duration(days: 1));
    final dayNames = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    final monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];

    final dName = dayNames[dt.weekday - 1];
    final mName = monthNames[dt.month - 1];
    final dateNum = dt.day.toString().padLeft(2, '0');

    if (_isSameDay(dt, now)) {
      return 'Hari Ini ($dateNum $mName)';
    } else if (_isSameDay(dt, tomorrow)) {
      return 'Besok ($dateNum $mName)';
    } else if (_isSameDay(dt, yesterday)) {
      return 'Kemarin ($dateNum $mName)';
    } else {
      return '$dName, $dateNum $mName ${dt.year}';
    }
  }

  List<String> get _availableTechnicians {
    final list = <String>['SEMUA'];
    for (final tech in _technicians) {
      if (!list.contains(tech)) list.add(tech);
    }
    return list;
  }

  List<DailyTaskModel> get _filteredTasks {
    final branchTechs = BranchService.instance.getTechnicians();
    return _tasksToday.where((t) {
      if (!branchTechs.contains(t.teknisiNama.trim())) return false;
      if (_selectedStatusFilter == 'PENDING' && t.isCompleted) return false;
      if (_selectedStatusFilter == 'COMPLETED' && !t.isCompleted) return false;
      if (_selectedTechFilter != 'SEMUA' && t.teknisiNama != _selectedTechFilter) return false;
      return true;
    }).toList();
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);
    final dateKey = _formatDateToKey(_selectedDate);
    final tasks = await DailyTaskService.getAllTasksToday(dateKey);
    if (mounted) {
      setState(() {
        _tasksToday = tasks;
        _isLoading = false;
      });
    }
  }

  Future<void> _pickCustomDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) {
        final isDark = ThemeService.isDarkMode(context);
        return Theme(
          data: isDark
              ? ThemeData.dark().copyWith(
                  colorScheme: const ColorScheme.dark(
                    primary: AppColors.accent,
                    onPrimary: Colors.white,
                    surface: Color(0xFF1E293B),
                    onSurface: Colors.white,
                  ),
                  dialogTheme: const DialogThemeData(backgroundColor: Color(0xFF0F172A)),
                )
              : ThemeData.light().copyWith(
                  colorScheme: const ColorScheme.light(
                    primary: AppColors.accent,
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: Color(0xFF1E293B),
                  ),
                ),
          child: child!,
        );
      },
    );

    if (picked != null && !_isSameDay(picked, _selectedDate)) {
      setState(() {
        _selectedDate = picked;
      });
      _loadTasks();
    }
  }

  void _shareRecap() {
    if (_tasksToday.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Belum ada tugas pada tanggal ini.'),
          backgroundColor: Color(0xFFE11D48),
        ),
      );
      return;
    }
    final currentUser = AuthRepository.instance.currentUser;
    final recapText = DailyTaskService.formatSpvTeamRecap(
      tanggal: _formatDateToKey(_selectedDate),
      tasks: _tasksToday,
      spvName: currentUser?.nama ?? 'Supervisor',
      cabangName: currentUser?.cabangName,
    );
    SharePlus.instance.share(
      ShareParams(
        text: recapText,
        subject: 'Rekap Harian Tim - ${_formatDateToKey(_selectedDate)}',
      ),
    );
  }

  void _showMorningDispatchBottomSheet(bool isDark) {
    final branchTechs = BranchService.instance.getTechnicians();
    final teamTasks = _tasksToday.where((t) => branchTechs.contains(t.teknisiNama.trim())).toList();

    if (teamTasks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.info_outline_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Expanded(child: Text('Belum ada tugas pada tanggal ini untuk dibagikan.')),
            ],
          ),
          backgroundColor: const Color(0xFFF59E0B),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    final branchShifts = BranchService.instance.getShifts();
    final savedShifts = Map<String, String>.from(StorageService.getSpvTechShifts());

    // Pastikan semua teknisi aktif punya default shift jika belum ada di cache
    final activeTechs = teamTasks.map((t) => t.teknisiNama.trim()).toSet().toList();
    for (int i = 0; i < activeTechs.length; i++) {
      final tech = activeTechs[i];
      if (!savedShifts.containsKey(tech) || !branchShifts.contains(savedShifts[tech])) {
        savedShifts[tech] = (i < branchShifts.length) ? branchShifts[i] : (branchShifts.isNotEmpty ? branchShifts.first : 'Shift 1');
      }
    }

    final sheetBg = isDark ? const Color(0xFF111827) : Colors.white;
    final handleColor = isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final cardBg = isDark ? const Color(0xFF0B1120) : const Color(0xFFF8FAFC);
    final cardBorder = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    final previewBg = isDark ? const Color(0xFF030712) : const Color(0xFFF1F5F9);
    final previewBorder = isDark ? const Color(0xFF1F2937) : const Color(0xFFCBD5E1);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final previewText = DailyTaskService.formatMorningDispatchReport(
              tasks: teamTasks,
              techShiftMap: savedShifts,
              branch: BranchService.instance.currentBranch,
            );

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.88,
              ),
              padding: const EdgeInsets.only(top: 10, left: 16, right: 16, bottom: 24),
              decoration: BoxDecoration(
                color: sheetBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(top: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Handle Bar
                    Center(
                      child: Container(
                        width: 38,
                        height: 4,
                        decoration: BoxDecoration(
                          color: handleColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Title Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF25D366).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.share_rounded, size: 18, color: Color(0xFF25D366)),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Format Briefing Tim (WA/Telegram)',
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w800,
                                    color: titleColor,
                                  ),
                                ),
                                Text(
                                  '${teamTasks.length} tugas • ${activeTechs.length} teknisi aktif',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                    color: subColor,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(bottomSheetContext),
                          icon: Icon(Icons.close_rounded, size: 20, color: subColor),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Scrollable Content
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Section: Atur Shift Teknisi
                            Text(
                              'ATUR SHIFT TEKNISI HARI INI',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: subColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: cardBorder),
                              ),
                              child: Column(
                                children: activeTechs.map((tech) {
                                  final techTaskCount = teamTasks.where((t) => t.teknisiNama.trim() == tech).length;
                                  final currentShift = savedShifts[tech] ?? (branchShifts.isNotEmpty ? branchShifts.first : 'Shift 1');

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.person_outline_rounded, size: 16, color: AppColors.accent),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                tech,
                                                style: TextStyle(
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: titleColor,
                                                ),
                                              ),
                                              Text(
                                                '$techTaskCount tugas',
                                                style: TextStyle(
                                                  fontSize: 10.5,
                                                  color: subColor,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: sheetBg,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: cardBorder),
                                          ),
                                          child: DropdownButtonHideUnderline(
                                            child: DropdownButton<String>(
                                              value: branchShifts.contains(currentShift) ? currentShift : branchShifts.first,
                                              isDense: true,
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w600,
                                                color: titleColor,
                                              ),
                                              dropdownColor: sheetBg,
                                              items: branchShifts.map((s) {
                                                return DropdownMenuItem(
                                                  value: s,
                                                  child: Text(s, style: TextStyle(color: titleColor, fontSize: 11.5)),
                                                );
                                              }).toList(),
                                              onChanged: (val) {
                                                if (val != null) {
                                                  savedShifts[tech] = val;
                                                  StorageService.saveSpvTechShift(tech, val);
                                                  setModalState(() {});
                                                }
                                              },
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Section: Live Preview Teks
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'PREVIEW PESAN SIAP KIRIM',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: subColor,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const Text(
                                  'Auto-grouped by Shift',
                                  style: TextStyle(fontSize: 10, color: AppColors.accent, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: previewBg,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: previewBorder),
                              ),
                              child: SelectableText(
                                previewText,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                  height: 1.45,
                                  color: titleColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: previewText));
                              Navigator.pop(bottomSheetContext);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Row(
                                    children: [
                                      Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                                      SizedBox(width: 8),
                                      Text('Format briefing berhasil disalin ke clipboard!'),
                                    ],
                                  ),
                                  backgroundColor: const Color(0xFF10B981),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              );
                            },
                            icon: const Icon(Icons.copy_rounded, size: 16),
                            label: const Text('Salin Format'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.accent,
                              side: const BorderSide(color: AppColors.accent, width: 1.2),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(bottomSheetContext);
                              SharePlus.instance.share(
                                ShareParams(
                                  text: previewText,
                                  subject: 'Briefing Harian Tim - ${_formatDateToKey(_selectedDate)}',
                                ),
                              );
                            },
                            icon: const Icon(Icons.send_rounded, size: 16),
                            label: const Text('Kirim ke WA'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF25D366),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
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

  Future<void> _pickTargetDispatchDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDispatchDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) {
        final isDark = ThemeService.isDarkMode(context);
        return Theme(
          data: isDark
              ? ThemeData.dark().copyWith(
                  colorScheme: const ColorScheme.dark(
                    primary: AppColors.accent,
                    onPrimary: Colors.white,
                    surface: Color(0xFF1E293B),
                    onSurface: Colors.white,
                  ),
                  dialogTheme: const DialogThemeData(backgroundColor: Color(0xFF0F172A)),
                )
              : ThemeData.light().copyWith(
                  colorScheme: const ColorScheme.light(
                    primary: AppColors.accent,
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: Color(0xFF1E293B),
                  ),
                ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _targetDispatchDate = picked;
      });
    }
  }

  Widget _buildRoutineTaskItem({
    required String num,
    required String title,
    required bool isDark,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 18,
          height: 18,
          margin: const EdgeInsets.only(top: 1.5),
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.accent.withValues(alpha: 0.5), width: 1),
          ),
          child: Center(
            child: Text(
              num,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.accent),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _dispatchShift1ManadoRoutine(String selectedTech) async {
    if (_isLoading) return;

    final isDark = ThemeService.isDarkMode(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.bolt_rounded, color: AppColors.accent, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tugaskan Rutin Shift 1',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Kirim 2 tugas rutin Shift 1 ke teknisi:',
                style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
              const SizedBox(height: 6),
              Text(
                '👤 $selectedTech',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '📅 Target: ${_formatDateDisplay(_targetDispatchDate)}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.accent),
              ),
              const SizedBox(height: 12),
              const Text(
                '1. Pengecekan Sistem Gate out 1-6 PBM (bukti dokumentasi layar aplikasi kasir)\n2. Pengecekan Sistem Gate ojek',
                style: TextStyle(fontSize: 12, height: 1.4, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal', style: TextStyle(color: Color(0xFF94A3B8))),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Kirim Sekarang', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    final targetDateKey = _formatDateToKey(_targetDispatchDate);

    // 1. Task Gate Out 1-6 PBM
    final res1 = await DailyTaskService.createTask(
      tanggal: targetDateKey,
      teknisiNama: selectedTech,
      posName: 'PBM',
      posTag: 'PBM',
      judul: 'Pengecekan Sistem Gate out 1-6 PBM (bukti dokumentasi layar aplikasi kasir)',
      deskripsi: 'Pengecekan operasional sistem gate out 1-6 pos PBM. Wajib lampirkan bukti foto dokumentasi layar aplikasi kasir aktif.',
      kategori: 'khusus',
    );

    // 2. Task Gate Ojek
    final res2 = await DailyTaskService.createTask(
      tanggal: targetDateKey,
      teknisiNama: selectedTech,
      posName: 'PBM',
      posTag: 'PBM',
      judul: 'Pengecekan Sistem Gate ojek',
      deskripsi: 'Pengecekan fungsionalitas barrier gate ojek, tap card reader, dan sensor kendaraan.',
      kategori: 'khusus',
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (res1 != null && res2 != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('2 Tugas Rutin Shift 1 berhasil dikirim ke $selectedTech untuk ${_formatDateDisplay(_targetDispatchDate)}'),
            backgroundColor: AppColors.success,
          ),
        );
        _selectedDate = _targetDispatchDate;
        _tabController.animateTo(1);
        _loadTasks();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res1 != null || res2 != null
                ? 'Sebagian tugas berhasil dikirim. Periksa Status Tim.'
                : 'Tugas rutin gagal dikirim. Periksa koneksi lalu coba lagi.'),
            backgroundColor: res1 != null || res2 != null ? AppColors.warning : AppColors.danger,
          ),
        );
        _selectedDate = _targetDispatchDate;
        _tabController.animateTo(1);
        _loadTasks();
      }
    }
  }

  Future<void> _submitTask() async {
    if (_isLoading) return; // Anti-double submit

    final lokasi = _lokasiCtrl.text.trim();
    final pekerjaan = _pekerjaanCtrl.text.trim();

    if (lokasi.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lokasi harus diisi.')),
      );
      return;
    }

    if (pekerjaan.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Detail pekerjaan harus diisi.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final res = await DailyTaskService.createTask(
      tanggal: _formatDateToKey(_targetDispatchDate),
      teknisiNama: _selectedTech,
      posName: lokasi,
      posTag: lokasi,
      judul: pekerjaan,
      deskripsi: _catatanCtrl.text.trim(),
      kategori: _taskCategory,
      templateId: _taskCategory == 'maintenance' ? _selectedTemplateId : null,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (res != null) {
        _pekerjaanCtrl.clear();
        _catatanCtrl.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tugas berhasil dikirim ke $_selectedTech untuk ${_formatDateDisplay(_targetDispatchDate)}'),
            backgroundColor: AppColors.success,
          ),
        );
        _selectedDate = _targetDispatchDate;
        _tabController.animateTo(1);
        _loadTasks();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tugas gagal dikirim. Periksa koneksi lalu coba lagi.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthRepository.instance.currentUser;
    final isDark = ThemeService.isDarkMode(context);

    if (user?.role != UserRole.supervisor) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: isDark ? const Color(0xFF1E293B) : AppColors.primary,
          title: const Text('Akses Dibatasi', style: TextStyle(color: Colors.white)),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              'Halaman ini khusus untuk Supervisor (SPV).\nTeknisi hanya melihat tugas di layar utama kamera.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                fontSize: 14,
              ),
            ),
          ),
        ),
      );
    }

    final bgScaffold = isDark ? const Color(0xFF0B1120) : const Color(0xFFFAF8F5);
    final bgAppBar = isDark ? const Color(0xFF111827) : AppColors.primary;

    return Scaffold(
      backgroundColor: bgScaffold,
      appBar: AppBar(
        backgroundColor: bgAppBar,
        elevation: 0,
        title: const Text(
          'Daily Task Team PMA',
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Format Briefing WA / Telegram',
            icon: const Icon(Icons.share_rounded, color: Colors.white),
            onPressed: () => _showMorningDispatchBottomSheet(isDark),
          ),
          const SizedBox(width: 4),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.accent,
          labelColor: Colors.white,
          unselectedLabelColor: isDark ? const Color(0xFF94A3B8) : Colors.white70,
          tabs: const [
            Tab(text: 'Beri Tugas'),
            Tab(text: 'Status Tim'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFormTugaskan(isDark),
          _buildListPantau(isDark),
        ],
      ),
    );
  }

  Widget _buildFormTugaskan(bool isDark) {
    final labelColor = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155);
    final inputBg = isDark ? const Color(0xFF111827) : Colors.white;
    final inputBorder = isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final hintColor = isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // QUICK DISPATCH: RUTIN SHIFT 1 MANADO (2 TUGAS PERMANEN)
          if (BranchService.instance.currentBranch == AppBranch.manado) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                      : [const Color(0xFFEFF6FF), Colors.white],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.accent.withValues(alpha: isDark ? 0.35 : 0.45),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.bolt_rounded, color: AppColors.accent, size: 20),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Rutin Shift 1 KC Manado',
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              '2 Tugas Permanen Pagi (03:00 - 11:00 WITA)',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'PBM',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                            color: AppColors.accent,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // List 2 tugas permanen
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF111827).withValues(alpha: 0.5) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildRoutineTaskItem(
                          num: '1',
                          title: 'Pengecekan Sistem Gate out 1-6 PBM (bukti dokumentasi layar aplikasi kasir)',
                          isDark: isDark,
                        ),
                        const SizedBox(height: 8),
                        _buildRoutineTaskItem(
                          num: '2',
                          title: 'Pengecekan Sistem Gate ojek',
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Row teknisi dan tombol kirim
                  Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: inputBg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: inputBorder),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _shift1ManadoTech ?? (_technicians.isNotEmpty ? _technicians.first : null),
                              isExpanded: true,
                              dropdownColor: inputBg,
                              style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.w600),
                              items: _technicians.map((t) => DropdownMenuItem(
                                value: t,
                                child: Text(t, overflow: TextOverflow.ellipsis),
                              )).toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _shift1ManadoTech = val);
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 6,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading
                              ? null
                              : () => _dispatchShift1ManadoRoutine(_shift1ManadoTech ?? _selectedTech),
                          icon: const Icon(Icons.send_rounded, size: 14),
                          label: const Text(
                            'Kirim 2 Tugas',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],

          // PILIH TARGET TANGGAL PENUGASAN
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Target Tanggal Penugasan *',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: labelColor),
              ),
              InkWell(
                onTap: _pickTargetDispatchDate,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_month_rounded, size: 14, color: AppColors.accent),
                      const SizedBox(width: 4),
                      Text(
                        _formatDateDisplay(_targetDispatchDate),
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(3.5),
            decoration: BoxDecoration(
              color: inputBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: inputBorder, width: 1.0),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _targetDispatchDate = DateTime.now()),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _isSameDay(_targetDispatchDate, DateTime.now()) ? AppColors.accent : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Hari Ini',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: _isSameDay(_targetDispatchDate, DateTime.now()) ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _targetDispatchDate = DateTime.now().add(const Duration(days: 1))),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _isSameDay(_targetDispatchDate, DateTime.now().add(const Duration(days: 1))) ? AppColors.accent : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Besok',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: _isSameDay(_targetDispatchDate, DateTime.now().add(const Duration(days: 1))) ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: _pickTargetDispatchDate,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: (!_isSameDay(_targetDispatchDate, DateTime.now()) && !_isSameDay(_targetDispatchDate, DateTime.now().add(const Duration(days: 1))))
                            ? AppColors.accent
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.event_rounded,
                            size: 14,
                            color: (!_isSameDay(_targetDispatchDate, DateTime.now()) && !_isSameDay(_targetDispatchDate, DateTime.now().add(const Duration(days: 1))))
                                ? Colors.white
                                : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Pilih Lain',
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: (!_isSameDay(_targetDispatchDate, DateTime.now()) && !_isSameDay(_targetDispatchDate, DateTime.now().add(const Duration(days: 1))))
                                  ? Colors.white
                                  : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Segment Jenis Tugas
          Text(
            'Jenis Tugas *',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: labelColor),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(3.5),
            decoration: BoxDecoration(
              color: inputBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: inputBorder, width: 1.0),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _taskCategory = 'khusus'),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _taskCategory == 'khusus' ? AppColors.accent : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: _taskCategory == 'khusus'
                            ? [
                                BoxShadow(
                                  color: AppColors.accent.withValues(alpha: 0.3),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Text(
                        'Tugas Khusus',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.1,
                          color: _taskCategory == 'khusus' ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _taskCategory = 'maintenance'),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _taskCategory == 'maintenance' ? AppColors.accent : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: _taskCategory == 'maintenance'
                            ? [
                                BoxShadow(
                                  color: AppColors.accent.withValues(alpha: 0.3),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Text(
                        'Maintenance SOP',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.1,
                          color: _taskCategory == 'maintenance' ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Dropdown Teknisi
          Text(
            'Pilih Teknisi *',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: labelColor),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: inputBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: inputBorder),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedTech,
                isExpanded: true,
                dropdownColor: inputBg,
                style: TextStyle(color: textColor, fontSize: 13),
                items: _technicians.map((t) => DropdownMenuItem(value: t, child: Text(t, style: TextStyle(color: textColor)))).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedTech = val);
                },
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Template jika Maintenance SOP
          if (_taskCategory == 'maintenance') ...[
            Text(
              'Template SOP *',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: labelColor),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: inputBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: inputBorder),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedTemplateId,
                  isExpanded: true,
                  dropdownColor: inputBg,
                  style: TextStyle(color: textColor, fontSize: 13),
                  items: _templates.map((tpl) => DropdownMenuItem(value: tpl['id'], child: Text(tpl['nama']!, style: TextStyle(color: textColor)))).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedTemplateId = val;
                        final found = _templates.firstWhere((e) => e['id'] == val);
                        _pekerjaanCtrl.text = '${found['nama']} - ${_lokasiCtrl.text.trim()}';
                      });
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Lokasi Manual Murni & Quick Selection
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Lokasi *',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: labelColor),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: isDark ? 0.15 : 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  BranchService.instance.currentBranch.name,
                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.accent),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _lokasiCtrl,
            style: TextStyle(color: textColor, fontSize: 13),
            decoration: InputDecoration(
              hintText: BranchService.instance.currentBranch == AppBranch.bali
                  ? 'Contoh: PBKD, PCD, PKRD'
                  : 'Contoh: PBM, TBM, PKM',
              hintStyle: TextStyle(color: hintColor, fontSize: 13),
              filled: true,
              fillColor: inputBg,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: inputBorder)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: inputBorder)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.accent, width: 1.5)),
            ),
          ),

          const SizedBox(height: 16),

          // Detail Pekerjaan
          Text(
            'Detail Pekerjaan *',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: labelColor),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _pekerjaanCtrl,
            style: TextStyle(color: textColor, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Contoh: Pengecatan markah panah lokasi TBM',
              hintStyle: TextStyle(color: hintColor, fontSize: 13),
              filled: true,
              fillColor: inputBg,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: inputBorder)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: inputBorder)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.accent, width: 1.5)),
            ),
          ),
          const SizedBox(height: 16),

          // Catatan Tambahan
          Text(
            'Catatan (Opsional)',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: labelColor),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _catatanCtrl,
            maxLines: 2,
            style: TextStyle(color: textColor, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Instruksi atau catatan khusus jika ada',
              hintStyle: TextStyle(color: hintColor, fontSize: 13),
              filled: true,
              fillColor: inputBg,
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: inputBorder)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: inputBorder)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.accent, width: 1.5)),
            ),
          ),
          const SizedBox(height: 24),

          // Tombol Kirim Tugas (Min height 46px)
          ElevatedButton(
            onPressed: _isLoading ? null : _submitTask,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 46),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: _isLoading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Kirim Tugas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildListPantau(bool isDark) {
    return RefreshIndicator(
      onRefresh: _loadTasks,
      color: AppColors.accent,
      child: Column(
        children: [
          _buildTopHeaderBar(isDark),
          _buildQuickStatusFilterBar(isDark),
          if (_selectedTechFilter != 'SEMUA') _buildActiveTechFilterBanner(isDark),
          const SizedBox(height: 4),
          Expanded(
            child: _buildTaskList(isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildTopHeaderBar(bool isDark) {
    final total = _tasksToday.length;
    final completed = _tasksToday.where((t) => t.isCompleted).length;
    final percentInt = total > 0 ? ((completed / total) * 100).toInt() : 0;
    final now = DateTime.now();
    final isToday = _isSameDay(_selectedDate, now);
    final dateLabel = isToday ? 'Hari Ini' : _formatDateDisplay(_selectedDate);
    final hasActiveFilter = _selectedTechFilter != 'SEMUA' || !isToday;

    final headerBg = isDark ? const Color(0xFF0B1120) : const Color(0xFFFAF8F5);
    final pillBg = isDark ? const Color(0xFF111827) : Colors.white;
    final pillBorder = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    final dateTextColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: headerBg,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Tanggal & Mini Rekap Pill
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: pillBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: pillBorder),
                  boxShadow: isDark ? null : [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 1)),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 12, color: AppColors.accent),
                    const SizedBox(width: 5),
                    Text(
                      dateLabel,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: dateTextColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: completed == total && total > 0
                      ? AppColors.success.withValues(alpha: isDark ? 0.15 : 0.12)
                      : AppColors.accent.withValues(alpha: isDark ? 0.12 : 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: completed == total && total > 0
                        ? AppColors.success.withValues(alpha: 0.3)
                        : AppColors.accent.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      completed == total && total > 0 ? Icons.check_circle_rounded : Icons.bolt_rounded,
                      size: 13,
                      color: completed == total && total > 0 ? AppColors.success : AppColors.accent,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$completed/$total ($percentInt%)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: completed == total && total > 0 ? AppColors.success : AppColors.accent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Right: Tombol Kontrol Tim
          InkWell(
            onTap: () => _showTeamControlBottomSheet(isDark),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.tune_rounded, size: 14, color: Colors.white),
                  const SizedBox(width: 5),
                  const Text(
                    'Kontrol Tim',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  if (hasActiveFilter) ...[
                    const SizedBox(width: 4),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStatusFilterBar(bool isDark) {
    final pendingCount = _tasksToday.where((t) => !t.isCompleted).length;
    final doneCount = _tasksToday.where((t) => t.isCompleted).length;
    final total = _tasksToday.length;

    final filterBarBg = isDark ? const Color(0xFF111827) : const Color(0xFFF1F5F9);
    final filterBarBorder = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: filterBarBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: filterBarBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatusSegment(
              label: 'Selesai ($doneCount)',
              filterKey: 'COMPLETED',
              isDark: isDark,
            ),
          ),
          Expanded(
            child: _buildStatusSegment(
              label: 'Belum Mulai ($pendingCount)',
              filterKey: 'PENDING',
              isDark: isDark,
            ),
          ),
          Expanded(
            child: _buildStatusSegment(
              label: 'Semua ($total)',
              filterKey: 'ALL',
              isDark: isDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSegment({
    required String label,
    required String filterKey,
    required bool isDark,
  }) {
    final isSelected = _selectedStatusFilter == filterKey;
    final selectedBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final inactiveText = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final activeText = isDark ? Colors.white : AppColors.accent;

    return InkWell(
      onTap: () => setState(() => _selectedStatusFilter = filterKey),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6.5),
        decoration: BoxDecoration(
          color: isSelected ? selectedBg : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected
              ? Border.all(color: AppColors.accent.withValues(alpha: 0.8), width: 1.2)
              : null,
          boxShadow: isSelected && !isDark ? [
            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 1)),
          ] : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? activeText : inactiveText,
          ),
        ),
      ),
    );
  }

  Widget _buildActiveTechFilterBanner(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.person_rounded, size: 13, color: AppColors.accent),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Filter Teknisi: $_selectedTechFilter',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ),
          InkWell(
            onTap: () => setState(() => _selectedTechFilter = 'SEMUA'),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'Reset ✕',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.accent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showTeamControlBottomSheet(bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final total = _tasksToday.length;
            final completed = _tasksToday.where((t) => t.isCompleted).length;
            final pending = total - completed;
            final percent = total > 0 ? (completed / total) : 0.0;
            final percentInt = (percent * 100).toInt();

            final now = DateTime.now();
            final yesterday = now.subtract(const Duration(days: 1));
            final isToday = _isSameDay(_selectedDate, now);
            final isYesterday = _isSameDay(_selectedDate, yesterday);
            final isCustom = !isToday && !isYesterday;

            final sheetBg = isDark ? const Color(0xFF111827) : Colors.white;
            final handleColor = isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);
            final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
            final closeColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
            final sectionTitleColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
            final recapBg = isDark ? const Color(0xFF0B1120) : const Color(0xFFF8FAFC);
            final recapBorder = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
            final progressTrack = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);

            return Container(
              padding: const EdgeInsets.only(top: 10, left: 16, right: 16, bottom: 24),
              decoration: BoxDecoration(
                color: sheetBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(top: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Handle Bar
                    Center(
                      child: Container(
                        width: 38,
                        height: 4,
                        decoration: BoxDecoration(
                          color: handleColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Sheet Title
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.tune_rounded, size: 18, color: AppColors.accent),
                            const SizedBox(width: 8),
                            Text(
                              'Kontrol Tim & Rekap',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: titleColor,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(bottomSheetContext),
                          icon: Icon(Icons.close_rounded, size: 20, color: closeColor),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Switch Cabang Aktif SPV (Hanya jika user login adalah HO, jika SPV terkunci sesuai cabangnya)
                    if (AuthRepository.instance.currentUser?.role == UserRole.ho)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0B1120) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(color: recapBorder),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () async {
                                  if (BranchService.instance.currentBranch != AppBranch.manado) {
                                    await BranchService.instance.setBranch(AppBranch.manado);
                                    setState(() {
                                      _technicians = List.from(BranchService.instance.getTechnicians());
                                      _selectedTech = _technicians.isNotEmpty ? _technicians.first : 'Teknisi';
                                      _lokasiCtrl.text = BranchService.instance.currentBranch.defaultLocationTag;
                                      _selectedTechFilter = 'SEMUA';
                                    });
                                    await _loadTasks();
                                    setModalState(() {});
                                  }
                                },
                                borderRadius: BorderRadius.circular(7),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 6.5),
                                  decoration: BoxDecoration(
                                    color: BranchService.instance.currentBranch == AppBranch.manado
                                        ? AppColors.accent
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(7),
                                  ),
                                  child: Text(
                                    'KC Manado',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: BranchService.instance.currentBranch == AppBranch.manado
                                          ? FontWeight.bold
                                          : FontWeight.w600,
                                      color: BranchService.instance.currentBranch == AppBranch.manado
                                          ? Colors.white
                                          : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: InkWell(
                                onTap: () async {
                                  if (BranchService.instance.currentBranch != AppBranch.bali) {
                                    await BranchService.instance.setBranch(AppBranch.bali);
                                    setState(() {
                                      _technicians = List.from(BranchService.instance.getTechnicians());
                                      _selectedTech = _technicians.isNotEmpty ? _technicians.first : 'Teknisi';
                                      _lokasiCtrl.text = BranchService.instance.currentBranch.defaultLocationTag;
                                      _selectedTechFilter = 'SEMUA';
                                    });
                                    await _loadTasks();
                                    setModalState(() {});
                                  }
                                },
                                borderRadius: BorderRadius.circular(7),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 6.5),
                                  decoration: BoxDecoration(
                                    color: BranchService.instance.currentBranch == AppBranch.bali
                                        ? AppColors.accent
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(7),
                                  ),
                                  child: Text(
                                    'KC Bali',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: BranchService.instance.currentBranch == AppBranch.bali
                                          ? FontWeight.bold
                                          : FontWeight.w600,
                                      color: BranchService.instance.currentBranch == AppBranch.bali
                                          ? Colors.white
                                          : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0B1120) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: recapBorder),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.location_on_rounded, size: 15, color: AppColors.accent),
                            const SizedBox(width: 6),
                            Text(
                              'Cabang: ${BranchService.instance.currentBranch.name}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // SECTION 1: REKAP TIM LENGKAP
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: recapBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: recapBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Progres Harian Tim',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: titleColor,
                                ),
                              ),
                              Text(
                                '$percentInt% Selesai',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: percentInt == 100 ? AppColors.success : AppColors.accent,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: percent,
                              minHeight: 5,
                              backgroundColor: progressTrack,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                percentInt == 100 ? AppColors.success : AppColors.accent,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatItem(
                                  label: 'Total',
                                  value: '$total',
                                  icon: Icons.assignment_outlined,
                                  color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                                  isDark: isDark,
                                ),
                              ),
                              Expanded(
                                child: _buildStatItem(
                                  label: 'Selesai',
                                  value: '$completed',
                                  icon: Icons.check_circle_outline_rounded,
                                  color: AppColors.success,
                                  isDark: isDark,
                                ),
                              ),
                              Expanded(
                                child: _buildStatItem(
                                  label: 'Belum Mulai',
                                  value: '$pending',
                                  icon: Icons.schedule_rounded,
                                  color: AppColors.accent,
                                  isDark: isDark,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(bottomSheetContext);
                              _showMorningDispatchBottomSheet(isDark);
                            },
                            icon: const Icon(Icons.copy_rounded, size: 14),
                            label: const Text('Format Briefing Pagi (WA / Telegram)'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.accent,
                              side: const BorderSide(color: AppColors.accent, width: 1.2),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(bottomSheetContext);
                              _shareRecap();
                            },
                            icon: const Icon(Icons.share_rounded, size: 14),
                            label: const Text('Bagikan Rekap Tim ke WhatsApp'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF25D366),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // SECTION 2: PILIH TANGGAL
                    Text(
                      'TANGGAL OPERASIONAL',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: sectionTitleColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDateChip(
                            label: 'Hari Ini',
                            isSelected: isToday,
                            isDark: isDark,
                            onTap: () {
                              if (!isToday) {
                                setState(() => _selectedDate = now);
                                setModalState(() {});
                                _loadTasks();
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _buildDateChip(
                            label: 'Kemarin',
                            isSelected: isYesterday,
                            isDark: isDark,
                            onTap: () {
                              if (!isYesterday) {
                                setState(() => _selectedDate = yesterday);
                                setModalState(() {});
                                _loadTasks();
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _buildDateChip(
                            label: isCustom ? _formatDateDisplay(_selectedDate) : 'Pilih 📅',
                            isSelected: isCustom,
                            isDark: isDark,
                            icon: Icons.calendar_month_rounded,
                            onTap: () async {
                              await _pickCustomDate();
                              setModalState(() {});
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // SECTION 3: FILTER TEKNISI
                    Text(
                      'FILTER TEKNISI LAPANGAN',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: sectionTitleColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _availableTechnicians.map((tech) {
                        final isSelected = _selectedTechFilter == tech;
                        final isAll = tech == 'SEMUA';
                        final String chipLabel;
                        if (isAll) {
                          chipLabel = 'Semua ($total)';
                        } else {
                          final techTasks = _tasksToday.where((t) => t.teknisiNama == tech).toList();
                          final done = techTasks.where((t) => t.isCompleted).length;
                          chipLabel = '$tech ($done/${techTasks.length})';
                        }

                        final unselectedChipBg = isDark ? const Color(0xFF0B1120) : const Color(0xFFF1F5F9);
                        final unselectedChipBorder = isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);
                        final unselectedChipText = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155);

                        return InkWell(
                          onTap: () {
                            setState(() {
                              _selectedTechFilter = tech;
                            });
                            setModalState(() {});
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.accent
                                  : unselectedChipBg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.accent
                                    : unselectedChipBorder,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isAll ? Icons.group_outlined : Icons.person_outline_rounded,
                                  size: 12,
                                  color: isSelected ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  chipLabel,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    color: isSelected ? Colors.white : unselectedChipText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18),

                    // Tombol Terapkan / Tutup
                    ElevatedButton(
                      onPressed: () => Navigator.pop(bottomSheetContext),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text(
                        'Terapkan & Lihat Tugas',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
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

  Widget _buildDateChip({
    required String label,
    required bool isSelected,
    IconData? icon,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    final unselectedBg = isDark ? const Color(0xFF0B1120) : const Color(0xFFF1F5F9);
    final unselectedBorder = isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);
    final unselectedText = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent.withValues(alpha: isDark ? 0.2 : 0.15) : unselectedBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.accent : unselectedBorder,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 13,
                color: isSelected ? AppColors.accent : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
              const SizedBox(width: 5),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? (isDark ? Colors.white : AppColors.accent) : unselectedText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    final cardBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    final labelColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: cardBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            '$value ',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: labelColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskList(bool isDark) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accent));
    }

    if (_tasksToday.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.assignment_outlined, size: 44, color: isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8)),
                const SizedBox(height: 12),
                Text(
                  'Tidak ada tugas untuk tanggal ini',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Semua penugasan akan muncul di sini setelah dibuat.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _loadTasks,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Muat Ulang'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                    side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final tasks = _filteredTasks;

    if (tasks.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.filter_alt_off_outlined, size: 40, color: isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8)),
                const SizedBox(height: 10),
                Text(
                  'Tidak ada tugas yang sesuai filter',
                  style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 13),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedStatusFilter = 'ALL';
                      _selectedTechFilter = 'SEMUA';
                    });
                  },
                  icon: const Icon(Icons.clear_all_rounded, size: 16),
                  label: const Text('Reset Filter'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    foregroundColor: isDark ? Colors.white : AppColors.primary,
                    side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: tasks.length,
      separatorBuilder: (_, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final t = tasks[index];
        return SpvTaskCard(
          task: t,
          isDark: isDark,
          isExpanded: _expandedTaskIds.contains(t.id),
          onToggleExpand: () {
            setState(() {
              if (_expandedTaskIds.contains(t.id)) {
                _expandedTaskIds.remove(t.id);
              } else {
                _expandedTaskIds.add(t.id);
              }
            });
          },
        );
      },
    );
  }

}
