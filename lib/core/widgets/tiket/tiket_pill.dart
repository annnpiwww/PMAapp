import 'package:flutter/material.dart';
import '../../constants/tiket_colors.dart';

enum TiketPillKind {
  primary,
  secondary,
  disabled,
  band,
  bandSelected,
}

class TiketPill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final TiketPillKind kind;
  final VoidCallback? onPressed;
  final double height;
  final bool expand;
  final String? badge;

  const TiketPill({
    super.key,
    required this.label,
    this.icon,
    this.kind = TiketPillKind.primary,
    this.onPressed,
    this.height = 44.0,
    this.expand = false,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final colors = TiketColors.of(context);
    final isDisabled = kind == TiketPillKind.disabled || onPressed == null;

    Color bg;
    Color textColor;
    Border? border;

    switch (kind) {
      case TiketPillKind.primary:
        bg = colors.primary;
        textColor = colors.onPrimary;
        break;
      case TiketPillKind.secondary:
        bg = Colors.transparent;
        textColor = colors.primary;
        border = Border.all(color: colors.primary, width: 1.5);
        break;
      case TiketPillKind.disabled:
        bg = colors.soft;
        textColor = colors.body;
        break;
      case TiketPillKind.band:
        bg = colors.bandRaise;
        textColor = colors.onBand;
        border = Border.all(color: colors.bandLine, width: 1.5);
        break;
      case TiketPillKind.bandSelected:
        bg = colors.white;
        textColor = colors.black;
        break;
    }

    Widget content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(
            icon,
            size: 18.0,
            color: textColor,
          ),
          const SizedBox(width: 6.0),
        ],
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              fontFamily: TiketType.fontFamily,
              fontSize: 14.0,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (badge != null) ...[
          const SizedBox(width: 6.0),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
            decoration: BoxDecoration(
              color: colors.signal,
              borderRadius: BorderRadius.circular(10.0),
            ),
            child: Text(
              badge!,
              style: TextStyle(
                fontFamily: TiketType.fontFamily,
                fontSize: 11.0,
                fontWeight: FontWeight.w700,
                color: colors.black,
              ),
            ),
          ),
        ],
      ],
    );

    return Semantics(
      button: true,
      enabled: !isDisabled,
      label: label,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: 48.0,
          minWidth: 48.0,
          maxWidth: expand ? double.infinity : double.infinity,
        ),
        child: Align(
          alignment: Alignment.center,
          child: SizedBox(
            height: height,
            width: expand ? double.infinity : null,
            child: Material(
              color: bg,
              shape: border != null
                  ? StadiumBorder(side: border.top)
                  : const StadiumBorder(),
              child: InkWell(
                customBorder: const StadiumBorder(),
                splashColor: colors.primaryPressed,
                highlightColor: colors.primaryPressed.withValues(alpha: 0.3),
                onTap: isDisabled ? null : onPressed,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Center(
                    widthFactor: expand ? null : 1.0,
                    child: content,
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
