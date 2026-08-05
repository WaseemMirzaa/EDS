import 'package:flutter/material.dart';

/// Eye Drop Shop brand palette — from the 2026 Brand Guidelines.
///
/// Ocean / Waves / Cloud / Sunshine / Sand, plus Black & White.
class BrandColors {
  BrandColors._();

  // Core brand palette
  static const Color ocean = Color(0xFF0F3759); // deep blue — primary
  static const Color oceanDeep = Color(0xFF0A2A44); // darker ocean for gradients
  static const Color waves = Color(0xFF3D6B99); // medium blue — secondary
  static const Color cloud = Color(0xFFE9F5FA); // pale blue — soft surfaces
  static const Color sunshine = Color(0xFFE6D380); // warm yellow — accent
  static const Color sunshineDeep = Color(0xFFC9A93E); // readable yellow for text
  static const Color sand = Color(0xFFF4F0E6); // warm off-white — background

  static const Color black = Color(0xFF000000);
  static const Color white = Color(0xFFFFFFFF);

  // Neutrals derived to sit within the warm/blue world
  static const Color ink = Color(0xFF13293D); // primary text
  static const Color inkSoft = Color(0xFF4A5C6A); // secondary text
  static const Color inkFaint = Color(0xFF8A97A1); // tertiary text
  static const Color surface = Color(0xFFFFFFFF); // card surface
  static const Color background = Color(0xFFF7F4EC); // app background (sand-tinted)
  static const Color hairline = Color(0xFFE7E1D3); // subtle borders on sand
  static const Color hairlineCool = Color(0xFFE2E8EE); // borders on cool surfaces

  // Dose-response semantic colours (functional, brand-harmonised)
  static const Color tookIt = Color(0xFF2E8B6F); // calm green
  static const Color tookItBg = Color(0xFFE6F4EF);
  static const Color notSure = Color(0xFFC9972E); // amber
  static const Color notSureBg = Color(0xFFFBF3DD);
  static const Color snoozed = Color(0xFF3D6B99); // waves blue
  static const Color snoozedBg = Color(0xFFE9F5FA);
  static const Color skipped = Color(0xFFC2554D); // muted red
  static const Color skippedBg = Color(0xFFF9E9E7);

  static const Color danger = Color(0xFFC2554D);

  /// Soft brand gradient — swirled ocean tones, used on immersive screens.
  static const LinearGradient oceanGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [ocean, waves],
  );

  /// Deep immersive gradient for hero / onboarding backgrounds.
  static const LinearGradient deepGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [oceanDeep, ocean, waves],
    stops: [0.0, 0.55, 1.0],
  );
}

/// Bottle-cap colours — functional, carried over from the prototype so that a
/// user's real-world cap colour matches the app.
class CapColorSpec {
  final String key;
  final String label;
  final Color fill;
  final Color ring;
  const CapColorSpec(this.key, this.label, this.fill, this.ring);
}

const Map<String, CapColorSpec> kCapColors = {
  'white': CapColorSpec('white', 'White', Color(0xFFF1F5F9), Color(0xFFCBD5E1)),
  'pink': CapColorSpec('pink', 'Pink', Color(0xFFF9A8D4), Color(0xFFEC4899)),
  'tan': CapColorSpec('tan', 'Tan', Color(0xFFD4B896), Color(0xFFA16207)),
  'red': CapColorSpec('red', 'Red', Color(0xFFEF4444), Color(0xFFB91C1C)),
  'green': CapColorSpec('green', 'Green', Color(0xFF22C55E), Color(0xFF15803D)),
  'blue': CapColorSpec('blue', 'Blue', Color(0xFF3B82F6), Color(0xFF1D4ED8)),
  'teal': CapColorSpec('teal', 'Teal', Color(0xFF14B8A6), Color(0xFF0F766E)),
  'gray': CapColorSpec('gray', 'Gray', Color(0xFF9CA3AF), Color(0xFF4B5563)),
};

CapColorSpec capSpec(String? key) =>
    kCapColors[key] ?? kCapColors['white']!;
