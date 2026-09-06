import 'package:shared_preferences/shared_preferences.dart';

/// Where a recorded instant's authority came from.
enum ClockSource {
  /// The device clock was reconciled against the server, and the recorded
  /// offset can be applied to recover true UTC.
  serverSynced('server_synced'),

  /// No server reading was available. The device clock is taken at face value
  /// and the offset is zero — the value is usable but unverified.
  deviceOnly('device_only');

  const ClockSource(this.code);
  final String code;

  static ClockSource fromCode(String? c) => ClockSource.values
      .firstWhere((e) => e.code == c, orElse: () => ClockSource.deviceOnly);
}

/// A recorded instant, stored the way this project requires:
/// **the current device timestamp, plus its difference from server UTC.**
///
/// Both halves are kept rather than collapsing them into one corrected value.
/// The raw device reading is what the user actually saw on their phone, and the
/// offset is what makes it verifiable — keeping the pair means a record can be
/// re-derived later even if the offset is found to have been wrong, which a
/// single pre-corrected timestamp would make impossible.
class ClockStamp {
  /// The device's own clock reading, in UTC. "Timestamp current".
  final DateTime deviceUtc;

  /// serverUtc − deviceUtc at the moment of writing, in milliseconds.
  /// Positive means the device clock is running behind the server.
  final int serverOffsetMs;

  final ClockSource source;

  const ClockStamp({
    required this.deviceUtc,
    this.serverOffsetMs = 0,
    this.source = ClockSource.deviceOnly,
  });

  /// The device reading corrected onto the server's timeline — the value to
  /// use for anything that must be accurate rather than merely local
  /// (adherence intervals, report timestamps, cross-device ordering).
  DateTime get trustedUtc =>
      deviceUtc.add(Duration(milliseconds: serverOffsetMs));

  /// True when the device clock is far enough out that its unadjusted readings
  /// should not be relied on.
  bool get deviceClockSuspect =>
      serverOffsetMs.abs() >= TrustedClock.suspectThresholdMs;

  Map<String, dynamic> toJson() => {
        'device_utc': deviceUtc.toIso8601String(),
        'server_offset_ms': serverOffsetMs,
        'clock_source': source.code,
      };

  factory ClockStamp.fromJson(Map<String, dynamic> j) => ClockStamp(
        deviceUtc: DateTime.tryParse((j['device_utc'] ?? '') as String)?.toUtc() ??
            DateTime.now().toUtc(),
        serverOffsetMs: (j['server_offset_ms'] as num?)?.toInt() ?? 0,
        source: ClockSource.fromCode(j['clock_source'] as String?),
      );

  /// Reconstructs a stamp for a record written before offsets were tracked.
  /// Such a value is device-only by definition.
  factory ClockStamp.legacy(DateTime deviceUtc) =>
      ClockStamp(deviceUtc: deviceUtc.toUtc());
}

/// Holds the device↔server clock difference and issues [ClockStamp]s.
///
/// The device clock cannot be trusted on its own: it drifts, it can be changed
/// by hand, and it resets on some devices after a flat battery. For a
/// medication app that matters twice over — a reminder scheduled against a
/// wrong clock fires at the wrong real-world moment, and an adherence report
/// shown to a prescriber is only meaningful if its timestamps are true.
///
/// So every recorded instant carries the device reading *and* the offset from
/// server UTC, and reminders are scheduled with that offset applied.
class TrustedClock {
  TrustedClock._();
  static final TrustedClock instance = TrustedClock._();

  static const _offsetKey = 'droptracker_clock_offset_ms';
  static const _measuredKey = 'droptracker_clock_measured_at';

  /// Beyond this, the device clock is treated as wrong rather than merely
  /// imprecise. Two minutes is comfortably above normal drift and NTP jitter,
  /// and well below anything that would shift a dose slot meaningfully.
  static const int suspectThresholdMs = 2 * 60 * 1000;

  /// Corrections larger than this are refused when scheduling. An offset of
  /// hours is far more likely to be a timezone or DST misreading than genuine
  /// skew, and acting on it would move reminders wildly. Better to schedule
  /// uncorrected than to schedule confidently wrong.
  static const Duration maxSchedulingCorrection = Duration(hours: 6);

