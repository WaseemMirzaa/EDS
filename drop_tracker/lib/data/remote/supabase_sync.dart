import 'package:flutter/foundation.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

import '../../models/app_user.dart';
import '../../models/dose_event.dart';
import '../../models/enums.dart';
import '../../models/medication.dart';
import '../../models/taper_step.dart';
import '../trusted_clock.dart';
import 'supabase_bootstrap.dart';
import 'supabase_config.dart';

/// Maps between the app's local models (see [Medication.toJson] etc., used for
/// the on-device SharedPreferences cache) and the Postgres schema in
/// `db/migrations/`.
///
/// Kept deliberately separate from the local `toJson`/`fromJson` pairs: the
/// local shape is the app's own long-standing wire format and must not change
/// just because the server's column names or types differ slightly (medications
/// nest `taper_steps` inline locally; the server normalises them into their own
/// table, for example).
///
/// Every call here is best-effort — [DropStore] writes to the local cache
/// first and always renders from it, so a failed or slow push never blocks the
/// UI. Failures are logged, not surfaced, which is the right default for a
/// background sync; the local cache is retried on next mutation and on the
/// next app launch's [pullAccount].
class SupabaseSync {
  SupabaseSync._();

  static bool get isAvailable =>
      SupabaseConfig.isConfigured &&
      SupabaseBootstrap.client.auth.currentUser != null;

  static String? get _uid => SupabaseBootstrap.client.auth.currentUser?.id;

  // ---------------------------------------------------------------- profile

