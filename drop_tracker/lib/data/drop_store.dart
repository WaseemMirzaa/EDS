import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:uuid/uuid.dart';

import '../models/app_user.dart';
import '../models/dose.dart';
import '../models/dose_event.dart';
import '../models/enums.dart';
import '../models/medication.dart';
import 'background_scheduler.dart';
import 'dose_logic.dart';
import 'notification_service.dart';
import 'presets.dart';
// FCM push is disabled — see main.dart's commented-out Firebase init.
// import 'remote/fcm_service.dart';
import 'remote/supabase_bootstrap.dart';
import 'remote/supabase_config.dart';
import 'remote/supabase_realtime.dart';
import 'remote/supabase_sync.dart';
import 'remote/sync_outbox.dart';
import 'trusted_clock.dart';

/// App-wide state + persistence.
///
/// Local-first: every read renders from the on-device SharedPreferences cache,
/// and every mutation writes there first, so the UI never waits on a network
/// round trip. Once a Supabase project is configured (see
/// data/remote/supabase_config.dart) and the user is signed in:
///   * every mutation is also pushed to Postgres in the background — if that
///     push fails (typically no connectivity), it's queued in [SyncOutbox]
///     and retried until it confirms, rather than silently dropped;
///   * [init] pulls the account down on launch and migrates any local-only
///     data up on first sign-in;
///   * [SupabaseRealtime] keeps this device live — a change made on another
///     device (or by another provider integration) is reflected here without
///     reopening the app.
/// With no Supabase project configured, none of the above runs: the app
/// behaves exactly as the original local/guest-mode design (Proposal §3.5).
class DropStore extends ChangeNotifier {
  static const _medsKey = 'droptracker_medications';
  static const _eventsKey = 'droptracker_dose_events';
  static const _userKey = 'droptracker_user';

  final _uuid = const Uuid();
  late SharedPreferences _prefs;
  late SyncOutbox _outbox;
  Timer? _retryTimer;
  StreamSubscription<sb.AuthState>? _authSub;
  AppLifecycleListener? _lifecycleListener;

  AppUser _user = const AppUser();
  List<Medication> _meds = [];
  List<DoseEvent> _events = [];
  bool _loaded = false;

  AppUser get user => _user;
  List<Medication> get medications => List.unmodifiable(_meds);
  List<DoseEvent> get events => List.unmodifiable(_events);
  bool get loaded => _loaded;

  /// Number of local mutations still waiting to reach the server. Surfaced so
  /// Settings can show a small "N changes pending sync" indicator rather than
  /// this being invisible.
  int get pendingSyncCount => _outbox.length;

  /// Reads just enough of the persisted cache to rebuild notifications,
  /// without needing a live [DropStore] instance — for use from the
  /// background isolate a periodic task runs in (see
  /// data/background_scheduler.dart), which has no [ChangeNotifier] tree or
  /// Provider context to attach to.
  static Future<(List<Medication>, AppUser)> loadPersistedForBackground() async {
    final prefs = await SharedPreferences.getInstance();
    final userRaw = prefs.getString(_userKey);
    final user = userRaw != null
        ? AppUser.fromJson(jsonDecode(userRaw) as Map<String, dynamic>)
        : const AppUser();
    final medsRaw = prefs.getString(_medsKey);
    List<Medication> meds = [];
    if (medsRaw != null) {
      try {
        meds = (jsonDecode(medsRaw) as List)
            .cast<Map<String, dynamic>>()
            .map((e) => Medication.fromJson(e))
            .toList();
      } catch (_) {}
    }
    return (meds, user);
  }

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    // Restore the last known device↔server clock offset before anything is
    // read or written, so timestamps are stamped consistently from first use.
    await TrustedClock.instance.init(_prefs);
    _outbox = await SyncOutbox.load(_prefs);
    _load();
    _loaded = true;
    notifyListeners();
    // Fire-and-forget: keep native reminders in sync with stored schedule.
    _syncReminders();

