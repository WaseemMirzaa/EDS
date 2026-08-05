import 'enums.dart';
import 'instructions.dart';
import 'taper_step.dart';

/// A medication and its dosing schedule.
class Medication {
  final String id;
  final String name;
  final String bottleCapColor; // key into kCapColors
  final Eye eye;
  final FrequencyType frequencyType;
  final int? frequencyValue; // hours, for everyNHours
  final List<String> doseTimes; // HH:mm
  final String? startDate; // yyyy-MM-dd
  final String? endDate; // yyyy-MM-dd
  final bool ongoing;
  final Instructions instructions;
  final List<TaperStep> taperSteps;
  final Category category;

  const Medication({
    required this.id,
    required this.name,
    this.bottleCapColor = 'white',
    this.eye = Eye.both,
    this.frequencyType = FrequencyType.fourDaily,
    this.frequencyValue,
    this.doseTimes = const [],
    this.startDate,
    this.endDate,
    this.ongoing = false,
    this.instructions = const Instructions(),
    this.taperSteps = const [],
    this.category = Category.other,
  });

  Medication copyWith({
    String? id,
    String? name,
    String? bottleCapColor,
    Eye? eye,
    FrequencyType? frequencyType,
    int? frequencyValue,
    List<String>? doseTimes,
    String? startDate,
    String? endDate,
    bool? ongoing,
    Instructions? instructions,
    List<TaperStep>? taperSteps,
    Category? category,
  }) =>
      Medication(
        id: id ?? this.id,
        name: name ?? this.name,
        bottleCapColor: bottleCapColor ?? this.bottleCapColor,
        eye: eye ?? this.eye,
        frequencyType: frequencyType ?? this.frequencyType,
        frequencyValue: frequencyValue ?? this.frequencyValue,
        doseTimes: doseTimes ?? this.doseTimes,
        startDate: startDate ?? this.startDate,
        endDate: endDate ?? this.endDate,
        ongoing: ongoing ?? this.ongoing,
        instructions: instructions ?? this.instructions,
        taperSteps: taperSteps ?? this.taperSteps,
        category: category ?? this.category,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'bottle_cap_color': bottleCapColor,
        'eye': eye.code,
        'frequency_type': frequencyType.code,
        'frequency_value': frequencyValue,
        'dose_times': doseTimes,
        'start_date': startDate,
        'end_date': endDate,
        'ongoing': ongoing,
        'instructions': instructions.toJson(),
        'taper_steps': taperSteps.map((t) => t.toJson()).toList(),
        'category': category.code,
      };

  factory Medication.fromJson(Map<String, dynamic> j) => Medication(
        id: j['id'] as String,
        name: (j['name'] ?? '') as String,
        bottleCapColor: (j['bottle_cap_color'] ?? 'white') as String,
        eye: Eye.fromCode(j['eye'] as String?),
        frequencyType: FrequencyType.fromCode(j['frequency_type'] as String?),
        frequencyValue: (j['frequency_value'] as num?)?.toInt(),
        doseTimes: ((j['dose_times'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        startDate: j['start_date'] as String?,
        endDate: j['end_date'] as String?,
        ongoing: j['ongoing'] == true,
        instructions:
            Instructions.fromJson(j['instructions'] as Map<String, dynamic>?),
        taperSteps: ((j['taper_steps'] as List?) ?? const [])
            .map((e) => TaperStep.fromJson(e as Map<String, dynamic>))
            .toList(),
        category: Category.fromCode(j['category'] as String?),
      );
}
