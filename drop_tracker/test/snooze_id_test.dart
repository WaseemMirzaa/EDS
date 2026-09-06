import 'package:flutter_test/flutter_test.dart';

import 'package:drop_tracker/data/notification_service.dart';

void main() {
  group('snoozeIdFor', () {
    test('is deterministic — snoozing the same dose twice reuses the id, '
        'so it replaces the pending snooze instead of stacking a second one',
        () {
      final first = NotificationService.snoozeIdFor('med-1', '07:00');
      final second = NotificationService.snoozeIdFor('med-1', '07:00');
      expect(first, second);
    });

    test('differs for a different medication at the same time', () {
      final a = NotificationService.snoozeIdFor('med-1', '07:00');
      final b = NotificationService.snoozeIdFor('med-2', '07:00');
      expect(a, isNot(b));
    });

    test('differs for the same medication at a different time', () {
      final a = NotificationService.snoozeIdFor('med-1', '07:00');
      final b = NotificationService.snoozeIdFor('med-1', '19:00');
      expect(a, isNot(b));
    });

    test('always falls in the range reserved for snoozes, disjoint from '
        'the managed schedule\'s own ids — so rescheduleAll\'s stale-id '
        'cleanup (which only ever touches ids below 0x40000000) can never '
        'cancel a pending snooze', () {
      for (final args in [
        ('med-1', '07:00'),
        ('another-medication-id', '23:59'),
        ('', '00:00'),
      ]) {
        final id = NotificationService.snoozeIdFor(args.$1, args.$2);
        expect(id, greaterThanOrEqualTo(0x40000000));
        expect(id, lessThanOrEqualTo(0x7fffffff)); // valid 32-bit int id
      }
    });
  });
}
