import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_theme.dart';

const Curve _kEaseOut = Cubic(0.23, 1.0, 0.32, 1.0);
const Curve _kEaseInOut = Cubic(0.77, 0.0, 0.175, 1.0);
const Curve _kSpringOvershoot = Cubic(0.34, 1.56, 0.64, 1.0);

const Duration _kIntroDuration = Duration(milliseconds: 1200);
const double _kLogoSize = 112.0;
const double _kContentMaxWidth = 320.0;
const Color _kLightStatusColor = Color(0xFF475569);
const Color _kDarkSubtitleColor = Color(0xFFE2E8F0);
const Color _kDarkStatusColor = Color(0xFFCBD5E1);

double _segment(double tMs, double startMs, double durationMs, Curve curve) {
  final raw = ((tMs - startMs) / durationMs).clamp(0.0, 1.0);
  return curve.transform(raw);
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

/// Shared circular PMA emblem with asset fallback matching SplashScreen.
class _SplashLogo extends StatelessWidget {
  const _SplashLogo();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _kLogoSize,
      height: _kLogoSize,
      child: ClipOval(
        child: Image.asset(
          'foto/splash_logo.png',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => const ColoredBox(
            color: AppColors.primary,
            child: Center(
              child: Text(
                'PMA',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shared PMA + Project Maintenance Assembly wordmark block.
class _SplashWordmark extends StatelessWidget {
  const _SplashWordmark({
    required this.titleOpacity,
    required this.titleOffsetY,
    required this.subtitleOpacity,
    required this.subtitleOffsetY,
    required this.titleColor,
    required this.subtitleColor,
  });

  final double titleOpacity;
  final double titleOffsetY;
  final double subtitleOpacity;
  final double subtitleOffsetY;
  final Color titleColor;
  final Color subtitleColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Opacity(
          opacity: titleOpacity.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, titleOffsetY),
            child: Text(
              'PMA',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 34,
                fontWeight: FontWeight.w900,
                color: titleColor,
                letterSpacing: 3.0,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Opacity(
          opacity: subtitleOpacity.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, subtitleOffsetY),
            child: Text(
              'Project Maintenance Assembly',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: subtitleColor,
                letterSpacing: 0.4,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SplashLayoutShell extends StatelessWidget {
  const _SplashLayoutShell({
    required this.backgroundColor,
    required this.emblem,
    required this.wordmark,
    required this.status,
    required this.statusColor,
    required this.statusOpacity,
  });

  final Color backgroundColor;
  final Widget emblem;
  final Widget wordmark;
  final String status;
  final Color statusColor;
  final double statusOpacity;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: backgroundColor,
      child: DefaultTextStyle(
        style: const TextStyle(
          fontFamily: AppTheme.fontFamily,
          decoration: TextDecoration.none,
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _kContentMaxWidth),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    emblem,
                    const SizedBox(height: 24),
                    wordmark,
                    const SizedBox(height: 36),
                    Semantics(
                      label: 'PMA sedang dimuat',
                      liveRegion: true,
                      child: Opacity(
                        opacity: statusOpacity.clamp(0.0, 1.0),
                        child: Text(
                          status,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                            letterSpacing: 0.2,
                            decoration: TextDecoration.none,
                          ),
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
    );
  }
}

/// Concept A: Time-mark clock sweep ring + check stroke around the PMA logo.
class SplashConceptTickMark extends StatefulWidget {
  const SplashConceptTickMark({
    super.key,
    this.status = 'Menyiapkan aplikasi...',
  });

  final String status;

  @override
  State<SplashConceptTickMark> createState() => _SplashConceptTickMarkState();
}

class _SplashConceptTickMarkState extends State<SplashConceptTickMark>
    with SingleTickerProviderStateMixin {
  static const Duration _idleDuration = Duration(milliseconds: 1200);

  late final AnimationController _controller;
  bool _hasStarted = false;
  bool _isIdle = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _kIntroDuration,
    )..addStatusListener(_onStatusChanged);
  }

  void _onStatusChanged(AnimationStatus status) {
    if (status != AnimationStatus.completed || _isIdle) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isIdle) return;
      if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return;
      _isIdle = true;
      _controller.duration = _idleDuration;
      _controller.repeat();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disableAnimations = MediaQuery.of(context).disableAnimations;
    if (disableAnimations) {
      _hasStarted = true;
      _isIdle = false;
      _controller.stop();
      _controller.duration = _kIntroDuration;
      _controller.value = 1.0;
      return;
    }
    if (!_hasStarted) {
      _hasStarted = true;
      _controller.duration = _kIntroDuration;
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_onStatusChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final double tMs = _isIdle ? 1200.0 : _controller.value * 1200.0;
        final double logoP = _segment(tMs, 0, 320, _kEaseOut);
        final double logoOpacity = logoP;
        final double logoScale = _lerp(0.95, 1.0, logoP);
        final double ringSweepP = _segment(tMs, 160, 900, _kEaseInOut);
        final double checkP = _segment(tMs, 900, 220, _kEaseOut);
        final double titleP = _segment(tMs, 700, 220, _kEaseOut);
        final double subtitleP = _segment(tMs, 740, 220, _kEaseOut);
        final double statusP = _segment(tMs, 1000, 160, _kEaseOut);

        return _SplashLayoutShell(
          backgroundColor: AppColors.background,
          emblem: SizedBox(
            width: 136,
            height: 136,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Opacity(
                  opacity: logoOpacity.clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: logoScale,
                    child: child,
                  ),
                ),
                Positioned.fill(
                  child: CustomPaint(
                    painter: _TickMarkPainter(
                      isIdle: _isIdle,
                      ringSweepProgress: ringSweepP,
                      checkProgress: checkP,
                      idleTurnProgress: _isIdle ? _controller.value : 0.0,
                    ),
                  ),
                ),
              ],
            ),
          ),
          wordmark: _SplashWordmark(
            titleOpacity: titleP,
            titleOffsetY: _lerp(8.0, 0.0, titleP),
            subtitleOpacity: subtitleP,
            subtitleOffsetY: _lerp(8.0, 0.0, subtitleP),
            titleColor: AppColors.primary,
            subtitleColor: AppColors.primary,
          ),
          status: widget.status,
          statusColor: _kLightStatusColor,
          statusOpacity: statusP,
        );
      },
      child: const _SplashLogo(),
    );
  }
}

class _TickMarkPainter extends CustomPainter {
  const _TickMarkPainter({
    required this.isIdle,
    required this.ringSweepProgress,
    required this.checkProgress,
    required this.idleTurnProgress,
  });

  final bool isIdle;
  final double ringSweepProgress;
  final double checkProgress;
  final double idleTurnProgress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    const double ringRadius = 61.0;
    final rect = Rect.fromCircle(center: center, radius: ringRadius);

    final ringPaint = Paint()
      ..color = AppColors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    if (isIdle) {
      final startAngle = -math.pi / 2 + idleTurnProgress * 2 * math.pi;
      const sweepAngle = math.pi / 3;
      canvas.drawArc(rect, startAngle, sweepAngle, false, ringPaint);
    } else if (ringSweepProgress > 0) {
      final sweepAngle = ringSweepProgress * 2 * math.pi;
      canvas.drawArc(rect, -math.pi / 2, sweepAngle, false, ringPaint);
    }

    if (checkProgress > 0) {
      final badgeCenter = Offset(
        center.dx + ringRadius * math.cos(math.pi / 4),
        center.dy + ringRadius * math.sin(math.pi / 4),
      );
      final haloPaint = Paint()
        ..color = AppColors.background
        ..style = PaintingStyle.fill;
      canvas.drawCircle(badgeCenter, 13.0, haloPaint);

      final checkPath = Path()
        ..moveTo(badgeCenter.dx - 6.0, badgeCenter.dy + 0.5)
        ..lineTo(badgeCenter.dx - 1.5, badgeCenter.dy + 5.0)
        ..lineTo(badgeCenter.dx + 6.5, badgeCenter.dy - 4.5);

      final extracted = Path();
      for (final PathMetric metric in checkPath.computeMetrics()) {
        extracted.addPath(
          metric.extractPath(0, metric.length * checkProgress),
          Offset.zero,
        );
      }

      final checkPaint = Paint()
        ..color = AppColors.accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(extracted, checkPaint);
    }
  }

  @override
  bool shouldRepaint(_TickMarkPainter oldDelegate) {
    return oldDelegate.isIdle != isIdle ||
        oldDelegate.ringSweepProgress != ringSweepProgress ||
        oldDelegate.checkProgress != checkProgress ||
        oldDelegate.idleTurnProgress != idleTurnProgress;
  }
}

/// Concept B: 6-blade camera aperture opening to reveal the PMA logo.
class SplashConceptShutter extends StatefulWidget {
  const SplashConceptShutter({
    super.key,
    this.status = 'Menyiapkan aplikasi...',
  });

  final String status;

  @override
  State<SplashConceptShutter> createState() => _SplashConceptShutterState();
}

class _SplashConceptShutterState extends State<SplashConceptShutter>
    with SingleTickerProviderStateMixin {
  static const Duration _idleDuration = Duration(milliseconds: 1600);

  late final AnimationController _controller;
  bool _hasStarted = false;
  bool _isIdle = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _kIntroDuration,
    )..addStatusListener(_onStatusChanged);
  }

  void _onStatusChanged(AnimationStatus status) {
    if (status != AnimationStatus.completed || _isIdle) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isIdle) return;
      if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return;
      _isIdle = true;
      _controller.duration = _idleDuration;
      _controller.value = 0.0;
      _controller.repeat(reverse: true);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disableAnimations = MediaQuery.of(context).disableAnimations;
    if (disableAnimations) {
      _hasStarted = true;
      _isIdle = false;
      _controller.stop();
      _controller.duration = _kIntroDuration;
      _controller.value = 1.0;
      return;
    }
    if (!_hasStarted) {
      _hasStarted = true;
      _controller.duration = _kIntroDuration;
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_onStatusChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final double tMs = _isIdle ? 1200.0 : _controller.value * 1200.0;
        final double apertureOpenP = _segment(tMs, 120, 520, _kEaseInOut);
        final double logoScaleP = _segment(tMs, 400, 320, _kEaseOut);
        final double logoScale = _lerp(0.95, 1.0, logoScaleP);
        final double titleP = _segment(tMs, 700, 220, _kEaseOut);
        final double subtitleP = _segment(tMs, 740, 220, _kEaseOut);
        final double statusP = _segment(tMs, 1000, 160, _kEaseOut);

        final double focusRingOpacity = _isIdle
            ? _lerp(0.35, 0.9, _kEaseInOut.transform(_controller.value))
            : _lerp(0.0, 0.35, _segment(tMs, 800, 320, _kEaseOut));

        return _SplashLayoutShell(
          backgroundColor: AppColors.primaryDark,
          emblem: SizedBox(
            width: 136,
            height: 136,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: _kLogoSize,
                  height: _kLogoSize,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.background,
                  ),
                ),
                Opacity(
                  opacity: 1.0,
                  child: Transform.scale(
                    scale: logoScale,
                    child: child,
                  ),
                ),
                Positioned.fill(
                  child: CustomPaint(
                    painter: _ShutterAperturePainter(
                      openProgress: apertureOpenP,
                      focusRingOpacity: focusRingOpacity,
                    ),
                  ),
                ),
              ],
            ),
          ),
          wordmark: _SplashWordmark(
            titleOpacity: titleP,
            titleOffsetY: _lerp(8.0, 0.0, titleP),
            subtitleOpacity: subtitleP,
            subtitleOffsetY: _lerp(8.0, 0.0, subtitleP),
            titleColor: Colors.white,
            subtitleColor: _kDarkSubtitleColor,
          ),
          status: widget.status,
          statusColor: _kDarkStatusColor,
          statusOpacity: statusP,
        );
      },
      child: const _SplashLogo(),
    );
  }
}

