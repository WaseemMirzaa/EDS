import 'package:flutter/material.dart';

import '../data/dose_logic.dart';
import '../models/dose.dart';
import '../models/dose_event.dart';
import '../theme/app_theme.dart';
import '../theme/brand.dart';
import 'cap_color_dot.dart';

/// A single dose row on the Today list. Shows time, cap colour, medication,
/// eye and instruction tag, with a check button or logged status.
class DoseCard extends StatelessWidget {
  final Dose dose;
  final DoseEvent? event;
  final VoidCallback onCheck;
  const DoseCard({super.key, required this.dose, required this.event, required this.onCheck});

  @override
  Widget build(BuildContext context) {
    final logged = event != null;
    final done = logged; // took_it / not_sure / skipped are all terminal here
    final instr = dose.instructions.summary;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: done ? BrandColors.background : BrandColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: done ? BrandColors.hairline : BrandColors.hairlineCool,
        ),
        boxShadow: done
            ? null
            : [
                BoxShadow(
                  color: BrandColors.ocean.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 66,
            child: Text(
              DoseLogic.formatTime(dose.scheduledHhmm),
              style: AppTypography.body(15,
                  weight: FontWeight.w700,
                  color: done ? BrandColors.inkFaint : BrandColors.ink),
            ),
          ),
          Container(width: 1, height: 40, color: BrandColors.hairline),
          const SizedBox(width: 12),
          CapColorDot(colorKey: dose.bottleCapColor, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dose.medicationName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body(15,
                      weight: FontWeight.w700,
                      color: done ? BrandColors.inkFaint : BrandColors.ink,
                      height: 1.1).copyWith(
                    decoration: done ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: BrandColors.cloud,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(dose.eye.short,
                          style: AppTypography.body(11, weight: FontWeight.w700, color: BrandColors.waves)),
                    ),
                    if (instr.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(instr.first,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.body(12, weight: FontWeight.w600, color: BrandColors.waves)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (logged)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(event!.response.emoji, style: const TextStyle(fontSize: 22)),
                const SizedBox(height: 2),
                Text(event!.response.label,
                    style: AppTypography.body(10, weight: FontWeight.w600, color: BrandColors.inkFaint)),
              ],
            )
          else
            _CheckButton(onTap: onCheck),
        ],
      ),
    );
  }
}

class _CheckButton extends StatelessWidget {
  final VoidCallback onTap;
  const _CheckButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Log this dose',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            gradient: BrandColors.oceanGradient,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: BrandColors.ocean.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Icon(Icons.check_rounded, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}
