import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/dose_logic.dart';
import '../data/drop_store.dart';
import '../data/ics_generator.dart';
import '../models/dose.dart';
import '../models/enums.dart';
import '../theme/app_theme.dart';
import '../theme/brand.dart';
import '../widgets/common.dart';
import '../widgets/confidence_check_sheet.dart';
import '../widgets/did_i_take_it_sheet.dart';
import '../widgets/dose_timeline.dart';
import '../widgets/drop_logo.dart';
import '../widgets/motion.dart';
import '../widgets/next_dose_banner.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  Timer? _ticker;
  final Set<String> _prompted = {};
  bool _sheetOpen = false;

  @override
  void initState() {
    super.initState();
    // Refresh the countdown + due-dose detection each minute.
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
      _checkDue();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkDue());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  /// When a scheduled dose becomes due and hasn't been logged, gently open the
  /// Confidence Check (once per dose per session) — mirrors the prototype.
  void _checkDue() {
    if (_sheetOpen) return;
    final store = context.read<DropStore>();
    final today = DoseLogic.todayStr();
    final doses = store.dosesFor(today);
    final events = store.eventsOn(today);
    final now = DateTime.now();
    final nowHhmm =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    for (final dose in doses) {
      final key = '${dose.medicationId}-${dose.scheduledHhmm}';
      final logged = DoseLogic.matchDoseToEvent(dose, events) != null;
      if (logged) {
        _prompted.remove(key);
        continue;
      }
      if (_prompted.contains(key)) continue;
      if (dose.scheduledHhmm.compareTo(nowHhmm) <= 0) {
        _prompted.add(key);
        _openConfidenceCheck(dose);
        break;
      }
    }
  }

  Future<void> _openConfidenceCheck(Dose dose) async {
    _sheetOpen = true;
    final store = context.read<DropStore>();
    final response = await showConfidenceCheck(context, dose);
    _sheetOpen = false;
    if (response != null) {
      if (response == DoseResponse.tookIt) {
        HapticFeedback.mediumImpact();
      } else {
        HapticFeedback.selectionClick();
      }
      await store.logResponse(dose, response);
      if (mounted && response == DoseResponse.snoozed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Snoozed — we\'ll remind you in 10 minutes.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<DropStore>();
    final user = store.user;
    final today = DoseLogic.todayStr();
    final doses = store.dosesFor(today);
    final events = store.eventsOn(today);

    final done = doses.where((d) => DoseLogic.matchDoseToEvent(d, events) != null).toList();
    final doneCount = done.length;
    final progress = doses.isEmpty ? 0.0 : doneCount / doses.length;

    final now = DateTime.now();
    final nowHhmm =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    Dose? nextDose;
    for (final d in doses) {
      if (DoseLogic.matchDoseToEvent(d, events) == null &&
          d.scheduledHhmm.compareTo(nowHhmm) >= 0) {
        nextDose = d;
        break;
      }
    }
    final allDone = doses.isNotEmpty && doneCount == doses.length;

    // Tips: 3+ "not sure" responses in the last 7 days.
    final weekStart = DoseLogic.getLastNDays(7, today).first;
    final notSureWeek = store
        .eventsSince(weekStart)
        .where((e) => e.response == DoseResponse.notSure)
        .length;

    final firstName = user.firstName.isNotEmpty ? user.firstName : 'there';

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            _header(firstName),
            const Gap(20),
            FadeSlideIn(
              child: NextDoseBanner(
                nextDose: nextDose,
                allDone: allDone,
                onTapNext: nextDose == null ? null : () => _openConfidenceCheck(nextDose!),
              ),
            ),
            if (doses.isNotEmpty) ...[
              const Gap(24),
              FadeSlideIn(delay: const Duration(milliseconds: 80), child: _progress(doneCount, doses.length, progress)),
            ],
            const Gap(20),
            if (doses.isEmpty)
              FadeSlideIn(delay: const Duration(milliseconds: 120), child: _emptyState())
            else
              ..._doseList(doses, events),
            if (notSureWeek >= 3) ...[
              const Gap(4),
              _tipsCard(),
            ],
            if (doses.isNotEmpty) ...[
              const Gap(12),
              _didITakeItButton(store),
              const Gap(10),
              SecondaryButton(
                label: 'Add all reminders to Calendar',
                icon: Icons.event_available_rounded,
                onPressed: () => IcsGenerator.share(
                  'drop-tracker-reminders.ics',
                  IcsGenerator.forAll(store.medications, store.user),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _header(String firstName) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(DoseLogic.greeting(),
                  style: AppTypography.body(14, weight: FontWeight.w500, color: BrandColors.inkFaint)),
              const SizedBox(height: 2),
              Text('$firstName 👋',
                  style: AppTypography.display(30, weight: FontWeight.w700)),
            ],
          ),
        ),
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: BrandColors.surface,
            shape: BoxShape.circle,
            boxShadow: BrandColors.softShadow,
          ),
          alignment: Alignment.center,
          child: const DropBadge(size: 34),
        ),
      ],
    );
  }

  Widget _progress(int done, int total, double progress) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Today\'s progress',
                style: AppTypography.body(14, weight: FontWeight.w600, color: BrandColors.inkSoft)),
            Text('$done of $total done',
                style: AppTypography.body(14, weight: FontWeight.w700, color: BrandColors.primary)),
          ],
        ),
        const SizedBox(height: 10),
        // Thin, animated track.
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (_, v, __) => LinearProgressIndicator(
              value: v,
              minHeight: 6,
              backgroundColor: BrandColors.border,
              valueColor: const AlwaysStoppedAnimation(BrandColors.primary),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _doseList(List<Dose> doses, List events) {
    final widgets = <Widget>[];
    for (var i = 0; i < doses.length; i++) {
      final dose = doses[i];
      final event = DoseLogic.matchDoseToEvent(dose, events.cast());
      final t = DoseLogic.formatTime(dose.scheduledHhmm).split(' ');
      widgets.add(FadeSlideIn(
        delay: Duration(milliseconds: 120 + 50 * i),
        child: TimelineRow(
          timeTop: t.first,
          timeBottom: t.last,
          dotColorKey: dose.bottleCapColor,
          extendTop: i > 0,
          extendBottom: i < doses.length - 1,
          child: DoseTimelineCard(
            dose: dose,
            event: event,
            onCheck: () => _openConfidenceCheck(dose),
          ),
        ),
      ));
      // Inline "wait between drops" notification, threaded onto the timeline.
      if (i < doses.length - 1) {
        final next = doses[i + 1];
        final diff = _minDiff(dose.scheduledHhmm, next.scheduledHhmm);
        if (diff <= 5 && (dose.instructions.wait5min || next.instructions.wait5min)) {
          widgets.add(const TimelineRow(child: WaitBanner()));
        }
      }
    }
    return widgets;
  }

  int _minDiff(String a, String b) {
    final pa = a.split(':').map(int.parse).toList();
    final pb = b.split(':').map(int.parse).toList();
    return ((pb[0] * 60 + pb[1]) - (pa[0] * 60 + pa[1])).abs();
  }

  Widget _emptyState() {
    return AppCard(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          Opacity(opacity: 0.5, child: DropMark(size: 48, color: BrandColors.waves, filled: true)),
          const SizedBox(height: 14),
          Text('No medications set up yet',
              style: AppTypography.body(16, weight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text('Add your first eye drop to start tracking.',
              textAlign: TextAlign.center,
              style: AppTypography.body(13, weight: FontWeight.w500, color: BrandColors.inkSoft)),
        ],
      ),
    );
  }

  Widget _tipsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BrandColors.notSureBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: BrandColors.notSure.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tips_and_updates_rounded, size: 18, color: BrandColors.notSure),
              const SizedBox(width: 8),
              Text('Instilling drops — a quick tip',
                  style: AppTypography.body(14, weight: FontWeight.w700, color: BrandColors.notSure)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'You\'ve marked a few doses as "not sure" this week. Try tilting your head back, pulling down the lower lid to make a pocket, and looking up before you squeeze. Consider mentioning this at your next eye-care visit.',
            style: AppTypography.body(13, weight: FontWeight.w500, color: BrandColors.ink, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _didITakeItButton(DropStore store) {
    return SizedBox(
      height: 56,
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => showDidITakeIt(
          context,
          store.medications,
          store.eventsOn(DoseLogic.todayStr()),
        ),
        icon: const Icon(Icons.help_outline_rounded, size: 22),
        label: const Text('Did I take my drop?'),
        style: OutlinedButton.styleFrom(
          foregroundColor: BrandColors.ocean,
          backgroundColor: BrandColors.cloud,
          side: BorderSide(color: BrandColors.waves.withValues(alpha: 0.35), width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          textStyle: AppTypography.body(16, weight: FontWeight.w700),
        ),
      ),
    );
  }
}
