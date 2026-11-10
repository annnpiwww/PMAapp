import 'package:flutter/material.dart';
import '../../../core/constants/tiket_colors.dart';

/// Compact action pill for task cards (visual height 36, radius 18, hit area 48x48).
class DailyTaskActionPill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool isPrimary;
  final bool? isDark;
  final VoidCallback? onPressed;

  const DailyTaskActionPill({
    super.key,
    required this.label,
    this.icon,
    this.isPrimary = false,
    this.isDark,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colors = TiketColors.of(context);
    final dark = isDark ?? (Theme.of(context).brightness == Brightness.dark);

    final Color bg;
    final Color textColor;
    final Border? border;

    if (isPrimary) {
      bg = colors.primary;
      textColor = colors.onPrimary;
      border = null;
    } else {
      bg = Colors.transparent;
      textColor = dark ? Colors.white.withValues(alpha: 0.90) : colors.ink;
      final borderColor = dark ? Colors.white.withValues(alpha: 0.70) : colors.ink;
      border = Border.all(color: borderColor, width: 1.0);
    }

    final fontWeight = isPrimary ? FontWeight.w700 : FontWeight.w600;

    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          child: Align(
            alignment: Alignment.center,
            widthFactor: 1.0,
            child: SizedBox(
              height: 36,
              child: Material(
                color: bg,
                shape: border != null
                    ? StadiumBorder(side: border.top)
                    : const StadiumBorder(),
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: onPressed,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (icon != null) ...[
                          Icon(icon, size: 16, color: textColor),
                          const SizedBox(width: 6),
                        ],
                        Flexible(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: TiketType.fontFamily,
                              fontSize: 13,
                              fontWeight: fontWeight,
                              color: textColor,
                            ),
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
      ),
    );
  }
}
