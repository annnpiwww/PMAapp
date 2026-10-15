import 'package:flutter/material.dart';

class AppColors {
  // Brand Colors (PMAapp Signature: Putih, Biru, Orange, Cream)
  static const Color primary = Color(0xFF1A428A); // BSS Signature Royal Blue
  static const Color primaryLight = Color(0xFF2563EB); // Vibrant Operational Blue
  static const Color primaryDark = Color(0xFF0B192C); // Deep Midnight Navy
  
  // Tactical Safety Orange (Action, Watermark Accent, Shutter Ring, Hazard)
  static const Color accent = Color(0xFFFF6500); // Vibrant Safety Orange
  static const Color accentLight = Color(0xFFFFF4ED); // Warm Orange Tint
  static const Color accentDark = Color(0xFFD85200); // Deep Tactile Orange
  static const Color accentSecondary = Color(0xFF0284C7); // Sky Technical Blue

  // Warm Cream / Ivory Palette (Anti-AI-Slop warm paper feeling)
  static const Color cream = Color(0xFFFAF7F0); // Warm Cream Canvas
  static const Color creamSurface = Color(0xFFFFFDF9); // Crisp Warm White
  static const Color creamContainer = Color(0xFFF3EFE6); // Soft Cream Chip
  static const Color creamBorder = Color(0xFFE6DFD3); // Subtle Cream Divider

  // Status Colors (Extended Tonal)
  static const Color success = Color(0xFF059669); // Emerald Green
  static const Color successLight = Color(0xFFECFDF5);
  static const Color successBorder = Color(0xFFA7F3D0);

  static const Color danger = Color(0xFFDC2626); // Rose Red
  static const Color dangerLight = Color(0xFFFEF2F2);
  static const Color dangerBorder = Color(0xFFFECACA);

  static const Color warning = Color(0xFFFF8A00); // Orange-Amber Warning
  static const Color warningLight = Color(0xFFFFF7ED);
  static const Color warningBorder = Color(0xFFFFEDD5);

  static const Color info = Color(0xFF2563EB); // Blue Info
  static const Color infoLight = Color(0xFFEFF6FF);
  static const Color infoBorder = Color(0xFFBFDBFE);

  // Surface Containers & Neutrals
  static const Color background = Color(0xFFFAF8F5); // Warm Cream Slate
  static const Color surface = Colors.white;
  static const Color surfaceContainerLow = Color(0xFFF6F4EE); // Warm Cream Low
  static const Color surfaceContainer = Color(0xFFECE7DC);
  static const Color cardBorder = Color(0xFFE6E2D8); // Ultra-fine tactile border

  // Text Colors (High-Contrast Readability)
  static const Color textPrimary = Color(0xFF18181B); // Charcoal Neutral 900
  static const Color textSecondary = Color(0xFF52525B); // Zinc 600
  static const Color textMuted = Color(0xFF71717A); // Zinc 500 - WCAG 4.5:1 on white
  static const Color textLight = Colors.white;
  // Dark Theme Neutral (Standardized Deep Slate / Obsidian)
  static const Color darkBackground = Color(0xFF0B1120); // Deep Midnight Canvas
  static const Color darkSurface = Color(0xFF111827); // Dark Surface Card
  static const Color darkSurfaceContainer = Color(0xFF1E293B); // Dark Container / Inputs
  static const Color darkBorder = Color(0xFF1E293B); // Dark Sublte Border
  static const Color darkBorderMuted = Color(0xFF334155); // Dark Accent Border
  static const Color textDarkPrimary = Color(0xFFF8FAFC); // Slate 50
  static const Color textDarkSecondary = Color(0xFF94A3B8); // Slate 400
  static const Color textDarkMuted = Color(0xFF64748B); // Slate 500

  // Tactile Design Dimensions & Radii Scale
  static const double radiusSmall = 8.0;
  static const double radiusChip = 10.0;
  static const double radiusInput = 14.0;
  static const double radiusButton = 14.0;
  static const double radiusCard = 16.0;
  static const double radiusModal = 24.0;
  static const double radiusBottomSheet = 28.0;
  static const double minTouchTarget = 48.0;
}
