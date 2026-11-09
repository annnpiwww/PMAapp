import 'package:flutter/material.dart';
import '../../constants/tiket_colors.dart';

class TiketBottomBar extends StatelessWidget {
  final Widget primary;
  final Widget? secondary;
  final String? helper;

  const TiketBottomBar({
    super.key,
    required this.primary,
    this.secondary,
    this.helper,
  });

  @override
  Widget build(BuildContext context) {
    final colors = TiketColors.of(context);
    final pad = TiketSpace.padOf(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Container(
      decoration: BoxDecoration(
        color: colors.bar,
        border: Border(
          top: BorderSide(
            color: colors.hairline,
            width: 1.0,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: colors.ink.withValues(alpha: 0.06),
            blurRadius: 8.0,
            offset: const Offset(0, -2.0),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: pad,
        right: pad,
        top: 12.0,
        bottom: 12.0 + bottomInset,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (helper != null) ...[
            Text(
              helper!,
              style: TextStyle(
                fontFamily: TiketType.fontFamily,
                fontSize: 13.0,
                fontWeight: FontWeight.w500,
                color: colors.body,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8.0),
          ],
          SizedBox(
            height: 52.0,
            child: primary,
          ),
          if (secondary != null) ...[
            const SizedBox(height: 8.0),
            SizedBox(
              height: 48.0,
              child: secondary!,
            ),
          ],
        ],
      ),
    );
  }
}