  /// A measurement older than this is stale — the device may have been
  /// rebooted or adjusted since — so it is reported but not applied.
  static const Duration measurementValidity = Duration(days: 7);

  SharedPreferences? _prefs;
  int _offsetMs = 0;
  DateTime? _measuredAtDeviceUtc;

  /// serverUtc − deviceUtc, in milliseconds.
  int get offsetMs => _offsetMs;
  Duration get offset => Duration(milliseconds: _offsetMs);

  bool get isSynced => _measuredAtDeviceUtc != null;

  ClockSource get source =>
      isSynced ? ClockSource.serverSynced : ClockSource.deviceOnly;

  /// How long ago the offset was measured, by the device's own reckoning.
  Duration? get measurementAge => _measuredAtDeviceUtc == null
      ? null
      : DateTime.now().toUtc().difference(_measuredAtDeviceUtc!);

  bool get isStale {
    final age = measurementAge;
    return age == null || age > measurementValidity;
  }

  /// True when the device clock is meaningfully wrong — worth surfacing, since
  /// the user will otherwise see reminders that look mistimed against the
  /// clock on their own phone.
  bool get deviceClockSuspect => _offsetMs.abs() >= suspectThresholdMs;

  Future<void> init([SharedPreferences? prefs]) async {
    _prefs = prefs ?? await SharedPreferences.getInstance();
    _offsetMs = _prefs!.getInt(_offsetKey) ?? 0;
    final raw = _prefs!.getString(_measuredKey);
    _measuredAtDeviceUtc = raw == null ? null : DateTime.tryParse(raw)?.toUtc();
  }

  /// Records a fresh reading of server time.
  ///
  /// [roundTrip] is the full request duration, when known. Half of it is
  /// subtracted so the offset reflects the server's time at the moment the
  /// response was produced rather than when it arrived — without this, every
  /// sync would bias the offset by the network latency.
  Future<void> syncWith(DateTime serverUtc, {Duration? roundTrip}) async {
    final deviceUtc = DateTime.now().toUtc();
    var deltaMs = serverUtc.toUtc().difference(deviceUtc).inMilliseconds;
    if (roundTrip != null) {
      deltaMs -= roundTrip.inMilliseconds ~/ 2;
    }
    _offsetMs = deltaMs;
    _measuredAtDeviceUtc = deviceUtc;

    await _prefs?.setInt(_offsetKey, _offsetMs);
    await _prefs?.setString(_measuredKey, deviceUtc.toIso8601String());
  }

  /// Clears the measurement — used on sign-out, so one account's reading is
  /// never applied to another session.
  Future<void> reset() async {
    _offsetMs = 0;
    _measuredAtDeviceUtc = null;
    await _prefs?.remove(_offsetKey);
    await _prefs?.remove(_measuredKey);
  }

  /// A stamp for right now: the device reading plus the current offset.
  /// This is what every recorded instant in the app should be built from.
  ClockStamp stamp() => ClockStamp(
        deviceUtc: DateTime.now().toUtc(),
        serverOffsetMs: _offsetMs,
        source: source,
      );

  /// Best available UTC — the device clock with the offset applied.
  DateTime nowUtc() => DateTime.now().toUtc().add(offset);

  /// The correction to apply when scheduling a reminder.
  ///
  /// A reminder is scheduled against the device's clock, but it should fire at
  /// the correct *real* moment. If the device runs 40 minutes fast, a 7:00 AM
  /// dose must be scheduled for 7:40 by the device's reckoning to actually
  /// fire at 7:00. That is `intended − offset`.
  ///
  /// Returns [Duration.zero] when there is nothing trustworthy to apply, so
  /// callers can use it unconditionally.
  Duration schedulingCorrection() {
    if (!isSynced || isStale) return Duration.zero;
    final o = offset;
    if (o.abs() > maxSchedulingCorrection) return Duration.zero;
    return o;
  }

  /// Applies [schedulingCorrection] to an intended local fire time.
  DateTime applyToFireTime(DateTime intendedLocal) =>
      intendedLocal.subtract(schedulingCorrection());

  /// Test seam — sets the offset without touching storage.
  void debugSetOffset(int ms, {DateTime? measuredAt}) {
    _offsetMs = ms;
    _measuredAtDeviceUtc = measuredAt ?? DateTime.now().toUtc();
  }
}