class _ShutterAperturePainter extends CustomPainter {
  const _ShutterAperturePainter({
    required this.openProgress,
    required this.focusRingOpacity,
  });

  final double openProgress;
  final double focusRingOpacity;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    const double housingRadius = 58.0;

    if (openProgress < 0.999) {
      canvas.save();
      canvas.clipPath(
        Path()..addOval(Rect.fromCircle(center: center, radius: housingRadius)),
      );

      final bladeFill = Paint()
        ..color = AppColors.primary
        ..style = PaintingStyle.fill;
      final bladeEdge = Paint()
        ..color = const Color(0x33FFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;

      final double radialOffset = _lerp(-1.5, housingRadius + 4.0, openProgress);
      final double twistAngle = openProgress * (math.pi / 5);

      for (int i = 0; i < 6; i++) {
        canvas.save();
        canvas.translate(center.dx, center.dy);
        canvas.rotate(i * (math.pi / 3) + twistAngle);

        final blade = Path()
          ..moveTo(-housingRadius * 0.25, radialOffset)
          ..lineTo(housingRadius * 1.45, radialOffset)
          ..lineTo(housingRadius * 1.65, radialOffset + housingRadius * 1.8)
          ..lineTo(-housingRadius * 0.55, radialOffset + housingRadius * 1.8)
          ..close();

        canvas.drawPath(blade, bladeFill);
        canvas.drawPath(blade, bladeEdge);
        canvas.restore();
      }
      canvas.restore();
    }

    if (focusRingOpacity > 0) {
      final focusPaint = Paint()
        ..color = AppColors.accent.withValues(alpha: focusRingOpacity.clamp(0.0, 1.0))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawCircle(center, 63.0, focusPaint);
    }
  }

