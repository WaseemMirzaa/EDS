import '../models/enums.dart';
import '../models/instructions.dart';
import '../models/medication.dart';
import '../models/taper_step.dart';
import 'dose_logic.dart';

/// A quick-start preset shown on the last onboarding step.
class Preset {
  final String id;
  final String label;
  final String description;
  final List<Medication> Function(String startDate) build;
  const Preset({
    required this.id,
    required this.label,
    required this.description,
    required this.build,
  });

  int get medicationCount => build(DoseLogic.todayStr()).length;
}

String _plusDays(String startDate, int days) =>
    DoseLogic.dateToStr(DoseLogic.strToDate(startDate).add(Duration(days: days)));

/// Cataract Surgery — antibiotic + tapering steroid + artificial tears.
///
/// Improvement over the web prototype: the steroid taper is staggered by week
/// (0/7/14/21 days) so the step-down actually takes effect over time, matching
/// the "4× for a week, then 3×, then 2×, then once daily" regimen described in
/// the proposal.
List<Medication> _cataract(String startDate) => [
      Medication(
        id: '',
        name: 'Antibiotic (e.g. Vigamox)',
        bottleCapColor: 'blue',
        eye: Eye.both,
        frequencyType: FrequencyType.fourDaily,
        doseTimes: const ['07:00', '11:00', '15:00', '19:00'],
        startDate: startDate,
        endDate: _plusDays(startDate, 7),
        ongoing: false,
        category: Category.antibiotic,
        instructions: const Instructions(wait5min: true, pressTearDuct: true),
      ),
      Medication(
        id: '',
        name: 'Steroid (e.g. Pred Forte)',
        bottleCapColor: 'pink',
        eye: Eye.both,
        frequencyType: FrequencyType.fourDaily,
        doseTimes: const ['07:00', '11:00', '15:00', '19:00'],
        startDate: startDate,
        endDate: _plusDays(startDate, 28),
        ongoing: false,
        category: Category.steroid,
        instructions: const Instructions(shake: true, wait5min: true, pressTearDuct: true),
        taperSteps: [
          TaperStep(
            startDate: startDate,
            frequencyType: FrequencyType.fourDaily,
            doseTimes: const ['07:00', '11:00', '15:00', '19:00'],
          ),
          TaperStep(
            startDate: _plusDays(startDate, 7),
            frequencyType: FrequencyType.threeDaily,
            doseTimes: const ['08:00', '14:00', '20:00'],
          ),
          TaperStep(
            startDate: _plusDays(startDate, 14),
            frequencyType: FrequencyType.twiceDaily,
            doseTimes: const ['09:00', '21:00'],
          ),
          TaperStep(
            startDate: _plusDays(startDate, 21),
            frequencyType: FrequencyType.onceDaily,
            doseTimes: const ['09:00'],
          ),
        ],
      ),
      Medication(
        id: '',
        name: 'Artificial Tears',
        bottleCapColor: 'white',
        eye: Eye.both,
        frequencyType: FrequencyType.customTimes,
        doseTimes: const ['09:00', '13:00', '17:00', '21:00'],
        startDate: startDate,
        ongoing: true,
        category: Category.artificialTears,
        instructions: const Instructions(removeContacts: true),
      ),
    ];

const List<Preset> kPresets = [
  Preset(
    id: 'cataract_surgery',
    label: 'Cataract Surgery',
    description:
        'Typical post-op regimen with an antibiotic, a tapering steroid, and artificial tears.',
    build: _cataract,
  ),
];
