import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../data/dose_logic.dart';
import '../data/drop_store.dart';
import '../models/dose.dart';
import '../models/dose_event.dart';
import '../models/enums.dart';
import '../models/medication.dart';
import '../theme/app_theme.dart';
import '../theme/brand.dart';
import '../widgets/common.dart';

class _MedStats {
  int scheduled = 0, taken = 0, missed = 0, unsure = 0;
  final List<({String day, String time, DoseResponse response})> log = [];
  int get pct => DoseLogic.calculateAdherence(scheduled, taken);
}

/// [dosesForDay] must be computed from the FULL medication list (not just
/// [med]) so any same-time auto-spacing between different medications
/// (see DoseLogic._autoSpaceCollisions) matches the times that were actually
/// scheduled and logged, rather than recomputing [med] in isolation.
_MedStats _statsFor(
  Medication med,
  List<String> last30,
  List<DoseEvent> events,
  List<Dose> Function(String day) dosesForDay,
  String today,
) {
  final s = _MedStats();
  for (final day in last30) {
    final doses = dosesForDay(day).where((d) => d.medicationId == med.id);
    for (final dose in doses) {
      s.scheduled++;
      final ev = DoseLogic.matchDoseToEvent(dose, events);
      if (ev != null) {
        if (ev.response == DoseResponse.tookIt) {
          s.taken++;
        } else if (ev.response == DoseResponse.notSure) {
          s.unsure++;
          s.taken++;
        } else if (ev.response == DoseResponse.skipped) {
          s.missed++;
        }
        s.log.add((day: day, time: dose.scheduledHhmm, response: ev.response));
      } else if (day.compareTo(today) < 0) {
        s.missed++;
      }
    }
  }
  return s;
}

class DoctorReportScreen extends StatelessWidget {
  const DoctorReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<DropStore>();
    final meds = store.medications;
    final events = store.events;
    final user = store.user;
    final today = DoseLogic.todayStr();
    final last30 = DoseLogic.getLastNDays(30, today);

    // Compute each day's dose list once, from the FULL medication list, so
    // any auto-spacing between same-time medications is applied consistently
    // with what Today/notifications actually scheduled.
    final dosesByDay = <String, List<Dose>>{
      for (final day in last30)
        day: DoseLogic.getDosesForDate(meds, day, wakingStart: user.wakingStart, wakingEnd: user.wakingEnd),
    };

