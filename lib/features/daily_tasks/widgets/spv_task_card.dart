import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../data/models/daily_task_model.dart';
import 'completed_daily_task_modal.dart';

/// Compact task card for supervisor dispatcher with inline header, merged metadata, and footer actions.
class SpvTaskCard extends StatelessWidget {
  final DailyTaskModel task;
  final bool isDark;
  final bool isExpanded;
  final VoidCallback onToggleExpand;
  final VoidCallback? onHandover;
  final VoidCallback? onDelete;

  const SpvTaskCard({
    super.key,
    required this.task,
    required this.isDark,
    required this.isExpanded,
    required this.onToggleExpand,
    this.onHandover,
    this.onDelete,
  });

  static const List<String> _dayNames = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
  static const List<String> _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
  ];

  @override
  Widget build(BuildContext context) {
    final isDone = task.isCompleted;
    final hasNotes = task.catatanTeknisi != null &&
        task.catatanTeknisi!.trim().isNotEmpty &&
        task.catatanTeknisi != '-';

    final posPillText = task.posTag.trim().isNotEmpty ? task.posTag.trim() : task.posName.trim();
    final hasPos = posPillText.isNotEmpty;

    final status = _statusStyle();
    final accentColor = status.accent;

    final cardBg = isDark ? AppColors.darkSurface : AppColors.surface;
    final cardBorder = isDark ? AppColors.darkBorder : AppColors.cardBorder;
    final titleColor = isDark ? AppColors.textDarkPrimary : AppColors.textPrimary;
    final metaColor = isDark ? AppColors.textDarkSecondary : AppColors.textSecondary;
    final mutedColor = isDark ? AppColors.textDarkMuted : AppColors.textMuted;

    final deskripsiText = task.deskripsi.trim();
    final hasDeskripsi = deskripsiText.isNotEmpty;
    final trimmedPosName = task.posName.trim();
    final metaText = [
      if (task.labelPelaksana.trim().isNotEmpty) task.labelPelaksana.trim(),
      if (_dateLine(isDone).trim().isNotEmpty) _dateLine(isDone).trim(),
      if (trimmedPosName.isNotEmpty && trimmedPosName != posPillText) trimmedPosName,
    ].join(' · ');

    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: 'Tugas ${task.judul} di lokasi ${task.posName}, pelaksana ${task.labelPelaksana}, status ${status.label}',
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(AppColors.radiusCard),
          border: Border.all(color: cardBorder),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
        ),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 4,
              child: ColoredBox(color: accentColor),
            ),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: isDone ? () => CompletedDailyTaskModal.show(context, task) : onToggleExpand,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 4, 6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 40),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            if (hasPos) ...[
                              Semantics(
                                container: true,
                                label: 'Lokasi $posPillText',
                                excludeSemantics: true,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: isDark ? 0.30 : 0.10),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    posPillText,
                                    style: TextStyle(
                                      fontFamily: 'PlusJakartaSans',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.3,
                                      color: isDark ? AppColors.textDarkPrimary : AppColors.primary,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Expanded(
                              child: Text(
                                task.judul,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  height: 1.3,
                                  color: titleColor,
                                ),
                              ),
                            ),
                            _kebabMenu(hasNotes, isDone, mutedColor),
                          ],
                        ),
                      ),
                      ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 36),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Flexible(
                              child: _statusPill(status),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text.rich(
                                TextSpan(
                                  children: [
                                    WidgetSpan(
                                      alignment: PlaceholderAlignment.middle,
                                      child: Padding(
                                        padding: const EdgeInsets.only(right: 4),
                                        child: Icon(Icons.person_outline_rounded, size: 14, color: metaColor),
                                      ),
                                    ),
                                    TextSpan(text: metaText),
                                  ],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: metaColor,
                                ),
                              ),
                            ),
                            if (!isDone && onHandover != null) ...[
                              const SizedBox(width: 6),
                              _handoverButton(),
                            ] else if (isDone) ...[
                              const SizedBox(width: 6),
                              _buktiButton(context),
                            ],
                          ],
                        ),
                      ),
                      if (isExpanded) ...[
                        if (hasDeskripsi) ...[
                          const SizedBox(height: 6),
                          Text(
                            deskripsiText,
                            maxLines: null,
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 12,
                              color: mutedColor,
                            ),
                          ),
                        ],
                        if (hasNotes) ...[
                          const SizedBox(height: 6),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkBackground : AppColors.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.cardBorder),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Catatan Teknisi:',
                                  style: TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: metaColor,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  task.catatanTeknisi!.trim(),
                                  style: TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                    color: titleColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  _CardStatus _statusStyle() {
    if (task.isCompleted) {
      return _CardStatus(
        label: 'Selesai',
        icon: Icons.check_rounded,
        accent: AppColors.success,
        background: isDark ? AppColors.success.withValues(alpha: 0.18) : AppColors.successLight,
        border: isDark ? AppColors.success.withValues(alpha: 0.45) : AppColors.successBorder,
        foreground: isDark ? const Color(0xFF34D399) : AppColors.success,
      );
    }
    if (task.isOpenHandover) {
      return _CardStatus(
        label: 'Menunggu Alih',
        icon: Icons.swap_horiz_rounded,
        accent: AppColors.info,
        background: AppColors.info.withValues(alpha: isDark ? 0.20 : 0.10),
        border: AppColors.info.withValues(alpha: isDark ? 0.45 : 0.35),
        foreground: isDark ? const Color(0xFF38BDF8) : AppColors.info,
      );
    }
    if (task.status == TaskStatus.inProgress) {
      return _CardStatus(
        label: 'Dalam Proses',
        icon: Icons.play_arrow_rounded,
        accent: AppColors.warning,
        background: isDark ? AppColors.warning.withValues(alpha: 0.18) : AppColors.warningLight,
        border: isDark ? AppColors.warning.withValues(alpha: 0.45) : AppColors.warningBorder,
        foreground: isDark ? const Color(0xFFFBBF24) : AppColors.warning,
      );
    }
    return _CardStatus(
      label: 'Belum Mulai',
      accent: AppColors.info,
      background: isDark ? AppColors.darkSurfaceContainer : AppColors.creamContainer,
      border: isDark ? AppColors.darkBorderMuted : AppColors.cardBorder,
      foreground: isDark ? AppColors.textDarkSecondary : AppColors.textSecondary,
    );
  }

  String _dateLine(bool isDone) {
    final relative = _relativeDate(task.tanggal);
    final jam = task.jamSelesai?.trim() ?? '';
    if (isDone && jam.isNotEmpty) {
      final label = jam.contains('WITA') ? jam : '$jam WITA';
      return '$relative · Selesai $label';
    }
    return relative;
  }

  String _relativeDate(String tanggal) {
    final parsed = DateTime.tryParse(tanggal);
    if (parsed == null) return tanggal;
    final now = DateTime.now();
    final target = DateTime(parsed.year, parsed.month, parsed.day);
    final today = DateTime(now.year, now.month, now.day);
    final diff = target.difference(today).inDays;
    if (diff == 0) return 'Hari ini';
    if (diff == 1) return 'Besok';
    if (diff == -1) return 'Kemarin';
    return '${_dayNames[target.weekday - 1]}, ${target.day} ${_monthNames[target.month - 1]}';
  }

  Widget _statusPill(_CardStatus status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: status.background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: status.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status.icon != null) ...[
            Icon(status.icon, size: 12, color: status.foreground),
            const SizedBox(width: 3),
          ],
          Flexible(
            child: Text(
              status.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: status.foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kebabMenu(bool hasNotes, bool isDone, Color mutedColor) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      child: SizedBox(
        width: 44,
        height: 44,
        child: PopupMenuButton<String>(
          tooltip: 'Pilihan menu tugas',
          padding: EdgeInsets.zero,
          iconSize: 18,
          icon: Icon(Icons.more_vert_rounded, color: mutedColor),
          onSelected: (value) {
            switch (value) {
              case 'alihkan':
                onHandover?.call();
                break;
              case 'catatan':
                onToggleExpand();
                break;
              case 'hapus':
                onDelete?.call();
                break;
            }
          },
          itemBuilder: (context) => [
            if (!isDone && onHandover != null)
              _menuItem('alihkan', Icons.swap_horiz_rounded, 'Alihkan Tugas'),
            if (hasNotes)
              _menuItem('catatan', Icons.notes_rounded, isExpanded ? 'Tutup Catatan' : 'Lihat Catatan'),
            if (!isDone && onDelete != null)
              _menuItem('hapus', Icons.delete_outline_rounded, 'Hapus Tugas', danger: true),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<String> _menuItem(String value, IconData icon, String label, {bool danger = false}) {
    final color = danger ? AppColors.danger : (isDark ? AppColors.textDarkPrimary : AppColors.textPrimary);
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }

  Widget _handoverButton() {
    return Semantics(
      button: true,
      label: 'Alihkan tugas',
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
        child: InkWell(
          onTap: onHandover,
          borderRadius: BorderRadius.circular(8),
          child: Center(
            child: SizedBox(
              height: 32,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.accent.withValues(alpha: 0.35)),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.swap_horiz_rounded, size: 14, color: AppColors.accent),
                      SizedBox(width: 4),
                      Text(
                        'Alihkan',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buktiButton(BuildContext context) {
    final hasVideo = task.fotoBuktiUrls.any((u) {
      final l = u.toLowerCase();
      return l.endsWith('.mp4') || l.endsWith('.mov') || l.endsWith('.mkv') || l.endsWith('.webm');
    });
    final hasPhoto = task.fotoBuktiUrls.any((u) {
      final l = u.toLowerCase();
      return !l.endsWith('.mp4') && !l.endsWith('.mov') && !l.endsWith('.mkv') && !l.endsWith('.webm');
    });
    final icon = (hasPhoto && hasVideo)
        ? Icons.perm_media_outlined
        : (hasVideo ? Icons.videocam_outlined : Icons.image_outlined);
    final label = task.fotoBuktiUrls.isNotEmpty ? 'Bukti (${task.fotoBuktiUrls.length})' : 'Bukti';
    return Semantics(
      button: true,
      label: 'Lihat bukti',
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
        child: InkWell(
          onTap: () => CompletedDailyTaskModal.show(context, task),
          borderRadius: BorderRadius.circular(8),
          child: Center(
            child: SizedBox(
              height: 32,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.success.withValues(alpha: 0.35)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 16, color: AppColors.success),
                      const SizedBox(width: 4),
                      Text(
                        label,
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CardStatus {
  final String label;
  final IconData? icon;
  final Color accent;
  final Color background;
  final Color border;
  final Color foreground;

  const _CardStatus({
    required this.label,
    this.icon,
    required this.accent,
    required this.background,
    required this.border,
    required this.foreground,
  });
}
