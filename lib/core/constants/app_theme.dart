import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'tiket_colors.dart';

class AppTheme {
  static const String fontFamily = 'PlusJakartaSans';

  static ThemeData get lightTheme {
    final baseTextTheme = ThemeData.light().textTheme.apply(
          fontFamily: fontFamily,
        );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: TiketColors.light.primary,
      scaffoldBackgroundColor: TiketColors.light.canvas,
      extensions: const [TiketColors.light],
      colorScheme: ColorScheme.light(
        primary: TiketColors.light.primary,
        onPrimary: TiketColors.light.onPrimary,
        secondary: AppColors.accent,
        onSecondary: Colors.white,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        error: TiketColors.light.danger,
        onError: Colors.white,
      ),
      textTheme: baseTextTheme.copyWith(
        displayLarge: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 26,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.6,
          color: AppColors.textPrimary,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
        headlineMedium: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
          color: AppColors.textPrimary,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
        titleLarge: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
          color: AppColors.textPrimary,
        ),
        bodyLarge: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
        bodyMedium: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: AppColors.textSecondary,
        ),
        labelSmall: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: AppColors.textMuted,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.cardBorder, width: 1.2),
        ),
        margin: EdgeInsets.zero,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: TiketColors.light.dialog,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: TiketColors.light.dialog,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: TiketColors.light.hairline,
        thickness: 1,
        space: 1,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: TiketColors.light.primary,
          foregroundColor: TiketColors.light.onPrimary,
          elevation: 0,
          minimumSize: const Size(double.infinity, 48),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: TiketColors.light.primary,
          foregroundColor: TiketColors.light.onPrimary,
          elevation: 0,
          minimumSize: const Size(double.infinity, 48),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: TiketColors.light.primary,
          side: BorderSide(color: TiketColors.light.primary, width: 1.5),
          minimumSize: const Size(double.infinity, 48),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: TiketColors.light.soft,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: TiketColors.light.primary, width: 2.0),
        ),
        hintStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 13,
          color: AppColors.textMuted,
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    final baseTextTheme = ThemeData.dark().textTheme.apply(
          fontFamily: fontFamily,
        );

    const darkSurface = AppColors.darkSurface;
    const darkBorder = AppColors.darkBorder;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: TiketColors.dark.primary,
      scaffoldBackgroundColor: TiketColors.dark.canvas,
      extensions: const [TiketColors.dark],
      colorScheme: ColorScheme.dark(
        primary: TiketColors.dark.primary,
        onPrimary: TiketColors.dark.onPrimary,
        secondary: AppColors.accent,
        onSecondary: Colors.white,
        surface: darkSurface,
        onSurface: Colors.white,
        error: TiketColors.dark.danger,
        onError: Colors.white,
      ),
      textTheme: baseTextTheme.copyWith(
        displayLarge: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 26,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.6,
          color: Colors.white,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
        headlineMedium: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
          color: Colors.white,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
        titleLarge: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
          color: Colors.white,
        ),
        bodyLarge: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
        bodyMedium: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: Color(0xFF94A3B8),
        ),
        labelSmall: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: Color(0xFF64748B),
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkSurface,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        color: darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: darkBorder, width: 1.2),
        ),
        margin: EdgeInsets.zero,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: TiketColors.dark.dialog,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: TiketColors.dark.dialog,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: TiketColors.dark.hairline,
        thickness: 1,
        space: 1,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: TiketColors.dark.primary,
          foregroundColor: TiketColors.dark.onPrimary,
          elevation: 0,
          minimumSize: const Size(double.infinity, 48),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: TiketColors.dark.primary,
          foregroundColor: TiketColors.dark.onPrimary,
          elevation: 0,
          minimumSize: const Size(double.infinity, 48),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: TiketColors.dark.primary,
          side: BorderSide(color: TiketColors.dark.primary, width: 1.5),
          minimumSize: const Size(double.infinity, 48),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: TiketColors.dark.soft,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: darkBorder),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: AppColors.accent, width: 2.0),
        ),
        hintStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 13,
          color: Color(0xFF64748B),
        ),
      ),
    );
  }
}
