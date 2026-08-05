import 'package:flutter/material.dart';

import '../data/dose_logic.dart';
import '../models/dose.dart';
import '../models/enums.dart';
import '../theme/app_theme.dart';
import '../theme/brand.dart';

/// The Confidence Check modal. Returns the chosen [DoseResponse], or null on
/// Cancel.
Future<DoseResponse?> showConfidenceCheck(BuildContext context, Dose dose) {
  return showModalBottomSheet<DoseResponse>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => _ConfidenceSheet(dose: dose),
  );
}

class _Option {
  final DoseResponse response;
  final String title;
  final String sub;
  const _Option(this.response, this.title, this.sub);
}

const _options = [
  _Option(DoseResponse.tookIt, 'Took it', 'I instilled the drop'),
  _Option(DoseResponse.notSure, 'Not sure it went in', 'I think I missed'),
  _Option(DoseResponse.snoozed, 'Snooze 10 min', 'Remind me shortly'),
  _Option(DoseResponse.skipped, 'Skip this dose', 'I\'ll skip for now'),
];

class _ConfidenceSheet extends StatelessWidget {
  final Dose dose;
  const _ConfidenceSheet({required this.dose});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: BrandColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: 20 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: BrandColors.hairline,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text('Confidence Check',
              style: AppTypography.body(13, weight: FontWeight.w600, color: BrandColors.inkFaint)),
          const SizedBox(height: 4),
          Text(dose.medicationName,
              textAlign: TextAlign.center,
              style: AppTypography.display(24, weight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text('${dose.eye.label} · ${DoseLogic.formatTime(dose.scheduledHhmm)}',
              style: AppTypography.body(14, weight: FontWeight.w500, color: BrandColors.inkSoft)),
          const SizedBox(height: 20),
          ..._options.map((o) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _OptionButton(
                  option: o,
                  onTap: () => Navigator.of(context).pop(o.response),
                ),
              )),
          const SizedBox(height: 4),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel',
                style: AppTypography.body(15, weight: FontWeight.w600, color: BrandColors.inkFaint)),
          ),
        ],
      ),
    );
  }
}

class _OptionButton extends StatelessWidget {
  final _Option option;
  final VoidCallback onTap;
  const _OptionButton({required this.option, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final r = option.response;
    return Material(
      color: r.bg,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: r.color.withValues(alpha: 0.4), width: 1.5),
          ),
          child: Row(
            children: [
              Text(r.emoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(option.title,
                        style: AppTypography.body(16, weight: FontWeight.w700, color: r.color)),
                    Text(option.sub,
                        style: AppTypography.body(12, weight: FontWeight.w500, color: r.color.withValues(alpha: 0.8))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
