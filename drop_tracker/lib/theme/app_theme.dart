import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'brand.dart';

/// Typography maps the Brand Guidelines pairing onto freely-available
/// equivalents:
///   • Headings (Kellissa — elegant serif)  → Fraunces
///   • Body / UI (General Sans — grotesque)  → Manrope
class AppTypography {
  AppTypography._();

  static TextStyle display(double size, {FontWeight weight = FontWeight.w600, Color? color, double? height}) =>
      GoogleFonts.fraunces(
        fontSize: size,
        fontWeight: weight,
        color: color ?? BrandColors.ink,
        height: height,
      );

  static TextStyle body(double size, {FontWeight weight = FontWeight.w500, Color? color, double? height}) =>
      GoogleFonts.manrope(
        fontSize: size,
        fontWeight: weight,
        color: color ?? BrandColors.ink,
        height: height,
      );
}

class AppTheme {
  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: BrandColors.background,
      colorScheme: const ColorScheme.light(
        primary: BrandColors.ocean,
        onPrimary: BrandColors.white,
        secondary: BrandColors.sunshine,
        onSecondary: BrandColors.ocean,
        surface: BrandColors.surface,
        onSurface: BrandColors.ink,
        error: BrandColors.danger,
      ),
    );

    final manrope = GoogleFonts.manropeTextTheme(base.textTheme);

    return base.copyWith(
      textTheme: manrope.copyWith(
        displayLarge: AppTypography.display(40, weight: FontWeight.w600),
        displayMedium: AppTypography.display(32, weight: FontWeight.w600),
        displaySmall: AppTypography.display(28, weight: FontWeight.w600),
        headlineMedium: AppTypography.display(24, weight: FontWeight.w600),
        headlineSmall: AppTypography.display(20, weight: FontWeight.w600),
        titleLarge: AppTypography.body(18, weight: FontWeight.w700),
        titleMedium: AppTypography.body(16, weight: FontWeight.w600),
        bodyLarge: AppTypography.body(16, weight: FontWeight.w500),
        bodyMedium: AppTypography.body(14, weight: FontWeight.w500),
        labelLarge: AppTypography.body(15, weight: FontWeight.w600),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: BrandColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: BrandColors.ink),
        titleTextStyle: AppTypography.display(22, weight: FontWeight.w600),
      ),
      dividerColor: BrandColors.hairline,
      splashFactory: InkRipple.splashFactory,
    );
  }
}
