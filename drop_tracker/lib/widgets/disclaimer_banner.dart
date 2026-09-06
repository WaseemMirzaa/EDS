import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/brand.dart';

/// Persistent safety disclaimer — Drop Tracker is a reminder/tracking tool
/// only, not a medical device.
class DisclaimerBanner extends StatelessWidget {
  final bool compact;
  const DisclaimerBanner({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: BrandColors.cloud,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BrandColors.hairlineCool),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, size: 20, color: BrandColors.waves),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              compact
                  ? 'A reminder & tracking tool only — not a medical device. Always follow your eye doctor\'s instructions.'
                  : 'Drop Tracker is a reminder and tracking tool only. It is not a medical device and does not provide medical advice. Contact your eye care provider or pharmacist if you are unsure.',
              style: AppTypography.body(13, weight: FontWeight.w500, color: BrandColors.ocean, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
