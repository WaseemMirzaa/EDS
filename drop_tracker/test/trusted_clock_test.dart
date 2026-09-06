import 'package:flutter_test/flutter_test.dart';

import 'package:drop_tracker/data/trusted_clock.dart';
import 'package:drop_tracker/models/dose_event.dart';
import 'package:drop_tracker/models/enums.dart';

void main() {
  group('ClockStamp', () {
    test('trusted time is the device reading plus the server offset', () {
      final device = DateTime.utc(2026, 8, 13, 7, 0);
      // Device is 40 minutes behind the server.
      const offset = 40 * 60 * 1000;

      final stamp = ClockStamp(
        deviceUtc: device,
        serverOffsetMs: offset,
        source: ClockSource.serverSynced,
      );

      expect(stamp.trustedUtc, DateTime.utc(2026, 8, 13, 7, 40));
      // The raw device reading is preserved, not overwritten.
      expect(stamp.deviceUtc, device);
    });

    test('a device running fast yields a negative offset', () {
      final device = DateTime.utc(2026, 8, 13, 7, 40);
      const offset = -40 * 60 * 1000;

      final stamp = ClockStamp(deviceUtc: device, serverOffsetMs: offset);
      expect(stamp.trustedUtc, DateTime.utc(2026, 8, 13, 7, 0));
    });

    test('small drift is not flagged, large skew is', () {
      expect(
        ClockStamp(deviceUtc: DateTime.utc(2026), serverOffsetMs: 30 * 1000)
            .deviceClockSuspect,
        isFalse,
      );
      expect(
        ClockStamp(deviceUtc: DateTime.utc(2026), serverOffsetMs: 10 * 60 * 1000)
            .deviceClockSuspect,
        isTrue,
      );
    });

    test('survives a round trip through JSON', () {
      final stamp = ClockStamp(
        deviceUtc: DateTime.utc(2026, 8, 13, 7, 0),
        serverOffsetMs: 12345,
        source: ClockSource.serverSynced,
      );
      final back = ClockStamp.fromJson(stamp.toJson());

      expect(back.deviceUtc, stamp.deviceUtc);
      expect(back.serverOffsetMs, 12345);
      expect(back.source, ClockSource.serverSynced);
    });

    test('a legacy value is device-only with no offset', () {
      final stamp = ClockStamp.legacy(DateTime.utc(2026, 8, 13, 7, 0));
      expect(stamp.serverOffsetMs, 0);
      expect(stamp.source, ClockSource.deviceOnly);
      expect(stamp.trustedUtc, stamp.deviceUtc);
    });
  });

  group('TrustedClock', () {
    final clock = TrustedClock.instance;

    setUp(() => clock.debugSetOffset(0));

    test('syncing computes the offset from a server reading', () async {
      final device = DateTime.now().toUtc();
      // Pretend the server is a minute ahead of this device.
      await clock.syncWith(device.add(const Duration(minutes: 1)));

      expect(clock.offsetMs, closeTo(60 * 1000, 2000));
      expect(clock.isSynced, isTrue);
      expect(clock.source, ClockSource.serverSynced);
    });

    test('half the round trip is discounted so latency does not bias it',
        () async {
      final device = DateTime.now().toUtc();
      await clock.syncWith(
        device.add(const Duration(seconds: 10)),
        roundTrip: const Duration(seconds: 4),
      );
      // 10s apparent difference minus 2s (half of 4s in flight).
      expect(clock.offsetMs, closeTo(8 * 1000, 2000));
    });

    test('scheduling shifts the fire time against the device clock', () {
      // Device runs 40 minutes fast.
      clock.debugSetOffset(-40 * 60 * 1000);

      final intended = DateTime(2026, 8, 13, 7, 0);
      // To fire at real 07:00 it must be scheduled for 07:40 device time.
      expect(clock.applyToFireTime(intended), DateTime(2026, 8, 13, 7, 40));
    });

    test('an implausible offset is not applied to scheduling', () {
      // Hours of skew is far more likely a timezone misreading than real drift;
      // acting on it would move reminders wildly.
      clock.debugSetOffset(9 * 60 * 60 * 1000);
      expect(clock.schedulingCorrection(), Duration.zero);

      final intended = DateTime(2026, 8, 13, 7, 0);
      expect(clock.applyToFireTime(intended), intended);
    });

    test('a stale measurement is reported but not applied', () {
      clock.debugSetOffset(
        5 * 60 * 1000,
        measuredAt: DateTime.now().toUtc().subtract(const Duration(days: 30)),
      );

      expect(clock.isStale, isTrue);
      expect(clock.deviceClockSuspect, isTrue); // still surfaced to the user
      expect(clock.schedulingCorrection(), Duration.zero); // but not acted on
    });

    test('an unsynced clock corrects nothing', () async {
      await clock.reset();
      expect(clock.isSynced, isFalse);
      expect(clock.schedulingCorrection(), Duration.zero);

      final s = clock.stamp();
      expect(s.serverOffsetMs, 0);
      expect(s.source, ClockSource.deviceOnly);
    });
  });

  group('DoseEvent', () {
    DoseEvent build(ClockStamp stamp) => DoseEvent(
          id: 'e1',
          medicationId: 'm1',
          medicationName: 'Pred Forte',
          eye: Eye.both,
          scheduledTime: '2026-08-13T07:00:00',
          scheduledDate: '2026-08-13',
          scheduledHhmm: '07:00',
          response: DoseResponse.tookIt,
          responseTime: '2026-08-13T07:02:00',
          stamp: stamp,
        );

    test('carries the stamp through serialisation', () {
      final event = build(ClockStamp(
        deviceUtc: DateTime.utc(2026, 8, 13, 11, 2),
        serverOffsetMs: 90 * 1000,
        source: ClockSource.serverSynced,
      ));

      final back = DoseEvent.fromJson(event.toJson());
      expect(back.stamp.serverOffsetMs, 90 * 1000);
      expect(back.stamp.source, ClockSource.serverSynced);
      expect(back.trustedUtc, DateTime.utc(2026, 8, 13, 11, 3, 30));
      // The user-facing local reading is untouched.
      expect(back.responseTime, '2026-08-13T07:02:00');
    });

    test('records written before offsets existed still load', () {
      // A row from the previous schema: no device_utc, no offset.
      final legacy = {
        'id': 'old',
        'medication_id': 'm1',
        'medication_name': 'Vigamox',
        'eye': 'both',
        'scheduled_time': '2026-08-01T07:00:00',
        'scheduled_date': '2026-08-01',
        'scheduled_hhmm': '07:00',
        'response': 'took_it',
        'response_time': '2026-08-01T07:05:00',
      };

      final event = DoseEvent.fromJson(legacy);
      expect(event.stamp.source, ClockSource.deviceOnly);
      expect(event.stamp.serverOffsetMs, 0);
      expect(event.clockWasSuspect, isFalse);
    });

    test('a dose logged on a badly wrong clock is flagged', () {
      final event = build(ClockStamp(
        deviceUtc: DateTime.utc(2026, 8, 13, 11, 2),
        serverOffsetMs: 45 * 60 * 1000,
        source: ClockSource.serverSynced,
      ));
      expect(event.clockWasSuspect, isTrue);
    });
  });
}
