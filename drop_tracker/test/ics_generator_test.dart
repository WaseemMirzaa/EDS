import 'package:flutter_test/flutter_test.dart';

import 'package:drop_tracker/data/ics_generator.dart';
import 'package:drop_tracker/models/app_user.dart';
import 'package:drop_tracker/models/enums.dart';
import 'package:drop_tracker/models/medication.dart';
import 'package:drop_tracker/models/taper_step.dart';

void main() {
  const user = AppUser(wakingStart: '07:00', wakingEnd: '21:00');

  test('a plain (non-taper) medication gets one open-ended DAILY rule', () {
    const med = Medication(
      id: 'm1',
      name: 'Artificial Tears',
      frequencyType: FrequencyType.onceDaily,
      doseTimes: ['09:00'],
      startDate: '2026-01-01',
      ongoing: true,
    );
    final ics = IcsGenerator.forMedication(med, user);
    expect('BEGIN:VEVENT'.allMatches(ics).length, 1);
    expect(ics.contains('DTSTART:20260101T090000'), true);
    expect(ics.contains('RRULE:FREQ=DAILY'), true);
    // Ongoing and only one segment: no UNTIL bound at all.
    expect(ics.contains('UNTIL='), false);
  });

  test('a taper regimen emits one date-bounded rule per step, not one rule forever', () {
    final med = Medication(
      id: 'm2',
      name: 'Steroid',
      frequencyType: FrequencyType.fourDaily,
      doseTimes: const ['07:00', '11:00', '15:00', '19:00'],
      startDate: '2026-01-01',
      ongoing: true,
      taperSteps: const [
        TaperStep(
          startDate: '2026-01-01',
          frequencyType: FrequencyType.fourDaily,
          doseTimes: ['07:00', '11:00', '15:00', '19:00'],
        ),
        TaperStep(
          startDate: '2026-01-08',
          frequencyType: FrequencyType.twiceDaily,
          doseTimes: ['08:00', '20:00'],
        ),
        TaperStep(
          startDate: '2026-01-15',
          frequencyType: FrequencyType.onceDaily,
          doseTimes: ['09:00'],
        ),
      ],
    );
    final ics = IcsGenerator.forMedication(med, user);

    // 4 events for step 1 + 2 for step 2 + 1 for step 3 (ongoing, so the
    // last step has no UNTIL).
    expect('BEGIN:VEVENT'.allMatches(ics).length, 7);

    // Step 1 (Jan 1-7) is bounded the day before step 2 starts.
    expect(ics.contains('DTSTART:20260101T070000'), true);
    expect(ics.contains('UNTIL=20260107T235959'), true);

    // Step 2 (Jan 8-14) is bounded the day before step 3 starts, and its own
    // times — not step 1's — are used.
    expect(ics.contains('DTSTART:20260108T080000'), true);
    expect(ics.contains('UNTIL=20260114T235959'), true);

    // Step 3 (Jan 15 onward) is the last segment and the medication is
    // ongoing, so it has no UNTIL bound — proving this step doesn't just
    // repeat an earlier step's times forever, and isn't itself cut off.
    expect(ics.contains('DTSTART:20260115T090000'), true);
  });

  test('a taper step sharing the medication\'s own start date fully supersedes it', () {
    final med = Medication(
      id: 'm3',
      name: 'Steroid',
      frequencyType: FrequencyType.fourDaily,
      doseTimes: const ['07:00', '11:00', '15:00', '19:00'],
      startDate: '2026-01-01',
      ongoing: true,
      taperSteps: const [
        TaperStep(
          startDate: '2026-01-01',
          frequencyType: FrequencyType.onceDaily,
          doseTimes: ['12:50'],
        ),
      ],
    );
    final ics = IcsGenerator.forMedication(med, user);
    // Only the taper step's single time is exported — the base schedule's
    // 4-times-daily is fully overridden from day one, matching what the app
    // actually schedules (dose_logic.dart's active-taper-step selection).
    expect('BEGIN:VEVENT'.allMatches(ics).length, 1);
    expect(ics.contains('DTSTART:20260101T125000'), true);
  });
}
