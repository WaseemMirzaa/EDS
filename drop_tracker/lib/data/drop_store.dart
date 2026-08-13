import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/app_user.dart';
import '../models/dose.dart';
import '../models/dose_event.dart';
import '../models/enums.dart';
import '../models/medication.dart';
import 'dose_logic.dart';
import 'notification_service.dart';
import 'presets.dart';
import 'trusted_clock.dart';

/// App-wide state + local persistence. Guest mode with on-device storage,
/// exactly as the prototype (Proposal §3.5) — the seam where a Firebase /
/// Supabase backend would later plug in (M2).
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
  }

  // ---- medications ----------------------------------------------------------

  Future<Medication> addMedication(Medication draft) async {
    final med = draft.copyWith(id: _uuid.v4());
    _meds.add(med);
    await _persistMeds();
    notifyListeners();
    await _syncReminders();
    return med;
  }

  Future<void> updateMedication(String id, Medication updated) async {
    final idx = _meds.indexWhere((m) => m.id == id);
    if (idx == -1) return;
    _meds[idx] = updated.copyWith(id: id);
    await _persistMeds();
    notifyListeners();
    await _syncReminders();
  }

  Future<void> deleteMedication(String id) async {
    _meds.removeWhere((m) => m.id == id);
    await _persistMeds();
    notifyListeners();
    await _syncReminders();
  }

  Future<void> applyPreset(Preset preset) async {
    final drafts = preset.build(DoseLogic.todayStr());
    for (final draft in drafts) {
      _meds.add(draft.copyWith(id: _uuid.v4()));
    }
    await _persistMeds();
    notifyListeners();
    await _syncReminders();
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
    _events.add(DoseEvent(
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
    ));
    await _persistEvents();
    notifyListeners();
  }

  // ---- account --------------------------------------------------------------

  /// In-app account deletion (Proposal §04, required for iOS): wipes all local
  /// data and cancels every scheduled reminder.
  Future<void> deleteAllData() async {
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
