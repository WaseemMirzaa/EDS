import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:uuid/uuid.dart';

import '../models/app_user.dart';
import '../models/dose.dart';
import '../models/dose_event.dart';
import '../models/enums.dart';
import '../models/medication.dart';
import 'dose_logic.dart';
import 'notification_service.dart';
import 'presets.dart';
import 'remote/supabase_bootstrap.dart';
import 'remote/supabase_config.dart';
import 'remote/supabase_sync.dart';
import 'trusted_clock.dart';

/// App-wide state + persistence.
///
/// Local-first: every read renders from the on-device SharedPreferences cache,
/// and every mutation writes there first, so the UI never waits on a network
/// round trip. Once a Supabase project is configured (see
/// data/remote/supabase_config.dart) and the user is signed in, the same
/// mutation is also pushed to Postgres in the background — best-effort, logged
/// on failure, never blocking — and [init] pulls the account down on launch,
/// migrating any local-only data up on first sign-in. With no Supabase project
/// configured, this behaves exactly as the original local/guest-mode design
/// (Proposal §3.5): nothing here changes until a project exists.
class DropStore extends ChangeNotifier {
  static const _medsKey = 'droptracker_medications';
  static const _eventsKey = 'droptracker_dose_events';
  static const _userKey = 'droptracker_user';

  final _uuid = const Uuid();
  late SharedPreferences _prefs;

  AppUser _user = const AppUser();
  List<Medication> _meds = [];
  List<DoseEvent> _events = [];
  bool _loaded = false;

  AppUser get user => _user;
  List<Medication> get medications => List.unmodifiable(_meds);
  List<DoseEvent> get events => List.unmodifiable(_events);
  bool get loaded => _loaded;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    // Restore the last known device↔server clock offset before anything is
    // read or written, so timestamps are stamped consistently from first use.
    await TrustedClock.instance.init(_prefs);
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
      SupabaseBootstrap.client.auth.onAuthStateChange.listen((state) {
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
    }
  }

  /// Drops the local cache back to an empty, unonboarded state on sign-out —
  /// otherwise the next account to sign in on this device would briefly see
  /// the previous account's medications rendered from local cache before its
  /// own pull completes. Server-side data is never at risk either way (row-
  /// level security scopes every query to the authenticated user), this is
  /// purely about what the UI shows locally in that window.
  Future<void> _clearForSignOut() async {
    _meds = [];
    _events = [];
    _user = const AppUser();
    await Future.wait([_persistUser(), _persistMeds(), _persistEvents()]);
    notifyListeners();
    await NotificationService.instance.cancelAll();
  }

  /// Reconciles the local cache against the account once signed in:
  ///   * no profile row yet (first time this account has ever synced) →
  ///     migrate the local cache up, so guest data isn't lost on sign-up;
  ///   * a profile row exists → the server is the account's source of truth,
  ///     so pull it down and replace the local cache.
  Future<void> _syncAccount() async {
    if (!SupabaseSync.isAvailable) return;
    await SupabaseSync.syncClock();

    final remoteUser = await SupabaseSync.pullProfile();
    if (remoteUser == null) {
      await _migrateLocalToRemote();
      return;
    }

    _user = remoteUser;
    final remoteMeds = await SupabaseSync.pullMedications();
    final remoteEvents = await SupabaseSync.pullDoseEvents();
    _meds = remoteMeds;
    _events = remoteEvents;
    await Future.wait([_persistUser(), _persistMeds(), _persistEvents()]);
    notifyListeners();
    await _syncReminders();
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
    try {
      await NotificationService.instance.rescheduleAll(_meds, _user);
    } catch (e) {
      debugPrint('reminder sync failed: $e');
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
    // Waking-hour changes recompute auto-spaced times → reschedule.
    await _syncReminders();
    unawaited(SupabaseSync.pushProfile(_user));
  }

  // ---- medications ----------------------------------------------------------

  Future<Medication> addMedication(Medication draft) async {
    final med = draft.copyWith(id: _uuid.v4());
    _meds.add(med);
    await _persistMeds();
    notifyListeners();
    await _syncReminders();
    unawaited(SupabaseSync.pushMedication(med));
    return med;
  }

  Future<void> updateMedication(String id, Medication updated) async {
    final idx = _meds.indexWhere((m) => m.id == id);
    if (idx == -1) return;
    final med = updated.copyWith(id: id);
    _meds[idx] = med;
    await _persistMeds();
    notifyListeners();
    await _syncReminders();
    unawaited(SupabaseSync.pushMedication(med));
  }

  Future<void> deleteMedication(String id) async {
    _meds.removeWhere((m) => m.id == id);
    await _persistMeds();
    notifyListeners();
    await _syncReminders();
    unawaited(SupabaseSync.deleteMedication(id));
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
      unawaited(SupabaseSync.pushMedication(med));
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
    unawaited(SupabaseSync.pushDoseEvent(event));
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
