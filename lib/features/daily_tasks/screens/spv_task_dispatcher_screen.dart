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
import '../widgets/app_outlined_form_field.dart';
import '../widgets/spv_progress_ring_card.dart';
import '../widgets/spv_status_segment_bar.dart';
import '../widgets/spv_task_card.dart';
import '../widgets/spv_tech_filter_strip.dart';
import '../widgets/task_handover_dialog.dart';

class SpvTaskDispatcherScreen extends StatefulWidget {
  const SpvTaskDispatcherScreen({super.key});

  @override
  State<SpvTaskDispatcherScreen> createState() => _SpvTaskDispatcherScreenState();
}

class _SpvTaskDispatcherScreenState extends State<SpvTaskDispatcherScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  late final AnimationController _pulse;
  List<DailyTaskModel> _tasksToday = [];

  // Filter States
  DateTime _selectedDate = DateTime.now();
  DateTime _targetDispatchDate = DateTime.now();
  String _selectedStatusFilter = 'ALL'; // 'ALL', 'PENDING', 'COMPLETED'
  String _selectedTechFilter = 'SEMUA';
  final Set<String> _expandedTaskIds = <String>{};

  late List<String> _technicians;
  late String _selectedTech;
  String _formTab = 'khusus'; // 'rutin' hanya muncul di cabang Manado
  late final TextEditingController _lokasiCtrl;
  final _pekerjaanCtrl = TextEditingController();
  final _catatanCtrl = TextEditingController();
  String _taskCategory = 'khusus'; // 'khusus' atau 'maintenance'
  String? _selectedTemplateId = 'tpl_maint_pos';
  final Set<String> _pesertaTerpilih = {}; // teknisi tambahan (tugas bareng)
  bool _pesertaTerbuka = true; // daftar teknisi tambahan terbuka/tertutup

  final List<Map<String, String>> _templates = [
    {'id': 'tpl_maint_pos', 'nama': 'Maintenance Pos Parkir & Booth'},
    {'id': 'tpl_maint_manless', 'nama': 'Maintenance Manless Gate'},
    {'id': 'tpl_maint_barrier', 'nama': 'Maintenance Barrier Gate'},
    {'id': 'tpl_maint_server', 'nama': 'Maintenance PC Server & Kasir'},
    {
      'id': 'tpl_maint_lengkap',
      'nama': 'Maintenance Lengkap (Gate + Manless + Pos + Server)',
    },
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
    _lokasiCtrl = TextEditingController(text: BranchService.instance.currentBranch.defaultLocationTag);
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _loadTasks();
  }

  @override
  void dispose() {
    _pulse.dispose();
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

  /// Tugas hari ini milik teknisi cabang aktif. Tugas cabang lain tidak ikut
  /// dihitung dan tidak ikut ke rekap, biar SPV Bali tidak melihat pekerjaan Manado.
  List<DailyTaskModel> get _teamTasks =>
      DailyTaskService.tasksForBranch(_tasksToday);

  List<DailyTaskModel> get _filteredTasks {
    return _techScopedTasks.where((t) {
      if (_selectedStatusFilter == 'PENDING' && t.isCompleted) return false;
      if (_selectedStatusFilter == 'COMPLETED' && !t.isCompleted) return false;
      return true;
    }).toList();
  }

  /// Tugas tim yang tampil saat filter teknisi aktif. Teknisi tambahan (peserta)
  /// ikut dihitung sebagai pelaksana tugas itu.
  List<DailyTaskModel> get _techScopedTasks {
    if (_selectedTechFilter == 'SEMUA') return _teamTasks;
    final tech = _selectedTechFilter;
    return _teamTasks.where((t) => t.teknisiNama == tech || t.pesertaList.contains(tech)).toList();
  }

  int _pendingForTech(String tech) {
    if (tech == 'SEMUA') return _teamTasks.where((t) => !t.isCompleted).length;
    return _teamTasks.where((t) => !t.isCompleted && (t.teknisiNama == tech || t.pesertaList.contains(tech))).length;
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);
    // MediaQuery tidak boleh dibaca di initState, jadi pulse dijadwalkan setelah frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_isLoading || _pulse.isAnimating) return;
      if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) return;
      _pulse.repeat(reverse: true);
    });
    final dateKey = _formatDateToKey(_selectedDate);
    final tasks = await DailyTaskService.getAllTasksToday(dateKey);
    _pulse.stop();
    if (mounted) {
      setState(() {
        _tasksToday = tasks;
        _isLoading = false;
      });
    }
  }

  /// SPV memindahkan tugas yang belum selesai ke teknisi shift berikutnya.
  Future<void> _alihkanTugas(DailyTaskModel task) async {
    final spv = AuthRepository.instance.currentUser;
    await TaskHandoverDialog.show(
      context,
      judul: task.judul,
      lokasi: task.posName,
      pemilik: task.teknisiNama,
      judulDialog: 'Alihkan Tugas',
      tujuanLabel: 'Alihkan Ke',
      tombolLabel: 'Alihkan Sekarang',
      teknisiOptions: _technicians.where((t) => !DailyTaskService.isAssignedTo(task, t)).toList(),
      onSubmit: (alasan, penerus) async {
        final ok = await DailyTaskService.transferTask(
          task: task,
          keTeknisi: penerus,
          alasan: alasan,
          olehSiapa: spv?.nama ?? 'SPV',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                ok
                    ? (penerus.isEmpty ? 'Tugas dilepas ke daftar terbuka.' : 'Tugas dialihkan ke $penerus.')
                    : 'Gagal mengalihkan tugas, coba lagi saat sinyal stabil.',
              ),
              backgroundColor: ok ? AppColors.success : AppColors.danger,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        if (ok) await _loadTasks();
        return ok;
      },
    );
  }

  Future<void> _hapusTugas(DailyTaskModel task) async {
    if (task.isCompleted) return;
    final isDark = ThemeService.isDarkMode(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Hapus Tugas?',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        content: Text(
          'Tugas "${task.judul}" untuk ${task.teknisiNama} akan dihapus permanen.',
          style: TextStyle(
            fontSize: 13,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final deleted = await DailyTaskService.deleteTask(task);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          deleted
              ? 'Tugas "${task.judul}" dihapus.'
              : 'Gagal menghapus tugas, coba lagi saat sinyal stabil.',
        ),
        backgroundColor: deleted ? AppColors.success : AppColors.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
    if (deleted) {
      setState(() => _tasksToday.removeWhere((t) => t.id == task.id));
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
    if (_teamTasks.isEmpty) {
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
      tasks: _teamTasks,
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
    final teamTasks = _teamTasks;

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
                                      Text('Format briefing tersalin.'),
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

  Future<bool> _dispatchShift1ManadoRoutine(String selectedTech) async {
    if (_isLoading) return false;

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

    if (confirm != true) return false;

    setState(() => _isLoading = true);
    final targetDateKey = _formatDateToKey(_targetDispatchDate);

    DailyTaskModel? res1;
    DailyTaskModel? res2;
    try {
      // 1. Task Gate Out 1-6 PBM
      res1 = await DailyTaskService.createTask(
        tanggal: targetDateKey,
        teknisiNama: selectedTech,
        posName: 'PBM',
        posTag: 'PBM',
        judul: 'Pengecekan Sistem Gate out 1-6 PBM (bukti dokumentasi layar aplikasi kasir)',
        deskripsi: 'Pengecekan operasional sistem gate out 1-6 pos PBM. Wajib lampirkan bukti foto dokumentasi layar aplikasi kasir aktif.',
        kategori: 'khusus',
      );

      // 2. Task Gate Ojek
      res2 = await DailyTaskService.createTask(
        tanggal: targetDateKey,
        teknisiNama: selectedTech,
        posName: 'PBM',
        posTag: 'PBM',
        judul: 'Pengecekan Sistem Gate ojek',
        deskripsi: 'Pengecekan fungsionalitas barrier gate ojek, tap card reader, dan sensor kendaraan.',
        kategori: 'khusus',
      );
    } catch (e) {
      debugPrint('[SpvTaskDispatcherScreen] _dispatchShift1RoutineTasks error: $e');
    }

    final success = res1 != null && res2 != null;
    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        final isOffline = res1.id.startsWith('local_') || res2.id.startsWith('local_');
        final suffix = isOffline ? ' (Tersimpan di Perangkat / Mode Offline)' : '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('2 Tugas Rutin Shift 1 dibuat$suffix untuk $selectedTech (${_formatDateDisplay(_targetDispatchDate)})'),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res1 != null || res2 != null
                ? 'Sebagian tugas berhasil dikirim. Periksa Status Tim.'
                : 'Tugas rutin gagal dikirim. Periksa koneksi lalu coba lagi.'),
            backgroundColor: res1 != null || res2 != null ? AppColors.warning : AppColors.danger,
          ),
        );
      }
      _selectedDate = _targetDispatchDate;
      _loadTasks();
    }
    return success;
  }

  Future<bool> _submitTask() async {
    if (_isLoading) return false; // Anti-double submit

    final lokasi = _lokasiCtrl.text.trim();
    final pekerjaan = _pekerjaanCtrl.text.trim();

    if (lokasi.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lokasi harus diisi.')),
      );
      return false;
    }

    if (pekerjaan.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Detail pekerjaan harus diisi.')),
      );
      return false;
    }

    setState(() => _isLoading = true);

    DailyTaskModel? res;
    try {
      res = await DailyTaskService.createTask(
        tanggal: _formatDateToKey(_targetDispatchDate),
        teknisiNama: _selectedTech,
        posName: lokasi,
        posTag: lokasi,
        judul: pekerjaan,
        deskripsi: _catatanCtrl.text.trim(),
        kategori: _taskCategory,
        templateId: _taskCategory == 'maintenance' ? _selectedTemplateId : null,
        peserta: _pesertaTerpilih.join(', '),
      );
    } catch (e) {
      debugPrint('[SpvTaskDispatcherScreen] _submitTask error: $e');
    }

    if (mounted) {
      setState(() => _isLoading = false);
      if (res != null) {
        _pekerjaanCtrl.clear();
        _catatanCtrl.clear();
        setState(() => _pesertaTerpilih.clear());
        final isOffline = res.id.startsWith('local_');
        final suffix = isOffline ? ' (Tersimpan di Perangkat / Mode Offline)' : '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tugas dibuat$suffix untuk $_selectedTech (${_formatDateDisplay(_targetDispatchDate)})'),
            backgroundColor: AppColors.success,
          ),
        );
        _selectedDate = _targetDispatchDate;
        _loadTasks();
        return true;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal kirim tugas. Cek koneksi, coba lagi.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
    return false;
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

    final bgScaffold = isDark ? AppColors.darkBackground : AppColors.background;

    return Scaffold(
      backgroundColor: bgScaffold,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showBeriTugasBottomSheet(isDark),
        tooltip: 'Buat tugas baru',
        icon: const Icon(Icons.add_rounded, size: 20),
        label: const Text(
          'Buat Tugas',
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: isDark ? AppColors.primaryLight : AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeaderBand(isDark),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadTasks,
                color: AppColors.accent,
                child: _buildTaskList(isDark),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderBand(bool isDark) {
    final canPop = Navigator.of(context).canPop();
    return Container(
      width: double.infinity,
      color: isDark ? AppColors.primaryDark : AppColors.primary,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      child: Row(
        children: [
          if (canPop)
            IconButton(
              tooltip: 'Kembali',
              onPressed: () => Navigator.maybePop(context),
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: canPop ? 4 : 12),
              child: const Text(
                'Daily Task',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _headerAction(
            tooltip: 'Format Briefing WA / Telegram',
            icon: Icons.share_rounded,
            onPressed: () => _showMorningDispatchBottomSheet(isDark),
          ),
          const SizedBox(width: 6),
          _headerAction(
            tooltip: 'Kontrol Tim & Rekap',
            icon: Icons.tune_rounded,
            onPressed: () => _showTeamControlBottomSheet(isDark),
          ),
        ],
      ),
    );
  }

  Widget _headerAction({required String tooltip, required IconData icon, required VoidCallback onPressed}) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, color: Colors.white, size: 20),
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        minimumSize: const Size(40, 40),
        padding: const EdgeInsets.all(8),
      ),
    );
  }

  Widget _formLabel(String text, Color color) => Text(
        text.toUpperCase(),
        style: TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: 12,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      );

  Widget _formHelper(String text, Color color) => Text(
        text,
        style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 12, color: color, height: 1.35),
      );

  InputDecoration _bareInput(String hint, Color hintColor) => InputDecoration(
        isDense: true,
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        contentPadding: EdgeInsets.zero,
        hintText: hint,
        hintStyle: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13, color: hintColor),
      );

  /// Draf dianggap ada kalau teknisi sudah mengetik detail/catatan atau memilih
  /// rekan kerja. Kategori & tanggal tidak dihitung supaya sheet tetap bisa
  /// ditutup tanpa dialog.
  bool get _isFormDirty =>
      _pekerjaanCtrl.text.trim().isNotEmpty ||
      _catatanCtrl.text.trim().isNotEmpty ||
      _pesertaTerpilih.isNotEmpty;

  Future<bool> _confirmDiscardDraft() async {
    final isDark = ThemeService.isDarkMode(context);
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Buang draf tugas?',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        content: Text(
          'Isian yang sudah diketik akan hilang.',
          style: TextStyle(
            fontSize: 13,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Lanjut Isi'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Buang'),
          ),
        ],
      ),
    );
    return discard ?? false;
  }

  Future<void> _pickTargetDispatchDateFromSheet(void Function(VoidCallback) apply) async {
    await _pickTargetDispatchDate();
    apply(() {});
  }

  Widget _pesertaRow(
    String nama, {
    required Color line,
    required Color head,
    required Color sub,
    required bool isDark,
    required VoidCallback onToggle,
  }) {
    final selected = _pesertaTerpilih.contains(nama);
    return Column(
      children: [
        InkWell(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 11),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary : (isDark ? const Color(0xFF1E293B) : Colors.white),
                    shape: BoxShape.circle,
                    border: Border.all(color: selected ? AppColors.primary : line),
                  ),
                  child: Text(
                    nama.characters.first.toUpperCase(),
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: selected ? Colors.white : sub),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    nama,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                      color: head,
                    ),
                  ),
                ),
                Icon(
                  selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                  size: 19,
                  color: selected ? AppColors.success : (isDark ? const Color(0xFF334155) : const Color(0xFFCFCABF)),
                ),
              ],
            ),
          ),
        ),
        Divider(height: 1, thickness: 1, color: line),
      ],
    );
  }

  Widget _categoryChip({
    required String label,
    required IconData icon,
    required bool active,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    final selectedColor = isDark ? AppColors.primaryLight : AppColors.primary;
    final bg = active ? selectedColor : (isDark ? AppColors.darkSurfaceContainer : AppColors.surfaceContainerLow);
    final fg = active ? Colors.white : (isDark ? AppColors.textDarkSecondary : AppColors.textSecondary);
    final borderColor = active ? selectedColor : (isDark ? AppColors.darkBorder : AppColors.cardBorder);

    return Semantics(
      button: true,
      selected: active,
      label: 'Kategori $label',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          height: 44,
          child: Center(
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 13, color: fg),
                  const SizedBox(width: 2),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 12,
                        letterSpacing: -0.5,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                        color: fg,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showBeriTugasBottomSheet(bool isDark) {
    final sheetBg = isDark ? AppColors.darkSurface : AppColors.surface;
    final line = isDark ? AppColors.darkBorder : AppColors.cardBorder;
    final titleColor = isDark ? AppColors.textDarkPrimary : AppColors.textPrimary;
    final subColor = isDark ? AppColors.textDarkSecondary : AppColors.textSecondary;
    final isManado = BranchService.instance.currentBranch == AppBranch.manado;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            void apply(VoidCallback fn) => setModalState(fn);

            Future<void> handleClose() async {
              if (_isFormDirty && !await _confirmDiscardDraft()) return;
              if (sheetContext.mounted) Navigator.pop(sheetContext);
            }

            Future<void> handleSubmit() async {
              if (_isLoading) return;
              final rutin = BranchService.instance.currentBranch == AppBranch.manado && _formTab == 'rutin';
              final future = rutin ? _dispatchShift1ManadoRoutine(_selectedTech) : _submitTask();
              setModalState(() {});
              final ok = await future;
              if (!sheetContext.mounted) return;
              setModalState(() {});
              if (ok) Navigator.pop(sheetContext);
            }

            final isRutin = isManado && _formTab == 'rutin';

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(modalContext).viewInsets.bottom),
              child: PopScope(
                canPop: !_isFormDirty,
                onPopInvokedWithResult: (didPop, result) async {
                  if (didPop) return;
                  if (await _confirmDiscardDraft() && sheetContext.mounted) {
                    Navigator.pop(sheetContext);
                  }
                },
                child: DraggableScrollableSheet(
                  initialChildSize: 0.92,
                  minChildSize: 0.6,
                  maxChildSize: 0.96,
                  expand: false,
                  builder: (dragContext, scrollController) {
                    return Container(
                      decoration: BoxDecoration(
                        color: sheetBg,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(AppColors.radiusBottomSheet),
                        ),
                      ),
                      child: Column(
                        children: [
                          const SizedBox(height: 10),
                          Center(
                            child: Container(
                              width: 38,
                              height: 4,
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.darkBorderMuted : const Color(0xFFCBD5E1),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
                            child: Row(
                              children: [
                                Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? AppColors.primaryLight.withValues(alpha: 0.18)
                                        : AppColors.primary.withValues(alpha: 0.10),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.add_rounded,
                                    size: 20,
                                    color: isDark ? AppColors.primaryLight : AppColors.primary,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Buat Tugas Baru',
                                        style: TextStyle(
                                          fontFamily: 'PlusJakartaSans',
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: titleColor,
                                        ),
                                      ),
                                      Text(
                                        'Pilih kategori dan isi detail tugas',
                                        style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 12, color: subColor),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Tutup',
                                  onPressed: handleClose,
                                  icon: Icon(Icons.close_rounded, size: 20, color: subColor),
                                  constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Expanded(
                            child: SingleChildScrollView(
                              controller: scrollController,
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      if (isManado) ...[
                                        Expanded(
                                          child: _categoryChip(
                                            label: 'Rutin',
                                            icon: Icons.event_repeat_rounded,
                                            active: _formTab == 'rutin',
                                            onTap: () => apply(() => _formTab = 'rutin'),
                                            isDark: isDark,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                      ],
                                      Expanded(
                                        child: _categoryChip(
                                          label: 'Maintenance',
                                          icon: Icons.build_rounded,
                                          active: _formTab == 'maintenance',
                                          onTap: () => apply(() {
                                            _formTab = 'maintenance';
                                            _taskCategory = 'maintenance';
                                          }),
                                          isDark: isDark,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: _categoryChip(
                                          label: 'Tugas Khusus',
                                          icon: Icons.star_outline_rounded,
                                          active: _formTab == 'khusus',
                                          onTap: () => apply(() {
                                            _formTab = 'khusus';
                                            _taskCategory = 'khusus';
                                          }),
                                          isDark: isDark,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 18),
                                  _buildFormTugaskan(isDark, apply: apply),
                                  const SizedBox(height: 14),
                                  Container(
                                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                                    decoration: BoxDecoration(
                                      color: AppColors.info.withValues(alpha: isDark ? 0.16 : 0.08),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: AppColors.info.withValues(alpha: 0.28)),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.info),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Pastikan data sudah sesuai sebelum menyimpan.',
                                            style: TextStyle(
                                              fontFamily: 'PlusJakartaSans',
                                              fontSize: 12,
                                              height: 1.35,
                                              color: isDark ? AppColors.textDarkPrimary : AppColors.textPrimary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                            decoration: BoxDecoration(
                              color: sheetBg,
                              border: Border(top: BorderSide(color: line)),
                            ),
                            child: SafeArea(
                              top: false,
                              child: SizedBox(
                                height: 48,
                                width: double.infinity,
                                child: FilledButton(
                                  onPressed: _isLoading ? null : handleSubmit,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: isDark ? AppColors.primaryLight : AppColors.primary,
                                    foregroundColor: Colors.white,
                                    disabledBackgroundColor: (isDark ? AppColors.primaryLight : AppColors.primary)
                                        .withValues(alpha: 0.55),
                                    disabledForegroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: _isLoading
                                      ? const Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                            ),
                                            SizedBox(width: 10),
                                            Text(
                                              'Menyimpan...',
                                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                                            ),
                                          ],
                                        )
                                      : Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(isRutin ? Icons.bolt_rounded : Icons.check_rounded, size: 18),
                                            const SizedBox(width: 8),
                                            Flexible(
                                              child: Text(
                                                isRutin ? 'Tugaskan 2 Rutin Shift 1' : 'Simpan Tugas',
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
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
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFormTugaskan(bool isDark, {required void Function(VoidCallback) apply}) {
    final labelColor = isDark ? AppColors.textDarkSecondary : AppColors.textSecondary;
    final inputText = isDark ? AppColors.textDarkPrimary : AppColors.textPrimary;
    final hintColor = isDark ? AppColors.textDarkMuted : AppColors.textMuted;
    final panelBg = isDark ? AppColors.darkSurfaceContainer : AppColors.surfaceContainerLow;
    final line = isDark ? AppColors.darkBorder : AppColors.cardBorder;
    final inputStyle = TextStyle(
      fontFamily: 'PlusJakartaSans',
      fontSize: 13.5,
      fontWeight: FontWeight.w600,
      color: inputText,
    );

    final isManado = BranchService.instance.currentBranch == AppBranch.manado;
    final isRutin = isManado && _formTab == 'rutin';

    Widget dropdown<T>({
      required IconData icon,
      required T value,
      required List<DropdownMenuItem<T>> items,
      required ValueChanged<T?> onChanged,
    }) {
      return AppOutlinedFormField(
        isDark: isDark,
        leadingIcon: icon,
        trailingIcon: Icons.expand_more_rounded,
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: value,
            isExpanded: true,
            isDense: true,
            icon: const SizedBox.shrink(),
            dropdownColor: isDark ? AppColors.darkSurface : AppColors.surface,
            style: inputStyle,
            items: items,
            onChanged: (val) {
              if (val != null) onChanged(val);
            },
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _formLabel(isRutin ? 'Teknisi Shift 1' : 'Teknisi (Pemilik Tugas)', labelColor),
        const SizedBox(height: 6),
        dropdown<String>(
          icon: Icons.person_outline_rounded,
          value: _selectedTech,
          items: _technicians
              .map((t) => DropdownMenuItem(value: t, child: Text(t, overflow: TextOverflow.ellipsis)))
              .toList(),
          onChanged: (val) => apply(() {
            if (val != null) _selectedTech = val;
            _pesertaTerpilih.remove(val);
          }),
        ),
        const SizedBox(height: 6),
        _formHelper(isRutin ? 'Shift 1 (03:00 - 11:00 WITA) mengerjakan 2 tugas rutin.' : 'Yang pegang dokumentasi dan upload bukti.', labelColor),
        const SizedBox(height: 18),

        if (isRutin) ...[
          _formLabel('Tugas Rutin Shift 1 KC Manado', labelColor),
          const SizedBox(height: 4),
          _formHelper('Dikirim sebagai 2 tugas terpisah, masing-masing wajib ada bukti.', labelColor),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: panelBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: line),
            ),
            child: Column(
              children: [
                for (final (i, judul) in const [
                  'Pengecekan Sistem Gate out 1-6 PBM (bukti dokumentasi layar aplikasi kasir)',
                  'Pengecekan Sistem Gate ojek',
                ].indexed) ...[
                  if (i > 0) Divider(height: 1, thickness: 1, color: line),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: _buildRoutineTaskItem(num: '${i + 1}', title: judul, isDark: isDark),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
        ] else ...[
          if (_taskCategory == 'maintenance') ...[
            _formLabel('Template SOP', labelColor),
            const SizedBox(height: 6),
            dropdown<String>(
              icon: Icons.handyman_outlined,
              value: _selectedTemplateId ?? _templates.first['id']!,
              items: _templates
                  .map((tpl) => DropdownMenuItem(value: tpl['id'], child: Text(tpl['nama']!, overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: (val) => apply(() {
                _selectedTemplateId = val;
                final found = _templates.firstWhere((e) => e['id'] == val);
                _pekerjaanCtrl.text = '${found['nama']} - ${_lokasiCtrl.text.trim()}';
              }),
            ),
            const SizedBox(height: 18),
          ],

          _formLabel('Dikerjakan Bersama (Opsional)', labelColor),
          const SizedBox(height: 6),
          AppOutlinedFormField(
            isDark: isDark,
            leadingIcon: Icons.groups_2_outlined,
            trailingIcon: _pesertaTerbuka ? Icons.expand_less_rounded : Icons.expand_more_rounded,
            onTap: () => apply(() => _pesertaTerbuka = !_pesertaTerbuka),
            child: Text(
              _pesertaTerpilih.isEmpty ? 'Tidak ada teknisi tambahan' : _pesertaTerpilih.join(', '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 13.5,
                fontWeight: _pesertaTerpilih.isEmpty ? FontWeight.w500 : FontWeight.w600,
                color: _pesertaTerpilih.isEmpty ? hintColor : inputText,
              ),
            ),
          ),
          if (_pesertaTerbuka) ...[
            const SizedBox(height: 4),
            for (final tech in _technicians.where((t) => t != _selectedTech))
              _pesertaRow(
                tech,
                line: line,
                head: inputText,
                sub: labelColor,
                isDark: isDark,
                onToggle: () => apply(() {
                  if (_pesertaTerpilih.contains(tech)) {
                    _pesertaTerpilih.remove(tech);
                  } else {
                    _pesertaTerpilih.add(tech);
                  }
                }),
              ),
          ],
          if (_pesertaTerpilih.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.groups_2_outlined, size: 15, color: AppColors.success),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Bareng: ${_pesertaTerpilih.join(', ')} · bukti dari $_selectedTech',
                    style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 12, height: 1.35, color: inputText),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 18),
        ],

        if (!isRutin) ...[
          _formLabel('Lokasi Pekerjaan', labelColor),
          const SizedBox(height: 6),
          AppOutlinedFormField(
            isDark: isDark,
            leadingIcon: Icons.place_outlined,
            child: TextField(
              controller: _lokasiCtrl,
              style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13.5, color: inputText),
              onChanged: (_) => apply(() {}),
              decoration: _bareInput('Contoh: PKM, PBM, TBM', hintColor),
            ),
          ),
          const SizedBox(height: 18),

          _formLabel('Detail Pekerjaan', labelColor),
          const SizedBox(height: 6),
          AppOutlinedFormField(
            isDark: isDark,
            leadingIcon: Icons.edit_note_rounded,
            multiline: true,
            child: TextField(
              controller: _pekerjaanCtrl,
              maxLines: 2,
              style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13.5, height: 1.4, color: inputText),
              onChanged: (_) => apply(() {}),
              decoration: _bareInput('Contoh: Pemasangan lampu pos', hintColor),
            ),
          ),
          const SizedBox(height: 18),
        ],

        _formLabel('Tanggal Penugasan', labelColor),
        const SizedBox(height: 6),
        AppOutlinedFormField(
          isDark: isDark,
          leadingIcon: Icons.calendar_month_rounded,
          trailingIcon: Icons.edit_calendar_rounded,
          onTap: () => _pickTargetDispatchDateFromSheet(apply),
          child: Text(
            _formatDateDisplay(_targetDispatchDate),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13.5, fontWeight: FontWeight.w600, color: inputText),
          ),
        ),

        if (!isRutin) ...[
          const SizedBox(height: 18),
          _formLabel('Catatan (Opsional)', labelColor),
          const SizedBox(height: 6),
          AppOutlinedFormField(
            isDark: isDark,
            leadingIcon: Icons.notes_rounded,
            multiline: true,
            child: TextField(
              controller: _catatanCtrl,
              maxLines: 3,
              style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13.5, height: 1.4, color: inputText),
              onChanged: (_) => apply(() {}),
              decoration: _bareInput('Contoh: Lampu cadangan di gudang pos', hintColor),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTaskList(bool isDark) {
    final scoped = _techScopedTasks;
    final total = scoped.length;
    final completed = scoped.where((t) => t.isCompleted).length;
    final pending = total - completed;
    final isToday = _isSameDay(_selectedDate, DateTime.now());
    final subtitle = isToday ? 'Hari Ini' : _formatDateDisplay(_selectedDate);
    final techSuffix = _selectedTechFilter == 'SEMUA' ? '' : ' · $_selectedTechFilter';
    final tasks = _filteredTasks;
    final allDone = total > 0 && completed == total;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      children: [
        if (_isLoading)
          _buildSkeletonList(isDark)
        else ...[
          SpvProgressRingCard(
            completed: completed,
            total: total,
            subtitle: '$subtitle$techSuffix',
            isDark: isDark,
            onTap: () => _showTeamControlBottomSheet(isDark),
          ),
          const SizedBox(height: 12),
          SpvStatusSegmentBar(
            total: total,
            pending: pending,
            completed: completed,
            selected: _selectedStatusFilter,
            isDark: isDark,
            onSelect: (key) => setState(() => _selectedStatusFilter = key),
          ),
          const SizedBox(height: 10),
          SpvTechFilterStrip(
            isDark: isDark,
            selected: _selectedTechFilter,
            entries: [
              SpvTechFilterEntry(name: 'SEMUA', pendingCount: _pendingForTech('SEMUA')),
              for (final tech in _technicians)
                SpvTechFilterEntry(name: tech, pendingCount: _pendingForTech(tech)),
            ],
            onSelect: (tech) => setState(() {
              _selectedTechFilter = tech == _selectedTechFilter ? 'SEMUA' : tech;
            }),
          ),
          const SizedBox(height: 12),
          if (_selectedTechFilter != 'SEMUA') ...[
            _buildActiveTechFilterBanner(isDark),
            const SizedBox(height: 10),
          ],
          if (allDone) ...[
            _buildAllDoneBanner(completed, isDark),
            const SizedBox(height: 10),
          ],
          if (_teamTasks.isEmpty)
            _buildEmptyState(isDark)
          else if (tasks.isEmpty)
            _buildFilteredEmptyState(isDark)
          else
            for (final t in tasks)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SpvTaskCard(
                  task: t,
                  isDark: isDark,
                  isExpanded: _expandedTaskIds.contains(t.id),
                  onHandover: t.isCompleted ? null : () => _alihkanTugas(t),
                  onDelete: t.isCompleted ? null : () => _hapusTugas(t),
                  onToggleExpand: () {
                    setState(() {
                      if (!_expandedTaskIds.remove(t.id)) _expandedTaskIds.add(t.id);
                    });
                  },
                ),
              ),
        ],
      ],
    );
  }

  Widget _buildSkeletonList(bool isDark) {
    final base = isDark ? AppColors.darkSurfaceContainer : AppColors.creamContainer;
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    Widget bone(double height, {double? width}) => Container(
          height: height,
          width: width,
          decoration: BoxDecoration(
            color: base.withValues(alpha: reduceMotion ? 0.6 : 0.4 + (_pulse.value * 0.4)),
            borderRadius: BorderRadius.circular(6),
          ),
        );

    return Semantics(
      label: 'Memuat data tugas tim',
      container: true,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) => Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.surface,
                borderRadius: BorderRadius.circular(AppColors.radiusCard),
                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.cardBorder),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: base.withValues(alpha: reduceMotion ? 0.6 : 0.4 + (_pulse.value * 0.4)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      bone(12, width: 120),
                      const SizedBox(height: 6),
                      bone(10, width: 84),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                for (var i = 0; i < 3; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(child: bone(34)),
                ],
              ],
            ),
            const SizedBox(height: 14),
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.surface,
                  borderRadius: BorderRadius.circular(AppColors.radiusCard),
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.cardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        bone(20, width: 42),
                        const SizedBox(width: 8),
                        Expanded(child: bone(14)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    bone(12, width: 180),
                    const SizedBox(height: 8),
                    bone(11, width: 110),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAllDoneBanner(int completed, bool isDark) {
    final fg = isDark ? AppColors.successBorder : AppColors.success;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.success.withValues(alpha: 0.15) : AppColors.successLight,
        borderRadius: BorderRadius.circular(AppColors.radiusCard),
        border: Border.all(
          color: isDark ? AppColors.success.withValues(alpha: 0.35) : AppColors.successBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.celebration_rounded, size: 18, color: AppColors.success),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Semua Tugas Selesai Hari Ini! ($completed/$completed)',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: fg,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Seluruh penugasan teknisi telah selesai.',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 12.5,
              color: isDark ? AppColors.textDarkSecondary : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _shareRecap,
            icon: const Icon(Icons.ios_share_rounded, size: 16),
            label: const Text('Bagikan Rekap Tim via WA / Telegram'),
            style: TextButton.styleFrom(
              foregroundColor: fg,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 44),
              textStyle: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    final titleColor = isDark ? AppColors.textDarkPrimary : AppColors.textPrimary;
    final subColor = isDark ? AppColors.textDarkSecondary : AppColors.textSecondary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(
            Icons.assignment_outlined,
            size: 48,
            color: isDark ? AppColors.textDarkMuted : AppColors.textMuted,
          ),
          const SizedBox(height: 12),
          Text(
            'Belum Ada Tugas Tim Hari Ini',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: titleColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Belum ada penugasan teknisi untuk tanggal ${_formatDateDisplay(_selectedDate)}.',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13, color: subColor),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _showBeriTugasBottomSheet(isDark),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Buat Tugas Baru'),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? AppColors.primaryLight : AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 48),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              textStyle: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilteredEmptyState(bool isDark) {
    final titleColor = isDark ? AppColors.textDarkPrimary : AppColors.textPrimary;
    final subColor = isDark ? AppColors.textDarkSecondary : AppColors.textSecondary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(
            Icons.filter_alt_off_outlined,
            size: 44,
            color: isDark ? AppColors.textDarkMuted : AppColors.textMuted,
          ),
          const SizedBox(height: 10),
          Text(
            'Tidak Ada Tugas yang Cocok',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: titleColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tidak ada tugas dengan filter yang dipilih.',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 12.5, color: subColor),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => setState(() {
              _selectedStatusFilter = 'ALL';
              _selectedTechFilter = 'SEMUA';
            }),
            icon: const Icon(Icons.clear_all_rounded, size: 16),
            label: const Text('Reset Filter'),
            style: OutlinedButton.styleFrom(
              foregroundColor: isDark ? AppColors.textDarkPrimary : AppColors.primary,
              side: BorderSide(color: isDark ? AppColors.darkBorderMuted : AppColors.cardBorder),
              minimumSize: const Size(0, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildActiveTechFilterBanner(bool isDark) {
    return Container(
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
            final total = _teamTasks.length;
            final completed = _teamTasks.where((t) => t.isCompleted).length;
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

}