    var overallScheduled = 0, overallTaken = 0;
    final statList = <(Medication, _MedStats)>[];
    for (final m in meds) {
      final s = _statsFor(m, last30, events, (day) => dosesByDay[day]!, today);
      statList.add((m, s));
      overallScheduled += s.scheduled;
      overallTaken += s.taken;
    }
    final overallPct = DoseLogic.calculateAdherence(overallScheduled, overallTaken);
    final patient = user.firstName.isNotEmpty ? user.firstName : '—';
    final generated = _prettyDate(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Adherence Report'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton.icon(
              onPressed: () => _printPdf(context, patient, generated, last30, today,
                  overallPct, overallScheduled, overallTaken, statList),
              icon: const Icon(Icons.print_rounded, size: 18),
              label: const Text('Print / PDF'),
              style: FilledButton.styleFrom(
                backgroundColor: BrandColors.ocean,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Container(
              padding: const EdgeInsets.only(bottom: 16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: BrandColors.hairline, width: 2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Eye Drop Adherence Report',
                      style: AppTypography.display(24, weight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text('Patient: $patient · Generated: $generated',
                      style: AppTypography.body(13, color: BrandColors.inkSoft)),
                  Text('Reporting period: Last 30 days (${last30.first} to $today)',
                      style: AppTypography.body(13, color: BrandColors.inkSoft)),
                  const SizedBox(height: 8),
                  Text('Overall adherence: $overallPct% ($overallTaken/$overallScheduled doses)',
                      style: AppTypography.body(15, weight: FontWeight.w700, color: BrandColors.ocean)),
                ],
              ),
            ),
            const Gap(16),
            if (statList.isEmpty)
              Text('No medications to report.',
                  style: AppTypography.body(14, color: BrandColors.inkFaint))
            else
              ...statList.map((e) => _medCard(e.$1, e.$2)),
            const Gap(20),
            Text(
              'This report is a record of patient-reported dose responses from the Drop Tracker app. It is not a medical device and does not constitute medical advice.',
              style: AppTypography.body(11, color: BrandColors.inkFaint, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _medCard(Medication med, _MedStats s) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BrandColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: BrandColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(med.name, style: AppTypography.body(17, weight: FontWeight.w700)),
          Text('${med.eye.label} · Started ${med.startDate ?? "—"}',
              style: AppTypography.body(13, color: BrandColors.inkSoft)),
          const SizedBox(height: 12),
          Row(
            children: [
              _cell('Adherence', '${s.pct}%', BrandColors.ocean),
              _cell('Taken', '${s.taken}', BrandColors.tookIt),
              _cell('Missed', '${s.missed}', BrandColors.skipped),
              _cell('Unsure', '${s.unsure}', BrandColors.notSure),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cell(String label, String value, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: BrandColors.fill,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(label, style: AppTypography.body(11, color: BrandColors.inkFaint)),
            const SizedBox(height: 2),
            Text(value, style: AppTypography.body(17, weight: FontWeight.w700, color: color)),
          ],
        ),
      ),
    );
  }

  static String _prettyDate(DateTime d) =>
      '${DoseLogic.monthName(d.month - 1)} ${d.day}, ${d.year}';

  // ---- PDF ------------------------------------------------------------------

  Future<void> _printPdf(
    BuildContext context,
    String patient,
    String generated,
    List<String> last30,
    String today,
    int overallPct,
    int overallScheduled,
    int overallTaken,
    List<(Medication, _MedStats)> stats,
  ) async {
    final doc = pw.Document();
    const ocean = PdfColor.fromInt(0xFF0F3759);
    const inkSoft = PdfColor.fromInt(0xFF4A5C6A);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (ctx) => [
          pw.Text('Eye Drop Adherence Report',
              style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: ocean)),
          pw.SizedBox(height: 6),
          pw.Text('Patient: $patient   ·   Generated: $generated',
              style: const pw.TextStyle(fontSize: 11, color: inkSoft)),
          pw.Text('Reporting period: Last 30 days (${last30.first} to $today)',
              style: const pw.TextStyle(fontSize: 11, color: inkSoft)),
          pw.SizedBox(height: 6),
          pw.Text('Overall adherence: $overallPct%  ($overallTaken/$overallScheduled doses)',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: ocean)),
          pw.Divider(color: ocean, thickness: 1.5),
          pw.SizedBox(height: 8),
          if (stats.isEmpty)
            pw.Text('No medications to report.')
          else
            ...stats.map((e) {
              final med = e.$1;
              final s = e.$2;
              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 14),
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: const PdfColor.fromInt(0xFFDDDDDD)),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(med.name,
                        style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
                    pw.Text('${med.eye.label} · Started ${med.startDate ?? "—"}',
                        style: const pw.TextStyle(fontSize: 10, color: inkSoft)),
                    pw.SizedBox(height: 8),
                    pw.Row(
                      children: [
                        _pdfCell('Adherence', '${s.pct}%'),
                        _pdfCell('Taken', '${s.taken}'),
                        _pdfCell('Missed', '${s.missed}'),
                        _pdfCell('Unsure', '${s.unsure}'),
                      ],
                    ),
                  ],
                ),
              );
            }),
          pw.SizedBox(height: 12),
          pw.Text(
            'This report is a record of patient-reported dose responses from the Drop Tracker app. It is not a medical device and does not constitute medical advice.',
            style: const pw.TextStyle(fontSize: 9, color: inkSoft),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) => doc.save());
  }

  pw.Widget _pdfCell(String label, String value) {
    return pw.Expanded(
      child: pw.Container(
        margin: const pw.EdgeInsets.symmetric(horizontal: 2),
        padding: const pw.EdgeInsets.symmetric(vertical: 8),
        decoration: pw.BoxDecoration(
          color: const PdfColor.fromInt(0xFFF4F0E6),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(
          children: [
            pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
            pw.SizedBox(height: 2),
            pw.Text(value, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
