import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/utils/timemark_formatter.dart';
import '../../../data/models/template_model.dart';
import '../../../data/models/watermark_config.dart';
import '../../../data/services/location_service.dart';
import '../../../data/services/storage_service.dart';
import 'watermark_edit_modal.dart';

/// Interactive live watermark: tap to edit, drag to move, pinch to resize.
/// Position is normalized 0..1 (fraction of parent width/height from top-left).
/// Scale multiplier is applied to rendered content.
class InteractiveWatermark extends StatefulWidget {
  final double? lat;
  final double? lng;
  final String fullAddress;
  final String kodeVerifikasi;
  final TemplateModel template;
  final WatermarkConfig config;
  final String activeLocationTag;
  final Color activeLocationColor;
  final ValueChanged<WatermarkConfig> onConfigChanged;

  const InteractiveWatermark({
    super.key,
    this.lat,
    this.lng,
    required this.fullAddress,
    required this.kodeVerifikasi,
    required this.template,
    required this.config,
    required this.onConfigChanged,
    this.activeLocationTag = 'Absensi',
    this.activeLocationColor = const Color(0xFFF59E0B),
  });

  @override
  State<InteractiveWatermark> createState() => _InteractiveWatermarkState();
}

class _InteractiveWatermarkState extends State<InteractiveWatermark> {
  Timer? _ticker;
  late DateTime _now;

  // Local mutable state (mirrors config.positionX/Y/scale while user interacts,
  // flushed back to config via onConfigChanged on gesture end).
  // Default is bottom-left (0.0, 1.0) with safe margins.
  double _positionX = 0.0;
  double _positionY = 1.0;
  double _scale = 1.0;
  double _baseScale = 1.0;

  final GlobalKey _contentKey = GlobalKey();
  Size _contentSize = Size.zero;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _positionX = widget.config.positionX;
    _positionY = widget.config.positionY;
    _scale = widget.config.scale;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void didUpdateWidget(covariant InteractiveWatermark oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config != widget.config) {
      _positionX = widget.config.positionX;
      _positionY = widget.config.positionY;
      _scale = widget.config.scale;
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _flushConfig() {
    widget.onConfigChanged(
      widget.config.copyWith(
        positionX: _positionX,
        positionY: _positionY,
        scale: _scale,
      ),
    );
  }

  void _updateContentSize() {
    if (!mounted) return;
    final renderBox = _contentKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null && renderBox.hasSize) {
      final newSize = renderBox.size;
      if ((_contentSize.width - newSize.width).abs() > 1.5 ||
          (_contentSize.height - newSize.height).abs() > 1.5) {
        setState(() {
          _contentSize = newSize;
        });
      }
    }
  }

  Future<void> _openEditModal() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => WatermarkEditModal(
        initialConfig: widget.config,
        onConfigChanged: widget.onConfigChanged,
        livePreview: _buildContent(scale: 1.0, contentKey: null),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateContentSize());

