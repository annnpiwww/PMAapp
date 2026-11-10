import 'package:flutter/material.dart';
import '../../../../core/constants/tiket_colors.dart';
import '../../../../core/widgets/tiket/tiket.dart';
import '../../../../data/models/daily_task_model.dart';
import 'completed_daily_task_modal.dart';
import 'daily_task_action_pill.dart';

/// Compact task card for supervisor dispatcher with inline header, merged metadata, and footer actions.
class SpvTaskCard extends StatelessWidget {
  final DailyTaskModel task;
  final bool isDark;
  final bool isExpanded;
  final VoidCallback onToggleExpand;
  final VoidCallback? onHandover;
  final VoidCallback? onDelete;
  final VoidCallback? onKerjakan;

  const SpvTaskCard({
    super.key,
    required this.task,
    required this.isDark,
    required this.isExpanded,
    required this.onToggleExpand,
    this.onHandover,
    this.onDelete,
    this.onKerjakan,
  });

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'T';
    if (parts.length == 1) return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final colors = TiketColors.of(context);
    final isDone = task.isCompleted;
    final hasNotes = task.catatanTeknisi != null &&
        task.catatanTeknisi!.trim().isNotEmpty &&
        task.catatanTeknisi != '-';
    final deskripsiText = task.deskripsi.trim();
    final hasDeskripsi = deskripsiText.isNotEmpty;

    // Technician line: 'name · bersama X / dialihkan dari Y' (ink)
    final teknisiParts = [task.teknisiNama];
    if (task.peserta.trim().isNotEmpty) {
      teknisiParts.add('bersama ${task.peserta.trim()}');
    }
    if (task.handoverDari != null && task.handoverDari!.trim().isNotEmpty) {
      teknisiParts.add('dialihkan dari ${task.handoverDari!.trim()}');
    }
    final teknisiLine = teknisiParts.join(' · ');

    // Meta line: 'posName · kategori' (body)
    final metaParts = [
      if (task.posName.trim().isNotEmpty) task.posName.trim(),
      if (task.kategori.trim().isNotEmpty) task.kategori.trim(),
    ];
    final metaLine = metaParts.join(' · ');

    final statusText = isDone
        ? (task.jamSelesai != null && task.jamSelesai!.trim().isNotEmpty
            ? 'Selesai ${task.jamSelesai!.trim()} WITA'
            : 'Selesai')
        : (task.isOpenHandover
            ? 'Alih Tugas'
            : (task.status == TaskStatus.inProgress ? 'Proses' : 'Belum mulai'));

    final buktiLabel = task.fotoBuktiUrls.isNotEmpty ? 'Bukti (${task.fotoBuktiUrls.length})' : 'Bukti';
    final lokasiText = task.posName.trim().isNotEmpty ? ' di lokasi ${task.posName.trim()}' : '';

    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: 'Tugas ${task.judul}$lokasiText, pelaksana $teknisiLine, status $statusText',
      child: Material(
        color: colors.canvas,
        child: InkWell(
          onTap: isDone ? () => CompletedDailyTaskModal.show(context, task) : onToggleExpand,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Leading 44 circle soft avatar with technician initials
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.soft,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _initials(task.teknisiNama),
                        style: TextStyle(
                          fontFamily: TiketType.fontFamily,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: colors.ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Title wraps (no ellipsis, no maxLines)
                                    Text(
                                      task.judul,
                                      style: TextStyle(
                                        fontFamily: TiketType.fontFamily,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: colors.ink,
                                        height: 1.3,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    // Meta line 'posName · kategori' (body)
                                    if (metaLine.isNotEmpty) ...[
                                      Text(
                                        metaLine,
                                        style: TextStyle(
                                          fontFamily: TiketType.fontFamily,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: colors.body,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                    ],
                                    // Technician line 'name · bersama X / dialihkan dari Y' (ink)
                                    Text(
                                      teknisiLine,
                                      style: TextStyle(
                                        fontFamily: TiketType.fontFamily,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: colors.ink,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 4),
                              // Kebab trailing 48 hit
                              _kebabMenu(hasNotes, isDone, colors),
                            ],
                          ),
                          if (isDone || onHandover != null || (!isDone && onKerjakan != null)) ...[
                            const SizedBox(height: 6),
                            if (isDone)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  const Flexible(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        StatusMarker(status: TiketStatus.ok),
                                        SizedBox(width: 6),
                                        Flexible(
                                          child: StatusChip(
                                            label: 'Selesai',
                                            kind: TiketChipKind.ok,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  DailyTaskActionPill(
                                    label: buktiLabel,
                                    icon: Icons.photo_camera_outlined,
                                    isPrimary: false,
                                    isDark: isDark,
                                    onPressed: () => CompletedDailyTaskModal.show(context, task),
                                  ),
                                ],
                              )
                            else
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Flexible(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const StatusMarker(status: TiketStatus.notStarted),
                                        const SizedBox(width: 6),
                                        Flexible(
                                          child: Text(
                                            'Belum mulai',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontFamily: TiketType.fontFamily,
                                              fontSize: 12,
                                              color: colors.body,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (onKerjakan != null) ...[
                                        DailyTaskActionPill(
                                          label: 'Kerjakan',
                                          isPrimary: true,
                                          onPressed: onKerjakan,
                                        ),
                                        if (onHandover != null) const SizedBox(width: 8),
                                      ],
                                      if (onHandover != null)
                                        DailyTaskActionPill(
                                          label: 'Alihkan',
                                          icon: Icons.swap_horiz_rounded,
                                          isPrimary: false,
                                          onPressed: onHandover,
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                          ],
                          if (isExpanded) ...[
                            if (hasDeskripsi) ...[
                              const SizedBox(height: 8),
                              Text(
                                deskripsiText,
                                style: TextStyle(
                                  fontFamily: TiketType.fontFamily,
                                  fontSize: 12,
                                  color: colors.body,
                                  height: 1.35,
                                ),
                              ),
                            ],
                            if (hasNotes) ...[
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: colors.soft,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: colors.hairline),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Catatan Teknisi:',
                                      style: TextStyle(
                                        fontFamily: TiketType.fontFamily,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: colors.ink,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      task.catatanTeknisi!,
                                      style: TextStyle(
                                        fontFamily: TiketType.fontFamily,
                                        fontSize: 12,
                                        color: colors.body,
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
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 72, right: 16),
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: colors.hairline,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _kebabMenu(bool hasNotes, bool isDone, TiketColors colors) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      child: SizedBox(
        width: 48,
        height: 48,
        child: PopupMenuButton<String>(
          tooltip: 'Pilihan menu tugas',
          padding: EdgeInsets.zero,
          iconSize: 20,
          icon: Icon(Icons.more_vert_rounded, color: colors.body),
          color: colors.dialog,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: colors.hairline),
          ),
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
              _menuItem('alihkan', Icons.swap_horiz_rounded, 'Alihkan Tugas', colors),
            if (hasNotes)
              _menuItem('catatan', Icons.notes_rounded, isExpanded ? 'Tutup Catatan' : 'Lihat Catatan', colors),
            if (!isDone && onDelete != null)
              _menuItem('hapus', Icons.delete_outline_rounded, 'Hapus Tugas', colors, danger: true),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<String> _menuItem(String value, IconData icon, String label, TiketColors colors, {bool danger = false}) {
    final color = danger ? colors.danger : colors.ink;
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(fontFamily: TiketType.fontFamily, fontSize: 13, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}
