import 'package:flutter/material.dart';

import '../data/dose_logic.dart';
import '../models/dose.dart';
import '../theme/app_theme.dart';
import '../theme/brand.dart';
import 'cap_color_dot.dart';
import 'drop_logo.dart';
import 'motion.dart';

/// Hero banner showing the soonest upcoming, not-yet-logged dose with a live
/// countdown — or a celebratory / resting state.
class NextDoseBanner extends StatelessWidget {
  final Dose? nextDose;
  final bool allDone;
  final VoidCallback? onTapNext;
  const NextDoseBanner({super.key, required this.nextDose, required this.allDone, this.onTapNext});

  @override
  Widget build(BuildContext context) {
    if (allDone) return const _AllDoneBanner();
    if (nextDose == null) {
      return _StateCard(
        icon: Icons.wb_sunny_rounded,
        title: 'No doses scheduled today',
        subtitle: 'Enjoy your day.',
      );
    }

    final dose = nextDose!;
    final instr = dose.instructions.summary;
    final now = DateTime.now();
    final parts = dose.scheduledHhmm.split(':').map(int.parse).toList();
    final doseTime = DateTime(now.year, now.month, now.day, parts[0], parts[1]);
    final mins = doseTime.difference(now).inMinutes;
    final due = mins < 0;

    return _GlassHero(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.schedule_rounded, size: 17, color: Colors.white70),
              const SizedBox(width: 7),
              Text(due ? 'Dose is due' : 'Next drop in',
                  style: AppTypography.body(14, weight: FontWeight.w600, color: Colors.white70)),
              const Spacer(),
              _CircleButton(icon: Icons.more_horiz_rounded, onTap: onTapNext),
            ],
          ),
          const SizedBox(height: 8),
          _Countdown(due: due, minutes: mins),
          const SizedBox(height: 12),
          Container(width: 118, height: 1.5, color: Colors.white.withValues(alpha: 0.16)),
          const SizedBox(height: 18),
          Row(
            children: [
              MedMarker(colorKey: dose.bottleCapColor, size: 58),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(dose.medicationName,
                        style: AppTypography.display(23, weight: FontWeight.w700, color: Colors.white),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        const Icon(Icons.event_rounded, size: 14, color: Colors.white60),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text('${DoseLogic.formatTime(dose.scheduledHhmm)}  ·  ${dose.eye.label}',
                              style: AppTypography.body(14, weight: FontWeight.w500, color: Colors.white70)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (instr.isNotEmpty) ...[
            const SizedBox(height: 16),
            _InstructionPill(text: instr.first, onTap: onTapNext),
          ],
        ],
      ),
    );
  }
}

class _Countdown extends StatelessWidget {
  final bool due;
  final int minutes;
  const _Countdown({required this.due, required this.minutes});

  @override
  Widget build(BuildContext context) {
    if (due) {
      return Text('Due now',
          style: AppTypography.display(34, weight: FontWeight.w700, color: Colors.white));
    }
    final h = minutes ~/ 60;
    final m = minutes % 60;
    final unit = AppTypography.display(22, weight: FontWeight.w600, color: Colors.white70);
    final big = AppTypography.display(34, weight: FontWeight.w700, color: Colors.white);
    return RichText(
      text: TextSpan(children: [
        if (h > 0) ...[
          TextSpan(text: '$h', style: big),
          TextSpan(text: 'h ', style: unit),
        ],
        TextSpan(text: '$m', style: big),
        TextSpan(text: 'm', style: unit),
      ]),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _CircleButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), shape: BoxShape.circle),
        child: Icon(icon, size: 19, color: Colors.white),
      ),
    );
  }
}

class _InstructionPill extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  const _InstructionPill({required this.text, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), shape: BoxShape.circle),
              child: const Icon(Icons.lightbulb_outline_rounded, size: 15, color: BrandColors.gold),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body(14.5, weight: FontWeight.w600, color: Colors.white)),
            ),
            const Icon(Icons.chevron_right_rounded, size: 20, color: Colors.white54),
          ],
        ),
      ),
    );
  }
}

/// Deep-ocean hero surface with a soft glow and a faint drop watermark.
class _GlassHero extends StatelessWidget {
  final Widget child;
  const _GlassHero({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: BrandColors.heroGradient,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: BrandColors.primary.withValues(alpha: 0.32),
            blurRadius: 34,
            offset: const Offset(0, 18),
            spreadRadius: -12,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            Positioned(
              top: -70,
              right: -40,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    Colors.white.withValues(alpha: 0.10),
                    Colors.white.withValues(alpha: 0.0),
                  ]),
                ),
              ),
            ),
            Positioned(
              right: -30,
              bottom: -46,
              child: Opacity(
                opacity: 0.07,
                child: DropMark(size: 210, color: Colors.white, filled: true),
              ),
            ),
            Padding(padding: const EdgeInsets.all(22), child: child),
          ],
        ),
      ),
    );
  }
}

class _AllDoneBanner extends StatelessWidget {
  const _AllDoneBanner();

  @override
  Widget build(BuildContext context) {
    return _GlassHero(
      child: Row(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 600),
            curve: Curves.elasticOut,
            builder: (_, v, child) => Transform.scale(scale: v, child: child),
            child: Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(color: BrandColors.gold, shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded, color: BrandColors.primary, size: 28),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('All done for today',
                    style: AppTypography.display(22, weight: FontWeight.w700, color: Colors.white)),
                const SizedBox(height: 2),
                Text('Beautiful work caring for your eyes.',
                    style: AppTypography.body(13, weight: FontWeight.w500, color: Colors.white70)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StateCard extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  const _StateCard({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: BrandColors.cloud,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Icon(icon, size: 30, color: BrandColors.secondary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.body(16, weight: FontWeight.w700, color: BrandColors.primary)),
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
