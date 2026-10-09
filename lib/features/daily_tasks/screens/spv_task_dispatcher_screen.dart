import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/theme_service.dart';
import '../../../data/models/daily_task_model.dart';
import '../../../data/models/user_model.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/services/daily_task_service.dart';

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
  String _selectedStatusFilter = 'ALL'; // 'ALL', 'PENDING', 'COMPLETED'
  String _selectedTechFilter = 'SEMUA';
  final Set<String> _expandedTaskIds = <String>{};

  final List<String> _technicians = [
    'Ryan Lumasuge',
    'Raldy Sangkop',
    'Junifer Manua',
    'Alessandro Sulistyo',
  ];

  String _selectedTech = 'Ryan Lumasuge';
  final _lokasiCtrl = TextEditingController(text: 'TBM');
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
    final yesterday = now.subtract(const Duration(days: 1));
    final dayNames = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    final monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];

    final dName = dayNames[dt.weekday - 1];
    final mName = monthNames[dt.month - 1];
    final dateNum = dt.day.toString().padLeft(2, '0');

    if (_isSameDay(dt, now)) {
      return 'Hari Ini ($dateNum $mName)';
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
    for (final t in _tasksToday) {
      final name = t.teknisiNama.trim();
      if (name.isNotEmpty && !list.contains(name)) {
        list.add(name);
      }
    }
    return list;
  }

  List<DailyTaskModel> get _filteredTasks {
    return _tasksToday.where((t) {
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
          content: Text('Belum ada tugas pada tanggal ini untuk dibagikan'),
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
    );
    SharePlus.instance.share(
      ShareParams(
        text: recapText,
        subject: 'Rekap Harian Tim - ${_formatDateToKey(_selectedDate)}',
      ),
    );
  }

  Future<void> _submitTask() async {
    if (_isLoading) return; // Anti-double submit

    final lokasi = _lokasiCtrl.text.trim();
    final pekerjaan = _pekerjaanCtrl.text.trim();

    if (lokasi.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lokasi wajib diisi')),
      );
      return;
    }

    if (pekerjaan.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Detail pekerjaan wajib diisi')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final res = await DailyTaskService.createTask(
      tanggal: _formatDateToKey(DateTime.now()),
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
            content: Text('Tugas berhasil dikirim ke $_selectedTech'),
            backgroundColor: AppColors.success,
          ),
        );
        _tabController.animateTo(1);
        _loadTasks();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal mengirim tugas. Coba lagi.'),
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
          'Penugasan Teknisi',
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
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
          // Segment Jenis Tugas
          Text(
            'Jenis Tugas *',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: labelColor),
          ),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: inputBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: inputBorder),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _taskCategory = 'khusus'),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _taskCategory == 'khusus' ? AppColors.accent : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Tugas Khusus',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _taskCategory == 'khusus' ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _taskCategory = 'maintenance'),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _taskCategory == 'maintenance' ? AppColors.accent : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Maintenance SOP',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
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

          // Lokasi Manual Murni
          Text(
            'Lokasi *',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: labelColor),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _lokasiCtrl,
            style: TextStyle(color: textColor, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Contoh: TBM, MTC, Pos 1',
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
                    const SizedBox(height: 14),

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
                                'Progress Harian Tim',
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

  String _getInitial(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return 'TK';
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
        return _buildTaskCard(t, isDark);
      },
    );
  }

  Widget _buildTaskCard(DailyTaskModel t, bool isDark) {
    final isDone = t.isCompleted;
    final isExpanded = _expandedTaskIds.contains(t.id);
    final hasNotes = t.catatanTeknisi != null &&
        t.catatanTeknisi!.trim().isNotEmpty &&
        t.catatanTeknisi != '-';

    // Format badge status: '✓ Selesai · 09:49 WITA' atau '◷ Belum Mulai'
    final String statusText;
    if (isDone) {
      if (t.jamSelesai != null && t.jamSelesai!.isNotEmpty) {
        final js = t.jamSelesai!.trim();
        statusText = js.contains('WITA') ? '✓ Selesai · $js' : '✓ Selesai · $js WITA';
      } else {
        statusText = '✓ Selesai';
      }
    } else {
      statusText = '◷ Belum Mulai';
    }

    final initial = _getInitial(t.teknisiNama);
    final cardBg = isDark ? const Color(0xFF111827) : Colors.white;
    final cardBorder = isDone
        ? AppColors.success.withValues(alpha: 0.3)
        : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0));
    final avatarBg = isDone
        ? AppColors.success.withValues(alpha: 0.12)
        : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9));
    final techTextColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final titleTextColor = isDone
        ? const Color(0xFF94A3B8)
        : (isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A));
    final subTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: cardBorder,
          width: 1,
        ),
        boxShadow: isDark ? null : [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar Initial (RL, RS, JM, AS)
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: avatarBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDone
                        ? AppColors.success.withValues(alpha: 0.35)
                        : AppColors.accent.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isDone ? AppColors.success : AppColors.accent,
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Content Right Column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Row: Nama Teknisi + Status Badge
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            t.teknisiNama,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: techTextColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDone
                                ? AppColors.success.withValues(alpha: 0.15)
                                : AppColors.accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(
                              color: isDone
                                  ? AppColors.success.withValues(alpha: 0.3)
                                  : AppColors.accent.withValues(alpha: 0.3),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: isDone ? AppColors.success : AppColors.accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),

                    // Judul Tugas (strikethrough saat selesai)
                    Text(
                      t.judul,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: titleTextColor,
                        decoration: isDone ? TextDecoration.lineThrough : null,
                        decorationColor: isDone ? const Color(0xFF94A3B8) : null,
                        decorationThickness: isDone ? 2.0 : null,
                      ),
                    ),

                    // Deskripsi (jika ada)
                    if (t.deskripsi.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        t.deskripsi.trim(),
                        maxLines: isExpanded ? null : 1,
                        overflow: isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: subTextColor,
                        ),
                      ),
                    ],
                    const SizedBox(height: 5),

                    // Lokasi, SOP MTC Badge, & Notes Indicator
                    Row(
                      children: [
                        const Text('📍 ', style: TextStyle(fontSize: 10.5)),
                        Flexible(
                          child: Text(
                            t.posName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: subTextColor,
                            ),
                          ),
                        ),
                        if (t.isMaintenance) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: const Text(
                              'SOP MTC',
                              style: TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.bold,
                                color: AppColors.accent,
                              ),
                            ),
                          ),
                        ],
                        const Spacer(),
                        if (hasNotes)
                          InkWell(
                            onTap: () {
                              setState(() {
                                if (isExpanded) {
                                  _expandedTaskIds.remove(t.id);
                                } else {
                                  _expandedTaskIds.add(t.id);
                                }
                              });
                            },
                            borderRadius: BorderRadius.circular(4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0), width: 0.8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.notes_rounded, size: 10, color: AppColors.accent),
                                  const SizedBox(width: 3),
                                  const Text(
                                    'Catatan tersedia',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.accent,
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  Icon(
                                    isExpanded
                                        ? Icons.keyboard_arrow_up_rounded
                                        : Icons.keyboard_arrow_down_rounded,
                                    size: 11,
                                    color: AppColors.accent,
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Expanded Notes Box
          if (hasNotes && isExpanded) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF080D1A) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Catatan Teknisi:',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    t.catatanTeknisi!.trim(),
                    style: TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