  static Future<void> pushProfile(AppUser user) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      final tz = await FlutterTimezone.getLocalTimezone();
      await SupabaseBootstrap.client.from('profiles').upsert({
        'id': uid,
        'first_name': user.firstName,
        'waking_start': user.wakingStart,
        'waking_end': user.wakingEnd,
        'onboarded': user.onboarded,
        'has_seen_disclaimer': user.hasSeenDisclaimer,
        'timezone': tz,
      });
    } catch (e) {
      debugPrint('SupabaseSync.pushProfile failed: $e');
    }
  }

  /// Null when there is no session, or no profile row exists yet (a brand-new
  /// account — the caller should treat this as "nothing to pull", not an
  /// error, and offer to migrate local data up instead).
  static Future<AppUser?> pullProfile() async {
    final uid = _uid;
    if (uid == null) return null;
    try {
      final row = await SupabaseBootstrap.client
          .from('profiles')
          .select()
          .eq('id', uid)
          .maybeSingle();
      if (row == null) return null;
      return AppUser(
        firstName: (row['first_name'] ?? '') as String,
        wakingStart: _hhmm(row['waking_start']),
        wakingEnd: _hhmm(row['waking_end']),
        onboarded: row['onboarded'] == true,
        hasSeenDisclaimer: row['has_seen_disclaimer'] == true,
      );
    } catch (e) {
      debugPrint('SupabaseSync.pullProfile failed: $e');
      return null;
    }
  }

  /// Postgres returns `time` columns as `HH:mm:ss`; the app's wire format
  /// throughout is `HH:mm`.
  static String _hhmm(dynamic v) {
    final s = (v ?? '07:00:00') as String;
    return s.length >= 5 ? s.substring(0, 5) : s;
  }

  // ------------------------------------------------------------ medications

  static Map<String, dynamic> _medicationRow(Medication m, String uid) => {
        'id': m.id,
        'user_id': uid,
        'name': m.name,
        'bottle_cap_color': m.bottleCapColor,
        'eye': m.eye.code,
        'frequency_type': m.frequencyType.code,
        'frequency_value': m.frequencyValue,
        'dose_times': m.doseTimes,
        'start_date': m.startDate,
        'end_date': m.endDate,
        'ongoing': m.ongoing,
        'category': m.category.code,
        'instructions': m.instructions.toJson(),
        'notes': m.instructions.notes,
      };

  static Map<String, dynamic> _taperStepRow(
    TaperStep s,
    String medicationId,
    int index,
  ) =>
      {
        'medication_id': medicationId,
        'step_index': index,
        'start_date': s.startDate,
        'frequency_type': s.frequencyType.code,
        'frequency_value': s.frequencyValue,
        'dose_times': s.doseTimes,
      };

  /// Upserts a medication and replaces its full taper-step list.
  ///
  /// Taper steps are always edited as a whole ordered list in the UI (there is
  /// no "edit step 2 in isolation" affordance), so delete-then-reinsert is both
  /// simpler and safer than trying to diff steps — there is no scenario where
  /// a partial update is actually correct here.
  static Future<void> pushMedication(Medication m) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      final client = SupabaseBootstrap.client;
      await client.from('medications').upsert(_medicationRow(m, uid));
      await client.from('taper_steps').delete().eq('medication_id', m.id);
      if (m.taperSteps.isNotEmpty) {
        await client.from('taper_steps').insert([
          for (var i = 0; i < m.taperSteps.length; i++)
            _taperStepRow(m.taperSteps[i], m.id, i),
        ]);
      }
    } catch (e) {
      debugPrint('SupabaseSync.pushMedication failed: $e');
    }
  }

  static Future<void> deleteMedication(String id) async {
    if (_uid == null) return;
    try {
      // taper_steps cascades via the FK in db/migrations/001.
      await SupabaseBootstrap.client.from('medications').delete().eq('id', id);
    } catch (e) {
      debugPrint('SupabaseSync.deleteMedication failed: $e');
    }
  }

  static Future<List<Medication>> pullMedications() async {
    final uid = _uid;
    if (uid == null) return const [];
    try {
      final client = SupabaseBootstrap.client;
      final rows = await client
          .from('medications')
          .select()
          .eq('user_id', uid)
          .isFilter('deleted_at', null)
          .order('created_at');
      final stepRows = await client
          .from('taper_steps')
          .select()
          .inFilter('medication_id', rows.map((r) => r['id'] as String).toList())
          .order('step_index');

      final stepsByMed = <String, List<TaperStep>>{};
      for (final r in stepRows) {
        stepsByMed
            .putIfAbsent(r['medication_id'] as String, () => [])
            .add(TaperStep(
              startDate: (r['start_date'] ?? '') as String,
              frequencyType: FrequencyType.fromCode(r['frequency_type'] as String?),
              frequencyValue: (r['frequency_value'] as num?)?.toInt(),
              doseTimes: ((r['dose_times'] as List?) ?? const [])
                  .map((e) => e.toString())
                  .toList(),
            ));
      }

      return rows.map((r) {
        final id = r['id'] as String;
        return Medication.fromJson({
          'id': id,
          'name': r['name'],
          'bottle_cap_color': r['bottle_cap_color'],
          'eye': r['eye'],
          'frequency_type': r['frequency_type'],
          'frequency_value': r['frequency_value'],
          'dose_times': r['dose_times'],
          'start_date': r['start_date'],
          'end_date': r['end_date'],
          'ongoing': r['ongoing'],
          'category': r['category'],
          'instructions': r['instructions'] ?? {},
          'taper_steps': (stepsByMed[id] ?? const [])
              .map((s) => s.toJson())
              .toList(),
        });
      }).toList();
    } catch (e) {
      debugPrint('SupabaseSync.pullMedications failed: $e');
      return const [];
    }
  }

  // ------------------------------------------------------------ dose events

  static Map<String, dynamic> _doseEventRow(DoseEvent e, String uid) {
    // scheduled_hhmm/scheduled_date are wall-clock by design (a 7:00 AM dose
    // means 7:00 AM local, every day, independent of timezone). Resolving them
    // against the device's current local timezone to produce an instant is a
    // reasonable default; a dose scheduled just before a DST transition is the
    // one edge case this approximation doesn't handle perfectly.
    final parts = e.scheduledHhmm.split(':').map(int.parse).toList();
    final dateParts = e.scheduledDate.split('-').map(int.parse).toList();
    final scheduledLocal = DateTime(
        dateParts[0], dateParts[1], dateParts[2], parts[0], parts[1]);
    final respondedLocal =
        DateTime.tryParse(e.responseTime) ?? scheduledLocal;

    return {
      'id': e.id,
      'user_id': uid,
      'medication_id': e.medicationId,
      'medication_name': e.medicationName,
      'bottle_cap_color': e.bottleCapColor,
      'eye': e.eye.code,
      'instruction_flags': e.instructionFlags,
      'scheduled_date': e.scheduledDate,
      'scheduled_hhmm': e.scheduledHhmm,
      'scheduled_at': scheduledLocal.toUtc().toIso8601String(),
      'response': e.response.code,
      'responded_at': respondedLocal.toUtc().toIso8601String(),
      // Device-clock-trust pair (db/migrations/004) — never a single
      // pre-corrected value; see TrustedClock and ClockStamp.
      'device_reported_at': e.stamp.deviceUtc.toIso8601String(),
      'clock_offset_ms': e.stamp.serverOffsetMs,
      'clock_source': e.stamp.source.code,
    };
  }

  /// Dose events are append-only server-side (see db/migrations/002 — insert +
  /// select only, no update policy). [DropStore.logResponse] replaces the
  /// local record for a re-logged dose, so a push here must upsert on the
  /// primary key rather than always insert, or a correction would create a
  /// duplicate history row instead of replacing it.
  static Future<void> pushDoseEvent(DoseEvent e) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await SupabaseBootstrap.client
          .from('dose_events')
          .upsert(_doseEventRow(e, uid));
    } catch (err) {
      debugPrint('SupabaseSync.pushDoseEvent failed: $err');
    }
  }

  static Future<List<DoseEvent>> pullDoseEvents({int lastNDays = 400}) async {
    final uid = _uid;
    if (uid == null) return const [];
    try {
      final since = DateTime.now()
          .toUtc()
          .subtract(Duration(days: lastNDays))
          .toIso8601String()
          .substring(0, 10);
      final rows = await SupabaseBootstrap.client
          .from('dose_events')
          .select()
          .eq('user_id', uid)
          .gte('scheduled_date', since)
          .order('scheduled_date');

      return rows.map((r) {
        return DoseEvent.fromJson({
          'id': r['id'],
          'medication_id': r['medication_id'],
          'medication_name': r['medication_name'],
          'bottle_cap_color': r['bottle_cap_color'],
          'eye': r['eye'],
          'scheduled_time': '${r['scheduled_date']}T${_hhmm(r['scheduled_hhmm'])}:00',
          'scheduled_date': r['scheduled_date'],
          'scheduled_hhmm': _hhmm(r['scheduled_hhmm']),
          'response': r['response'],
          'response_time': (r['responded_at'] as String),
          'device_utc': r['device_reported_at'],
          'server_offset_ms': r['clock_offset_ms'],
          'clock_source': r['clock_source'],
          'instruction_flags': r['instruction_flags'] ?? {},
        });
      }).toList();
    } catch (e) {
      debugPrint('SupabaseSync.pullDoseEvents failed: $e');
      return const [];
    }
  }

  // --------------------------------------------------------- clock sync

  /// Measures the device↔server offset via the `server_now()` RPC
  /// (db/migrations/004) and records it in [TrustedClock] for every
  /// subsequent [ClockStamp] this session produces.
  static Future<void> syncClock() async {
    if (_uid == null) return;
    try {
      final started = DateTime.now();
      final result =
          await SupabaseBootstrap.client.rpc('server_now') as String;
      final roundTrip = DateTime.now().difference(started);
      await TrustedClock.instance
          .syncWith(DateTime.parse(result), roundTrip: roundTrip);
    } catch (e) {
      debugPrint('SupabaseSync.syncClock failed: $e');
    }
  }
}
