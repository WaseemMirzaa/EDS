import 'dart:io';

import 'package:flutter/widgets.dart' show Rect;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/app_user.dart';
import '../models/medication.dart';
import 'dose_logic.dart';

/// Generates RFC-5545 .ics calendar files for medication reminders. Retained
/// alongside the native reminders as a secondary/export mechanism (Proposal §3.5).
class IcsGenerator {
  IcsGenerator._();

  static String _stamp(DateTime d) {
    String p(int n) => n.toString().padLeft(2, '0');
    return '${d.year}${p(d.month)}${p(d.day)}T${p(d.hour)}${p(d.minute)}${p(d.second)}';
  }

  static String _fold(String line) {
    // Simple ICS line folding at 74 octets.
    if (line.length <= 74) return line;
    final buf = StringBuffer();
    var i = 0;
    while (i < line.length) {
      final end = (i + 74).clamp(0, line.length);
      buf.write(i == 0 ? line.substring(i, end) : '\r\n ${line.substring(i, end)}');
      i = end;
    }
    return buf.toString();
  }

  static String _esc(String s) =>
      s.replaceAll('\\', '\\\\').replaceAll(',', '\\,').replaceAll(';', '\\;');

  /// Emits one recurring VEVENT block per "segment" of the medication's
  /// timeline — the base schedule, then each taper step in turn — each
  /// bounded to the date range it's actually active for. A tapering
  /// medication's dose times genuinely change over the weeks (see
  /// dose_logic.dart's active-taper-step selection); a single DAILY rule
  /// covering the whole medication would otherwise repeat day-one's times
  /// forever, silently wrong for every day after the first taper step ends.
  static List<String> _eventsForMed(Medication med, AppUser user) {
    final medStart = med.startDate ?? DoseLogic.todayStr();
    final lines = <String>[];
    final now = DateTime.now();

    // Every point where the active dose times can change: the medication's
    // own start, plus each taper step's start date.
    final boundaries = <String>{medStart, ...med.taperSteps.map((s) => s.startDate)}
        .toList()
      ..sort();

    for (var i = 0; i < boundaries.length; i++) {
      final segStart = boundaries[i];

      // This segment runs until the day before the next boundary, or the
      // medication's own end date if it's the last segment and not
      // ongoing, or indefinitely if it's the last segment and ongoing.
      String? untilDateStr;
      if (i + 1 < boundaries.length) {
        final next = DoseLogic.strToDate(boundaries[i + 1]);
        untilDateStr =
            DoseLogic.dateToStr(next.subtract(const Duration(days: 1)));
      } else if (!med.ongoing && med.endDate != null) {
        untilDateStr = med.endDate;
      }
      // Two boundaries can collide on the same date (e.g. a taper step
      // dated the same as the medication's start) — skip the earlier,
      // now-zero-length segment rather than emit an inverted UNTIL.
      if (untilDateStr != null && untilDateStr.compareTo(segStart) < 0) {
        continue;
      }

      final times = DoseLogic.getDoseTimesForDate(med, segStart,
          wakingStart: user.wakingStart, wakingEnd: user.wakingEnd);
      final startDate = DoseLogic.strToDate(segStart);

      for (final t in times) {
        final hm = t.split(':').map(int.parse).toList();
        final dtStart = DateTime(
            startDate.year, startDate.month, startDate.day, hm[0], hm[1]);
        final uid =
            '${med.id}-seg$i-${t.replaceAll(':', '')}-${now.microsecondsSinceEpoch}@eyedropshop';
        var rrule = 'RRULE:FREQ=DAILY';
        if (untilDateStr != null) {
          final end = DoseLogic.strToDate(untilDateStr);
          rrule +=
              ';UNTIL=${_stamp(DateTime(end.year, end.month, end.day, 23, 59, 59))}';
        }
        final summary = 'Drop Tracker: ${med.name} (${med.eye.label})';
        final instr = med.instructions.summary;
        final desc = instr.isEmpty
            ? 'Time for your eye drop.'
            : 'Time for your eye drop. ${instr.join(', ')}.';
        lines.addAll([
          'BEGIN:VEVENT',
          _fold('UID:$uid'),
          'DTSTAMP:${_stamp(now)}',
          'DTSTART:${_stamp(dtStart)}',
          rrule,
          _fold('SUMMARY:${_esc(summary)}'),
          _fold('DESCRIPTION:${_esc(desc)}'),
          'BEGIN:VALARM',
          'TRIGGER:PT0M',
          'ACTION:DISPLAY',
          _fold('DESCRIPTION:${_esc(summary)}'),
          'END:VALARM',
          'END:VEVENT',
        ]);
      }
    }
    return lines;
  }

  static String _wrap(List<String> events) => [
        'BEGIN:VCALENDAR',
        'VERSION:2.0',
        'PRODID:-//Eye Drop Shop//Drop Tracker//EN',
        'CALSCALE:GREGORIAN',
        ...events,
        'END:VCALENDAR',
      ].join('\r\n');

  static String forMedication(Medication med, AppUser user) =>
      _wrap(_eventsForMed(med, user));

  static String forAll(List<Medication> meds, AppUser user) {
    final events = <String>[];
    for (final m in meds) {
      events.addAll(_eventsForMed(m, user));
    }
    return _wrap(events);
  }

  /// Writes the .ics to a temp file and opens the share sheet.
  ///
  /// [sharePositionOrigin], when provided, anchors the share sheet's popover
  /// — required on iPad or `Share.shareXFiles` throws a PlatformException
  /// ("must provide a sourceView") and the whole export silently does
  /// nothing from the caller's point of view. Pass the tapped tile's
  /// on-screen rect (e.g. via a GlobalKey) when calling this from a widget
  /// that might run on iPad; harmless to omit on iPhone/Android.
  static Future<void> share(
    String filename,
    String content, {
    Rect? sharePositionOrigin,
  }) async {
    final dir = await getTemporaryDirectory();
    final safe = filename.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '-');
    final file = File('${dir.path}/$safe');
    await file.writeAsString(content);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'text/calendar')],
      subject: 'Drop Tracker reminders',
      sharePositionOrigin: sharePositionOrigin,
    );
  }
}
