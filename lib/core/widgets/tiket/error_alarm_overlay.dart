import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:bssparking_timemark/data/models/daily_task_model.dart';

/// App-wide red alarm overlay shown while any error location ticket is open.
///
/// Features:
/// - Pushes app content down via Column so nothing is covered.
/// - Edge vignette red glow painted with CustomPainter.
/// - Pulsing animation when ringing is true.
/// - Respects MediaQuery.disableAnimations.
class ErrorAlarmOverlay extends StatefulWidget {
  final Widget child;
  final ValueListenable<List<DailyTaskModel>> openErrors;
  final ValueListenable<bool> ringing;
  final VoidCallback onLihat;

  const ErrorAlarmOverlay({
    super.key,
    required this.child,
    required this.openErrors,
    required this.ringing,
    required this.onLihat,
  });

  @override
  State<ErrorAlarmOverlay> createState() => _ErrorAlarmOverlayState();
}

class _ErrorAlarmOverlayState extends State<ErrorAlarmOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Color?> _colorAnimation;
  late final Animation<double> _alphaAnimation;

  static const Color _dangerRed = Color(0xFFC81E1E);
  static const Color _deepDangerRed = Color(0xFF9E1414);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    final CurvedAnimation curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    _colorAnimation = ColorTween(
      begin: _dangerRed,
      end: _deepDangerRed,
    ).animate(curved);

    _alphaAnimation = Tween<double>(
      begin: 0.30,
      end: 0.75,
    ).animate(curved);

    widget.openErrors.addListener(_onStateChanged);
    widget.ringing.addListener(_onStateChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant ErrorAlarmOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.openErrors != widget.openErrors) {
      oldWidget.openErrors.removeListener(_onStateChanged);
      widget.openErrors.addListener(_onStateChanged);
    }
    if (oldWidget.ringing != widget.ringing) {
      oldWidget.ringing.removeListener(_onStateChanged);
      widget.ringing.addListener(_onStateChanged);
    }
    _syncAnimation();
  }

  void _onStateChanged() {
    if (mounted) {
      _syncAnimation();
      setState(() {});
    }
  }

  void _syncAnimation() {
    final bool disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final bool hasErrors = widget.openErrors.value.isNotEmpty;
    final bool isRinging = widget.ringing.value;

    if (hasErrors && isRinging && !disableAnimations) {
      if (!_controller.isAnimating) {
        _controller.repeat(reverse: true);
      }
    } else {
      if (_controller.isAnimating) {
        _controller.stop();
      }
      _controller.value = 0.0;
    }
  }

  @override
  void dispose() {
    widget.openErrors.removeListener(_onStateChanged);
    widget.ringing.removeListener(_onStateChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<DailyTaskModel> errors = widget.openErrors.value;
    if (errors.isEmpty) {
      return widget.child;
    }

    final bool isRinging = widget.ringing.value;
    final bool disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        final Color bannerColor;
        final double vignetteAlpha;

        if (isRinging && !disableAnimations) {
          bannerColor = _colorAnimation.value ?? _dangerRed;
          vignetteAlpha = _alphaAnimation.value;
        } else if (isRinging && disableAnimations) {
          bannerColor = _dangerRed;
          vignetteAlpha = 0.30;
        } else {
          bannerColor = _dangerRed;
          vignetteAlpha = 0.22;
        }

        return Stack(
          children: <Widget>[
            Column(
              children: <Widget>[
                _buildBanner(
                  context: context,
                  errors: errors,
                  bannerColor: bannerColor,
                  isRinging: isRinging,
                ),
                Expanded(
                  child: MediaQuery.removePadding(
                    context: context,
                    removeTop: true,
                    child: widget.child,
                  ),
                ),
              ],
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _EdgeVignettePainter(
                    color: _dangerRed,
                    alpha: vignetteAlpha,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBanner({
    required BuildContext context,
    required List<DailyTaskModel> errors,
    required Color bannerColor,
    required bool isRinging,
  }) {
    final double topInset = MediaQuery.paddingOf(context).top;
    final DailyTaskModel newest = errors.first;
    final String posName = newest.posName;
    final String judul = newest.judul;

    return Semantics(
      container: true,
      liveRegion: true,
      label: 'Lokasi error: $posName, $judul',
      child: Material(
        color: bannerColor,
        child: InkWell(
          onTap: widget.onLihat,
          child: Padding(
            padding: EdgeInsets.only(top: topInset),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(
                      Icons.warning_amber_rounded,
                      size: 24,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Text(
                            'LOKASI ERROR',
                            style: TextStyle(
                              fontFamily: 'Figtree',
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              letterSpacing: 0.8,
                              color: Color(0xD9FFFFFF), // 85% alpha white
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: <Widget>[
                              Flexible(
                                flex: 3,
                                child: Text(
                                  '$posName · $judul',
                                  style: const TextStyle(
                                    fontFamily: 'Figtree',
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    color: Colors.white,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (errors.length > 1) ...<Widget>[
                                const SizedBox(width: 4),
                                Flexible(
                                  flex: 2,
                                  child: Text(
                                    '+${errors.length - 1} lokasi lain',
                                    style: const TextStyle(
                                      fontFamily: 'Figtree',
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: Color(0xD9FFFFFF), // 85% alpha white
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildPillButton(isRinging: isRinging),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPillButton({required bool isRinging}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onLihat,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        child: Center(
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (isRinging) ...<Widget>[
                  Semantics(
                    label: 'Alarm berbunyi',
                    child: const Icon(
                      Icons.volume_up_rounded,
                      size: 18,
                      color: _dangerRed,
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                const Text(
                  'Lihat',
                  style: TextStyle(
                    fontFamily: 'Figtree',
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: _dangerRed,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints a 28dp deep linear gradient glow along all 4 edges of the screen.
class _EdgeVignettePainter extends CustomPainter {
  final Color color;
  final double alpha;
  static const double depth = 28.0;

  const _EdgeVignettePainter({
    required this.color,
    required this.alpha,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (alpha <= 0.0 || size.isEmpty) return;

    final Color startColor = color.withValues(alpha: alpha);
    const Color endColor = Color(0x00000000);

    final Paint paint = Paint();

    // Top edge
    paint.shader = ui.Gradient.linear(
      Offset.zero,
      const Offset(0, depth),
      <Color>[startColor, endColor],
    );
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, depth), paint);

    // Bottom edge
    paint.shader = ui.Gradient.linear(
      Offset(0, size.height),
      Offset(0, size.height - depth),
      <Color>[startColor, endColor],
    );
    canvas.drawRect(
      Rect.fromLTWH(0, size.height - depth, size.width, depth),
      paint,
    );

    // Left edge
    paint.shader = ui.Gradient.linear(
      Offset.zero,
      const Offset(depth, 0),
      <Color>[startColor, endColor],
    );
    canvas.drawRect(Rect.fromLTWH(0, 0, depth, size.height), paint);

    // Right edge
    paint.shader = ui.Gradient.linear(
      Offset(size.width, 0),
      Offset(size.width - depth, 0),
      <Color>[startColor, endColor],
    );
    canvas.drawRect(
      Rect.fromLTWH(size.width - depth, 0, depth, size.height),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _EdgeVignettePainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.alpha != alpha;
  }
}
