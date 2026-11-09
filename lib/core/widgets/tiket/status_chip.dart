import 'package:flutter/material.dart';
import '../../constants/tiket_colors.dart';

enum TiketChipKind {
  ok,
  attention,
  neutral,
  danger,
}

class StatusChip extends StatelessWidget {
  final String label;
  final TiketChipKind kind;

  const StatusChip({
    super.key,
    required this.label,
    required this.kind,
  });

  @override
  Widget build(BuildContext context) {
    final colors = TiketColors.of(context);

    Color bg;
    Color textColor;
    switch (kind) {
      case TiketChipKind.ok:
        bg = colors.ok;
        textColor = colors.white;
        break;
      case TiketChipKind.attention:
        bg = colors.signal;
        textColor = colors.black;
        break;
      case TiketChipKind.neutral:
        bg = colors.soft;
        textColor = colors.body;
        break;
      case TiketChipKind.danger:
        bg = colors.dangerTint;
        textColor = colors.danger;
        break;
    }

    return Container(
      height: 28.0,
      padding: const EdgeInsets.symmetric(horizontal: 6.0),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14.0),
      ),
      child: Center(
        widthFactor: 1,
        child: Text(
          label,
          style: TextStyle(
            fontFamily: TiketType.fontFamily,
            fontSize: 12.0,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ),
    );
  }
}
