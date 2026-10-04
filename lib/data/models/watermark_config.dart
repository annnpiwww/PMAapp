import 'package:flutter/material.dart';

/// Per-element visibility toggles for the watermark.
/// Mirrors the toggle list in the "Edit Watermark" modal.
class WatermarkElementToggles {
  final bool showLogo;
  final bool showTitle;
  final bool showNote;
  final bool showBadgeTag;
  final bool showDateTime;
  final bool showAddress;
  final bool showCoordinates;
  final bool showMap;

  const WatermarkElementToggles({
    this.showLogo = true,
    this.showTitle = false,
    this.showNote = false,
    this.showBadgeTag = true,
    this.showDateTime = true,
    this.showAddress = true,
    this.showCoordinates = true,
    this.showMap = false,
  });

  WatermarkElementToggles copyWith({
    bool? showLogo,
    bool? showTitle,
    bool? showNote,
    bool? showBadgeTag,
    bool? showDateTime,
    bool? showAddress,
    bool? showCoordinates,
    bool? showMap,
  }) {
    return WatermarkElementToggles(
      showLogo: showLogo ?? this.showLogo,
      showTitle: showTitle ?? this.showTitle,
      showNote: showNote ?? this.showNote,
      showBadgeTag: showBadgeTag ?? this.showBadgeTag,
      showDateTime: showDateTime ?? this.showDateTime,
      showAddress: showAddress ?? this.showAddress,
      showCoordinates: showCoordinates ?? this.showCoordinates,
      showMap: showMap ?? this.showMap,
    );
  }

  Map<String, dynamic> toJson() => {
        'showLogo': showLogo,
        'showTitle': showTitle,
        'showNote': showNote,
        'showBadgeTag': showBadgeTag,
        'showDateTime': showDateTime,
        'showAddress': showAddress,
        'showCoordinates': showCoordinates,
        'showMap': showMap,
      };

  factory WatermarkElementToggles.fromJson(Map<String, dynamic> json) =>
      WatermarkElementToggles(
        showLogo: json['showLogo'] as bool? ?? true,
        showTitle: json['showTitle'] as bool? ?? false,
        showNote: json['showNote'] as bool? ?? false,
        showBadgeTag: json['showBadgeTag'] as bool? ?? true,
        showDateTime: json['showDateTime'] as bool? ?? true,
        showAddress: json['showAddress'] as bool? ?? true,
        showCoordinates: json['showCoordinates'] as bool? ?? true,
        showMap: json['showMap'] as bool? ?? false,
      );
}

class WatermarkConfig {
  final String? logoImagePath;
  final String badgeTag;
  final Color badgeColor;
  final String timeZone;
  final bool showLocationOnCamera;
  final bool showLocationOnResult;

  // Custom text overrides (null = use auto value)
  final String? customTitle;
  final String? customNote;

  // Per-element visibility toggles
  final WatermarkElementToggles elements;

  // Interactive placement (camera preview)
  // Position is normalized 0..1 (fraction of preview width/height from top-left)
  final double positionX;
  final double positionY;
  // Scale multiplier 0.5x .. 3.0x
  final double scale;

  // Mode Template Card Khusus: Work Shift Tracker (On Duty & Work Duration)
  final bool isShiftTracker;

  const WatermarkConfig({
    this.logoImagePath,
    this.badgeTag = 'Absensi',
    this.badgeColor = const Color(0xFFF59E0B),
    this.timeZone = 'WITA',
    this.showLocationOnCamera = true,
    this.showLocationOnResult = true,
    this.customTitle,
    this.customNote,
    this.elements = const WatermarkElementToggles(),
    this.positionX = 0.0,
    this.positionY = 1.0,
    this.scale = 1.0,
    this.isShiftTracker = false,
  });

  WatermarkConfig copyWith({
    String? logoImagePath,
    String? badgeTag,
    Color? badgeColor,
    String? timeZone,
    bool? showLocationOnCamera,
    bool? showLocationOnResult,
    String? customTitle,
    String? customNote,
    WatermarkElementToggles? elements,
    double? positionX,
    double? positionY,
    double? scale,
    bool? isShiftTracker,
  }) {
    return WatermarkConfig(
      logoImagePath: logoImagePath ?? this.logoImagePath,
      badgeTag: badgeTag ?? this.badgeTag,
      badgeColor: badgeColor ?? this.badgeColor,
      timeZone: timeZone ?? this.timeZone,
      showLocationOnCamera: showLocationOnCamera ?? this.showLocationOnCamera,
      showLocationOnResult: showLocationOnResult ?? this.showLocationOnResult,
      customTitle: customTitle ?? this.customTitle,
      customNote: customNote ?? this.customNote,
      elements: elements ?? this.elements,
      positionX: positionX ?? this.positionX,
      positionY: positionY ?? this.positionY,
      scale: scale ?? this.scale,
      isShiftTracker: isShiftTracker ?? this.isShiftTracker,
    );
  }

  Map<String, dynamic> toJson() => {
        'logoImagePath': logoImagePath,
        'badgeTag': badgeTag,
        'badgeColorValue': badgeColor.toARGB32(),
        'timeZone': timeZone,
        'showLocationOnCamera': showLocationOnCamera,
        'showLocationOnResult': showLocationOnResult,
        'customTitle': customTitle,
        'customNote': customNote,
        'elements': elements.toJson(),
        'positionX': positionX,
        'positionY': positionY,
        'scale': scale,
        'isShiftTracker': isShiftTracker,
      };

  factory WatermarkConfig.fromJson(Map<String, dynamic> json) =>
      WatermarkConfig(
        logoImagePath: json['logoImagePath'] as String?,
        badgeTag: json['badgeTag'] as String? ?? 'Absensi',
        badgeColor: Color(json['badgeColorValue'] as int? ?? 0xFFF59E0B),
        timeZone: json['timeZone'] as String? ?? 'WITA',
        showLocationOnCamera: json['showLocationOnCamera'] as bool? ?? true,
        showLocationOnResult: json['showLocationOnResult'] as bool? ?? true,
        customTitle: json['customTitle'] as String?,
        customNote: json['customNote'] as String?,
        elements: json['elements'] != null
            ? WatermarkElementToggles.fromJson(
                json['elements'] as Map<String, dynamic>)
            : const WatermarkElementToggles(),
        positionX: (json['positionX'] as num?)?.toDouble() ?? 0.0,
        positionY: (json['positionY'] as num?)?.toDouble() ?? 1.0,
        scale: (json['scale'] as num?)?.toDouble() ?? 1.0,
        isShiftTracker: json['isShiftTracker'] as bool? ?? false,
      );
}