    if (SupabaseConfig.isConfigured) {
      // Covers a session already restored at launch (Supabase.initialize()
      // completes, with any persisted session, before this runs — see
      // main.dart). The UI has already rendered the local cache above, so
      // this only ever refines what's shown, never blocks first paint.
      unawaited(_syncAccount());

      // Covers every sign-in/out that happens *after* launch — without this,
      // DropStore would only ever see whatever was true at cold start, and a
      // user who signs in from the Auth flow would keep looking at an empty
      // or stale local cache until they force-quit and reopened the app.
      _authSub = SupabaseBootstrap.client.auth.onAuthStateChange.listen((state) {
        switch (state.event) {
          case sb.AuthChangeEvent.signedIn:
          case sb.AuthChangeEvent.tokenRefreshed:
            unawaited(_syncAccount());
          case sb.AuthChangeEvent.signedOut:
            unawaited(_clearForSignOut());
          default:
            break;
        }
      });

      // Retry the outbox opportunistically: on a timer while the app is open
      // (catches "connectivity came back" with no other trigger), and every
      // time the app returns to the foreground (the most likely moment a
      // previously-offline device has a connection again). No new package
      // needed for either — this app doesn't otherwise need continuous
      // connectivity *detection*, only periodic connectivity *attempts*.
      _retryTimer = Timer.periodic(const Duration(seconds: 45), (_) {
        unawaited(_outbox.flush());
      });
      _lifecycleListener =
          AppLifecycleListener(onResume: () => unawaited(_outbox.flush()));
    }
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _authSub?.cancel();
    _lifecycleListener?.dispose();
    SupabaseRealtime.instance.stop();
    super.dispose();
  }

  /// Drops the local cache back to an empty, unonboarded state on sign-out —
  /// otherwise the next account to sign in on this device would briefly see
  /// the previous account's medications rendered from local cache before its
  /// own pull completes. Server-side data is never at risk either way (row-
  /// level security scopes every query to the authenticated user), this is
  /// purely about what the UI shows locally in that window.
  Future<void> _clearForSignOut() async {
    SupabaseRealtime.instance.stop();
    _meds = [];
    _events = [];
    _user = const AppUser();
    await Future.wait([_persistUser(), _persistMeds(), _persistEvents()]);
    notifyListeners();
    await NotificationService.instance.cancelAll();
    unawaited(BackgroundScheduler.cancel());
  }

  /// Reconciles the local cache against the account once signed in:
  ///   * no profile row yet (first time this account has ever synced) →
  ///     migrate the local cache up, so guest data isn't lost on sign-up;
  ///   * a profile row exists → the server is the account's source of truth,
  ///     so pull it down and replace the local cache.
  /// Either way, starts (or restarts) the realtime subscription and drains
  /// anything left over in the outbox from a previous session.
  Future<void> _syncAccount() async {
    if (!SupabaseSync.isAvailable) return;
    await SupabaseSync.syncClock();

    // Drain anything still queued from a previous session — most
    // importantly, onboarding completion (or any other profile/medication
    // write) that failed to push and was queued instead — BEFORE pulling.
    // Pulling first would read the server's still-stale state (e.g.
    // `onboarded: false`, since 005_profile_bootstrap.sql's trigger creates
    // the profile row at signup with nothing but a name) and overwrite the
    // correct local value with it, undoing a completed onboarding on the
    // very next sign-in. Awaited, not fire-and-forget, so the pull below is
    // guaranteed to see whatever this flush just landed.
    await _outbox.flush();

    final uid = SupabaseBootstrap.client.auth.currentUser!.id;
    final remoteUser = await SupabaseSync.pullProfile();
    if (remoteUser == null) {
      await _migrateLocalToRemote();
    } else {
      _user = remoteUser;
      final remoteMeds = await SupabaseSync.pullMedications();
      final remoteEvents = await SupabaseSync.pullDoseEvents();
      _meds = remoteMeds;
      _events = remoteEvents;
      await Future.wait([_persistUser(), _persistMeds(), _persistEvents()]);
      notifyListeners();
      await _syncReminders();
    }

    SupabaseRealtime.instance.start(
      userId: uid,
      onMedicationsChanged: () => unawaited(_pullMedicationsIntoCache()),
      onDoseEventsChanged: () => unawaited(_pullDoseEventsIntoCache()),
      onProfileChanged: () => unawaited(_pullProfileIntoCache()),
    );

    // FCM disabled — see main.dart.
    // unawaited(FcmService.instance.registerDevice());

    unawaited(_outbox.flush());
  }

  /// First sync for a new account: whatever is already in the local cache
  /// (guest-mode data, or an earlier local-only session) becomes the seed for
  /// this account server-side, rather than being silently discarded.
  Future<void> _migrateLocalToRemote() async {
    await SupabaseSync.pushProfile(_user);
    for (final med in _meds) {
      await SupabaseSync.pushMedication(med);
    }
    for (final event in _events) {
      await SupabaseSync.pushDoseEvent(event);
    }
  }

  // ---- realtime pull handlers -------------------------------------------
  // Each re-pulls its whole slice and replaces local state. See
  // SupabaseRealtime's doc comment for why a full re-pull, not a per-row
  // patch, is the right amount of complexity here.

  Future<void> _pullMedicationsIntoCache() async {
    final remote = await SupabaseSync.pullMedications();
    _meds = remote;
    await _persistMeds();
    notifyListeners();
    await _syncReminders();
  }

  Future<void> _pullDoseEventsIntoCache() async {
    final remote = await SupabaseSync.pullDoseEvents();
    _events = remote;
    await _persistEvents();
    notifyListeners();
  }

  Future<void> _pullProfileIntoCache() async {
    final remote = await SupabaseSync.pullProfile();
    if (remote == null) return;
    _user = remote;
    await _persistUser();
    notifyListeners();
    await _syncReminders();
  }

  void _load() {
    final userRaw = _prefs.getString(_userKey);
    _user = userRaw != null
        ? AppUser.fromJson(jsonDecode(userRaw) as Map<String, dynamic>)
        : const AppUser();

    _meds = _decodeList(_medsKey)
        .map((e) => Medication.fromJson(e))
        .toList(growable: true);
    _events = _decodeList(_eventsKey)
        .map((e) => DoseEvent.fromJson(e))
        .toList(growable: true);
  }

  List<Map<String, dynamic>> _decodeList(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<void> _persistUser() =>
      _prefs.setString(_userKey, jsonEncode(_user.toJson()));
  Future<void> _persistMeds() => _prefs.setString(
      _medsKey, jsonEncode(_meds.map((m) => m.toJson()).toList()));
  Future<void> _persistEvents() => _prefs.setString(
      _eventsKey, jsonEncode(_events.map((e) => e.toJson()).toList()));

  Future<void> _syncReminders() async {
    // Same input, same window as the local reschedule below — publishing
    // it is what lets the server-side scheduler fire pushes at identical
    // real-world moments without re-deriving taper/frequency logic of its
    // own. Fire-and-forget: this is the cross-device/fallback layer, never
    // a prerequisite for local reminders working (see FcmService's doc
    // comment) — it must not be able to delay or block the line below.
    // FCM disabled — see main.dart.
    // unawaited(FcmService.instance.publishSchedule(_meds, _user));
    try {
      await NotificationService.instance.rescheduleAll(_meds, _user);
      // Keeps the rolling window topped up even if the app isn't opened
      // again for a while — see BackgroundScheduler's doc comment for what
      // this can and can't guarantee per platform.
      unawaited(BackgroundScheduler.schedulePeriodic());
    } catch (e) {
      debugPrint('reminder sync failed: $e');
    }
  }

  // ---- background push helpers ----------------------------------------
  // Try immediately; if that fails (almost always: no connectivity), queue
  // for retry rather than losing the write. Never awaited by a mutation
  // method — the local save has already happened and the UI has already
  // updated by the time these run.

  Future<void> _pushProfileWithRetry() async {
    if (!SupabaseSync.isAvailable) return;
    try {
      final row = await SupabaseSync.buildProfileRow(_user);
      await SupabaseSync.pushProfileRaw(row);
    } catch (e) {
      debugPrint('profile push failed, queued for retry: $e');
      final row = await SupabaseSync.buildProfileRow(_user);
      await _outbox.enqueueProfile(row);
    }
  }

  Future<void> _pushMedicationWithRetry(Medication med) async {
    if (!SupabaseSync.isAvailable) return;
    final row = SupabaseSync.medicationRow(med);
    final taperRows = SupabaseSync.taperStepRows(med);
    try {
      await SupabaseSync.pushMedicationRaw(row, taperRows);
    } catch (e) {
      debugPrint('medication push failed, queued for retry: $e');
      await _outbox.enqueueMedication(row, taperRows);
    }
  }

  Future<void> _deleteMedicationWithRetry(String id) async {
    if (!SupabaseSync.isAvailable) return;
    try {
      await SupabaseSync.deleteMedicationRaw(id);
    } catch (e) {
      debugPrint('medication delete failed, queued for retry: $e');
      await _outbox.enqueueMedicationDelete(id);
    }
  }

  Future<void> _pushDoseEventWithRetry(DoseEvent event) async {
    if (!SupabaseSync.isAvailable) return;
    final row = SupabaseSync.doseEventRow(event);
    try {
      await SupabaseSync.pushDoseEventRaw(row);
    } catch (e) {
      debugPrint('dose event push failed, queued for retry: $e');
      await _outbox.enqueueDoseEvent(row);
    }
  }

  // ---- user -----------------------------------------------------------------

  Future<void> updateUser({
    String? firstName,
    String? wakingStart,
    String? wakingEnd,
    bool? onboarded,
    bool? hasSeenDisclaimer,
  }) async {
    _user = _user.copyWith(
      firstName: firstName,
      wakingStart: wakingStart,
      wakingEnd: wakingEnd,
      onboarded: onboarded,
      hasSeenDisclaimer: hasSeenDisclaimer,
    );
    await _persistUser();
    notifyListeners();
    // Fired before (not after) _syncReminders — the server push, which is
    // how onboarding completion and every other profile change actually
    // reaches the account, must never be gated behind reminder scheduling
    // succeeding or even finishing. rescheduleAll is internally timeout-
    // bounded now, but there's no reason for this to wait on it at all.
    unawaited(_pushProfileWithRetry());
    // Waking-hour changes recompute auto-spaced times → reschedule.
    await _syncReminders();
  }

  // ---- medications ----------------------------------------------------------

  Future<Medication> addMedication(Medication draft) async {
    final med = draft.copyWith(id: _uuid.v4());
    _meds.add(med);
    await _persistMeds();
    notifyListeners();
    unawaited(_pushMedicationWithRetry(med));
    await _syncReminders();
    return med;
  }

  Future<void> updateMedication(String id, Medication updated) async {
    final idx = _meds.indexWhere((m) => m.id == id);
    if (idx == -1) return;
    final med = updated.copyWith(id: id);
    _meds[idx] = med;
    await _persistMeds();
    notifyListeners();
    unawaited(_pushMedicationWithRetry(med));
    await _syncReminders();
  }

  Future<void> deleteMedication(String id) async {
    _meds.removeWhere((m) => m.id == id);
    await _persistMeds();
    notifyListeners();
    unawaited(_deleteMedicationWithRetry(id));
    await _syncReminders();
  }

  Future<void> applyPreset(Preset preset) async {
    final drafts = preset.build(DoseLogic.todayStr());
    final added = <Medication>[];
    for (final draft in drafts) {
      final med = draft.copyWith(id: _uuid.v4());
      _meds.add(med);
      added.add(med);
    }
    await _persistMeds();
    notifyListeners();
    await _syncReminders();
    for (final med in added) {
      unawaited(_pushMedicationWithRetry(med));
    }
  }

  // ---- dose events ----------------------------------------------------------

  /// Log a Confidence-Check response.
  ///
  /// Improvement over the prototype: *Snooze* keeps the dose pending (no
  /// terminal record) and simply reschedules the reminder 10 minutes out,
  /// matching the proposal's described behaviour.
  Future<void> logResponse(Dose dose, DoseResponse response) async {
    if (response == DoseResponse.snoozed) {
      await NotificationService.instance.scheduleSnooze(dose, minutes: 10);
      // Mirrors the same +10-minutes snooze to the server-side scheduler,
      // so snoozing on this device is honoured on every signed-in device —
      // see FcmService.publishSnooze's doc comment.
      // FCM disabled — see main.dart.
      // unawaited(FcmService.instance.publishSnooze(
      //     dose.medicationId, dose.scheduledDate, dose.scheduledHhmm,
      //     minutes: 10));
      return;
    }
    // Replace any prior terminal event for this exact dose slot.
    _events.removeWhere((e) =>
        e.medicationId == dose.medicationId &&
        e.scheduledHhmm == dose.scheduledHhmm &&
        e.scheduledDate == dose.scheduledDate);
    final event = DoseEvent(
      id: _uuid.v4(),
      medicationId: dose.medicationId,
      medicationName: dose.medicationName,
      bottleCapColor: dose.bottleCapColor,
      eye: dose.eye,
      scheduledTime: dose.scheduledTime,
      scheduledDate: dose.scheduledDate,
      scheduledHhmm: dose.scheduledHhmm,
      response: response,
      responseTime: DateTime.now().toIso8601String(),
      // Device reading + its difference from server UTC, so this record stays
      // verifiable even if the phone's clock is wrong or later changed.
      stamp: TrustedClock.instance.stamp(),
      instructionFlags: dose.instructions.toJson(),
    );
    _events.add(event);
    await _persistEvents();
    notifyListeners();
    unawaited(_pushDoseEventWithRetry(event));
  }

  // ---- account --------------------------------------------------------------

  /// In-app account deletion (Proposal §04, required for iOS): wipes all local
  /// data, cancels every scheduled reminder, and — once signed in against
  /// Supabase — removes the account server-side too (delete_my_account() in
  /// db/migrations/002 cascades from profiles, taking every medication and
  /// dose event with it). Called before the caller signs the session out.
  Future<void> deleteAllData() async {
    if (SupabaseSync.isAvailable) {
      try {
        await SupabaseBootstrap.client.rpc('delete_my_account');
      } catch (e) {
        debugPrint('remote account deletion failed: $e');
      }
    }
    _meds = [];
    _events = [];
    _user = const AppUser();
    await _prefs.remove(_medsKey);
    await _prefs.remove(_eventsKey);
    await _prefs.remove(_userKey);
    await NotificationService.instance.cancelAll();
    unawaited(BackgroundScheduler.cancel());
    notifyListeners();
  }

  Future<void> logOut() async {
    // Local/guest session — clearing onboarding returns to the welcome flow
    // without destroying medications.
    _user = _user.copyWith(onboarded: false);
    await _persistUser();
    notifyListeners();
  }

  // ---- convenience selectors ------------------------------------------------

  List<Dose> dosesFor(String dateStr) => DoseLogic.getDosesForDate(
        _meds,
        dateStr,
        wakingStart: _user.wakingStart,
        wakingEnd: _user.wakingEnd,
      );

  List<DoseEvent> eventsOn(String dateStr) =>
      _events.where((e) => e.scheduledDate == dateStr).toList();

  List<DoseEvent> eventsSince(String startDate) =>
      _events.where((e) => e.scheduledDate.compareTo(startDate) >= 0).toList();
}
