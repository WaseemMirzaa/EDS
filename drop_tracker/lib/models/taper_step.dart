import 'enums.dart';

/// A single stage in a step-down taper regimen. Its [startDate] is the day the
/// medication switches to this step's frequency and times.
class TaperStep {
  final String startDate; // yyyy-MM-dd
  final FrequencyType frequencyType;
  final int? frequencyValue; // hours, for everyNHours
  final List<String> doseTimes; // HH:mm

  const TaperStep({
    required this.startDate,
    required this.frequencyType,
    this.frequencyValue,
    this.doseTimes = const [],
  });

  TaperStep copyWith({
    String? startDate,
    FrequencyType? frequencyType,
    int? frequencyValue,
    List<String>? doseTimes,
  }) =>
      TaperStep(
        startDate: startDate ?? this.startDate,
        frequencyType: frequencyType ?? this.frequencyType,
        frequencyValue: frequencyValue ?? this.frequencyValue,
        doseTimes: doseTimes ?? this.doseTimes,
      );

  Map<String, dynamic> toJson() => {
        'start_date': startDate,
        'frequency_type': frequencyType.code,
        'frequency_value': frequencyValue,
        'dose_times': doseTimes,
      };

  factory TaperStep.fromJson(Map<String, dynamic> j) => TaperStep(
        startDate: (j['start_date'] ?? '') as String,
        frequencyType: FrequencyType.fromCode(j['frequency_type'] as String?),
        frequencyValue: (j['frequency_value'] as num?)?.toInt(),
        doseTimes: ((j['dose_times'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
      );
}
