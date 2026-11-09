import 'package:flutter/material.dart';
import '../../constants/tiket_colors.dart';

class PerforationPainter extends CustomPainter {
  final Color canvasColor;

  const PerforationPainter({required this.canvasColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = canvasColor
      ..style = PaintingStyle.fill;

    const diameter = 10.0;
    const radius = diameter / 2.0;
    const spacing = 22.0;

    final count = (size.width / spacing).floor();
    if (count <= 0) return;
    final startX = (size.width - (count - 1) * spacing) / 2.0;

    for (int i = 0; i < count; i++) {
      final x = startX + i * spacing;
      canvas.drawCircle(Offset(x, size.height), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant PerforationPainter oldDelegate) =>
      oldDelegate.canvasColor != canvasColor;
}

class TiketBand extends StatelessWidget {
  final Widget? leading;
  final List<Widget> actions;
  final String? caption;
  final Widget? hero;
  final Widget? footer;
  final EdgeInsetsGeometry? padding;

  const TiketBand({
    super.key,
    this.leading,
    this.actions = const [],
    this.caption,
    this.hero,
    this.footer,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final colors = TiketColors.of(context);
    final topInset = MediaQuery.paddingOf(context).top;
    final horizontalPad = TiketSpace.padOf(context);
    final type = TiketType.of(context);

    return ExcludeSemantics(
      excluding: false,
      child: Stack(
        children: [
          Container(
            color: colors.band,
            padding: padding ??
                EdgeInsets.only(
                  top: topInset + 12.0,
                  left: horizontalPad,
                  right: horizontalPad,
                  bottom: 18.0,
                ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (leading != null || actions.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (leading != null) leading! else const SizedBox.shrink(),
                      if (actions.isNotEmpty)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (int i = 0; i < actions.length; i++) ...[
                              if (i > 0) const SizedBox(width: 8.0),
                              actions[i],
                            ],
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 12.0),
                ],
                if (caption != null) ...[
                  Text(
                    caption!,
                    style: type.caption(color: colors.bandCaption),
                  ),
                  const SizedBox(height: 4.0),
                ],
                if (hero != null) ...[
                  hero!,
                ],
                if (footer != null) ...[
                  const SizedBox(height: 12.0),
                  footer!,
                ],
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 10.0,
            child: ExcludeSemantics(
              child: CustomPaint(
                painter: PerforationPainter(canvasColor: colors.canvas),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
