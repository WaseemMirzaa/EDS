import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/dose_logic.dart';
import '../data/drop_store.dart';
import '../models/dose_event.dart';
import '../models/enums.dart';
import '../theme/app_theme.dart';
import '../theme/brand.dart';
import '../widgets/common.dart';
import 'doctor_report_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late int _year;
  late int _month; // 0-based
  String? _selectedDay;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year = now.year;
    _month = now.month - 1;
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<DropStore>();
    final meds = store.medications;
    final events = store.events;
    final wStart = store.user.wakingStart;
    final wEnd = store.user.wakingEnd;
    final today = DoseLogic.todayStr();

    ({int pct, int taken, int scheduled}) rangeAdherence(List<String> days) {
      var scheduled = 0, taken = 0;
      for (final day in days) {
        final doses = DoseLogic.getDosesForDate(meds, day, wakingStart: wStart, wakingEnd: wEnd);
        scheduled += doses.length;
        for (final dose in doses) {
          final ev = DoseLogic.matchDoseToEvent(dose, events);
          if (ev != null &&
              (ev.response == DoseResponse.tookIt || ev.response == DoseResponse.notSure)) {
            taken++;
          }
        }
      }
      return (pct: DoseLogic.calculateAdherence(scheduled, taken), taken: taken, scheduled: scheduled);
    }

    final last7 = DoseLogic.getLastNDays(7, today);
    final last30 = DoseLogic.getLastNDays(30, today);
    final a7 = rangeAdherence(last7);
    final a30 = rangeAdherence(last30);

    // Streak of perfect days (walking back from today).
    var streak = 0;
    for (var i = 0; i < last30.length; i++) {
      final day = last30[last30.length - 1 - i];
      final doses = DoseLogic.getDosesForDate(meds, day, wakingStart: wStart, wakingEnd: wEnd);
      if (doses.isEmpty) continue;
      final completion = DoseLogic.dayCompletion(doses, events);
      if (completion == 'full') {
        streak++;
      } else if (day == today) {
        continue;
      } else {
        break;
      }
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Row(
              children: [
                Expanded(child: Text('History', style: AppTypography.display(28, weight: FontWeight.w600))),
                FilledButton.icon(
                  onPressed: () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => const DoctorReportScreen())),
                  icon: const Icon(Icons.description_outlined, size: 18),
                  label: const Text('Doctor Report'),
                  style: FilledButton.styleFrom(
                    backgroundColor: BrandColors.ocean,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ],
            ),
            const Gap(16),
            Row(
              children: [
                Expanded(child: _stat('7-day', '${a7.pct}%', '${a7.taken}/${a7.scheduled}')),
                const SizedBox(width: 10),
                Expanded(child: _stat('30-day', '${a30.pct}%', '${a30.taken}/${a30.scheduled}')),
                const SizedBox(width: 10),
                Expanded(child: _stat('Streak', '$streak 🔥', 'perfect days')),
              ],
            ),
            const Gap(16),
            _calendar(meds, events, wStart, wEnd, today),
            if (_selectedDay != null) ...[
              const Gap(14),
              _dayDetail(meds, events, wStart, wEnd),
            ],
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value, String sub) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      child: Column(
        children: [
          Text(label, style: AppTypography.body(12, weight: FontWeight.w600, color: BrandColors.inkFaint)),
          const SizedBox(height: 4),
          Text(value,
              maxLines: 1,
              style: AppTypography.display(22, weight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(sub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.body(11, weight: FontWeight.w500, color: BrandColors.inkFaint)),
        ],
      ),
    );
  }

  void _prevMonth() => setState(() {
        if (_month == 0) {
          _month = 11;
          _year--;
        } else {
          _month--;
        }
      });

  void _nextMonth() => setState(() {
        if (_month == 11) {
          _month = 0;
          _year++;
        } else {
          _month++;
        }
      });

  Widget _calendar(List meds, List<DoseEvent> events, String wStart, String wEnd, String today) {
    final days = DoseLogic.getCalendarMonth(_year, _month);
    return AppCard(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(onPressed: _prevMonth, icon: const Icon(Icons.chevron_left_rounded)),
              Text('${DoseLogic.monthName(_month)} $_year',
                  style: AppTypography.body(16, weight: FontWeight.w700)),
              IconButton(onPressed: _nextMonth, icon: const Icon(Icons.chevron_right_rounded)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: const ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                .map((d) => Expanded(
                      child: Center(
                        child: Text(d,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: BrandColors.inkFaint)),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 6),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 5,
            crossAxisSpacing: 5,
            children: days.map((day) {
              if (day == null) return const SizedBox.shrink();
              final ds = DoseLogic.dateToStr(day);
              return _dayCell(day, ds, meds, events, wStart, wEnd, today);
            }).toList(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _legend(BrandColors.tookItBg, BrandColors.tookIt, 'All doses'),
              const SizedBox(width: 14),
              _legend(BrandColors.notSureBg, BrandColors.notSure, 'Some'),
              const SizedBox(width: 14),
              _legend(BrandColors.skippedBg, BrandColors.skipped, 'None'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dayCell(DateTime day, String ds, List meds, List<DoseEvent> events,
      String wStart, String wEnd, String today) {
    Color bg = Colors.transparent;
    Color fg = BrandColors.ink;
    Color? border;
    final isFuture = ds.compareTo(today) > 0;

    if (isFuture) {
      fg = BrandColors.inkFaint.withValues(alpha: 0.5);
    } else {
      final doses =
          DoseLogic.getDosesForDate(meds.cast(), ds, wakingStart: wStart, wakingEnd: wEnd);
      if (doses.isEmpty) {
        fg = BrandColors.inkFaint;
      } else {
        final completion = DoseLogic.dayCompletion(doses, events);
        if (completion == 'full') {
          bg = BrandColors.tookItBg;
          fg = BrandColors.tookIt;
          border = BrandColors.tookIt.withValues(alpha: 0.4);
        } else if (completion == 'partial') {
          bg = BrandColors.notSureBg;
          fg = BrandColors.notSure;
          border = BrandColors.notSure.withValues(alpha: 0.4);
        } else {
          bg = BrandColors.skippedBg;
          fg = BrandColors.skipped;
          border = BrandColors.skipped.withValues(alpha: 0.35);
        }
      }
    }

    final selected = ds == _selectedDay;
    return GestureDetector(
      onTap: () => setState(() => _selectedDay = selected ? null : ds),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? BrandColors.ocean : (border ?? Colors.transparent),
            width: selected ? 2 : 1,
          ),
        ),
        alignment: Alignment.center,
        child: Text('${day.day}',
            style: AppTypography.body(13, weight: FontWeight.w600, color: fg)),
      ),
    );
  }

  Widget _legend(Color bg, Color border, String label) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: border.withValues(alpha: 0.5)),
          ),
        ),
        const SizedBox(width: 5),
        Text(label, style: AppTypography.body(11, weight: FontWeight.w500, color: BrandColors.inkSoft)),
      ],
    );
  }

  Widget _dayDetail(List meds, List<DoseEvent> events, String wStart, String wEnd) {
    final ds = _selectedDay!;
    final doses = DoseLogic.getDosesForDate(meds.cast(), ds, wakingStart: wStart, wakingEnd: wEnd);
    final date = DoseLogic.strToDate(ds);
    final title =
        '${_weekday(date.weekday)}, ${DoseLogic.monthName(date.month - 1)} ${date.day}';

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: AppTypography.body(16, weight: FontWeight.w700)),
              InkWell(
                onTap: () => setState(() => _selectedDay = null),
                child: const Icon(Icons.close_rounded, size: 18, color: BrandColors.inkFaint),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (doses.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('No doses scheduled.',
                  style: AppTypography.body(13, color: BrandColors.inkFaint)),
            )
          else
            ...doses.map((dose) {
              final ev = DoseLogic.matchDoseToEvent(dose, events);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 74,
                      child: Text(DoseLogic.formatTime(dose.scheduledHhmm),
                          style: AppTypography.body(13, weight: FontWeight.w500, color: BrandColors.inkSoft)),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(dose.medicationName,
                              style: AppTypography.body(14, weight: FontWeight.w600)),
                          Text(dose.eye.label,
                              style: AppTypography.body(11, color: BrandColors.inkFaint)),
                        ],
                      ),
                    ),
                    if (ev != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(ev.response.emoji, style: const TextStyle(fontSize: 18)),
                          Text(DoseLogic.formatIsoTimeShort(ev.responseTime),
                              style: AppTypography.body(10, color: BrandColors.inkFaint)),
                        ],
                      )
                    else
                      Text('—', style: AppTypography.body(14, color: BrandColors.inkFaint)),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  String _weekday(int w) =>
      const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][w - 1];
}
