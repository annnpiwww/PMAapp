import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../data/models/daily_task_model.dart';
import 'completed_daily_task_modal.dart';

/// Card widget for a single daily task item in supervisor dispatcher view
class SpvTaskCard extends StatelessWidget {
  final DailyTaskModel task;
  final bool isDark;
  final bool isExpanded;
  final VoidCallback onToggleExpand;

  const SpvTaskCard({
    super.key,
    required this.task,
    required this.isDark,
    required this.isExpanded,
    required this.onToggleExpand,
  });

  String _getInitial(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return 'TK';
  }

  @override
  Widget build(BuildContext context) {
    final isDone = task.isCompleted;
    final hasNotes = task.catatanTeknisi != null &&
        task.catatanTeknisi!.trim().isNotEmpty &&
        task.catatanTeknisi != '-';

    // Format badge status: '✓ Selesai · 09:49 WITA' atau '◷ Belum Mulai'
    final String statusText;
    if (isDone) {
      if (task.jamSelesai != null && task.jamSelesai!.isNotEmpty) {
        final js = task.jamSelesai!.trim();
        statusText = js.contains('WITA') ? '✓ Selesai · $js' : '✓ Selesai · $js WITA';
      } else {
        statusText = '✓ Selesai';
      }
    } else {
      statusText = '◷ Belum Mulai';
    }

    final initial = _getInitial(task.teknisiNama);
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
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: isDone ? () => CompletedDailyTaskModal.show(context, task) : null,
          child: Padding(
            padding: const EdgeInsets.all(10),
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
                            task.teknisiNama,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: techTextColor,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: isDone
                                ? AppColors.success.withValues(alpha: 0.12)
                                : AppColors.accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(5),
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

                    // Judul Tugas
                    Text(
                      task.judul,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: titleTextColor,
                        decoration: isDone ? TextDecoration.lineThrough : null,
                        decorationColor: const Color(0xFF94A3B8),
                      ),
                    ),

                    // Deskripsi (jika ada)
                    if (task.deskripsi.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        task.deskripsi.trim(),
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
                            task.posName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: subTextColor,
                            ),
                          ),
                        ),
                        if (task.isMaintenance) ...[
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
                        if (isDone) ...[
                          InkWell(
                            onTap: () => CompletedDailyTaskModal.show(context, task),
                            borderRadius: BorderRadius.circular(4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: AppColors.success.withValues(alpha: 0.35), width: 0.8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.photo_library_outlined, size: 10, color: AppColors.success),
                                  const SizedBox(width: 3),
                                  Text(
                                    task.fotoBuktiUrls.isNotEmpty ? 'Bukti (${task.fotoBuktiUrls.length})' : 'Lihat Bukti',
                                    style: const TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.success,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (hasNotes) const SizedBox(width: 6),
                        ],
                        if (hasNotes)
                          InkWell(
                            onTap: onToggleExpand,
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
                    task.catatanTeknisi!.trim(),
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
    ),
  ),
),
);
  }
}
