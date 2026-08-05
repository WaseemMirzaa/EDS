import '../models/dose.dart';
import '../models/dose_event.dart';
import '../models/enums.dart';
import '../models/medication.dart';
import '../models/taper_step.dart';

/// Pure scheduling / adherence logic — a direct port of the prototype's
/// `doseUtils.js`, so the native app produces identical schedules.
class DoseLogic {
  DoseLogic._();

  // ---- date helpers ---------------------------------------------------------

  static String todayStr() => dateToStr(DateTime.now());

  static String dateToStr(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  static DateTime strToDate(String s) {
    final p = s.split('-').map(int.parse).toList();
    return DateTime(p[0], p[1], p[2]);
  }

  static int _hhmmToMin(String hhmm) {
    final p = hhmm.split(':').map(int.parse).toList();
    return p[0] * 60 + p[1];
  }

  static String _minToHhmm(int mins) {
    final h = (mins ~/ 60).clamp(0, 23);
    final m = mins % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  // ---- time generation ------------------------------------------------------

  /// Evenly-spaced times across waking hours for fixed frequencies.
  static List<String> suggestTimes(FrequencyType freq,
      {String wakingStart = '07:00', String wakingEnd = '21:00'}) {
    final count = freq.count;
    if (count == null) return [];
    final startMin = _hhmmToMin(wakingStart);
    final endMin = _hhmmToMin(wakingEnd);
    final span = endMin - startMin;
    if (count == 1) return [wakingStart];
    final interval = (span / (count - 1)).round();
    return [for (var i = 0; i < count; i++) _minToHhmm(startMin + interval * i)];
  }

  /// Rolling times every N hours across waking hours.
  static List<String> timesForEveryNHours(int n,
      {String wakingStart = '07:00', String wakingEnd = '21:00'}) {
    final startMin = _hhmmToMin(wakingStart);
    final endMin = _hhmmToMin(wakingEnd);
    final interval = n * 60;
    final times = <String>[];
    if (interval <= 0) return [wakingStart];
    for (var mins = startMin; mins <= endMin; mins += interval) {
      times.add(_minToHhmm(mins));
    }
    return times;
  }

  // ---- taper ----------------------------------------------------------------

  static TaperStep? getActiveTaperStep(Medication med, String dateStr) {
    if (med.taperSteps.isEmpty) return null;
    final sorted = [...med.taperSteps]
      ..sort((a, b) => a.startDate.compareTo(b.startDate));
    TaperStep? active;
    for (final step in sorted) {
      if (step.startDate.compareTo(dateStr) <= 0) active = step;
    }
    return active;
  }

  static List<String> getDoseTimesForDate(Medication med, String dateStr,
      {String wakingStart = '07:00', String wakingEnd = '21:00'}) {
    final taper = getActiveTaperStep(med, dateStr);
    final ftype = taper?.frequencyType ?? med.frequencyType;
    final fval = taper?.frequencyValue ?? med.frequencyValue;
    final dtimes = taper?.doseTimes ?? med.doseTimes;

    if (ftype == FrequencyType.customTimes && dtimes.isNotEmpty) return dtimes;
    if (ftype == FrequencyType.everyNHours && fval != null) {
      return timesForEveryNHours(fval, wakingStart: wakingStart, wakingEnd: wakingEnd);
    }
    if (dtimes.isNotEmpty) return dtimes;
    return suggestTimes(ftype, wakingStart: wakingStart, wakingEnd: wakingEnd);
  }

  // ---- active window --------------------------------------------------------

  static bool isMedicationActiveOn(Medication med, String dateStr) {
    if (med.startDate != null && med.startDate!.compareTo(dateStr) > 0) {
      return false;
    }
    if (!med.ongoing &&
        med.endDate != null &&
        med.endDate!.compareTo(dateStr) < 0) {
      return false;
    }
    return true;
  }

  // ---- daily dose list ------------------------------------------------------

  static List<Dose> getDosesForDate(List<Medication> meds, String dateStr,
      {String wakingStart = '07:00', String wakingEnd = '21:00'}) {
    final doses = <Dose>[];
    for (final med in meds) {
      if (!isMedicationActiveOn(med, dateStr)) continue;
      final times = getDoseTimesForDate(med, dateStr,
          wakingStart: wakingStart, wakingEnd: wakingEnd);
      for (final t in times) {
        doses.add(Dose(
          medicationId: med.id,
          medicationName: med.name,
          bottleCapColor: med.bottleCapColor,
          eye: med.eye,
          scheduledHhmm: t,
          scheduledDate: dateStr,
          scheduledTime: '${dateStr}T$t:00',
          instructions: med.instructions,
          category: med.category,
        ));
      }
    }
    doses.sort((a, b) => a.scheduledHhmm.compareTo(b.scheduledHhmm));
    return doses;
  }

  // ---- matching / adherence -------------------------------------------------

  static DoseEvent? matchDoseToEvent(Dose dose, List<DoseEvent> events) {
    for (final e in events) {
      if (e.medicationId == dose.medicationId &&
          e.scheduledHhmm == dose.scheduledHhmm &&
          e.scheduledDate == dose.scheduledDate) {
        return e;
      }
    }
    return null;
  }

  static int calculateAdherence(int scheduled, int taken) {
    if (scheduled == 0) return 0;
    return ((taken / scheduled) * 100).round();
  }

  static List<String> getLastNDays(int n, String endDateStr) {
    final end = strToDate(endDateStr);
    final days = <String>[];
    for (var i = n - 1; i >= 0; i--) {
      days.add(dateToStr(end.subtract(Duration(days: i))));
    }
    return days;
  }

  /// 'none' | 'partial' | 'full' — a day's completion level.
  static String dayCompletion(List<Dose> doses, List<DoseEvent> events) {
    if (doses.isEmpty) return 'none';
    var taken = 0;
    for (final dose in doses) {
      final ev = matchDoseToEvent(dose, events);
      if (ev != null &&
          (ev.response == DoseResponse.tookIt ||
              ev.response == DoseResponse.notSure)) {
        taken++;
      }
    }
    if (taken == 0) return 'none';
    if (taken >= doses.length) return 'full';
    return 'partial';
  }

  // ---- calendar -------------------------------------------------------------

  /// Returns the month grid (leading/trailing nulls pad to whole weeks,
  /// Sunday-first to match the prototype).
  static List<DateTime?> getCalendarMonth(int year, int month) {
    final firstDay = DateTime(year, month + 1, 1);
    final lastDay = DateTime(year, month + 2, 0);
    final startWeekday = firstDay.weekday % 7; // DateTime: Mon=1..Sun=7 → Sun=0
    final days = <DateTime?>[];
    for (var i = 0; i < startWeekday; i++) {
      days.add(null);
    }
    for (var d = 1; d <= lastDay.day; d++) {
      days.add(DateTime(year, month + 1, d));
    }
    final trailing = (7 - (days.length % 7)) % 7;
    for (var i = 0; i < trailing; i++) {
      days.add(null);
    }
    return days;
  }

  static const List<String> monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  static String monthName(int month) => monthNames[month];

  // ---- formatting -----------------------------------------------------------

  static String formatTime(String hhmm) {
    final p = hhmm.split(':').map(int.parse).toList();
    final h = p[0];
    final m = p[1];
    final period = h >= 12 ? 'PM' : 'AM';
    final hr = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$hr:${m.toString().padLeft(2, '0')} $period';
  }

  static String formatIsoTimeShort(String iso) {
    if (iso.isEmpty) return '';
    final d = DateTime.tryParse(iso);
    if (d == null) return '';
    final local = d.toLocal();
    final h = local.hour;
    final period = h >= 12 ? 'PM' : 'AM';
    final hr = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$hr:${local.minute.toString().padLeft(2, '0')} $period';
  }

  static String greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 18) return 'Good afternoon';
    return 'Good evening';
  }
}
