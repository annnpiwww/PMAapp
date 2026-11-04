import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// Shared outlined input shell for the "Buat Tugas" sheet: leading icon,
/// content (text field or dropdown), optional trailing icon, 48dp min height.
class AppOutlinedFormField extends StatelessWidget {
  final IconData leadingIcon;
  final Widget child;
  final IconData? trailingIcon;
  final VoidCallback? onTap;
  final bool isDark;
  final bool multiline;

  const AppOutlinedFormField({
    super.key,
    required this.leadingIcon,
    required this.child,
    this.trailingIcon,
    this.onTap,
    required this.isDark,
    this.multiline = false,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = isDark ? AppColors.textDarkMuted : AppColors.textMuted;
    final bg = isDark ? AppColors.darkSurfaceContainer : AppColors.surface;
    final border = isDark ? AppColors.darkBorderMuted : AppColors.cardBorder;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: multiline ? 10 : 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        child: Row(
          crossAxisAlignment: multiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
          children: [
            Padding(
              padding: EdgeInsets.only(top: multiline ? 2 : 0),
              child: Icon(leadingIcon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 10),
            Expanded(child: child),
            if (trailingIcon != null) ...[
              const SizedBox(width: 8),
              Icon(trailingIcon, size: 18, color: iconColor),
            ],
          ],
        ),
      ),
    );
  }
}
