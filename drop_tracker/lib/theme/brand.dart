import 'package:flutter/material.dart';

/// Eye Drop Shop design system.
///
/// Palette follows the premium refinement spec (deep, calm medical blue on a
/// warm paper background), harmonised with the brand's gold drop mark.
class BrandColors {
  BrandColors._();

  // Core — minimalist clinical cyan/teal (uipro: calm cyan + health green)
  static const Color primary = Color(0xFF0891B2); // calm cyan
  static const Color primaryDeep = Color(0xFF0E7490); // deeper cyan
  static const Color secondary = Color(0xFF3E9FBB); // muted cyan
  static const Color gold = Color(0xFFE6B84C); // brand drop mark

  static const Color background = Color(0xFFFFFFFF); // white app background
  static const Color backgroundWarm = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceTint = Color(0xFFFBFEFF); // barely-there cool card top
  static const Color fill = Color(0xFFEFF5F7); // subtle inner fill

  static const Color ink = Color(0xFF143C4A); // dark teal text (high contrast)
  static const Color inkSoft = Color(0xFF5B7480); // secondary text
  static const Color inkFaint = Color(0xFF9CB0B8); // tertiary text
  static const Color border = Color(0xFFE6EEF1); // cool hairline
  static const Color borderCool = Color(0xFFE6EEF1);

  // Semantic
  static const Color success = Color(0xFF059669); // health green
  static const Color successBg = Color(0xFFE6F5EF);
  static const Color warning = Color(0xFFE0A32E);
  static const Color warningText = Color(0xFF9A6E12);
  static const Color warningBg = Color(0xFFFBF2DC);
  static const Color danger = Color(0xFFDC2626);
  static const Color dangerBg = Color(0xFFFBEAEA);
  static const Color infoBg = Color(0xFFE6F4F8);

  // Soft tinted surface for chips / secondary backgrounds
  static const Color cloud = Color(0xFFE6F4F8);

  // ---- Back-compat aliases (older widgets referenced these names) ----
  static const Color ocean = primary;
  static const Color oceanDeep = primaryDeep;
  static const Color waves = secondary;
  static const Color sunshine = gold;
  static const Color sand = backgroundWarm;
  static const Color white = Color(0xFFFFFFFF);
  static const Color hairline = border;
  static const Color hairlineCool = borderCool;
  static const Color tookIt = success;
  static const Color tookItBg = successBg;
  static const Color notSure = warning;
  static const Color notSureBg = warningBg;
  static const Color snoozed = secondary;
  static const Color snoozedBg = infoBg;
  static const Color skipped = danger;
  static const Color skippedBg = dangerBg;

  // ---- Gradients ----
  static const LinearGradient pageGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [background, backgroundWarm],
    stops: [0.5, 1.0],
  );

  /// Near-flat hero surface — minimalist (uipro: avoid flashy gradients).
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0B9DC2), primary],
    stops: [0.0, 1.0],
  );

  static const LinearGradient oceanGradient = heroGradient;
  static const LinearGradient deepGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [primaryDeep, primary, secondary],
    stops: [0.0, 0.6, 1.0],
  );

  // ---- Elevation: near-invisible (minimalist relies on borders + space) ----
  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: const Color(0xFF0F172A).withValues(alpha: 0.05),
      blurRadius: 20,
      offset: const Offset(0, 6),
      spreadRadius: -6,
    ),
  ];

  static List<BoxShadow> softShadow = [
    BoxShadow(
      color: const Color(0xFF0F172A).withValues(alpha: 0.04),
      blurRadius: 14,
      offset: const Offset(0, 4),
      spreadRadius: -6,
    ),
  ];
}

/// Standardised corner radii (spec).
class AppRadius {
  AppRadius._();
  static const double button = 18;
  static const double card = 28;
  static const double input = 18;
  static const double chip = 14;
  static const double fab = 28;
  static const double nav = 30;
}

/// 8-point spacing scale.
class Space {
  Space._();
  static const double xs = 8;
  static const double sm = 16;
  static const double md = 24;
  static const double lg = 32;
  static const double xl = 40;
}

/// Bottle-cap colours — functional, so a user's real cap matches the app.
class CapColorSpec {
  final String key;
  final String label;
  final Color fill;
  final Color ring;
  const CapColorSpec(this.key, this.label, this.fill, this.ring);
}

const Map<String, CapColorSpec> kCapColors = {
  'white': CapColorSpec('white', 'White', Color(0xFFF1F5F9), Color(0xFFB9C4D0)),
  'pink': CapColorSpec('pink', 'Pink', Color(0xFFF9A8D4), Color(0xFFEC4899)),
  'tan': CapColorSpec('tan', 'Tan', Color(0xFFD4B896), Color(0xFFA16207)),
  'red': CapColorSpec('red', 'Red', Color(0xFFEF4444), Color(0xFFB91C1C)),
  'green': CapColorSpec('green', 'Green', Color(0xFF22C55E), Color(0xFF15803D)),
  'blue': CapColorSpec('blue', 'Blue', Color(0xFF3B82F6), Color(0xFF1D4ED8)),
  'teal': CapColorSpec('teal', 'Teal', Color(0xFF14B8A6), Color(0xFF0F766E)),
  'gray': CapColorSpec('gray', 'Gray', Color(0xFF9CA3AF), Color(0xFF4B5563)),
};

CapColorSpec capSpec(String? key) => kCapColors[key] ?? kCapColors['white']!;
