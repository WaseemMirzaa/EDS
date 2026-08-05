import 'package:flutter/material.dart';

import '../data/dose_logic.dart';
import '../models/dose.dart';
import '../theme/app_theme.dart';
import '../theme/brand.dart';
import 'cap_color_dot.dart';

/// Hero banner showing the soonest upcoming, not-yet-logged dose with a live
/// countdown — or a celebratory / resting state.
class NextDoseBanner extends StatelessWidget {
  final Dose? nextDose;
  final bool allDone;
  const NextDoseBanner({super.key, required this.nextDose, required this.allDone});

  @override
  Widget build(BuildContext context) {
    if (allDone) {
      return _StateCard(
        bg: BrandColors.tookItBg,
        border: BrandColors.tookIt.withValues(alpha: 0.4),
        icon: Icons.check_circle_rounded,
        iconColor: BrandColors.tookIt,
        title: 'All done for today!',
        subtitle: 'Great work taking care of your eyes. 🎉',
        titleColor: BrandColors.tookIt,
      );
    }
    if (nextDose == null) {
      return _StateCard(
        bg: BrandColors.cloud,
        border: BrandColors.hairlineCool,
        icon: Icons.wb_sunny_rounded,
        iconColor: BrandColors.waves,
        title: 'No doses scheduled today',
        subtitle: 'Enjoy your day!',
        titleColor: BrandColors.ocean,
      );
    }

    final dose = nextDose!;
    final instr = dose.instructions.summary;
    final now = DateTime.now();
    final parts = dose.scheduledHhmm.split(':').map(int.parse).toList();
    final doseTime = DateTime(now.year, now.month, now.day, parts[0], parts[1]);
    final mins = doseTime.difference(now).inMinutes;
    String timeLabel;
    if (mins < 0) {
      timeLabel = 'Due now';
    } else if (mins < 60) {
      timeLabel = 'In $mins min';
    } else {
      timeLabel = 'In ${mins ~/ 60}h ${mins % 60}m';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: BrandColors.oceanGradient,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: BrandColors.ocean.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.schedule_rounded, size: 18, color: Colors.white70),
              const SizedBox(width: 6),
              Text('Next drop · $timeLabel',
                  style: AppTypography.body(13, weight: FontWeight.w600, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              CapColorDot(colorKey: dose.bottleCapColor, size: 34),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(dose.medicationName,
                        style: AppTypography.display(22, weight: FontWeight.w600, color: Colors.white),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text('${DoseLogic.formatTime(dose.scheduledHhmm)} · ${dose.eye.label}',
                        style: AppTypography.body(14, weight: FontWeight.w500, color: Colors.white70)),
                  ],
                ),
              ),
            ],
          ),
          if (instr.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.tips_and_updates_rounded, size: 16, color: BrandColors.sunshine),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(instr.first,
                        style: AppTypography.body(13, weight: FontWeight.w600, color: Colors.white)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StateCard extends StatelessWidget {
  final Color bg, border, iconColor, titleColor;
  final IconData icon;
  final String title, subtitle;
  const _StateCard({
    required this.bg,
    required this.border,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 30, color: iconColor),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.body(16, weight: FontWeight.w700, color: titleColor)),
                const SizedBox(height: 2),
                Text(subtitle, style: AppTypography.body(13, weight: FontWeight.w500, color: BrandColors.inkSoft)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
