/// Local user profile — name + waking hours drive app-wide dose spacing.
class AppUser {
  final String firstName;
  final String wakingStart; // HH:mm
  final String wakingEnd; // HH:mm
  final bool onboarded;
  final bool hasSeenDisclaimer;

  const AppUser({
    this.firstName = '',
    this.wakingStart = '07:00',
    this.wakingEnd = '21:00',
    this.onboarded = false,
    this.hasSeenDisclaimer = false,
  });

  AppUser copyWith({
    String? firstName,
    String? wakingStart,
    String? wakingEnd,
    bool? onboarded,
    bool? hasSeenDisclaimer,
  }) =>
      AppUser(
        firstName: firstName ?? this.firstName,
        wakingStart: wakingStart ?? this.wakingStart,
        wakingEnd: wakingEnd ?? this.wakingEnd,
        onboarded: onboarded ?? this.onboarded,
        hasSeenDisclaimer: hasSeenDisclaimer ?? this.hasSeenDisclaimer,
      );

  Map<String, dynamic> toJson() => {
        'first_name': firstName,
        'waking_start': wakingStart,
        'waking_end': wakingEnd,
        'onboarded': onboarded,
        'has_seen_disclaimer': hasSeenDisclaimer,
      };

  factory AppUser.fromJson(Map<String, dynamic>? j) {
    j ??= const {};
    return AppUser(
      firstName: (j['first_name'] ?? '') as String,
      wakingStart: (j['waking_start'] ?? '07:00') as String,
      wakingEnd: (j['waking_end'] ?? '21:00') as String,
      onboarded: j['onboarded'] == true,
      hasSeenDisclaimer: j['has_seen_disclaimer'] == true,
    );
  }
}
