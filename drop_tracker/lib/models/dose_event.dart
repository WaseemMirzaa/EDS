import 'enums.dart';

/// A logged response to a scheduled dose (the History record).
class DoseEvent {
  final String id;
  final String medicationId;
  final String medicationName;
  final String? bottleCapColor;
  final Eye eye;
  final String scheduledTime; // ISO-ish yyyy-MM-ddTHH:mm:00
  final String scheduledDate; // yyyy-MM-dd
  final String scheduledHhmm; // HH:mm
  final DoseResponse response;
  final String responseTime; // ISO 8601
  final Map<String, dynamic> instructionFlags;

  const DoseEvent({
    required this.id,
    required this.medicationId,
    required this.medicationName,
    this.bottleCapColor,
    required this.eye,
    required this.scheduledTime,
    required this.scheduledDate,
    required this.scheduledHhmm,
    required this.response,
    required this.responseTime,
    this.instructionFlags = const {},
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'medication_id': medicationId,
        'medication_name': medicationName,
        'bottle_cap_color': bottleCapColor,
        'eye': eye.code,
        'scheduled_time': scheduledTime,
        'scheduled_date': scheduledDate,
        'scheduled_hhmm': scheduledHhmm,
        'response': response.code,
        'response_time': responseTime,
        'instruction_flags': instructionFlags,
      };

  factory DoseEvent.fromJson(Map<String, dynamic> j) => DoseEvent(
        id: j['id'] as String,
        medicationId: (j['medication_id'] ?? '') as String,
        medicationName: (j['medication_name'] ?? '') as String,
        bottleCapColor: j['bottle_cap_color'] as String?,
        eye: Eye.fromCode(j['eye'] as String?),
        scheduledTime: (j['scheduled_time'] ?? '') as String,
        scheduledDate: (j['scheduled_date'] ?? '') as String,
        scheduledHhmm: (j['scheduled_hhmm'] ?? '') as String,
        response: DoseResponse.fromCode(j['response'] as String?),
        responseTime: (j['response_time'] ?? '') as String,
        instructionFlags:
            (j['instruction_flags'] as Map?)?.cast<String, dynamic>() ?? const {},
      );
}
