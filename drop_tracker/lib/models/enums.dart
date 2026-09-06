import 'package:flutter/material.dart';

import '../theme/brand.dart';

/// Which eye a medication is for.
enum Eye {
  right('right', 'Right eye', 'R'),
  left('left', 'Left eye', 'L'),
  both('both', 'Both eyes', 'Both');

  const Eye(this.code, this.label, this.short);
  final String code;
  final String label;
  final String short;

  static Eye fromCode(String? code) =>
      Eye.values.firstWhere((e) => e.code == code, orElse: () => Eye.both);
}

/// Dosing frequency modes.
enum FrequencyType {
  onceDaily('once_daily', 'Once daily', 1),
  twiceDaily('twice_daily', 'Twice daily', 2),
  threeDaily('three_daily', '3× daily', 3),
  fourDaily('four_daily', '4× daily', 4),
  everyNHours('every_n_hours', 'Every N hours', null),
  customTimes('custom_times', 'Custom times', null);

  const FrequencyType(this.code, this.label, this.count);
  final String code;
  final String label;

  /// Number of daily doses for the fixed frequencies, or null for the
  /// interval / custom modes.
  final int? count;

  static FrequencyType fromCode(String? code) => FrequencyType.values
      .firstWhere((e) => e.code == code, orElse: () => FrequencyType.fourDaily);
}

/// The four Confidence-Check responses recorded against a dose.
enum DoseResponse {
  tookIt('took_it', 'Took it', '✅', BrandColors.tookIt, BrandColors.tookItBg),
  notSure('not_sure', 'Not sure', '🤔', BrandColors.notSure, BrandColors.notSureBg),
  snoozed('snoozed', 'Snoozed', '⏰', BrandColors.snoozed, BrandColors.snoozedBg),
  skipped('skipped', 'Skipped', '❌', BrandColors.skipped, BrandColors.skippedBg);

  const DoseResponse(this.code, this.label, this.emoji, this.color, this.bg);
  final String code;
  final String label;
  final String emoji;
  final Color color;
  final Color bg;

  static DoseResponse fromCode(String? code) => DoseResponse.values
      .firstWhere((e) => e.code == code, orElse: () => DoseResponse.tookIt);
}

/// Clinical category (used by presets; free-text otherwise).
enum Category {
  antibiotic('antibiotic'),
  steroid('steroid'),
  nsaid('nsaid'),
  artificialTears('artificial_tears'),
  glaucoma('glaucoma'),
  other('other');

  const Category(this.code);
  final String code;

  static Category fromCode(String? code) =>
      Category.values.firstWhere((e) => e.code == code, orElse: () => Category.other);
}
