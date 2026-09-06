import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';

import 'drop_store.dart';
import 'notification_service.dart';

/// Best-effort background top-up for the reminder schedule.
///
/// [NotificationService.rescheduleAll] already schedules a rolling window of
/// real, dated reminders (1–2 weeks, depending on dose count) so the app
/// survives being closed for a while. This is the belt-and-suspenders layer
/// on top: a periodic OS-level task that re-runs the same scheduling logic
/// without the app being opened, so the window keeps getting topped up
/// during longer stretches of inactivity.
///
/// Platform reality check:
///  * Android's WorkManager runs this fairly reliably, modulo Doze/battery
///    restrictions (see the battery-optimisation guidance screen).
///  * iOS's BGTaskScheduler is opportunistic — the OS decides if/when to run
///    it based on the user's actual app-usage pattern, and may skip it
///    entirely for a rarely-opened app. It genuinely cannot be relied upon
///    alone, which is exactly why [NotificationService]'s own multi-day
///    window is the real safety margin and this is only a top-up.
class BackgroundScheduler {
  BackgroundScheduler._();

  /// Unique identifier for the periodic task. On iOS this doubles as the
  /// BGTaskScheduler identifier and MUST be listed in Info.plist under
  /// `BGTaskSchedulerPermittedIdentifiers`, AND registered from
  /// `ios/Runner/AppDelegate.swift` before `GeneratedPluginRegistrant`
  /// runs — BGTaskScheduler crashes hard (uncatchable
  /// NSInternalInconsistencyException) if `schedulePeriodic()` below
  /// ever submits a request for an identifier with no launch handler
  /// registered yet in the current process, which is unavoidably true
  /// the very first time this runs after install. Keep this string in
  /// sync across all three places.
  static const String taskUniqueName = 'com.eyedropshop.droptracker.reminderRefresh';
  static const String taskName = 'reminderRefresh';

  /// Registers the callback dispatcher with the OS. Call once, early in
  /// `main()`, before `runApp`.
  static Future<void> initialize() async {
    try {
      await Workmanager().initialize(callbackDispatcher);
    } catch (e) {
      // Best-effort: if platform setup is incomplete (e.g. running on a
      // platform without the plugin implementation) the app should still
      // work — NotificationService's own rolling window doesn't depend on
      // this.
      debugPrint('BackgroundScheduler.initialize failed: $e');
    }
  }

  /// (Re)registers the periodic refresh. Safe to call repeatedly — the same
  /// [taskUniqueName] means later calls update rather than duplicate it.
  static Future<void> schedulePeriodic() async {
    try {
      await Workmanager().registerPeriodicTask(
        taskUniqueName,
        taskName,
        // Android's practical minimum is 15 minutes; a day is plenty for
        // topping up a multi-day window. iOS ignores this and schedules
        // opportunistically instead.
        frequency: const Duration(hours: 20),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
        constraints: Constraints(networkType: NetworkType.notRequired),
      );
    } catch (e) {
      debugPrint('BackgroundScheduler.schedulePeriodic failed: $e');
    }
  }

  /// Cancels the periodic refresh — called alongside
  /// [NotificationService.cancelAll] on sign-out / account deletion, so a
  /// signed-out device doesn't keep waking up to reschedule reminders for
  /// data it no longer owns.
  static Future<void> cancel() async {
    try {
      await Workmanager().cancelByUniqueName(taskUniqueName);
    } catch (e) {
      debugPrint('BackgroundScheduler.cancel failed: $e');
    }
  }
}

/// Runs in a separate background isolate with no access to the running app's
/// widget tree, Provider context, or [DropStore] instance — it rebuilds just
/// enough state from the persisted SharedPreferences cache to top up the
/// notification schedule.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      final (meds, user) = await DropStore.loadPersistedForBackground();
      await NotificationService.instance.rescheduleAll(meds, user);
    } catch (e) {
      // Any failure here just means this cycle's top-up didn't happen — the
      // next scheduled run, or the app being opened, will retry. Nothing to
      // surface to a user who isn't there to see it.
      debugPrint('Background reminder refresh failed: $e');
    }
    return true;
  });
}
