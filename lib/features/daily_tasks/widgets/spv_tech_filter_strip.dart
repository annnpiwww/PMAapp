import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// One technician entry for the horizontal filter strip.
class SpvTechFilterEntry {
  final String name; // 'SEMUA' for the all-technicians chip
  final int pendingCount;

  const SpvTechFilterEntry({required this.name, required this.pendingCount});

  bool get isAll => name == 'SEMUA';
}

/// Horizontally scrollable technician filter chips with pending-count badges.
class SpvTechFilterStrip extends StatelessWidget {
  final List<SpvTechFilterEntry> entries;
  final String selected;
  final ValueChanged<String> onSelect;
  final bool isDark;

  const SpvTechFilterStrip({
    super.key,
    required this.entries,
    required this.selected,
    required this.onSelect,
    required this.isDark,
  });

  static String initialsOf(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return '${parts[0].characters.first}${parts[1].characters.first}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: entries.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final entry = entries[index];
          final isSelected = selected == entry.name;
          final selectedColor = isDark ? AppColors.primaryLight : AppColors.primary;
          final bg = isSelected
              ? selectedColor
              : (isDark ? AppColors.darkSurface : AppColors.surfaceContainerLow);
          final borderColor = isSelected
              ? selectedColor
              : (isDark ? AppColors.darkBorder : AppColors.cardBorder);
          final textColor = isSelected
              ? Colors.white
              : (isDark ? AppColors.textDarkSecondary : AppColors.textSecondary);

          return Semantics(
            button: true,
            selected: isSelected,
            label: entry.isAll ? 'Filter semua teknisi' : 'Filter teknisi ${entry.name}',
            excludeSemantics: true,
            child: InkWell(
              onTap: () => onSelect(entry.name),
              borderRadius: BorderRadius.circular(18),
              child: Container(
                height: 34,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (entry.isAll)
                      Icon(Icons.groups_rounded, size: 16, color: textColor)
                    else
                      Container(
                        width: 20,
                        height: 20,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.22)
                              : AppColors.primary.withValues(alpha: isDark ? 0.30 : 0.10),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          initialsOf(entry.name),
                          style: TextStyle(
                            fontFamily: 'Figtree',
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: isSelected
                                ? Colors.white
                                : (isDark ? AppColors.textDarkPrimary : AppColors.primary),
                          ),
                        ),                      ),
                    const SizedBox(width: 6),
                    Text(
                      entry.isAll ? 'Semua Teknisi' : _firstName(entry.name),
                      style: TextStyle(
                        fontFamily: 'Figtree',
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white.withValues(alpha: 0.22)
                            : (isDark ? AppColors.darkSurfaceContainer : AppColors.creamContainer),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${entry.pendingCount}',
                        style: TextStyle(
                          fontFamily: 'Figtree',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? Colors.white
                              : (isDark ? AppColors.textDarkSecondary : AppColors.textSecondary),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Chip shows the short name to fit 360dp; card + summary keep the full name.
  static String _firstName(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    return parts.isEmpty ? name : parts.first;
  }
}
