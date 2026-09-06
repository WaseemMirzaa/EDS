import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show WidgetsFlutterBinding;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../firebase_options.dart';
import '../../models/app_user.dart';
import '../../models/medication.dart';
import '../dose_logic.dart';
import '../drop_store.dart';
import '../notification_service.dart';
import 'supabase_bootstrap.dart';
import 'supabase_config.dart';

/// The server-authoritative half of reminders, layered *on top of* — never
/// instead of — the device-authoritative local scheduling in
/// [NotificationService]. Local notifications stay the reliability backbone:
/// they work with zero network dependency and zero server cost. FCM earns
/// its complexity for exactly two things local scheduling can't do alone:
///
///   1. Cross-device consistency — snoozing on one device is written to
///      Supabase (see [DropStore.logResponse]) and a server-side scheduler
///      (a Supabase Edge Function on a pg_cron schedule — see
///      db/migrations/007_push_scheduling.sql and
///      supabase/functions/send-due-reminders/) reads the same
///      `scheduled_reminders` table this service publishes to, so every
///      signed-in device converges on the same schedule.
///   2. A fallback alert when local scheduling has demonstrably failed on
///      *this* device (see [_shouldShowFallbackAlert]) — e.g. an OEM battery
///      manager killed the app's alarms despite every permission being
///      granted, the exact class of failure this project spent a lot of
///      effort diagnosing and mitigating (see DeviceReliabilityService).
///
/// Deliberately NOT a general-purpose double-alert: every reminder push is
/// sent as a **data-only** message (no `notification` block), so neither
/// platform auto-displays it — this class decides whether showing a visual
/// alert is actually warranted, specifically to avoid buzzing the user twice
/// for the same dose when local scheduling is working fine (the common
/// case). True cross-channel dedup (suppressing the fallback precisely when
/// the local alarm *did* fire) isn't achievable without a native receiver
/// hook this project doesn't have; the fallback-only-when-broken design is
/// the pragmatic trade-off instead of chasing that.
///
/// iOS caveat, stated plainly: Apple does not wake a **force-quit** app for
/// a silent/data-only push at all — this is a platform limitation, not a
/// bug here. Local notifications (which iOS *does* still fire when
/// force-quit) remain the only fully reliable channel in that specific
/// state; FCM's value applies whenever the app is merely backgrounded, not
/// swiped away.
class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  static const _lastTokenKey = 'droptracker_fcm_last_registered_token';

  bool _initialized = false;

  /// Call once at startup, after Firebase.initializeApp() — see main.dart.
  /// A no-op if Supabase isn't configured (mirrors every other remote
  /// feature in this app — see SupabaseConfig's own doc comment).
  Future<void> init() async {
    if (_initialized || !SupabaseConfig.isConfigured) return;
    _initialized = true;

    FirebaseMessaging.onMessage.listen(_handleMessage);
    FirebaseMessaging.onBackgroundMessage(_backgroundHandler);
    FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      unawaited(_registerToken(token));
    });
  }

  /// Registers (or refreshes) this device's push token against the
  /// `devices` table. Call after sign-in — there's nothing to register
  /// before a user exists to own the row.
  Future<void> registerDevice() async {
    if (!SupabaseConfig.isConfigured) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await _registerToken(token);
    } catch (e) {
      debugPrint('FcmService.registerDevice failed: $e');
    }
  }

  Future<void> _registerToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_lastTokenKey) == token) {
      // Same token as last time — still touch last_seen_at so the server
      // scheduler can tell a stale/uninstalled registration from a live
      // one, but skip the full upsert churn.
      await _touchLastSeen(token);
      return;
    }
    final uid = SupabaseBootstrap.client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final info = await PackageInfo.fromPlatform();
      await SupabaseBootstrap.client.from('devices').upsert({
        'user_id': uid,
        'platform': defaultTargetPlatform == TargetPlatform.iOS
            ? 'ios'
            : 'android',
        'push_token': token,
        'app_version': '${info.version}+${info.buildNumber}',
        'last_seen_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id,push_token');
      await prefs.setString(_lastTokenKey, token);
    } catch (e) {
      debugPrint('FcmService._registerToken failed: $e');
    }
  }

  /// Removes this device's push-token row so a signed-out device stops
  /// receiving reminders for the account it just left. Must be called
  /// *before* the Supabase session itself ends (RLS requires a live
  /// `auth.uid()` to authorize the delete) — see AuthController.signOut,
  /// which calls this ahead of `_auth.signOut()`, not DropStore's own
  /// sign-out cleanup, which only runs after the session is already gone.
  Future<void> unregisterDevice() async {
    if (!SupabaseConfig.isConfigured) return;
    final uid = SupabaseBootstrap.client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_lastTokenKey);
      if (token == null) return;
      await SupabaseBootstrap.client
          .from('devices')
          .delete()
          .eq('user_id', uid)
          .eq('push_token', token);
      await prefs.remove(_lastTokenKey);
    } catch (e) {
      debugPrint('FcmService.unregisterDevice failed: $e');
    }
  }

  Future<void> _touchLastSeen(String token) async {
    final uid = SupabaseBootstrap.client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      await SupabaseBootstrap.client
          .from('devices')
          .update({'last_seen_at': DateTime.now().toUtc().toIso8601String()})
          .eq('user_id', uid)
          .eq('push_token', token);
    } catch (e) {
      debugPrint('FcmService._touchLastSeen failed: $e');
    }
  }

  /// Publishes the same rolling window [NotificationService.rescheduleAll]
  /// just scheduled locally to the `scheduled_reminders` table, so the
  /// server-side cron scheduler can fire pushes at the identical real-world
  /// moments without re-deriving taper/frequency logic itself. Call this
  /// right alongside rescheduleAll (see DropStore._syncReminders) — same
  /// input, same window, so the two channels never drift apart.
  ///
  /// Deletes this user's not-yet-sent future rows first, then inserts fresh
  /// ones — mirroring rescheduleAll's own "schedule fresh, then clean up
  /// stale" shape, so a medication that's edited or deleted stops being
  /// pushed just as reliably as it stops being locally scheduled.
  Future<void> publishSchedule(List<Medication> meds, AppUser user) async {
    if (!SupabaseConfig.isConfigured) return;
    final uid = SupabaseBootstrap.client.auth.currentUser?.id;
    if (uid == null) return;
    final client = SupabaseBootstrap.client;

    try {
      final today = DoseLogic.todayStr();
      await client
          .from('scheduled_reminders')
          .delete()
          .eq('user_id', uid)
          .isFilter('sent_at', null)
          .gte('scheduled_date', today);

      final rows = <Map<String, dynamic>>[];
      final startDate = DoseLogic.strToDate(today);
      // Same 7-day default window as NotificationService's own fallback
      // sizing — this table isn't bound by iOS's 64-pending-notification
      // cap (that's a local-scheduling constraint only), but there's no
      // reason to publish further ahead than local already commits to.
      for (var i = 0; i < 7; i++) {
        final date = startDate.add(Duration(days: i));
        final dateStr = DoseLogic.dateToStr(date);
        final doses = DoseLogic.getDosesForDate(meds, dateStr,
            wakingStart: user.wakingStart, wakingEnd: user.wakingEnd);
        for (final dose in doses) {
          final parts = dose.scheduledHhmm.split(':').map(int.parse).toList();
          // The *intended* real-world instant — deliberately NOT corrected
          // by this device's TrustedClock offset (that correction exists
          // only so a device's own possibly-wrong clock fires its local
          // AlarmManager/UNUserNotificationCenter entry at the right real
          // moment). The server has its own always-correct clock, so the
          // uncorrected local-time-in-UTC value is exactly what it needs.
          final fireAt = DateTime(date.year, date.month, date.day, parts[0],
                  parts[1])
              .toUtc();
          if (fireAt.isBefore(DateTime.now().toUtc())) continue;
          rows.add({
            'user_id': uid,
            'medication_id': dose.medicationId,
            'scheduled_date': dateStr,
            'scheduled_hhmm': dose.scheduledHhmm,
            'fire_at': fireAt.toIso8601String(),
          });
        }
      }
      if (rows.isNotEmpty) {
        await client
            .from('scheduled_reminders')
            .upsert(rows, onConflict: 'user_id,medication_id,scheduled_date,scheduled_hhmm');
      }
    } catch (e) {
      debugPrint('FcmService.publishSchedule failed: $e');
    }
  }

  /// Writes a snooze to the server, mirroring exactly what
  /// [NotificationService.scheduleSnooze] does locally — the server-side
  /// scheduler picks this up and pushes at the same +10-minutes moment, so
  /// a snooze made on one device is honoured on every signed-in device.
  Future<void> publishSnooze(
      String medicationId, String scheduledDate, String scheduledHhmm,
      {int minutes = 10}) async {
    if (!SupabaseConfig.isConfigured) return;
    final uid = SupabaseBootstrap.client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final fireAt =
          DateTime.now().toUtc().add(Duration(minutes: minutes));
      await SupabaseBootstrap.client.from('scheduled_reminders').upsert({
        'user_id': uid,
        'medication_id': medicationId,
        'scheduled_date': scheduledDate,
        'scheduled_hhmm': scheduledHhmm,
        'fire_at': fireAt.toIso8601String(),
        'sent_at': null,
      }, onConflict: 'user_id,medication_id,scheduled_date,scheduled_hhmm');
    } catch (e) {
      debugPrint('FcmService.publishSnooze failed: $e');
    }
  }

  Future<void> _handleMessage(RemoteMessage message) async {
    final data = message.data;
    if (data['type'] != 'dose_reminder') return;

    // Always resync the local schedule on receipt — cheap, and covers the
    // case where this push is what's waking up an app the OS had otherwise
    // frozen. If local scheduling is healthy, its own already-pending alarm
    // is what the user actually sees; this call doesn't itself show
    // anything.
    final (meds, user) = await DropStore.loadPersistedForBackground();
    await NotificationService.instance.rescheduleAll(meds, user);

    if (!await _shouldShowFallbackAlert()) return;

    final medicationName = (data['medication_name'] as String?) ?? 'Drop Tracker';
    final eye = (data['eye'] as String?) ?? '';
    final hhmm = (data['scheduled_hhmm'] as String?) ?? '';
    await NotificationService.instance.showFallbackAlert(
      medicationId: (data['medication_id'] as String?) ?? '',
      scheduledDate: (data['scheduled_date'] as String?) ?? '',
      scheduledHhmm: hhmm,
      medicationName: medicationName,
      eye: eye,
    );
  }

  /// True only when this device's own local scheduling is demonstrably not
  /// working — a stale/never-set scheduled-through date, or a recorded
  /// error from the last reschedule attempt. See NotificationService's
  /// lastScheduleError/scheduledThroughDate, the same diagnostics already
  /// surfaced in Settings.
  Future<bool> _shouldShowFallbackAlert() async {
    final error = await NotificationService.instance.lastScheduleError();
    if (error != null) return true;
    final through = await NotificationService.instance.scheduledThroughDate();
    if (through == null) return true;
    return through.isBefore(DateTime.now());
  }
}

/// Must be a top-level (or static) function — the plugin invokes this in a
/// fresh background isolate that shares none of main()'s state, including
/// Firebase's own initialization, so that has to happen again here too.
@pragma('vm:entry-point')
Future<void> _backgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await FcmService.instance._handleMessage(message);
}
