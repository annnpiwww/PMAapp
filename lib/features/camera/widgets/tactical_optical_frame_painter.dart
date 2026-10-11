import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// Optical Viewfinder Frame Painter (Pro Optical Corner Brackets & Crosshair)
class TacticalOpticalFramePainter extends CustomPainter {
  const TacticalOpticalFramePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final bracketPaint = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.65)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // Outer subtle border
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), borderPaint);

    const cornerLen = 18.0;
    const padding = 10.0;

    // Top-Left
    canvas.drawLine(
      const Offset(padding, padding),
      const Offset(padding + cornerLen, padding),
      bracketPaint,
    );
    canvas.drawLine(
      const Offset(padding, padding),
      const Offset(padding, padding + cornerLen),
      bracketPaint,
    );

    // Top-Right
    canvas.drawLine(
      Offset(size.width - padding, padding),
      Offset(size.width - padding - cornerLen, padding),
      bracketPaint,
    );
    canvas.drawLine(
      Offset(size.width - padding, padding),
      Offset(size.width - padding, padding + cornerLen),
      bracketPaint,
    );

    // Bottom-Left
    canvas.drawLine(
      Offset(padding, size.height - padding),
      Offset(padding + cornerLen, size.height - padding),
      bracketPaint,
    );
    canvas.drawLine(
      Offset(padding, size.height - padding),
      Offset(padding, size.height - padding - cornerLen),
      bracketPaint,
    );

    // Bottom-Right
    canvas.drawLine(
      Offset(size.width - padding, size.height - padding),
      Offset(size.width - padding - cornerLen, size.height - padding),
      bracketPaint,
    );
    canvas.drawLine(
      Offset(size.width - padding, size.height - padding),
      Offset(size.width - padding, size.height - padding - cornerLen),
      bracketPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
