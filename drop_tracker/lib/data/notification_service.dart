import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/app_user.dart';
import '../models/dose.dart';
import '../models/medication.dart';
import 'dose_logic.dart';
import 'permission_service.dart';
import 'trusted_clock.dart';

/// Real, alarm-style local notifications scheduled on the device — the native
/// replacement for the prototype's .ics workaround (Proposal §04).
///
/// Each dose is scheduled as its own **date-specific, one-off** notification
/// (not a "repeat forever at this time" slot). That matters for taper
/// regimens and medications with an end date: their dose *times* legitimately
/// change from one day to the next, and a repeating notification can't
/// reflect that unless something re-runs [rescheduleAll] on exactly the right
/// day. Scheduling a rolling window of real dates ahead of time means the
/// correct time for each day is already in the OS's hands even if the app
/// isn't opened again until the window is running low.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  // Android notification channels are immutable once created — sound,
  // importance, and vibration are all locked in on the *first* app build
  // that ever scheduled a notification on this id, and no later code change
  // can repair an existing one; the OS only lets the user edit it by hand
  // in system Settings. This project went through many iterations of the
  // scheduling code (and just as many test installs) under the old ids
  // 'drop_reminders' and 'drop_reminders_v2', so any device that ran an
  // earlier build may be stuck with a channel that doesn't match what's
  // specified below (silently missing sound is exactly what that looks
  // like — reported again on v2, which is why this is now v3). Bumping the
  // id forces every device to get a fresh channel with the current, correct
  // settings. Do not reuse an old id here again for the same reason.
  static const String _channelId = 'drop_reminders_v3';
  static const String _channelName = 'Drop reminders';
  static const String _channelDesc =
      'Reminders to take your eye drops at their scheduled times.';

  // ---- persisted scheduling state ------------------------------------------
  //
  // iOS caps an app at 64 pending local notifications, so doses are scheduled
  // as one-off dated notifications for a rolling window sized to stay under
  // that cap, rather than one repeating slot per dose-time. This map keeps a
  // stable notification id per (medication, date, time) so a reschedule can
  // update in place instead of a blind cancel-everything-then-recreate pass.

  static const String _idMapKey = 'droptracker_notif_id_map';
  static const String _nextIdKey = 'droptracker_notif_next_id';
  static const String _scheduledThroughKey =
      'droptracker_notif_scheduled_through';
  static const String _fallbackUsedKey =
      'droptracker_notif_used_inexact_fallback';
  static const String _lastErrorKey = 'droptracker_notif_last_error';
  static const String _lastSuccessKey = 'droptracker_notif_last_success';

  /// Every call into the platform channel is bounded — a hung native call
  /// (seen in practice on some OEM Android builds and occasionally on iOS)
  /// must fail loudly and get retried next time, not silently stall the
  /// awaiting caller forever. [rescheduleAll] is awaited from
  /// DropStore.updateUser() before it pushes profile changes (like
  /// onboarding completion) to the server — an unbounded hang here doesn't
  /// just mean missing reminders, it silently blocks that push too.
  static const Duration _channelTimeout = Duration(seconds: 8);

  /// Stays comfortably under iOS's 64-pending-notification limit.
  static const int _iosSafeNotificationCap = 50;
  static const int _defaultWindowDays = 7;
  static const int _minWindowDays = 3;
  static const int _maxWindowDays = 14;

  SharedPreferences? _prefs;
  final Map<String, int> _idMap = {};
  int _nextId = 1000;
  bool _usedInexactFallback = false;
  bool _stateLoaded = false;

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
    // Defer the system permission dialog to [requestPermissions] so the
    // dedicated PermissionScreen can own the prompt timing.
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    try {
      await _plugin
          .initialize(
            const InitializationSettings(android: androidInit, iOS: iosInit),
          )
          .timeout(_channelTimeout);
    } catch (e) {
      // A hung/failed platform-channel init must not be treated as ready —
      // but it also must not throw out of here and leave the caller's own
      // await stuck, so record it and let every later call retry `init()`
      // (the `_ready` guard at the top only short-circuits once this
      // actually succeeds).
      debugPrint('NotificationService.init failed: $e');
      return;
    }
    _ready = true;
  }

  Future<void> _loadPersistedState() async {
    if (_stateLoaded) return;
    final prefs = _prefs ??= await SharedPreferences.getInstance();
    final raw = prefs.getString(_idMapKey);
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        decoded.forEach((k, v) {
          if (v is int) _idMap[k] = v;
        });
      } catch (_) {}
    }
    _nextId = prefs.getInt(_nextIdKey) ?? 1000;
    _stateLoaded = true;
  }

  Future<void> _persistState({DateTime? scheduledThrough}) async {
    final prefs = _prefs ??= await SharedPreferences.getInstance();
    await prefs.setString(_idMapKey, jsonEncode(_idMap));
    await prefs.setInt(_nextIdKey, _nextId);
    await prefs.setBool(_fallbackUsedKey, _usedInexactFallback);
    if (scheduledThrough != null) {
      await prefs.setString(
          _scheduledThroughKey, DoseLogic.dateToStr(scheduledThrough));
    }
  }

  /// A stable id for (medication, date, time), assigned once and reused on
  /// every later reschedule of the same slot — so re-running the scheduler
  /// updates existing notifications in place rather than needing to cancel
  /// and recreate everything to avoid duplicates.
  int _idFor(String key) {
    final existing = _idMap[key];
    if (existing != null) return existing;
    var id = _nextId;
    _nextId = (_nextId + 1) & 0x3fffffff;
    if (_nextId < 1000) _nextId = 1000; // guard against wraparound
    _idMap[key] = id;
    return id;
  }

  /// Ask the user to allow notifications via the native OS dialog
  /// (iOS + Android 13+). Exact-alarm capability is a separate, mandatory
  /// gate — see ExactAlarmScreen / PermissionService.requestExactAlarms —
  /// not requested here: it opens a system Settings screen rather than a
  /// dialog, so bundling it into this call gave no verifiable outcome and
  /// could pop an unrelated Settings screen mid-flow with no gate behind it.
  Future<bool> requestPermissions() async {
    await init();
    final granted = await PermissionService.instance.requestNotifications();

    // Mirror the grant into the iOS plugin so alert/badge/sound options apply.
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      await ios.requestPermissions(alert: true, badge: true, sound: true);
    }
    return granted;
  }

  Future<bool> permissionsGranted() =>
      PermissionService.instance.notificationsGranted();

  /// The last date [rescheduleAll] guaranteed reminders through. Null if
  /// nothing has been scheduled yet. Screens can use this to warn the user
  /// when the rolling window is about to run dry (e.g. because the app
  /// hasn't been opened in a while and no background refresh landed).
  Future<DateTime?> scheduledThroughDate() async {
    final prefs = _prefs ??= await SharedPreferences.getInstance();
    final raw = prefs.getString(_scheduledThroughKey);
    if (raw == null) return null;
    try {
      return DoseLogic.strToDate(raw);
    } catch (_) {
      return null;
    }
  }

  /// True if the most recent schedule pass had to fall back to inexact
  /// alarms on Android (exact alarms disallowed for this app). Timing may
  /// drift by a few minutes in that case.
  Future<bool> usedInexactAlarmFallback() async {
    final prefs = _prefs ??= await SharedPreferences.getInstance();
    return prefs.getBool(_fallbackUsedKey) ?? false;
  }

  /// The last error message from a failed/timed-out reschedule pass, or null
  /// if the most recent attempt succeeded (or none has run yet). Surfaced in
  /// Settings so a silent scheduling failure — the platform channel hanging
  /// or throwing — is no longer invisible to both the user and to support.
  Future<String?> lastScheduleError() async {
    final prefs = _prefs ??= await SharedPreferences.getInstance();
    return prefs.getString(_lastErrorKey);
  }

  /// When [rescheduleAll] last completed successfully, or null if it never
  /// has on this device.
  Future<DateTime?> lastScheduleSuccess() async {
    final prefs = _prefs ??= await SharedPreferences.getInstance();
    final raw = prefs.getString(_lastSuccessKey);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  // Sound/presentation are set explicitly everywhere below rather than
  // leaning on platform defaults — Android's default *is* sound-on, but an
  // immutable channel from an old build can silently override it (see the
  // channel-id comment above), and it costs nothing to be explicit on iOS
  // too instead of trusting init-time defaults to propagate correctly.
  NotificationDetails get _details => const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.max,
          priority: Priority.high,
          category: AndroidNotificationCategory.reminder,
          playSound: true,
          enableVibration: true,
          enableLights: true,
          visibility: NotificationVisibility.public,
        ),
        iOS: DarwinNotificationDetails(
          interruptionLevel: InterruptionLevel.timeSensitive,
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          presentBanner: true,
          presentList: true,
          // Deliberately omitted: leaving `sound` unset with presentSound:
          // true is how this plugin requests the system's *default*
          // notification sound. Setting it to any string (even 'default')
          // tells iOS to look for a bundled sound file with that exact
          // name — which doesn't exist here — and there's no fallback to
          // the system default in that case, only silence.
        ),
      );

  String _body(Dose dose) {
    final eye = dose.eye.label.toLowerCase();
    var body = 'Time for ${dose.medicationName} — $eye.';
    final instr = dose.instructions.summary;
    if (instr.isNotEmpty) body += ' ${instr.first} first.';
    return body;
  }

  /// Rebuilds the reminder schedule for a rolling window of real dates ahead
  /// (sized to stay under iOS's pending-notification cap), using each day's
  /// own taper-aware dose times — so a taper step or an end date that lands
  /// partway through the window is scheduled correctly today, not only once
  /// the app happens to be reopened on that exact day.
  ///
  /// New/changed slots are scheduled first; anything no longer needed is only
  /// cancelled afterwards, so a crash or kill mid-run never leaves the device
  /// with zero reminders.
  Future<void> rescheduleAll(List<Medication> meds, AppUser user) async {
    try {
      await _rescheduleAllInner(meds, user);
      final prefs = _prefs ??= await SharedPreferences.getInstance();
      await prefs.remove(_lastErrorKey);
      await prefs.setString(
          _lastSuccessKey, DateTime.now().toIso8601String());
    } catch (e) {
      // rescheduleAll is awaited by DropStore.updateUser() before it pushes
      // profile changes (onboarding completion included) — this method must
      // return (not hang, not rethrow past a bounded time) no matter what
      // the platform channel does, or that push silently never happens
      // either. Every native call below is timeout-wrapped for exactly this
      // reason; this outer catch is the last-resort backstop.
      debugPrint('rescheduleAll failed: $e');
      final prefs = _prefs ??= await SharedPreferences.getInstance();
      await prefs.setString(_lastErrorKey, e.toString());
    }
  }

  Future<void> _rescheduleAllInner(List<Medication> meds, AppUser user) async {
    await init();
    await _loadPersistedState();

    final today = DoseLogic.todayStr();
    final todayCount = DoseLogic.getDosesForDate(meds, today,
            wakingStart: user.wakingStart, wakingEnd: user.wakingEnd)
        .length;
    final windowDays = todayCount == 0
        ? _defaultWindowDays
        : (_iosSafeNotificationCap / todayCount)
            .floor()
            .clamp(_minWindowDays, _maxWindowDays);

    _usedInexactFallback = false;
    final desiredKeys = <String>{};
    final desiredIds = <int>{};
    final startDate = DoseLogic.strToDate(today);

    for (var i = 0; i < windowDays; i++) {
      final date = startDate.add(Duration(days: i));
      final dateStr = DoseLogic.dateToStr(date);
      final doses = DoseLogic.getDosesForDate(meds, dateStr,
          wakingStart: user.wakingStart, wakingEnd: user.wakingEnd);
      for (final dose in doses) {
        final key = '${dose.medicationId}|$dateStr|${dose.scheduledHhmm}';
        final id = _idFor(key);
        final scheduled = await _scheduleForDate(dose, dateStr, id);
        if (scheduled) {
          desiredKeys.add(key);
          desiredIds.add(id);
        }
      }
    }

    // Only now remove whatever is no longer wanted — the fresh set above is
    // already in place, so this ordering can't leave a gap with nothing
    // scheduled at all. Ids >= 0x40000000 belong to snoozes (see
    // scheduleSnooze) — they're deliberately never part of desiredIds, so
    // without this guard *every* reschedule (an app resume, any medication
    // edit) would silently cancel a pending snooze before it could fire.
    final pending =
        await _plugin.pendingNotificationRequests().timeout(_channelTimeout);
    for (final p in pending) {
      if (p.id < 0x40000000 && !desiredIds.contains(p.id)) {
        await _plugin.cancel(p.id).timeout(_channelTimeout);
      }
    }

    // Prune ids no longer in use so the persisted map doesn't grow forever.
    _idMap.removeWhere((k, _) => !desiredKeys.contains(k));
    await _persistState(
        scheduledThrough: startDate.add(Duration(days: windowDays)));
  }

  /// Schedules a single dated (non-repeating) notification. Returns false —
  /// without throwing — if the computed fire time has already passed (a
  /// dose earlier today, say) or if scheduling failed outright.
  Future<bool> _scheduleForDate(Dose dose, String dateStr, int id) async {
    final parts = dose.scheduledHhmm.split(':').map(int.parse).toList();
    final date = DoseLogic.strToDate(dateStr);
    var when = tz.TZDateTime(
        tz.local, date.year, date.month, date.day, parts[0], parts[1]);

    // The OS fires against the device's own clock, so a device running fast
    // or slow would fire at the wrong real-world moment. Shift by the
    // measured device↔server offset: a phone 40 minutes fast needs a 07:00
    // dose scheduled at 07:40 by its own reckoning to actually fire at 07:00.
    final correction = TrustedClock.instance.schedulingCorrection();
    if (correction != Duration.zero) {
      when = when.subtract(correction);
    }

    if (when.isBefore(tz.TZDateTime.now(tz.local))) {
      // A dated, one-off notification for a time that's already passed has
      // nothing to roll forward to — just skip it.
      return false;
    }

    try {
      await _plugin
          .zonedSchedule(
            id,
            'Drop Tracker',
            _body(dose),
            when,
            _details,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
          )
          .timeout(_channelTimeout);
      return true;
    } catch (e) {
      // Exact alarms may be disallowed; fall back to inexact.
      try {
        await _plugin
            .zonedSchedule(
              id,
              'Drop Tracker',
              _body(dose),
              when,
              _details,
              androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
              uiLocalNotificationDateInterpretation:
                  UILocalNotificationDateInterpretation.absoluteTime,
            )
            .timeout(_channelTimeout);
        _usedInexactFallback = true;
        return true;
      } catch (err) {
        debugPrint('Failed to schedule reminder: $err');
        return false;
      }
    }
  }

  /// Deterministic per (medication, dose-time) — snoozing the *same* dose
  /// again reuses this id, so it *replaces* the still-pending snooze rather
  /// than stacking a second one. Always >= 0x40000000, a range the managed
  /// schedule's own ids (see [_idFor]) never reach, so [rescheduleAll]'s
  /// stale-id cleanup can safely skip anything in this range without ever
  /// touching a pending snooze.
  @visibleForTesting
  static int snoozeIdFor(String medicationId, String scheduledHhmm) =>
      0x40000000 |
      ((medicationId.hashCode ^ scheduledHhmm.hashCode ^ 0x5eed) &
          0x3fffffff);

  /// Snooze: a single **one-off** reminder [minutes] from now — there is no
  /// repeat flag anywhere in this call, so a snooze can never itself become
  /// a recurring notification. Calling this again for the same dose (e.g.
  /// the user snoozes twice) replaces the pending one via [snoozeIdFor]'s
  /// determinism rather than creating a second, stacked notification.
  Future<void> scheduleSnooze(Dose dose, {int minutes = 10}) async {
    await init();
    final when = tz.TZDateTime.now(tz.local).add(Duration(minutes: minutes));
    final id = snoozeIdFor(dose.medicationId, dose.scheduledHhmm);
    try {
      await _plugin
          .zonedSchedule(
            id,
            'Drop Tracker — snoozed',
            _body(dose),
            when,
            _details,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
          )
          .timeout(_channelTimeout);
    } catch (e) {
      debugPrint('Failed to schedule snooze: $e');
    }
  }

  /// Shown immediately (not scheduled) when a server-pushed reminder
  /// arrives via FCM and this device's own local scheduling has been
  /// confirmed *not* working — see FcmService's doc comment for the full
  /// reasoning. Uses a third id range (0x50000000+, disjoint from both the
  /// managed schedule's ids and the snooze range at 0x40000000+) so it can
  /// never collide with or be swept up by rescheduleAll's stale-id cleanup.
  Future<void> showFallbackAlert({
    required String medicationId,
    required String scheduledDate,
    required String scheduledHhmm,
    required String medicationName,
    required String eye,
  }) async {
    await init();
    final id = 0x50000000 |
        ((medicationId.hashCode ^
                scheduledDate.hashCode ^
                scheduledHhmm.hashCode ^
                0x5eed) &
            0x2fffffff);
    final eyeLabel = eye.isEmpty ? '' : ' — ${eye.toLowerCase()}';
    try {
      await _plugin
          .show(
            id,
            'Drop Tracker',
            'Time for $medicationName$eyeLabel.',
            _details,
          )
          .timeout(_channelTimeout);
    } catch (e) {
      debugPrint('Failed to show fallback alert: $e');
    }
  }

  Future<void> cancelAll() async {
    await init();
    try {
      await _plugin.cancelAll().timeout(_channelTimeout);
    } catch (e) {
      debugPrint('cancelAll failed: $e');
    }
    _idMap.clear();
    _nextId = 1000;
    _usedInexactFallback = false;
    _stateLoaded = true;
    final prefs = _prefs ??= await SharedPreferences.getInstance();
    await prefs.remove(_idMapKey);
    await prefs.remove(_nextIdKey);
    await prefs.remove(_scheduledThroughKey);
    await prefs.remove(_fallbackUsedKey);
    await prefs.remove(_lastErrorKey);
    await prefs.remove(_lastSuccessKey);
  }
}
