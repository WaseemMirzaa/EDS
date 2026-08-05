import 'package:flutter_test/flutter_test.dart';

import 'package:drop_tracker/data/dose_logic.dart';
import 'package:drop_tracker/models/enums.dart';

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
}
