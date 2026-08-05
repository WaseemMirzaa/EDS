import 'dart:io';

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

  static List<String> _eventsForMed(Medication med, AppUser user) {
    final start = med.startDate ?? DoseLogic.todayStr();
    final startDate = DoseLogic.strToDate(start);
    final times = DoseLogic.getDoseTimesForDate(
      med,
      start,
      wakingStart: user.wakingStart,
      wakingEnd: user.wakingEnd,
    );
    final lines = <String>[];
    final now = DateTime.now();
    for (final t in times) {
      final hm = t.split(':').map(int.parse).toList();
      final dtStart = DateTime(
          startDate.year, startDate.month, startDate.day, hm[0], hm[1]);
      final uid =
          '${med.id}-${t.replaceAll(':', '')}-${now.microsecondsSinceEpoch}@eyedropshop';
      var rrule = 'RRULE:FREQ=DAILY';
      if (!med.ongoing && med.endDate != null) {
        final end = DoseLogic.strToDate(med.endDate!);
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
  static Future<void> share(String filename, String content) async {
    final dir = await getTemporaryDirectory();
    final safe = filename.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '-');
    final file = File('${dir.path}/$safe');
    await file.writeAsString(content);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'text/calendar')],
      subject: 'Drop Tracker reminders',
    );
  }
}
