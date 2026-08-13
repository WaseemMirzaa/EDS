import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/app_user.dart';
import '../models/dose.dart';
import '../models/medication.dart';
import 'dose_logic.dart';
import 'trusted_clock.dart';

/// Real, alarm-style local notifications scheduled on the device — the native
/// replacement for the prototype's .ics workaround (Proposal §04).
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const String _channelId = 'drop_reminders';
  static const String _channelName = 'Drop reminders';
  static const String _channelDesc =
      'Reminders to take your eye drops at their scheduled times.';

  Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    try {
      final dynamic local = await FlutterTimezone.getLocalTimezone();
      final String name =
          local is String ? local : (local.identifier as String);
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );
    _ready = true;
  }

  /// Ask the user to allow notifications (iOS + Android 13+).
  Future<bool> requestPermissions() async {
    await init();
    bool granted = true;
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      granted = await ios.requestPermissions(
              alert: true, badge: true, sound: true) ??
          false;
    }
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final notif = await android.requestNotificationsPermission() ?? false;
      // Exact alarms let reminders fire precisely; harmless if unavailable.
      try {
        await android.requestExactAlarmsPermission();
      } catch (_) {}
      granted = notif;
    }
    return granted;
  }

  NotificationDetails get _details => const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.max,
          priority: Priority.high,
          category: AndroidNotificationCategory.reminder,
        ),
        iOS: DarwinNotificationDetails(
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
      );

  /// Deterministic notification id for a medication + time so reschedules
  /// replace rather than duplicate.
  int _idFor(String medicationId, String hhmm) =>
      (medicationId.hashCode ^ hhmm.hashCode) & 0x7fffffff;

  String _body(Dose dose) {
    final eye = dose.eye.label.toLowerCase();
    var body = 'Time for ${dose.medicationName} — $eye.';
    final instr = dose.instructions.summary;
    if (instr.isNotEmpty) body += ' ${instr.first} first.';
    return body;
  }

  /// Cancel everything and reschedule daily reminders for every active
  /// medication using today's effective (taper-aware) dose times.
  Future<void> rescheduleAll(List<Medication> meds, AppUser user) async {
    await init();
    await _plugin.cancelAll();
    final today = DoseLogic.todayStr();
    final doses = DoseLogic.getDosesForDate(
      meds,
      today,
      wakingStart: user.wakingStart,
      wakingEnd: user.wakingEnd,
    );
    for (final dose in doses) {
      await _scheduleDaily(dose);
    }
  }

  Future<void> _scheduleDaily(Dose dose) async {
    final parts = dose.scheduledHhmm.split(':').map(int.parse).toList();
    final when = _nextInstanceOf(parts[0], parts[1]);
    try {
      await _plugin.zonedSchedule(
        _idFor(dose.medicationId, dose.scheduledHhmm),
        'Drop Tracker',
        _body(dose),
        when,
        _details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time, // repeat daily
      );
    } catch (e) {
      // Exact alarms may be disallowed; fall back to inexact.
      try {
        await _plugin.zonedSchedule(
          _idFor(dose.medicationId, dose.scheduledHhmm),
          'Drop Tracker',
          _body(dose),
          when,
          _details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      } catch (err) {
        debugPrint('Failed to schedule reminder: $err');
      }
    }
  }

  tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);

    // The OS fires against the device's own clock, so a device running fast or
    // slow would fire at the wrong real-world moment. Shift by the measured
    // device↔server offset: a phone 40 minutes fast needs a 07:00 dose
    // scheduled at 07:40 by its own reckoning to actually fire at 07:00.
    // Returns zero when there is no trustworthy measurement to apply.
    final correction = TrustedClock.instance.schedulingCorrection();
    if (correction != Duration.zero) {
      scheduled = scheduled.subtract(correction);
    }

    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  /// Snooze: a one-off reminder [minutes] from now.
  Future<void> scheduleSnooze(Dose dose, {int minutes = 10}) async {
    await init();
    final when = tz.TZDateTime.now(tz.local).add(Duration(minutes: minutes));
    try {
      await _plugin.zonedSchedule(
        (dose.medicationId.hashCode ^ dose.scheduledHhmm.hashCode ^ 0x5eed) &
            0x7fffffff,
        'Drop Tracker — snoozed',
        _body(dose),
        when,
        _details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {}
  }

  Future<void> cancelAll() async {
    await init();
    await _plugin.cancelAll();
  }
}
