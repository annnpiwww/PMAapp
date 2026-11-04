import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// Three-segment status filter (Semua / Belum / Selesai) with live counts.
class SpvStatusSegmentBar extends StatelessWidget {
  final int total;
  final int pending;
  final int completed;
  final String selected;
  final ValueChanged<String> onSelect;
  final bool isDark;

  const SpvStatusSegmentBar({
    super.key,
    required this.total,
    required this.pending,
    required this.completed,
    required this.selected,
    required this.onSelect,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final barBg = isDark ? AppColors.darkSurface : AppColors.creamContainer;
    final barBorder = isDark ? AppColors.darkBorder : AppColors.cardBorder;

    return Container(
      height: 40,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: barBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: barBorder),
      ),
      child: Row(
        children: [
          _segment('ALL', 'Semua', total, Icons.grid_view_rounded),
          _segment('PENDING', 'Belum', pending, Icons.schedule_rounded),
          _segment('COMPLETED', 'Selesai', completed, Icons.check_circle_rounded),
        ],
      ),
    );
  }

  Widget _segment(String key, String label, int count, IconData icon) {
    final isSelected = selected == key;
    final selectedBg = isDark ? AppColors.darkSurfaceContainer : AppColors.surface;
    final activeColor = isDark ? AppColors.textDarkPrimary : AppColors.textPrimary;
    final inactiveColor = isDark ? AppColors.textDarkSecondary : AppColors.textSecondary;

    return Expanded(
      child: Semantics(
        button: true,
        selected: isSelected,
        label: 'Filter status $label, $count tugas',
        excludeSemantics: true,
        child: InkWell(
          onTap: () => onSelect(key),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 34,
            decoration: BoxDecoration(
              color: isSelected ? selectedBg : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: isSelected
                  ? Border.all(color: isDark ? AppColors.darkBorderMuted : AppColors.cardBorder)
                  : null,
              boxShadow: isSelected && !isDark
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 13, color: isSelected ? AppColors.primaryLight : inactiveColor),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    '$label ($count)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? activeColor : inactiveColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
