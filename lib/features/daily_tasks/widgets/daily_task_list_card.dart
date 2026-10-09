import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/daily_task_model.dart';
import '../../../data/services/daily_task_service.dart';
import '../../../data/repositories/auth_repository.dart';

class DailyTaskListCard extends StatefulWidget {
  final VoidCallback? onTaskCompleted;
  final Function(DailyTaskModel task)? onStartTask;

  const DailyTaskListCard({
    super.key,
    this.onTaskCompleted,
    this.onStartTask,
  });

  @override
  State<DailyTaskListCard> createState() => _DailyTaskListCardState();
}

class _DailyTaskListCardState extends State<DailyTaskListCard> {
  List<DailyTaskModel> _myTasks = [];
  bool _isLoading = false;
  bool _isCollapsed = false;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  @override
  void didUpdateWidget(covariant DailyTaskListCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _loadTasks();
  }

  String _todayStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _loadTasks() async {
    final user = AuthRepository.instance.currentUser;
    if (user == null) return;
    setState(() => _isLoading = true);

    final tasks = await DailyTaskService.getTasksForTeknisi(
      tanggal: _todayStr(),
      teknisiNama: user.nama,
    );

    if (mounted) {
      setState(() {
        _myTasks = tasks;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _myTasks.isEmpty) {
      return const SizedBox.shrink();
    }

    if (_myTasks.isEmpty) {
      return const SizedBox.shrink(); // Jangan penuhi layar jika tidak ada tugas
    }

    final total = _myTasks.length;
    final done = _myTasks.where((t) => t.isCompleted).length;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: done == total ? AppColors.success.withValues(alpha: 0.4) : AppColors.accent.withValues(alpha: 0.4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar
          InkWell(
            onTap: () => setState(() => _isCollapsed = !_isCollapsed),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.assignment_turned_in_rounded, size: 16, color: AppColors.accent),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tugas Hari Ini',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          '$done/$total selesai',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 11,
                            color: done == total ? AppColors.success : const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, size: 16, color: Color(0xFF94A3B8)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: _loadTasks,
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _isCollapsed ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_up_rounded,
                    color: const Color(0xFF94A3B8),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          // Collapsible Task List
          if (!_isCollapsed) ...[
            const Divider(color: Color(0xFF334155), height: 1),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(12),
              itemCount: _myTasks.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (ctx, idx) {
                final task = _myTasks[idx];
                final isDone = task.isCompleted;

                return Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDone ? AppColors.success.withValues(alpha: 0.3) : const Color(0xFF334155),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Check icon
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: (isDone ? AppColors.success : const Color(0xFF334155)).withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDone ? AppColors.success : const Color(0xFF475569),
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            isDone ? Icons.check_rounded : Icons.pending_outlined,
                            size: 16,
                            color: isDone ? AppColors.success : const Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Text
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              task.judul,
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDone ? const Color(0xFF94A3B8) : Colors.white,
                                decoration: isDone ? TextDecoration.lineThrough : null,
                                decorationColor: isDone ? const Color(0xFF94A3B8) : null,
                                decorationThickness: isDone ? 2.0 : null,
                              ),
                            ),
                            if (task.posTag.isNotEmpty)
                              Text(
                                '${task.posTag} • ${task.posName}',
                                style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Button Kerjakan
                      if (!isDone)
                        Builder(builder: (_) {
                          final ongoing = DailyTaskService.getOngoingMaintenance(task);
                          final hasOngoing = ongoing != null;
                          return ElevatedButton.icon(
                            onPressed: () {
                              if (widget.onStartTask != null) {
                                widget.onStartTask!(task);
                              }
                            },
                            icon: Icon(
                              hasOngoing ? Icons.play_arrow_rounded : Icons.camera_alt_outlined,
                              size: 13,
                            ),
                            label: Text(
                              hasOngoing
                                  ? 'Lanjutkan (${ongoing.doneCount}/${ongoing.totalPoints})'
                                  : 'Kerjakan',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: hasOngoing ? AppColors.primary : AppColors.accent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              minimumSize: Size.zero,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          );
                        })
                      else
                        const Text(
                          'Selesai ✅',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.success),
                        ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
