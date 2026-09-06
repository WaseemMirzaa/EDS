import '../data/trusted_clock.dart';
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

  /// When the user responded, as the device reported it. Local ISO 8601 — this
  /// is what the History screen shows, because it is the time the user
  /// themselves saw on their phone.
  final String responseTime;

  /// The same instant recorded as a device reading plus its difference from
  /// server UTC. [ClockStamp.trustedUtc] is the value to use anywhere accuracy
  /// matters — dose intervals, the Doctor Report, ordering across devices —
  /// since the device clock alone can be wrong or deliberately changed.
  final ClockStamp stamp;

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
    required this.stamp,
    this.instructionFlags = const {},
  });

  /// Corrected instant — prefer this over [responseTime] for any calculation.
  DateTime get trustedUtc => stamp.trustedUtc;

  /// True when this record was written while the device clock was meaningfully
  /// out. Surfaced on the Doctor Report so a reviewer knows the caveat.
  bool get clockWasSuspect => stamp.deviceClockSuspect;

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
        ...stamp.toJson(),
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
        // Records written before offsets were tracked carry no device_utc.
        // Fall back to the response time and mark them device-only rather than
        // implying a verification that never happened.
        stamp: j['device_utc'] != null
            ? ClockStamp.fromJson(j)
            : ClockStamp.legacy(
                DateTime.tryParse((j['response_time'] ?? '') as String) ??
                    DateTime.now()),
        instructionFlags:
            (j['instruction_flags'] as Map?)?.cast<String, dynamic>() ?? const {},
      );
}
