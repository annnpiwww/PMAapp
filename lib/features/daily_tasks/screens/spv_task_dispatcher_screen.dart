import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/tiket_colors.dart';
import '../../../core/services/theme_service.dart';
import '../../../core/widgets/tiket/tiket.dart';
import '../../../data/models/daily_task_model.dart';
import '../../../data/models/user_model.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/services/branch_service.dart';
import '../../../data/services/daily_task_service.dart';
import '../../../data/services/storage_service.dart';
import '../../../data/services/error_ticket_service.dart';
import '../../../data/services/location_service.dart';
import '../widgets/ad_hoc_task_dialog.dart';
import '../widgets/spv_task_card.dart';
import '../widgets/task_handover_dialog.dart';
import 'custom_task_execution_screen.dart';

class SpvTaskDispatcherScreen extends StatefulWidget {
  const SpvTaskDispatcherScreen({super.key});

  @override
  State<SpvTaskDispatcherScreen> createState() => _SpvTaskDispatcherScreenState();
}

class _SpvTaskDispatcherScreenState extends State<SpvTaskDispatcherScreen> {
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
  String _formTab = 'khusus'; // 'rutin' hanya muncul di cabang Manado
  late final TextEditingController _lokasiCtrl;
  final _pekerjaanCtrl = TextEditingController();
  final _catatanCtrl = TextEditingController();
  String _taskCategory = 'khusus'; // 'khusus' atau 'maintenance'
  String? _selectedTemplateId = 'tpl_maint_pos';
  final Set<String> _pesertaTerpilih = {}; // teknisi tambahan (tugas bareng)
  bool _pesertaTerbuka = false; // daftar teknisi tambahan terbuka/tertutup

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
    _loadTasks();
  }

  @override
  void dispose() {
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

  List<DailyTaskModel> get _teamTasks =>
      DailyTaskService.tasksForBranch(_tasksToday);

  List<DailyTaskModel> get _filteredTasks {
    return _techScopedTasks.where((t) {
      if (_selectedStatusFilter == 'PENDING' && t.isCompleted) return false;
      if (_selectedStatusFilter == 'COMPLETED' && !t.isCompleted) return false;
      return true;
    }).toList();
  }

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
    final dateKey = _formatDateToKey(_selectedDate);
    final tasks = await DailyTaskService.getAllTasksToday(dateKey);
    if (mounted) {
      setState(() {
        _tasksToday = tasks;
        _isLoading = false;
      });
    }
  }

  Future<void> _openTechFilterDialog() async {
    final pendingAll = _pendingForTech('SEMUA');
    final selected = await showTiketPickerDialog<String>(
      context: context,
      title: 'Pilih teknisi',
      subtitle: 'Angka di kanan = tugas belum selesai hari ini',
      options: [
        TiketOption(
          value: 'SEMUA',
          label: 'Semua teknisi',
          trailingText: pendingAll > 0 ? '$pendingAll belum' : 'beres',
          status: pendingAll > 0 ? TiketStatus.attention : TiketStatus.ok,
        ),
        for (final tech in _technicians)
          TiketOption(
            value: tech,
            label: tech,
            trailingText: _pendingForTech(tech) > 0 ? '${_pendingForTech(tech)} belum' : 'beres',
            status: _pendingForTech(tech) > 0 ? TiketStatus.attention : TiketStatus.ok,
          ),
      ],
      selected: _selectedTechFilter,
    );
    if (selected != null && mounted) {
      setState(() => _selectedTechFilter = selected);
    }
  }

  Future<void> _alihkanTugas(DailyTaskModel task) async {
    final colors = TiketColors.of(context);
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
              backgroundColor: ok ? colors.ok : colors.danger,
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
    final colors = TiketColors.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.dialog,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Hapus Tugas?',
          style: TextStyle(
            fontFamily: TiketType.fontFamily,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: colors.ink,
          ),
        ),
        content: Text(
          'Tugas "${task.judul}" untuk ${task.teknisiNama} akan dihapus permanen.',
          style: TextStyle(
            fontFamily: TiketType.fontFamily,
            fontSize: 13,
            color: colors.body,
          ),
        ),
        actions: [
          TiketPill(
            label: 'Batal',
            kind: TiketPillKind.secondary,
            height: 40,
            onPressed: () => Navigator.pop(ctx, false),
          ),
          const SizedBox(width: 8),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: colors.danger,
              foregroundColor: colors.white,
              minimumSize: const Size(0, 40),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus', style: TextStyle(fontWeight: FontWeight.bold)),
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
        backgroundColor: deleted ? colors.ok : colors.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
    if (deleted) {
      setState(() => _tasksToday.removeWhere((t) => t.id == task.id));
    }
  }

  Future<void> _pickCustomDate() async {
    final colors = TiketColors.of(context);
    final isDark = ThemeService.isDarkMode(context);
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: isDark
              ? ThemeData.dark().copyWith(
                  colorScheme: ColorScheme.dark(
                    primary: colors.primary,
                    onPrimary: colors.onPrimary,
                    surface: colors.dialog,
                    onSurface: colors.ink,
                  ),
                  dialogTheme: DialogThemeData(backgroundColor: colors.dialog),
                )
              : ThemeData.light().copyWith(
                  colorScheme: ColorScheme.light(
                    primary: colors.primary,
                    onPrimary: colors.onPrimary,
                    surface: colors.dialog,
                    onSurface: colors.ink,
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
    final colors = TiketColors.of(context);
    if (_teamTasks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Belum ada tugas pada tanggal ini.'),
          backgroundColor: colors.danger,
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
    final colors = TiketColors.of(context);
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
          backgroundColor: colors.signal,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    final branchShifts = BranchService.instance.getShifts();
    final savedShifts = Map<String, String>.from(StorageService.getSpvTechShifts());

    final activeTechs = teamTasks.map((t) => t.teknisiNama.trim()).toSet().toList();
    for (int i = 0; i < activeTechs.length; i++) {
      final tech = activeTechs[i];
      if (!savedShifts.containsKey(tech) || !branchShifts.contains(savedShifts[tech])) {
        savedShifts[tech] = (i < branchShifts.length) ? branchShifts[i] : (branchShifts.isNotEmpty ? branchShifts.first : 'Shift 1');
      }
    }

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
                color: colors.dialog,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(top: BorderSide(color: colors.hairline)),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 38,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colors.mute,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: colors.ok.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.share_rounded, size: 18, color: colors.ok),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Format Briefing Tim (WA/Telegram)',
                                  style: TextStyle(
                                    fontFamily: TiketType.fontFamily,
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w800,
                                    color: colors.ink,
                                  ),
                                ),
                                Text(
                                  '${teamTasks.length} tugas • ${activeTechs.length} teknisi aktif',
                                  style: TextStyle(
                                    fontFamily: TiketType.fontFamily,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                    color: colors.body,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        IconButton(
                          tooltip: 'Tutup',
                          onPressed: () => Navigator.pop(bottomSheetContext),
                          icon: Icon(Icons.close_rounded, size: 20, color: colors.body),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'ATUR SHIFT TEKNISI HARI INI',
                              style: TextStyle(
                                fontFamily: TiketType.fontFamily,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: colors.body,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: colors.soft,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: colors.hairline),
                              ),
                              child: Column(
                                children: activeTechs.map((tech) {
                                  final techTaskCount = teamTasks.where((t) => t.teknisiNama.trim() == tech).length;
                                  final currentShift = savedShifts[tech] ?? (branchShifts.isNotEmpty ? branchShifts.first : 'Shift 1');

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Row(
                                      children: [
                                        Icon(Icons.person_outline_rounded, size: 16, color: colors.primary),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                tech,
                                                style: TextStyle(
                                                  fontFamily: TiketType.fontFamily,
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: colors.ink,
                                                ),
                                              ),
                                              Text(
                                                '$techTaskCount tugas',
                                                style: TextStyle(
                                                  fontFamily: TiketType.fontFamily,
                                                  fontSize: 10.5,
                                                  color: colors.body,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: colors.dialog,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: colors.hairline),
                                          ),
                                          child: DropdownButtonHideUnderline(
                                            child: DropdownButton<String>(
                                              value: branchShifts.contains(currentShift) ? currentShift : branchShifts.first,
                                              isDense: true,
                                              style: TextStyle(
                                                fontFamily: TiketType.fontFamily,
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w600,
                                                color: colors.ink,
                                              ),
                                              dropdownColor: colors.dialog,
                                              items: branchShifts.map((s) {
                                                return DropdownMenuItem(
                                                  value: s,
                                                  child: Text(s, style: TextStyle(color: colors.ink, fontSize: 11.5)),
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
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'PREVIEW PESAN SIAP KIRIM',
                                  style: TextStyle(
                                    fontFamily: TiketType.fontFamily,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: colors.body,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                Text(
                                  'Auto-grouped by Shift',
                                  style: TextStyle(fontFamily: TiketType.fontFamily, fontSize: 10, color: colors.primary, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: colors.soft,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: colors.hairline),
                              ),
                              child: SelectableText(
                                previewText,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                  height: 1.45,
                                  color: colors.ink,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TiketPill(
                            label: 'Salin Format',
                            icon: Icons.copy_rounded,
                            kind: TiketPillKind.secondary,
                            height: 44,
                            expand: true,
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
                                  backgroundColor: colors.ok,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TiketPill(
                            label: 'Kirim ke WA',
                            icon: Icons.send_rounded,
                            kind: TiketPillKind.primary,
                            height: 44,
                            expand: true,
                            onPressed: () {
                              Navigator.pop(bottomSheetContext);
                              SharePlus.instance.share(
                                ShareParams(
                                  text: previewText,
                                  subject: 'Briefing Harian Tim - ${_formatDateToKey(_selectedDate)}',
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
            );
          },
        );
      },
    );
  }

  Future<void> _pickTargetDispatchDate() async {
    final colors = TiketColors.of(context);
    final isDark = ThemeService.isDarkMode(context);
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDispatchDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: isDark
              ? ThemeData.dark().copyWith(
                  colorScheme: ColorScheme.dark(
                    primary: colors.primary,
                    onPrimary: colors.onPrimary,
                    surface: colors.dialog,
                    onSurface: colors.ink,
                  ),
                  dialogTheme: DialogThemeData(backgroundColor: colors.dialog),
                )
              : ThemeData.light().copyWith(
                  colorScheme: ColorScheme.light(
                    primary: colors.primary,
                    onPrimary: colors.onPrimary,
                    surface: colors.dialog,
                    onSurface: colors.ink,
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
    required TiketColors colors,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          margin: const EdgeInsets.only(top: 1.5),
          decoration: BoxDecoration(
            color: colors.soft,
            shape: BoxShape.circle,
            border: Border.all(color: colors.primary, width: 1.5),
          ),
          child: Center(
            child: Text(
              num,
              style: TextStyle(
                fontFamily: TiketType.fontFamily,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: colors.primary,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontFamily: TiketType.fontFamily,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: colors.ink,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }

  Future<bool> _dispatchShift1ManadoRoutine(String selectedTech) async {
    if (_isLoading) return false;
    final colors = TiketColors.of(context);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: colors.dialog,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.bolt_rounded, color: colors.signal, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tugaskan Rutin Shift 1',
                  style: TextStyle(
                    fontFamily: TiketType.fontFamily,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colors.ink,
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
                style: TextStyle(fontFamily: TiketType.fontFamily, fontSize: 13, color: colors.body),
              ),
              const SizedBox(height: 6),
              Text(
                '👤 $selectedTech',
                style: TextStyle(
                  fontFamily: TiketType.fontFamily,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: colors.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '📅 Target: ${_formatDateDisplay(_targetDispatchDate)}',
                style: TextStyle(fontFamily: TiketType.fontFamily, fontSize: 13, fontWeight: FontWeight.w600, color: colors.primary),
              ),
              const SizedBox(height: 12),
              const Text(
                '1. Pengecekan Sistem Gate out 1-6 PBM (bukti dokumentasi layar aplikasi kasir)\n2. Pengecekan Sistem Gate ojek',
                style: TextStyle(fontSize: 12, height: 1.4, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          actions: [
            TiketPill(
              label: 'Batal',
              kind: TiketPillKind.secondary,
              height: 40,
              onPressed: () => Navigator.pop(ctx, false),
            ),
            const SizedBox(width: 8),
            TiketPill(
              label: 'Kirim Sekarang',
              kind: TiketPillKind.primary,
              height: 40,
              onPressed: () => Navigator.pop(ctx, true),
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
      res1 = await DailyTaskService.createTask(
        tanggal: targetDateKey,
        teknisiNama: selectedTech,
        posName: 'PBM',
        posTag: 'PBM',
        judul: 'Pengecekan Sistem Gate out 1-6 PBM (bukti dokumentasi layar aplikasi kasir)',
        deskripsi: 'Pengecekan operasional sistem gate out 1-6 pos PBM. Wajib lampirkan bukti foto dokumentasi layar aplikasi kasir aktif.',
        kategori: 'khusus',
      );

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
            backgroundColor: colors.ok,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res1 != null || res2 != null
                ? 'Sebagian tugas berhasil dikirim. Periksa Status Tim.'
                : 'Tugas rutin gagal dikirim. Periksa koneksi lalu coba lagi.'),
            backgroundColor: res1 != null || res2 != null ? colors.signal : colors.danger,
          ),
        );
      }
      _selectedDate = _targetDispatchDate;
      _loadTasks();
    }
    return success;
  }

  Future<bool> _submitTask() async {
    if (_isLoading) return false;
    final colors = TiketColors.of(context);

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
            backgroundColor: colors.ok,
          ),
        );
        _selectedDate = _targetDispatchDate;
        _loadTasks();
        return true;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Gagal kirim tugas. Cek koneksi, coba lagi.'),
            backgroundColor: colors.danger,
          ),
        );
      }
    }
    return false;
  }

  bool get _isFormDirty =>
      _pekerjaanCtrl.text.trim().isNotEmpty ||
      _catatanCtrl.text.trim().isNotEmpty ||
      _pesertaTerpilih.isNotEmpty;

  Future<bool> _confirmDiscardDraft() async {
    final colors = TiketColors.of(context);
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.dialog,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Buang draf tugas?',
          style: TextStyle(
            fontFamily: TiketType.fontFamily,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: colors.ink,
          ),
        ),
        content: Text(
          'Isian yang sudah diketik akan hilang.',
          style: TextStyle(
            fontFamily: TiketType.fontFamily,
            fontSize: 13,
            color: colors.body,
          ),
        ),
        actions: [
          TiketPill(
            label: 'Lanjut Isi',
            kind: TiketPillKind.secondary,
            height: 40,
            onPressed: () => Navigator.pop(ctx, false),
          ),
          const SizedBox(width: 8),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: colors.danger,
              foregroundColor: colors.white,
              minimumSize: const Size(0, 40),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Buang', style: TextStyle(fontWeight: FontWeight.bold)),
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

  void _showBeriTugasBottomSheet(bool isDark) {
    final colors = TiketColors.of(context);
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

            final categoryOptions = <(String, String)>[
              if (isManado) ('rutin', 'Rutin'),
              ('maintenance', 'Maintenance'),
              ('khusus', 'Tugas Khusus'),
            ];

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
                        color: colors.dialog,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(24),
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
                                color: colors.mute,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Buat Tugas Baru',
                                        style: TextStyle(
                                          fontFamily: TiketType.fontFamily,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          color: colors.ink,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Pilih kategori dan isi detail tugas',
                                        style: TextStyle(
                                          fontFamily: TiketType.fontFamily,
                                          fontSize: 13,
                                          color: colors.body,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Tutup',
                                  onPressed: handleClose,
                                  icon: Icon(Icons.close_rounded, size: 22, color: colors.ink),
                                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: SingleChildScrollView(
                              controller: scrollController,
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  TiketSegmented<String>(
                                    options: categoryOptions,
                                    selected: _formTab,
                                    onChanged: (val) => apply(() {
                                      _formTab = val;
                                      if (val != 'rutin') {
                                        _taskCategory = val;
                                      }
                                    }),
                                  ),
                                  const SizedBox(height: 18),
                                  _buildFormTugaskan(colors, apply: apply),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Icon(Icons.info_outline_rounded, size: 16, color: colors.body),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Pastikan data sudah sesuai sebelum menyimpan.',
                                          style: TextStyle(
                                            fontFamily: TiketType.fontFamily,
                                            fontSize: 12,
                                            color: colors.body,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          TiketBottomBar(
                            primary: TiketPill(
                              label: _isLoading
                                  ? 'Menyimpan...'
                                  : (isRutin ? 'Tugaskan 2 Rutin Shift 1' : 'Simpan Tugas'),
                              icon: _isLoading ? null : (isRutin ? Icons.bolt_rounded : Icons.check_rounded),
                              kind: TiketPillKind.primary,
                              height: 52,
                              expand: true,
                              onPressed: _isLoading ? null : handleSubmit,
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

  Widget _buildFormTugaskan(TiketColors colors, {required void Function(VoidCallback) apply}) {
    final isManado = BranchService.instance.currentBranch == AppBranch.manado;
    final isRutin = isManado && _formTab == 'rutin';

    Widget inputContainer({required String label, required Widget child}) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: colors.soft,
          border: Border(
            bottom: BorderSide(
              color: colors.body,
              width: 2.0,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: TiketType.fontFamily,
                fontSize: 11.0,
                fontWeight: FontWeight.w500,
                color: colors.body,
              ),
            ),
            const SizedBox(height: 2),
            child,
          ],
        ),
      );
    }

    final selectedTplName = _templates.firstWhere(
      (e) => e['id'] == _selectedTemplateId,
      orElse: () => _templates.first,
    )['nama']!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TiketDropdownField(
          label: isRutin ? 'Teknisi Shift 1' : 'Teknisi (Pemilik Tugas)',
          value: _selectedTech,
          onTap: () async {
            final picked = await showTiketPickerDialog<String>(
              context: context,
              title: isRutin ? 'Pilih Teknisi Shift 1' : 'Pilih Teknisi',
              options: [
                for (final tech in _technicians)
                  TiketOption(value: tech, label: tech),
              ],
              selected: _selectedTech,
            );
            if (picked != null) {
              apply(() {
                _selectedTech = picked;
                _pesertaTerpilih.remove(picked);
              });
            }
          },
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            isRutin ? 'Shift 1 (03:00 - 11:00 WITA) mengerjakan 2 tugas rutin.' : 'Yang pegang dokumentasi dan upload bukti.',
            style: TextStyle(fontFamily: TiketType.fontFamily, fontSize: 12, color: colors.body),
          ),
        ),
        const SizedBox(height: 16),

        if (isRutin) ...[
          Text(
            'TUGAS RUTIN SHIFT 1 KC MANADO',
            style: TextStyle(
              fontFamily: TiketType.fontFamily,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: colors.ink,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Dikirim sebagai 2 tugas terpisah, masing-masing wajib ada bukti.',
            style: TextStyle(fontFamily: TiketType.fontFamily, fontSize: 12, color: colors.body),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: colors.soft,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.hairline),
            ),
            child: Column(
              children: [
                for (final (i, judul) in const [
                  'Pengecekan Sistem Gate out 1-6 PBM (bukti dokumentasi layar aplikasi kasir)',
                  'Pengecekan Sistem Gate ojek',
                ].indexed) ...[
                  if (i > 0) Divider(height: 1, thickness: 1, color: colors.hairline),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: _buildRoutineTaskItem(num: '${i + 1}', title: judul, colors: colors),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
        ] else ...[
          if (_taskCategory == 'maintenance') ...[
            TiketDropdownField(
              label: 'Template SOP',
              value: selectedTplName,
              onTap: () async {
                final picked = await showTiketPickerDialog<String>(
                  context: context,
                  title: 'Pilih Template SOP',
                  options: [
                    for (final tpl in _templates)
                      TiketOption(value: tpl['id']!, label: tpl['nama']!),
                  ],
                  selected: _selectedTemplateId,
                );
                if (picked != null) {
                  apply(() {
                    _selectedTemplateId = picked;
                    final found = _templates.firstWhere((e) => e['id'] == picked);
                    _pekerjaanCtrl.text = '${found['nama']} - ${_lokasiCtrl.text.trim()}';
                  });
                }
              },
            ),
            const SizedBox(height: 16),
          ],

          TiketDropdownField(
            label: 'Dikerjakan Bersama (Opsional)',
            value: _pesertaTerpilih.isEmpty ? 'Tidak ada teknisi tambahan' : _pesertaTerpilih.join(', '),
            onTap: () => apply(() => _pesertaTerbuka = !_pesertaTerbuka),
          ),
          if (_pesertaTerbuka) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: colors.soft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  for (final tech in _technicians.where((t) => t != _selectedTech))
                    InkWell(
                      onTap: () => apply(() {
                        if (_pesertaTerpilih.contains(tech)) {
                          _pesertaTerpilih.remove(tech);
                        } else {
                          _pesertaTerpilih.add(tech);
                        }
                      }),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: _pesertaTerpilih.contains(tech) ? colors.primary : colors.canvas,
                                shape: BoxShape.circle,
                                border: Border.all(color: _pesertaTerpilih.contains(tech) ? colors.primary : colors.mute),
                              ),
                              child: Text(
                                tech.characters.first.toUpperCase(),
                                style: TextStyle(
                                  fontFamily: TiketType.fontFamily,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: _pesertaTerpilih.contains(tech) ? colors.onPrimary : colors.body,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                tech,
                                style: TextStyle(
                                  fontFamily: TiketType.fontFamily,
                                  fontSize: 13,
                                  fontWeight: _pesertaTerpilih.contains(tech) ? FontWeight.w700 : FontWeight.w500,
                                  color: colors.ink,
                                ),
                              ),
                            ),
                            Icon(
                              _pesertaTerpilih.contains(tech) ? Icons.check_circle_rounded : Icons.circle_outlined,
                              size: 20,
                              color: _pesertaTerpilih.contains(tech) ? colors.ok : colors.mute,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (_pesertaTerpilih.isNotEmpty) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'Bareng: ${_pesertaTerpilih.join(', ')} · bukti dari $_selectedTech',
                style: TextStyle(fontFamily: TiketType.fontFamily, fontSize: 12, color: colors.body),
              ),
            ),
          ],
          const SizedBox(height: 16),
        ],

        if (!isRutin) ...[
          inputContainer(
            label: 'Lokasi Pekerjaan',
            child: TextField(
              controller: _lokasiCtrl,
              style: TextStyle(fontFamily: TiketType.fontFamily, fontSize: 14, fontWeight: FontWeight.w600, color: colors.ink),
              onChanged: (_) => apply(() {}),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: 'Contoh: PKM, PBM, TBM',
                hintStyle: TextStyle(fontFamily: TiketType.fontFamily, fontSize: 14, color: colors.body),
              ),
            ),
          ),
          const SizedBox(height: 16),

          inputContainer(
            label: 'Detail Pekerjaan',
            child: TextField(
              controller: _pekerjaanCtrl,
              maxLines: 2,
              style: TextStyle(fontFamily: TiketType.fontFamily, fontSize: 14, fontWeight: FontWeight.w600, color: colors.ink),
              onChanged: (_) => apply(() {}),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: 'Contoh: Pemasangan lampu pos',
                hintStyle: TextStyle(fontFamily: TiketType.fontFamily, fontSize: 14, color: colors.body),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        TiketDropdownField(
          label: 'Tanggal Penugasan',
          value: _formatDateDisplay(_targetDispatchDate),
          onTap: () => _pickTargetDispatchDateFromSheet(apply),
        ),

        if (!isRutin) ...[
          const SizedBox(height: 16),
          inputContainer(
            label: 'Catatan (Opsional)',
            child: TextField(
              controller: _catatanCtrl,
              maxLines: 3,
              style: TextStyle(fontFamily: TiketType.fontFamily, fontSize: 14, fontWeight: FontWeight.w600, color: colors.ink),
              onChanged: (_) => apply(() {}),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: 'Contoh: Lampu cadangan di gudang pos',
                hintStyle: TextStyle(fontFamily: TiketType.fontFamily, fontSize: 14, color: colors.body),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _handleLaporanError(TiketColors colors) async {
    final user = AuthRepository.instance.currentUser;
    if (user == null) return;
    final res = await AdHocTaskDialog.show(
      context,
      teknisiNama: user.nama,
      tanggal: _formatDateToKey(DateTime.now()),
      lokasiOptions: LocationService.availablePosList,
      lokasiAwal: null,
      startInErrorMode: true,
    );
    if (!mounted) return;
    if (res == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Laporan error dicatat. Tim cabang dapat notifikasi.'),
          backgroundColor: colors.ok,
        ),
      );
      _loadTasks();
    } else if (res == false) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Gagal mencatat laporan. Coba lagi.'),
          backgroundColor: colors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthRepository.instance.currentUser;
    final colors = TiketColors.of(context);
    final isDark = ThemeService.isDarkMode(context);

    if (user?.role != UserRole.supervisor) {
      return Scaffold(
        backgroundColor: colors.canvas,
        appBar: AppBar(
          backgroundColor: colors.band,
          title: Text('Akses Dibatasi', style: TextStyle(color: colors.white)),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              'Halaman ini khusus untuk Supervisor (SPV).\nTeknisi hanya melihat tugas di layar utama kamera.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: TiketType.fontFamily,
                color: colors.body,
                fontSize: 14,
              ),
            ),
          ),
        ),
      );
    }

    final scoped = _techScopedTasks;
    final total = scoped.length;
    final completed = scoped.where((t) => t.isCompleted).length;
    final pending = total - completed;
    final tasks = _filteredTasks;
    final allDone = total > 0 && completed == total;
    final percentInt = total > 0 ? ((completed / total) * 100).toInt() : 0;
    final canPop = Navigator.of(context).canPop();
    final horizontalPad = TiketSpace.padOf(context);

    final mediaQuery = MediaQuery.of(context);
    final fitsFullPill = mediaQuery.size.width >= 390 && mediaQuery.textScaler.scale(14) <= 14;

    return Scaffold(
      backgroundColor: colors.canvas,
      floatingActionButton: UnconstrainedBox(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (fitsFullPill)
              Container(
                decoration: BoxDecoration(
                  color: colors.canvas,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: TiketPill(
                  label: 'Laporan Error',
                  icon: Icons.report_problem_outlined,
                  kind: TiketPillKind.secondary,
                  height: 56,
                  onPressed: () => _handleLaporanError(colors),
                ),
              )
            else
              SizedBox(
                width: 56,
                height: 56,
                child: TiketIconButton(
                  icon: Icons.report_problem_outlined,
                  semanticLabel: 'Laporan Error',
                  onPressed: () => _handleLaporanError(colors),
                ),
              ),
            const SizedBox(width: 12),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: colors.primary.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TiketPill(
                label: 'Buat Tugas',
                icon: Icons.add_rounded,
                kind: TiketPillKind.primary,
                height: 56,
                onPressed: () => _showBeriTugasBottomSheet(isDark),
              ),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadTasks,
        color: colors.primary,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _SpvSliverBand(
              expandedHeight: 180.0,
              compactTitle: 'Daily Task',
              leading: canPop
                  ? TiketIconButton(
                      icon: Icons.arrow_back_rounded,
                      semanticLabel: 'Kembali',
                      onPressed: () => Navigator.maybePop(context),
                    )
                  : null,
              onBriefing: () => _showMorningDispatchBottomSheet(isDark),
              onRekap: () => _showTeamControlBottomSheet(isDark),
              caption: 'Daily Task Tim · ${_formatDateDisplay(_selectedDate)}',
              hero: (_tasksToday.isEmpty && !_isLoading)
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '0/0',
                          style: TextStyle(
                            fontFamily: TiketType.fontFamily,
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            color: colors.white,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Belum ada tugas tim',
                          style: TextStyle(
                            fontFamily: TiketType.fontFamily,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: colors.bandCaption,
                          ),
                        ),
                      ],
                    )
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '$completed/$total',
                            style: TextStyle(
                              fontFamily: TiketType.fontFamily,
                              fontSize: 36,
                              fontWeight: FontWeight.w800,
                              color: colors.white,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'selesai · $percentInt%',
                            style: TextStyle(
                              fontFamily: TiketType.fontFamily,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
              footer: null,
            ),
            if (_isLoading)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: colors.primary),
                      const SizedBox(height: 16),
                      Text(
                        'Memuat tugas tim',
                        style: TextStyle(
                          fontFamily: TiketType.fontFamily,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: colors.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(horizontalPad, 16, horizontalPad, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TiketDropdownField(
                        label: 'Teknisi',
                        value: _selectedTechFilter == 'SEMUA' ? 'Semua teknisi' : _selectedTechFilter,
                        onTap: _openTechFilterDialog,
                      ),
                      const SizedBox(height: 12),
                      TiketSegmented<String>(
                        options: [
                          ('ALL', 'Semua $total'),
                          ('PENDING', 'Pending $pending'),
                          ('COMPLETED', 'Selesai $completed'),
                        ],
                        selected: _selectedStatusFilter,
                        onChanged: (val) => setState(() => _selectedStatusFilter = val),
                      ),
                      if (_selectedTechFilter != 'SEMUA') ...[
                        const SizedBox(height: 10),
                        _buildActiveTechFilterBanner(colors),
                      ],
                      if (allDone) ...[
                        const SizedBox(height: 10),
                        _buildAllDoneBanner(completed, colors),
                      ],
                    ],
                  ),
                ),
              ),
              if (_teamTasks.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildEmptyState(colors, isDark),
                )
              else if (tasks.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildFilteredEmptyState(colors),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(horizontalPad, 4, horizontalPad, 96),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final t = tasks[index];
                        final isErrorTask = t.kategori == ErrorTicketService.kategori;
                        final currentUser = AuthRepository.instance.currentUser;
                        final isAssignedToMe = currentUser != null && DailyTaskService.isAssignedTo(t, currentUser.nama);
                        final canKerjakan = isErrorTask && !t.isCompleted && isAssignedToMe;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: SpvTaskCard(
                            task: t,
                            isDark: isDark,
                            isExpanded: _expandedTaskIds.contains(t.id),
                            onHandover: t.isCompleted ? null : () => _alihkanTugas(t),
                            onDelete: t.isCompleted ? null : () => _hapusTugas(t),
                            onKerjakan: canKerjakan
                                ? () async {
                                    await Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => CustomTaskExecutionScreen(task: t),
                                      ),
                                    );
                                    _loadTasks();
                                  }
                                : null,
                            onToggleExpand: () {
                              setState(() {
                                if (!_expandedTaskIds.remove(t.id)) {
                                  _expandedTaskIds.add(t.id);
                                }
                              });
                            },
                          ),
                        );
                      },
                      childCount: tasks.length,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAllDoneBanner(int completed, TiketColors colors) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.soft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.ok),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.celebration_rounded, size: 18, color: colors.ok),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Semua Tugas Selesai Hari Ini! ($completed/$completed)',
                  style: TextStyle(
                    fontFamily: TiketType.fontFamily,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: colors.ok,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Seluruh penugasan teknisi telah selesai.',
            style: TextStyle(
              fontFamily: TiketType.fontFamily,
              fontSize: 12.5,
              color: colors.body,
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _shareRecap,
            icon: Icon(Icons.ios_share_rounded, size: 16, color: colors.ok),
            label: Text(
              'Bagikan Rekap Tim via WA / Telegram',
              style: TextStyle(
                fontFamily: TiketType.fontFamily,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: colors.ok,
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 44),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(TiketColors colors, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.assignment_outlined,
            size: 48,
            color: colors.mute,
          ),
          const SizedBox(height: 12),
          Text(
            'Belum Ada Tugas Tim Hari Ini',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: TiketType.fontFamily,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: colors.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Belum ada penugasan teknisi untuk tanggal ${_formatDateDisplay(_selectedDate)}.',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: TiketType.fontFamily, fontSize: 13, color: colors.body),
          ),
          const SizedBox(height: 18),
          TiketPill(
            label: 'Buat Tugas Baru',
            icon: Icons.add_rounded,
            kind: TiketPillKind.primary,
            height: 48,
            onPressed: () => _showBeriTugasBottomSheet(isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildFilteredEmptyState(TiketColors colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.filter_alt_off_outlined,
            size: 44,
            color: colors.mute,
          ),
          const SizedBox(height: 10),
          Text(
            'Tidak Ada Tugas yang Cocok',
            style: TextStyle(
              fontFamily: TiketType.fontFamily,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: colors.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tidak ada tugas dengan filter yang dipilih.',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: TiketType.fontFamily, fontSize: 13, color: colors.body),
          ),
          const SizedBox(height: 16),
          TiketPill(
            label: 'Reset Filter',
            icon: Icons.clear_all_rounded,
            kind: TiketPillKind.secondary,
            height: 44,
            onPressed: () => setState(() {
              _selectedStatusFilter = 'ALL';
              _selectedTechFilter = 'SEMUA';
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveTechFilterBanner(TiketColors colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.soft,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.primary),
      ),
      child: Row(
        children: [
          Icon(Icons.person_rounded, size: 16, color: colors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Filter Teknisi: $_selectedTechFilter',
              style: TextStyle(
                fontFamily: TiketType.fontFamily,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: colors.ink,
              ),
            ),
          ),
          InkWell(
            onTap: () => setState(() => _selectedTechFilter = 'SEMUA'),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Text(
                'Reset ✕',
                style: TextStyle(
                  fontFamily: TiketType.fontFamily,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: colors.signalText,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showTeamControlBottomSheet(bool isDark) {
    final colors = TiketColors.of(context);
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

            return Container(
              padding: const EdgeInsets.only(top: 10, left: 16, right: 16, bottom: 24),
              decoration: BoxDecoration(
                color: colors.dialog,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(top: BorderSide(color: colors.hairline)),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 38,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colors.mute,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.tune_rounded, size: 18, color: colors.primary),
                            const SizedBox(width: 8),
                            Text(
                              'Kontrol Tim & Rekap',
                              style: TextStyle(
                                fontFamily: TiketType.fontFamily,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: colors.ink,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          tooltip: 'Tutup',
                          onPressed: () => Navigator.pop(bottomSheetContext),
                          icon: Icon(Icons.close_rounded, size: 22, color: colors.ink),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (AuthRepository.instance.currentUser?.role == UserRole.ho)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: colors.soft,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: colors.hairline),
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
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: BranchService.instance.currentBranch == AppBranch.manado
                                        ? colors.primary
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(7),
                                  ),
                                  child: Text(
                                    'KC Manado',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontFamily: TiketType.fontFamily,
                                      fontSize: 12,
                                      fontWeight: BranchService.instance.currentBranch == AppBranch.manado
                                          ? FontWeight.bold
                                          : FontWeight.w600,
                                      color: BranchService.instance.currentBranch == AppBranch.manado
                                          ? colors.onPrimary
                                          : colors.body,
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
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: BranchService.instance.currentBranch == AppBranch.bali
                                        ? colors.primary
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(7),
                                  ),
                                  child: Text(
                                    'KC Bali',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontFamily: TiketType.fontFamily,
                                      fontSize: 12,
                                      fontWeight: BranchService.instance.currentBranch == AppBranch.bali
                                          ? FontWeight.bold
                                          : FontWeight.w600,
                                      color: BranchService.instance.currentBranch == AppBranch.bali
                                          ? colors.onPrimary
                                          : colors.body,
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
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: colors.soft,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: colors.hairline),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.location_on_rounded, size: 16, color: colors.primary),
                            const SizedBox(width: 8),
                            Text(
                              'Cabang: ${BranchService.instance.currentBranch.name}',
                              style: TextStyle(
                                fontFamily: TiketType.fontFamily,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: colors.ink,
                              ),
                            ),
                          ],
                        ),
                      ),

                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: colors.soft,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: colors.hairline),
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
                                  fontFamily: TiketType.fontFamily,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: colors.ink,
                                ),
                              ),
                              Text(
                                '$percentInt% Selesai',
                                style: TextStyle(
                                  fontFamily: TiketType.fontFamily,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: percentInt == 100 ? colors.ok : colors.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: percent,
                              minHeight: 6,
                              backgroundColor: colors.hairline,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                percentInt == 100 ? colors.ok : colors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatItem(
                                  label: 'Total',
                                  value: '$total',
                                  icon: Icons.assignment_outlined,
                                  color: colors.body,
                                  colors: colors,
                                ),
                              ),
                              Expanded(
                                child: _buildStatItem(
                                  label: 'Selesai',
                                  value: '$completed',
                                  icon: Icons.check_circle_outline_rounded,
                                  color: colors.ok,
                                  colors: colors,
                                ),
                              ),
                              Expanded(
                                child: _buildStatItem(
                                  label: 'Belum Mulai',
                                  value: '$pending',
                                  icon: Icons.schedule_rounded,
                                  color: colors.primary,
                                  colors: colors,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TiketPill(
                            label: 'Format Briefing Pagi (WA / Telegram)',
                            icon: Icons.copy_rounded,
                            kind: TiketPillKind.secondary,
                            height: 44,
                            expand: true,
                            onPressed: () {
                              Navigator.pop(bottomSheetContext);
                              _showMorningDispatchBottomSheet(isDark);
                            },
                          ),
                          const SizedBox(height: 8),
                          TiketPill(
                            label: 'Bagikan Rekap Tim ke WhatsApp',
                            icon: Icons.share_rounded,
                            kind: TiketPillKind.primary,
                            height: 44,
                            expand: true,
                            onPressed: () {
                              Navigator.pop(bottomSheetContext);
                              _shareRecap();
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    Text(
                      'TANGGAL OPERASIONAL',
                      style: TextStyle(
                        fontFamily: TiketType.fontFamily,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: colors.body,
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
                            colors: colors,
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
                            colors: colors,
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
                            colors: colors,
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

                    Text(
                      'FILTER TEKNISI LAPANGAN',
                      style: TextStyle(
                        fontFamily: TiketType.fontFamily,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: colors.body,
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

                        return InkWell(
                          onTap: () {
                            setState(() {
                              _selectedTechFilter = tech;
                            });
                            setModalState(() {});
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected ? colors.primary : colors.soft,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected ? colors.primary : colors.hairline,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isAll ? Icons.group_outlined : Icons.person_outline_rounded,
                                  size: 13,
                                  color: isSelected ? colors.onPrimary : colors.body,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  chipLabel,
                                  style: TextStyle(
                                    fontFamily: TiketType.fontFamily,
                                    fontSize: 11.5,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    color: isSelected ? colors.onPrimary : colors.ink,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18),

                    TiketPill(
                      label: 'Terapkan & Lihat Tugas',
                      kind: TiketPillKind.primary,
                      height: 48,
                      expand: true,
                      onPressed: () => Navigator.pop(bottomSheetContext),
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
    required TiketColors colors,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? colors.primary.withValues(alpha: 0.15) : colors.soft,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? colors.primary : colors.hairline,
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
                size: 14,
                color: isSelected ? colors.primary : colors.body,
              ),
              const SizedBox(width: 5),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: TiketType.fontFamily,
                  fontSize: 11.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? colors.primary : colors.ink,
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
    required TiketColors colors,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: colors.dialog,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.hairline),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            '$value ',
            style: TextStyle(
              fontFamily: TiketType.fontFamily,
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
                fontFamily: TiketType.fontFamily,
                fontSize: 11,
                color: colors.body,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpvSliverBand extends StatelessWidget {
  final Widget? leading;
  final VoidCallback? onBriefing;
  final VoidCallback? onRekap;
  final String? caption;
  final Widget? hero;
  final Widget? footer;
  final String compactTitle;
  final double expandedHeight;

  const _SpvSliverBand({
    this.leading,
    this.onBriefing,
    this.onRekap,
    this.caption,
    this.hero,
    this.footer,
    required this.compactTitle,
    this.expandedHeight = 180.0,
  });

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    return SliverPersistentHeader(
      pinned: true,
      delegate: _SpvSliverBandDelegate(
        leading: leading,
        onBriefing: onBriefing,
        onRekap: onRekap,
        caption: caption,
        hero: hero,
        footer: footer,
        compactTitle: compactTitle,
        expandedHeight: expandedHeight,
        topInset: topInset,
      ),
    );
  }
}

class _SpvSliverBandDelegate extends SliverPersistentHeaderDelegate {
  final Widget? leading;
  final VoidCallback? onBriefing;
  final VoidCallback? onRekap;
  final String? caption;
  final Widget? hero;
  final Widget? footer;
  final String compactTitle;
  final double expandedHeight;
  final double topInset;

  _SpvSliverBandDelegate({
    this.leading,
    this.onBriefing,
    this.onRekap,
    this.caption,
    this.hero,
    this.footer,
    required this.compactTitle,
    required this.expandedHeight,
    required this.topInset,
  });

  @override
  double get minExtent => topInset + 56.0;

  @override
  double get maxExtent => expandedHeight + topInset;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final colors = TiketColors.of(context);
    final type = TiketType.of(context);
    final horizontalPad = TiketSpace.padOf(context);

    final maxShrink = (maxExtent - minExtent).clamp(1.0, double.infinity);
    final progress = (shrinkOffset / maxShrink).clamp(0.0, 1.0);
    final isCollapsed = progress > 0.8;

    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: colors.band),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: ExcludeSemantics(
            child: CustomPaint(
              size: const Size(double.infinity, 10),
              painter: PerforationPainter(canvasColor: colors.canvas),
            ),
          ),
        ),
        if (progress < 0.9)
          Positioned(
            top: topInset + 56.0,
            left: horizontalPad,
            right: horizontalPad,
            child: Opacity(
              opacity: (1.0 - progress * 1.5).clamp(0.0, 1.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (caption != null) ...[
                    Text(
                      caption!,
                      style: type.caption(color: colors.bandCaption),
                    ),
                    const SizedBox(height: 4.0),
                  ],
                  if (hero != null) ...[
                    hero!,
                    const SizedBox(height: 12.0),
                  ],
                  ?footer,
                ],
              ),
            ),
          ),
        Positioned(
          top: topInset,
          left: 0,
          right: 0,
          height: 56.0,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = MediaQuery.sizeOf(context).width < 375.0 ||
                    constraints.maxWidth < 350.0 ||
                    MediaQuery.textScalerOf(context).scale(1.0) > 1.15;
                final resolvedActions = [
                  if (onBriefing != null)
                    isCompact
                        ? TiketIconButton(
                            icon: Icons.share_rounded,
                            semanticLabel: 'Briefing',
                            onPressed: onBriefing,
                          )
                        : TiketPill(
                            label: 'Briefing',
                            icon: Icons.share_rounded,
                            kind: TiketPillKind.band,
                            height: 44,
                            onPressed: onBriefing,
                          ),
                  if (onRekap != null)
                    isCompact
                        ? TiketIconButton(
                            icon: Icons.tune_rounded,
                            semanticLabel: 'Rekap',
                            onPressed: onRekap,
                          )
                        : TiketPill(
                            label: 'Rekap',
                            icon: Icons.tune_rounded,
                            kind: TiketPillKind.band,
                            height: 44,
                            onPressed: onRekap,
                          ),
                ];
                return Row(
                  children: [
                    ?leading,
                    if (isCollapsed)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Text(
                            compactTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: TiketType.fontFamily,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: colors.white,
                            ),
                          ),
                        ),
                      )
                    else ...[
                      const Spacer(),
                      Opacity(
                        opacity: 0.0,
                        child: SizedBox(
                          width: 0,
                          height: 0,
                          child: Text(
                            compactTitle,
                            style: TextStyle(
                              fontFamily: TiketType.fontFamily,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (resolvedActions.isNotEmpty && progress < 0.8)
                      Opacity(
                        opacity: (1.0 - progress * 1.5).clamp(0.0, 1.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (int i = 0; i < resolvedActions.length; i++) ...[
                              if (i > 0) const SizedBox(width: 6.0),
                              resolvedActions[i],
                            ],
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  @override
  bool shouldRebuild(covariant _SpvSliverBandDelegate oldDelegate) {
    return oldDelegate.compactTitle != compactTitle ||
        oldDelegate.caption != caption ||
        oldDelegate.hero != hero ||
        oldDelegate.footer != footer ||
        oldDelegate.topInset != topInset ||
        oldDelegate.expandedHeight != expandedHeight ||
        oldDelegate.onBriefing != onBriefing ||
        oldDelegate.onRekap != onRekap;
  }
}