  @override
  bool shouldRepaint(_ShutterAperturePainter oldDelegate) {
    return oldDelegate.openProgress != openProgress ||
        oldDelegate.focusRingOpacity != focusRingOpacity;
  }
}

/// Concept C: Four operational tiles arc into a 2x2 cluster and assemble into the logo.
class SplashConceptAssembly extends StatefulWidget {
  const SplashConceptAssembly({
    super.key,
    this.status = 'Menyiapkan aplikasi...',
  });

  final String status;

  @override
  State<SplashConceptAssembly> createState() => _SplashConceptAssemblyState();
}

class _TileSpec {
  const _TileSpec({
    required this.icon,
    required this.color,
    required this.startOffset,
    required this.targetOffset,
    required this.startMs,
  });

  final IconData icon;
  final Color color;
  final Offset startOffset;
  final Offset targetOffset;
  final double startMs;
}

class _SplashConceptAssemblyState extends State<SplashConceptAssembly>
    with SingleTickerProviderStateMixin {
  static const Duration _idleDuration = Duration(milliseconds: 1800);

  static const List<_TileSpec> _tiles = [
    _TileSpec(
      icon: Icons.build,
      color: AppColors.primary,
      startOffset: Offset(-140, -140),
      targetOffset: Offset(-26, -26),
      startMs: 0,
    ),
    _TileSpec(
      icon: Icons.checklist,
      color: AppColors.accent,
      startOffset: Offset(140, -140),
      targetOffset: Offset(26, -26),
      startMs: 40,
    ),
    _TileSpec(
      icon: Icons.photo_camera,
      color: AppColors.primaryDark,
      startOffset: Offset(-140, 140),
      targetOffset: Offset(-26, 26),
      startMs: 80,
    ),
    _TileSpec(
      icon: Icons.place,
      color: AppColors.primaryLight,
      startOffset: Offset(140, 140),
      targetOffset: Offset(26, 26),
      startMs: 120,
    ),
  ];

  late final AnimationController _controller;
  bool _hasStarted = false;
  bool _isIdle = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _kIntroDuration,
    )..addStatusListener(_onStatusChanged);
  }

  void _onStatusChanged(AnimationStatus status) {
    if (status != AnimationStatus.completed || _isIdle) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isIdle) return;
      if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return;
      _isIdle = true;
      _controller.duration = _idleDuration;
      _controller.value = 0.0;
      _controller.repeat(reverse: true);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disableAnimations = MediaQuery.of(context).disableAnimations;
    if (disableAnimations) {
      _hasStarted = true;
      _isIdle = false;
      _controller.stop();
      _controller.duration = _kIntroDuration;
      _controller.value = 1.0;
      return;
    }
    if (!_hasStarted) {
      _hasStarted = true;
      _controller.duration = _kIntroDuration;
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_onStatusChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final double tMs = _isIdle ? 1200.0 : _controller.value * 1200.0;
        final double clusterExitP = _segment(tMs, 600, 220, _kEaseOut);
        final double clusterScale = _lerp(1.0, 0.95, clusterExitP);
        final double clusterOpacity = _lerp(1.0, 0.0, clusterExitP);

        final double logoPopP = _segment(tMs, 600, 220, _kEaseOut);
        final double logoScale = _isIdle
            ? _lerp(1.0, 1.02, _kEaseInOut.transform(_controller.value))
            : _lerp(0.95, 1.0, logoPopP);
        final double logoOpacity = _isIdle ? 1.0 : logoPopP;

        final double titleP = _segment(tMs, 760, 220, _kEaseOut);
        final double subtitleP = _segment(tMs, 800, 220, _kEaseOut);
        final double statusP = _segment(tMs, 960, 160, _kEaseOut);

        return _SplashLayoutShell(
          backgroundColor: AppColors.background,
          emblem: SizedBox(
            width: 136,
            height: 136,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (clusterOpacity > 0.001)
                  Opacity(
                    opacity: clusterOpacity.clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale: clusterScale,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          for (final tile in _tiles) _buildTile(tile, tMs),
                        ],
                      ),
                    ),
                  ),
                Opacity(
                  opacity: logoOpacity.clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: logoScale,
                    child: child,
                  ),
                ),
              ],
            ),
          ),
          wordmark: _SplashWordmark(
            titleOpacity: titleP,
            titleOffsetY: _lerp(8.0, 0.0, titleP),
            subtitleOpacity: subtitleP,
            subtitleOffsetY: _lerp(8.0, 0.0, subtitleP),
            titleColor: AppColors.primary,
            subtitleColor: AppColors.primary,
          ),
          status: widget.status,
          statusColor: _kLightStatusColor,
          statusOpacity: statusP,
        );
      },
      child: const _SplashLogo(),
    );
  }

  Widget _buildTile(_TileSpec tile, double tMs) {
    final double xP = _segment(tMs, tile.startMs, 320, _kEaseOut);
    final double yP = _segment(tMs, tile.startMs, 320, _kEaseInOut);
    final double scaleP = _segment(tMs, tile.startMs, 320, _kSpringOvershoot);
    final double opacityP = _segment(tMs, tile.startMs, 160, _kEaseOut);

    final double dx = _lerp(tile.startOffset.dx, tile.targetOffset.dx, xP);
    final double dy = _lerp(tile.startOffset.dy, tile.targetOffset.dy, yP);
    final double scale = _lerp(0.9, 1.0, scaleP);

    return Opacity(
      opacity: opacityP.clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(dx, dy),
        child: Transform.scale(
          scale: scale,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: tile.color,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(
              tile.icon,
              size: 22,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
