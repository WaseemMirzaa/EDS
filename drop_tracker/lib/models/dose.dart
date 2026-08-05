import 'enums.dart';
import 'instructions.dart';

/// A single scheduled dose for a given day — computed from a [Medication],
/// never persisted. Matched against [DoseEvent]s to determine status.
class Dose {
  final String medicationId;
  final String medicationName;
  final String bottleCapColor;
  final Eye eye;
  final String scheduledHhmm; // HH:mm
  final String scheduledDate; // yyyy-MM-dd
  final String scheduledTime; // yyyy-MM-ddTHH:mm:00
  final Instructions instructions;
  final Category category;

  const Dose({
    required this.medicationId,
    required this.medicationName,
    required this.bottleCapColor,
    required this.eye,
    required this.scheduledHhmm,
    required this.scheduledDate,
    required this.scheduledTime,
    required this.instructions,
    required this.category,
  });
}
