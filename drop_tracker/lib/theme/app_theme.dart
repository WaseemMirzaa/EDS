import 'package:flutter/material.dart';

import 'brand.dart';

/// Typography — SF Pro (the iOS system face) for all UI text, per the premium
/// spec. On Apple platforms these resolve to San Francisco Display/Text; on
/// Android they fall back gracefully. The serif is reserved for the logo mark.
class AppTypography {
  AppTypography._();

  static const String _display = 'CupertinoSystemDisplay';
  static const String _text = 'CupertinoSystemText';
  static const List<String> _fallback = ['SF Pro Display', '.SF Pro Display', 'Roboto'];

  /// Large headings / titles.
  static TextStyle display(double size,
          {FontWeight weight = FontWeight.w700, Color? color, double? height, double? letterSpacing}) =>
      TextStyle(
        fontFamily: _display,
        fontFamilyFallback: _fallback,
        fontSize: size,
        fontWeight: weight,
        color: color ?? BrandColors.ink,
        height: height ?? 1.12,
        letterSpacing: letterSpacing ?? (size >= 28 ? -0.6 : -0.3),
      );

  /// Body / UI text.
  static TextStyle body(double size,
          {FontWeight weight = FontWeight.w500, Color? color, double? height, double? letterSpacing}) =>
      TextStyle(
        fontFamily: _text,
        fontFamilyFallback: _fallback,
        fontSize: size,
        fontWeight: weight,
        color: color ?? BrandColors.ink,
        height: height ?? 1.35,
        letterSpacing: letterSpacing ?? (size <= 13 ? 0.0 : -0.1),
      );
}

class AppTheme {
  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: Colors.transparent,
      colorScheme: const ColorScheme.light(
        primary: BrandColors.primary,
        onPrimary: BrandColors.white,
        secondary: BrandColors.secondary,
        onSecondary: BrandColors.white,
        surface: BrandColors.surface,
        onSurface: BrandColors.ink,
        error: BrandColors.danger,
      ),
    );

    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        displayLarge: AppTypography.display(34, weight: FontWeight.w700),
        displayMedium: AppTypography.display(30, weight: FontWeight.w700),
        displaySmall: AppTypography.display(28, weight: FontWeight.w700),
        headlineMedium: AppTypography.display(24, weight: FontWeight.w700),
        headlineSmall: AppTypography.display(22, weight: FontWeight.w600),
        titleLarge: AppTypography.body(18, weight: FontWeight.w700),
        titleMedium: AppTypography.body(16, weight: FontWeight.w600),
        bodyLarge: AppTypography.body(17, weight: FontWeight.w500),
        bodyMedium: AppTypography.body(15, weight: FontWeight.w500),
        labelLarge: AppTypography.body(15, weight: FontWeight.w600),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: BrandColors.ink),
        titleTextStyle: AppTypography.display(22, weight: FontWeight.w700),
      ),
      dividerTheme: const DividerThemeData(color: BrandColors.border, thickness: 1, space: 1),
      splashFactory: InkSparkle.splashFactory,
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: BrandColors.ink,
        contentTextStyle: AppTypography.body(14, weight: FontWeight.w600, color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.chip)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        elevation: 6,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: BrandColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
        titleTextStyle: AppTypography.display(20, weight: FontWeight.w700),
        contentTextStyle: AppTypography.body(15, weight: FontWeight.w500, color: BrandColors.inkSoft, height: 1.45),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: BrandColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: BrandColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
      ),
    );
  }
}
