import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// Premium optical viewfinder — thin refined L-brackets with hairline border.
/// Tuned for tactical field-ops HUD: lighter stroke, longer corners, soft glow.
class TacticalOpticalFramePainter extends CustomPainter {
  const TacticalOpticalFramePainter();

  @override
  void paint(Canvas canvas, Size size) {
    // Hairline outer stroke — calm, lets viewfinder breathe.
    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..strokeWidth = 0.9
      ..style = PaintingStyle.stroke;

    // Premium corner brackets — thinner (1.45), longer (22), richer contrast
    final bracketPaint = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.92)
      ..strokeWidth = 1.45
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Subtle outer glow behind brackets for depth
    final glowPaint = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.18)
      ..strokeWidth = 4.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);

    // Outer subtle border with soft radius
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(6),
      ),
      borderPaint,
    );

    const cornerLen = 22.0;
    const padding = 12.0;
    const gap = 2.0;

    void drawCorner(Offset origin, bool flipX, bool flipY) {
      final dx = flipX ? -1 : 1;
      final dy = flipY ? -1 : 1;
      final h2 = Offset(origin.dx + dx * cornerLen, origin.dy);
      final v2 = Offset(origin.dx, origin.dy + dy * cornerLen);
      // Glow underlay
      canvas.drawLine(origin, h2, glowPaint);
      canvas.drawLine(origin, v2, glowPaint);
      // Crisp foreground
      canvas.drawLine(origin, h2, bracketPaint);
      canvas.drawLine(origin, v2, bracketPaint);
      // Tip dots — premium micro detail
      final dotPaint = Paint()..color = AppColors.accent.withValues(alpha: 0.95);
      canvas.drawCircle(h2, 1.25, dotPaint);
      canvas.drawCircle(v2, 1.25, dotPaint);
    }

    drawCorner(const Offset(padding + gap, padding + gap), false, false);
    drawCorner(Offset(size.width - padding - gap, padding + gap), true, false);
    drawCorner(Offset(padding + gap, size.height - padding - gap), false, true);
    drawCorner(Offset(size.width - padding - gap, size.height - padding - gap), true, true);

    // Center crosshair — ultra subtle alignment aid
    final cx = size.width / 2;
    final cy = size.height / 2;
    final crossPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.09)
      ..strokeWidth = 0.7
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const crossLen = 10.0;
    const crossGap = 3.0;
    canvas.drawLine(Offset(cx - crossLen - crossGap, cy), Offset(cx - crossGap, cy), crossPaint);
    canvas.drawLine(Offset(cx + crossGap, cy), Offset(cx + crossLen + crossGap, cy), crossPaint);
    canvas.drawLine(Offset(cx, cy - crossLen - crossGap), Offset(cx, cy - crossGap), crossPaint);
    canvas.drawLine(Offset(cx, cy + crossGap), Offset(cx, cy + crossLen + crossGap), crossPaint);
    canvas.drawCircle(Offset(cx, cy), 1.0, Paint()..color = Colors.white.withValues(alpha: 0.55));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
