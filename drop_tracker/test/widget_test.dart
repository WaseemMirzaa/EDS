import 'package:flutter_test/flutter_test.dart';

import 'package:drop_tracker/data/dose_logic.dart';
import 'package:drop_tracker/models/enums.dart';
import 'package:drop_tracker/models/medication.dart';

void main() {
  test('suggestTimes spaces doses across waking hours', () {
    expect(
      DoseLogic.suggestTimes(FrequencyType.onceDaily, wakingStart: '07:00', wakingEnd: '21:00'),
      ['07:00'],
    );
    expect(
      DoseLogic.suggestTimes(FrequencyType.twiceDaily, wakingStart: '07:00', wakingEnd: '21:00'),
      ['07:00', '21:00'],
    );
    expect(
      DoseLogic.suggestTimes(FrequencyType.fourDaily, wakingStart: '07:00', wakingEnd: '21:00').length,
      4,
    );
  });

  test('every-N-hours generates rolling times', () {
    final times = DoseLogic.timesForEveryNHours(4, wakingStart: '07:00', wakingEnd: '21:00');
    expect(times.first, '07:00');
    expect(times.contains('11:00'), true);
  });

  test('adherence percentage', () {
    expect(DoseLogic.calculateAdherence(0, 0), 0);
    expect(DoseLogic.calculateAdherence(4, 3), 75);
  });

  group('auto-spacing same-time collisions', () {
    test('artificial tears go first, antibiotic 5 min later', () {
      final meds = [
        const Medication(
          id: 'abx',
          name: 'Antibiotic',
          category: Category.antibiotic,
          frequencyType: FrequencyType.customTimes,
          doseTimes: ['07:00'],
          ongoing: true,
        ),
        const Medication(
          id: 'tears',
          name: 'Artificial Tears',
          category: Category.artificialTears,
          frequencyType: FrequencyType.customTimes,
          doseTimes: ['07:00'],
          ongoing: true,
        ),
      ];
      final doses = DoseLogic.getDosesForDate(meds, '2026-08-11');
      expect(doses.length, 2);
      expect(doses[0].medicationId, 'tears');
      expect(doses[0].scheduledHhmm, '07:00');
      expect(doses[1].medicationId, 'abx');
      expect(doses[1].scheduledHhmm, '07:05');
    });

    test('three colliding medications cascade 5 minutes apart', () {
      final meds = [
        const Medication(
          id: 'z',
          name: 'Zaditor',
          category: Category.other,
          frequencyType: FrequencyType.customTimes,
          doseTimes: ['08:00'],
          ongoing: true,
        ),
        const Medication(
          id: 'a',
          name: 'Alphagan',
          category: Category.glaucoma,
          frequencyType: FrequencyType.customTimes,
          doseTimes: ['08:00'],
          ongoing: true,
        ),
        const Medication(
          id: 'tears',
          name: 'Artificial Tears',
          category: Category.artificialTears,
          frequencyType: FrequencyType.customTimes,
          doseTimes: ['08:00'],
          ongoing: true,
        ),
      ];
      final doses = DoseLogic.getDosesForDate(meds, '2026-08-11');
      expect(doses.map((d) => d.medicationId).toList(), ['tears', 'a', 'z']);
      expect(doses.map((d) => d.scheduledHhmm).toList(), ['08:00', '08:05', '08:10']);
    });

    test('same medication at the same time twice is left untouched', () {
      final meds = [
        const Medication(
          id: 'x',
          name: 'Solo Drop',
          frequencyType: FrequencyType.customTimes,
          doseTimes: ['09:00', '09:00'],
          ongoing: true,
        ),
      ];
      final doses = DoseLogic.getDosesForDate(meds, '2026-08-11');
      expect(doses.every((d) => d.scheduledHhmm == '09:00'), true);
    });

    test('non-colliding schedules are unaffected', () {
      final meds = [
        const Medication(
          id: 'a',
          name: 'Morning Drop',
          frequencyType: FrequencyType.customTimes,
          doseTimes: ['07:00'],
          ongoing: true,
        ),
        const Medication(
          id: 'b',
          name: 'Evening Drop',
          frequencyType: FrequencyType.customTimes,
          doseTimes: ['20:00'],
          ongoing: true,
        ),
      ];
      final doses = DoseLogic.getDosesForDate(meds, '2026-08-11');
      expect(doses.map((d) => d.scheduledHhmm).toList(), ['07:00', '20:00']);
    });
  });
}
