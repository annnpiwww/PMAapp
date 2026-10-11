import 'package:flutter/material.dart';

/// Aspect ratio presets for camera viewfinder.
enum CameraAspectRatio {
  ratio1x1,
  ratio3x4,
  ratio9x16,
  ratioFull;

  /// Returns width / height ratio in portrait orientation.
  /// Null indicates full screen (matches container dimensions).
  double? get value {
    switch (this) {
      case CameraAspectRatio.ratio1x1:
        return 1.0;
      case CameraAspectRatio.ratio3x4:
        return 3 / 4; // 0.75
      case CameraAspectRatio.ratio9x16:
        return 9 / 16; // 0.5625
      case CameraAspectRatio.ratioFull:
        return null;
    }
  }

  String get label {
    switch (this) {
      case CameraAspectRatio.ratio1x1:
        return '1:1';
      case CameraAspectRatio.ratio3x4:
        return '3:4';
      case CameraAspectRatio.ratio9x16:
        return '9:16';
      case CameraAspectRatio.ratioFull:
        return 'Full';
    }
  }

  String get description {
    switch (this) {
      case CameraAspectRatio.ratio1x1:
        return 'Persegi Kotak (1:1)';
      case CameraAspectRatio.ratio3x4:
        return 'Standar Dokumentasi (3:4)';
      case CameraAspectRatio.ratio9x16:
        return 'Layar Penuh Story (9:16)';
      case CameraAspectRatio.ratioFull:
        return 'Penuh Bebas Frame (Default)';
    }
  }

  IconData get icon {
    switch (this) {
      case CameraAspectRatio.ratio1x1:
        return Icons.crop_square_rounded;
      case CameraAspectRatio.ratio3x4:
        return Icons.crop_portrait_rounded;
      case CameraAspectRatio.ratio9x16:
        return Icons.stay_current_portrait_rounded;
      case CameraAspectRatio.ratioFull:
        return Icons.fullscreen_rounded;
    }
  }
}
