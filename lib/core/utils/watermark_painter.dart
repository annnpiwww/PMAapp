import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'timemark_formatter.dart';
import '../../data/models/template_model.dart';
import '../../data/models/watermark_config.dart';
import '../../data/services/location_service.dart';

/// Live Bottom Overlay Watermark (Card + Address + GPS)
/// Encapsulates its own 1-second clock tick to prevent whole-screen rebuilds
class LiveTimemarkWatermarkWidget extends StatefulWidget {
  final DateTime? initialTimestamp;
  final double? lat;
  final double? lng;
  final String fullAddress;
  final String kodeVerifikasi;
  final TemplateModel template;
  final WatermarkConfig config;
  final String activeLocationTag;
  final Color activeLocationColor;
  final bool isMockLocation;
  final bool isDefaultFallback;

  const LiveTimemarkWatermarkWidget({
    super.key,
    this.initialTimestamp,
    this.lat,
    this.lng,
    required this.fullAddress,
    required this.kodeVerifikasi,
    required this.template,
    this.config = const WatermarkConfig(),
    this.activeLocationTag = 'Absensi',
    this.activeLocationColor = const Color(0xFFF59E0B),
    this.isMockLocation = false,
    this.isDefaultFallback = false,
  });

  @override
  State<LiveTimemarkWatermarkWidget> createState() =>
      _LiveTimemarkWatermarkWidgetState();
}

class _LiveTimemarkWatermarkWidgetState
    extends State<LiveTimemarkWatermarkWidget> {
  late DateTime _now;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _now = widget.initialTimestamp ?? DateTime.now();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _now = DateTime.now());
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final badgeTag = widget.config.badgeTag.isNotEmpty
        ? widget.config.badgeTag
        : widget.activeLocationTag;
    final badgeColor = widget.config.badgeColor != const Color(0xFFF59E0B)
        ? widget.config.badgeColor
        : widget.activeLocationColor;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          constraints: BoxConstraints(maxWidth: constraints.maxWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- 0. Warning Badge jika Mock Location atau Default Fallback ---
              if (widget.isMockLocation || widget.isDefaultFallback) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626), // Merah solid mencolok
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        widget.isMockLocation
                            ? '[PERINGATAN: LOKASI PALSU / GPS MOCK TERDETEKSI]'
                            : '[GPS TIDAK AKTIF - DEFAULT POS]',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 11.5,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              // --- 1. Top Integrated Sleek Banner (3 Sections: Badge Kuning + Jam Putih + Logo Navy) ---
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
                          // Left Section: Solid Yellow/Amber Location Tag
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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

                          // Center Section: White Background with Digital Clock
                          Container(
                            color: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            alignment: Alignment.center,
                            child: Text(
                              TimemarkFormatter.formatClockTime(_now),
                              style: const TextStyle(
                                color: Color(0xFF0F2C59),
                                fontWeight: FontWeight.w900,
                                fontSize: 26,
                                letterSpacing: -0.5,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),

                          // Right Section: Solid Royal Blue / Navy Background with Logo BSS Parking
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            color: const Color(0xFF1E448D),
                            alignment: Alignment.center,
                            child: _buildLogoWidget(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // --- 2. Lower Metadata Info with Left Colored Accent Bar ---
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Vertical Accent Line
                    Container(
                      width: 3.5,
                      decoration: BoxDecoration(
                        color: badgeColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Address, Date & Coordinates Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Line 1: Indonesian Day & Full Date (Minggu, 23 Agustus 2026)
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
                          if (widget.config.showLocationOnCamera) ...[
                            const SizedBox(height: 2),

                            // Line 2: Full Reverse-Geocoded Address
                            Text(
                              LocationService.cleanAddressString(widget.fullAddress),
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
                              maxLines: 3,
                              softWrap: true,
                            ),
                            const SizedBox(height: 2),

                            // Line 3: Exact GPS Degree Coordinates
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
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLogoWidget() {
    if (!kIsWeb &&
        widget.config.logoImagePath != null &&
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

    // Default Logo BSS Parking dari asset resmi (PNG transparan teks putih di atas card biru)
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
}

/// Static Watermark Overlay Widget for Captured / History Photos
class WatermarkOverlayWidget extends StatelessWidget {
  final DateTime timestamp;
  final double? lat;
  final double? lng;
  final double? accuracy;
  final String kodeVerifikasi;
  final String templateName;
  final String posName;
  final String cabangName;
  final String petugasName;
  final String petugasNpp;
  final bool showLocation;
  final String? logoImagePath;
  final String badgeTag;
  final Color badgeColor;
  final bool isMockLocation;
  final bool isDefaultFallback;

  const WatermarkOverlayWidget({
    super.key,
    required this.timestamp,
    this.lat,
    this.lng,
    this.accuracy,
    required this.kodeVerifikasi,
    required this.templateName,
    required this.posName,
    required this.cabangName,
    required this.petugasName,
    required this.petugasNpp,
    this.showLocation = true,
    this.logoImagePath,
    this.badgeTag = 'BSS',
    this.badgeColor = const Color(0xFFF59E0B),
    this.isMockLocation = false,
    this.isDefaultFallback = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.8),
            Colors.black.withValues(alpha: 0.95),
          ],
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Warning Badge jika Mock Location atau Default Fallback
          if (isMockLocation || isDefaultFallback) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.white, width: 1.2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    isMockLocation
                        ? '[PERINGATAN: LOKASI PALSU / GPS MOCK TERDETEKSI]'
                        : '[GPS TIDAK AKTIF - DEFAULT POS]',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 10.5,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      badgeTag,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'TIMEMARK VERIFIED',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.white30, width: 0.5),
                ),
                child: Text(
                  kodeVerifikasi,
                  style: const TextStyle(
                    color: Color(0xFF38BDF8),
                    fontSize: 10,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            TimemarkFormatter.formatIndonesianFullDate(timestamp),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (showLocation) ...[
            const SizedBox(height: 2),
            Text(
              '$posName • $cabangName',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13.0,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (lat != null && lng != null) ...[
              const SizedBox(height: 2),
              Text(
                TimemarkFormatter.formatGpsDegree(lat, lng),
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 10,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ],
          const SizedBox(height: 4),
          Text(
            'Petugas: $petugasName ($petugasNpp) • SOP: $templateName',
            style: const TextStyle(color: Colors.white54, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
