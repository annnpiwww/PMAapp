import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/theme_service.dart';
import '../../../data/models/daily_task_model.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/template_repository.dart';
import '../../../data/services/daily_task_service.dart';
import '../../maintenance/widgets/maintenance_setup_dialog.dart';
import 'custom_task_execution_screen.dart';

class TeknisiDailyTasksScreen extends StatefulWidget {
  const TeknisiDailyTasksScreen({super.key});

  @override
  State<TeknisiDailyTasksScreen> createState() => _TeknisiDailyTasksScreenState();
}

class _TeknisiDailyTasksScreenState extends State<TeknisiDailyTasksScreen> {
  List<DailyTaskModel> _tasks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  String _todayStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _loadTasks() async {
    final user = AuthRepository.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    setState(() => _isLoading = true);

    final tasks = await DailyTaskService.getTasksForTeknisi(
      tanggal: _todayStr(),
      teknisiNama: user.nama,
    );

    if (mounted) {
      setState(() {
        _tasks = tasks;
        _isLoading = false;
      });
    }
  }

  void _startTask(DailyTaskModel task) async {
    if (task.templateId != null && task.templateId!.isNotEmpty) {
      // Tugas Maintenance SOP (Checklist Point Pos)
      final templates = TemplateRepository.instance.templates;
      final foundTpl = templates.firstWhere(
        (t) => t.id == task.templateId,
        orElse: () => templates.first,
      );

      if (foundTpl.isPerPoint) {
        await showDialog(
          context: context,
          builder: (_) => MaintenanceSetupDialog(initialTemplate: foundTpl),
        );
        _loadTasks();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Mulai tugas: ${task.judul}')),
        );
      }
    } else {
      // Tugas Khusus (Non-SOP Checklist): Buka layar pengerjaan mandiri
      final refreshed = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => CustomTaskExecutionScreen(task: task),
        ),
      );
      if (refreshed == true) {
        _loadTasks();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthRepository.instance.currentUser;
    final total = _tasks.length;
    final done = _tasks.where((t) => t.isCompleted).length;
    final isDark = ThemeService.isDarkMode(context);

    final bgScaffold = isDark ? const Color(0xFF0B1120) : const Color(0xFFFAF8F5);
    final bgAppBar = isDark ? const Color(0xFF111827) : AppColors.primary;
    final bgCard = isDark ? const Color(0xFF111827) : Colors.white;
    final borderCard = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    final textHead = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSub = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: bgScaffold,
      appBar: AppBar(
        backgroundColor: bgAppBar,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Daily Task',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              user?.nama ?? 'IT Support KC BSG',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 11,
                color: isDark ? const Color(0xFF94A3B8) : Colors.white70,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'Muat Ulang',
            onPressed: _loadTasks,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : RefreshIndicator(
              onRefresh: _loadTasks,
              color: AppColors.accent,
              child: _tasks.isEmpty
                  ? ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        const SizedBox(height: 60),
                        Icon(Icons.assignment_turned_in_outlined, size: 56, color: isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8)),
                        const SizedBox(height: 16),
                        Text(
                          'Belum Ada Tugas Hari Ini',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: textHead,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'SPV belum memberikan tugas untuk akun ${user?.nama ?? "Teknisi"}.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 12,
                            color: textSub,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Center(
                          child: OutlinedButton.icon(
                            onPressed: _loadTasks,
                            icon: const Icon(Icons.refresh_rounded, size: 16),
                            label: const Text('Periksa Ulang'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: textHead,
                              side: BorderSide(color: borderCard),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // Status Card Ringkas
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: bgCard,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: borderCard),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Status Pengerjaan',
                                    style: TextStyle(fontSize: 11, color: textSub),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$done dari $total Selesai',
                                    style: TextStyle(
                                      fontFamily: 'PlusJakartaSans',
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: textHead,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: (done == total ? AppColors.success : AppColors.accent).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: done == total ? AppColors.success : AppColors.accent),
                                ),
                                child: Text(
                                  done == total ? 'Semua Selesai' : '${total - done} Belum',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: done == total ? AppColors.success : AppColors.accent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // List Tugas
                        ..._tasks.map((task) {
                          final isDone = task.isCompleted;
                          final isKhusus = task.kategori == 'khusus' || task.templateId == null || task.templateId!.isEmpty;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: bgCard,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDone ? AppColors.success.withValues(alpha: 0.3) : borderCard,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Top row: Kategori & Status
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: isKhusus
                                            ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                                            : const Color(0xFF3B82F6).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: isKhusus
                                              ? const Color(0xFFF59E0B).withValues(alpha: 0.35)
                                              : const Color(0xFF3B82F6).withValues(alpha: 0.35),
                                        ),
                                      ),
                                      child: Text(
                                        isKhusus ? 'Tugas Khusus' : 'Maintenance',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: isKhusus ? const Color(0xFFFBBF24) : const Color(0xFF60A5FA),
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: isDone
                                            ? AppColors.success.withValues(alpha: 0.15)
                                            : const Color(0xFFF59E0B).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: isDone ? AppColors.success : const Color(0xFFF59E0B).withValues(alpha: 0.35),
                                        ),
                                      ),
                                      child: Text(
                                        isDone ? 'Selesai' : 'Baru',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: isDone ? AppColors.success : const Color(0xFFFBBF24),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),

                                // Judul Pekerjaan
                                Text(
                                  task.judul,
                                  style: TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: isDone ? textSub : textHead,
                                    decoration: isDone ? TextDecoration.lineThrough : null,
                                  ),
                                ),
                                const SizedBox(height: 4),

                                // Lokasi
                                Text(
                                  'Lokasi: ${task.posName}',
                                  style: TextStyle(fontSize: 12, color: textSub, fontWeight: FontWeight.w500),
                                ),

                                if (task.deskripsi.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    task.deskripsi,
                                    style: TextStyle(fontSize: 11, color: textSub),
                                  ),
                                ],

                                const SizedBox(height: 12),

                                // Action Row: Tombol Kerjakan di Kanan Bawah
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    if (!isDone)
                                      ElevatedButton(
                                        onPressed: () => _startTask(task),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.accent,
                                          foregroundColor: Colors.white,
                                          minimumSize: const Size(100, 44),
                                          padding: const EdgeInsets.symmetric(horizontal: 18),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          elevation: 0,
                                        ),
                                        child: const Text(
                                          'Kerjakan',
                                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                        ),
                                      )
                                    else
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: AppColors.success.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.check_circle_rounded, size: 14, color: AppColors.success),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Selesai (${task.jamSelesai ?? ""})',
                                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.success),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
            ),
    );
  }
}