    return LayoutBuilder(
      builder: (context, constraints) {
        final parentW = constraints.maxWidth;
        final parentH = constraints.maxHeight;

        final unscaledW = _contentSize.width > 0 ? _contentSize.width : 290.0;
        final unscaledH = _contentSize.height > 0
            ? _contentSize.height
            : (widget.config.isShiftTracker ? 170.0 : 145.0);
        final cardW = unscaledW * _scale;
        final cardH = unscaledH * _scale;

        final safeMarginX = parentW * 0.04;
        final safeMarginY = parentH * 0.04;

        final availW = (parentW - cardW - 2 * safeMarginX).clamp(0.0, parentW);
        final availH = (parentH - cardH - 2 * safeMarginY).clamp(0.0, parentH);

        final left = safeMarginX + _positionX.clamp(0.0, 1.0) * availW;
        final top = safeMarginY + _positionY.clamp(0.0, 1.0) * availH;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: left,
              top: top,
              child: GestureDetector(
                onTap: _openEditModal,
                onScaleStart: (_) {
                  _baseScale = _scale;
                },
                onScaleUpdate: (details) {
                  if (details.pointerCount >= 2) {
                    // 2+ fingers: pinch-to-resize with smooth gentle damping
                    final scaleFactor = 1.0 + (details.scale - 1.0) * 0.35;
                    final targetScale = (_baseScale * scaleFactor).clamp(
                      0.5,
                      2.5,
                    );
                    setState(() {
                      _scale = targetScale;
                    });
                  } else {
                    // 1 finger: drag-to-move smoothly within bounds
                    if (availW > 0 || availH > 0) {
                      setState(() {
                        if (availW > 0) {
                          _positionX =
                              (_positionX + details.focalPointDelta.dx / availW)
                                  .clamp(0.0, 1.0);
                        }
                        if (availH > 0) {
                          _positionY =
                              (_positionY + details.focalPointDelta.dy / availH)
                                  .clamp(0.0, 1.0);
                        }
                      });
                    }
                  }
                },
                onScaleEnd: (_) => _flushConfig(),
                child: _buildContent(scale: _scale, contentKey: _contentKey),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildContent({required double scale, Key? contentKey}) {
    final isAbsensi = widget.template.jenis == TemplateCategory.absensi;
    final String badgeTag;
    final Color badgeColor;
    if (isAbsensi) {
      badgeTag = widget.config.badgeTag.isNotEmpty
          ? widget.config.badgeTag
          : widget.activeLocationTag;
      badgeColor = widget.config.badgeColor != const Color(0xFFF59E0B)
          ? widget.config.badgeColor
          : widget.activeLocationColor;
    } else {
      // Mode maintenance: tag WAJIB mengikuti lokasi maintenance yang dipilih (misal 'PBM', 'TBM', 'MEGAMAS')
      // jangan biarkan kata 'Absensi' terbawa ke kartu maintenance
      if (widget.activeLocationTag.isNotEmpty && widget.activeLocationTag.toLowerCase() != 'absensi') {
        badgeTag = widget.activeLocationTag;
        badgeColor = widget.activeLocationColor;
      } else if (widget.config.badgeTag.isNotEmpty && widget.config.badgeTag.toLowerCase() != 'absensi') {
        badgeTag = widget.config.badgeTag;
        badgeColor = widget.config.badgeColor;
      } else {
        badgeTag = widget.activeLocationTag.isNotEmpty ? widget.activeLocationTag : 'BSS';
        badgeColor = widget.activeLocationColor;
      }
    }
    final elements = widget.config.elements;

    if (widget.config.isShiftTracker) {
      return Transform.scale(
        scale: scale,
        alignment: Alignment.topLeft,
        child: KeyedSubtree(
          key: contentKey,
          child: _buildShiftTrackerWidget(badgeColor),
        ),
      );
    }

    return Transform.scale(
      scale: scale,
      alignment: Alignment.topLeft,
      child: KeyedSubtree(
        key: contentKey,
        child: Container(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(10)),
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Top Card Pill: 3-Section Integrated Banner (Badge Kuning + Jam Putih + Logo Navy) ---
            if (elements.showBadgeTag ||
                elements.showDateTime ||
                elements.showLogo ||
                elements.showTitle)
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: IntrinsicHeight(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (elements.showBadgeTag)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              color: badgeColor,
                              alignment: Alignment.center,
                              child: Text(
                                badgeTag,
                                style: const TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13.5,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          if (elements.showDateTime)
                            Container(
                              color: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                TimemarkFormatter.formatClockTime(_now),
                                style: const TextStyle(
                                  color: Color(0xFF0F2C59),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 26,
                                  letterSpacing: -0.5,
                                  fontFamily: 'monospace',
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                            ),
                          if (elements.showLogo)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              color: const Color(0xFF1E448D),
                              alignment: Alignment.center,
                              child: _buildLogoWidget(badgeColor),
                            ),
                          if (elements.showTitle)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              color: const Color(0xFFF1F5F9),
                              alignment: Alignment.center,
                              child: Text(
                                widget.config.customTitle?.isNotEmpty == true
                                    ? widget.config.customTitle!
                                    : widget.template.nama,
                                style: const TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 10.5,
                                  letterSpacing: 0.3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            if ((elements.showDateTime ||
                    elements.showLogo ||
                    elements.showBadgeTag ||
                    elements.showTitle) &&
                (elements.showAddress ||
                    elements.showCoordinates ||
                    elements.showDateTime))
              const SizedBox(height: 8),

            // --- Lower Metadata Block ---
            if (elements.showDateTime ||
                elements.showAddress ||
                elements.showCoordinates ||
                elements.showNote ||
                elements.showMap)
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 3.5,
                      decoration: BoxDecoration(
                        color: badgeColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                      children: [
                        if (elements.showDateTime)
                          Text(
                            TimemarkFormatter.formatIndonesianFullDate(_now),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              shadows: [
                                Shadow(
                                  color: Colors.black87,
                                  blurRadius: 4,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                        if (elements.showDateTime && elements.showAddress)
                          const SizedBox(height: 2),
                        if (elements.showAddress &&
                            widget.config.showLocationOnCamera)
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 280),
                            child: Text(
                              LocationService.cleanAddressString(widget.fullAddress),
                              maxLines: 3,
                              softWrap: true,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13.0,
                                fontWeight: FontWeight.w700,
                                height: 1.2,
                                shadows: [
                                  Shadow(
                                    color: Colors.black87,
                                    blurRadius: 4,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if ((elements.showAddress ||
                                elements.showCoordinates) &&
                            widget.config.showLocationOnCamera)
                          const SizedBox(height: 2),
                        if (elements.showCoordinates &&
                            widget.config.showLocationOnCamera)
                          Text(
                            TimemarkFormatter.formatGpsDegree(
                              widget.lat,
                              widget.lng,
                            ),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w600,
                              shadows: [
                                Shadow(
                                  color: Colors.black87,
                                  blurRadius: 4,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                        if (elements.showNote &&
                            widget.config.customNote?.isNotEmpty == true) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: badgeColor.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              widget.config.customNote!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                        if (elements.showMap) ...[
                          const SizedBox(height: 4),
                          _buildMiniMap(badgeColor),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildShiftTrackerWidget(Color badgeColor) {
    final lastCheckIn = StorageService.getLastCheckInTime();
    final checkIn = lastCheckIn ?? _now.subtract(const Duration(hours: 8, minutes: 19));
    final checkInStr = TimemarkFormatter.formatClockTime(checkIn);
    final nowStr = TimemarkFormatter.formatClockTime(_now);
    final diff = _now.difference(checkIn);
    final workDurationStr = TimemarkFormatter.formatWorkDuration(diff);

    final isTimeOut = widget.config.badgeTag.toLowerCase().contains('out') ||
        widget.config.customTitle?.toLowerCase().contains('pulang') == true;

    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Top Informational Overlay
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  isTimeOut ? 'Time Out' : 'Time In',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 11.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                nowStr,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 26,
                  fontFamily: 'monospace',
                  shadows: [
                    Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(0, 1)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // 2. Metadata with Vertical Accent Line
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 3.5,
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        TimemarkFormatter.formatIndonesianFullDate(_now),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          shadows: [Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(0, 1))],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        LocationService.cleanAddressString(widget.fullAddress),
                        maxLines: 3,
                        softWrap: true,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13.0,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                          shadows: [Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(0, 1))],
                        ),
                      ),
                      const SizedBox(height: 3),
                      const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified_rounded, size: 12, color: Color(0xFF38BDF8)),
                          SizedBox(width: 4),
                          Text(
                            'Verified time by Timemark Camera',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // 3. Bottom Work Session Statistics Panel
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Left: On duty
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'On duty',
                      style: TextStyle(fontSize: 9.5, color: Colors.white70, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '$checkInStr - $nowStr',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 18),

                // Right: Work duration
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Work',
                      style: TextStyle(fontSize: 9.5, color: Colors.white70, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      workDurationStr,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),

                // Pill status: pulang / masuk
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isTimeOut ? 'pulang' : 'masuk',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoWidget(Color badgeColor) {
    if (widget.config.logoImagePath != null &&
        widget.config.logoImagePath!.isNotEmpty) {
      final file = File(widget.config.logoImagePath!);
      if (file.existsSync()) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 28, maxWidth: 96),
            child: Image.file(file, fit: BoxFit.contain),
          ),
        );
      }
    }

    // Default: Gunakan logo BSS Parking resmi PNG transparan teks putih di atas background card biru
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 36, maxWidth: 110),
      child: Image.asset(
        'foto/bssfotologo_transparent.png',
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: const [
            Text(
              'BSS',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 13,
                letterSpacing: 0.5,
              ),
            ),
            Text(
              'PARKING',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 7.5,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniMap(Color accent) {
    return Container(
      width: 96,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: accent, width: 1.2),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1E3A8A).withValues(alpha: 0.6),
            const Color(0xFF0F172A).withValues(alpha: 0.7),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _MiniMapGridPainter(accent)),
          ),
          const Center(
            child: Icon(Icons.location_on, color: Colors.white, size: 18),
          ),
        ],
      ),
    );
  }
}

class _MiniMapGridPainter extends CustomPainter {
  final Color color;
  _MiniMapGridPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..strokeWidth = 0.6;
    const step = 12.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _MiniMapGridPainter old) => old.color != color;
}
