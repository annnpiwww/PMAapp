import 'package:flutter/material.dart';
import '../../constants/tiket_colors.dart';

class TiketIconButton extends StatelessWidget {
  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onPressed;

  const TiketIconButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colors = TiketColors.of(context);
    final isEnabled = onPressed != null;

    return Semantics(
      button: true,
      enabled: isEnabled,
      label: semanticLabel,
      child: Tooltip(
        message: semanticLabel,
        child: SizedBox(
          width: 48.0,
          height: 48.0,
          child: Center(
            child: Material(
              color: colors.bandRaise,
              shape: CircleBorder(
                side: BorderSide(
                  color: colors.bandLine,
                  width: 1.5,
                ),
              ),
              child: InkWell(
                customBorder: const CircleBorder(),
                splashColor: colors.primaryPressed,
                highlightColor: colors.primaryPressed.withValues(alpha: 0.4),
                onTap: onPressed,
                child: SizedBox(
                  width: 44.0,
                  height: 44.0,
                  child: Center(
                    child: Opacity(
                      opacity: isEnabled ? 1.0 : 0.4,
                      child: Icon(
                        icon,
                        size: 22.0,
                        color: colors.onBand,
                      ),
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
