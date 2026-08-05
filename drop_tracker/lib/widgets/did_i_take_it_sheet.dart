import 'package:flutter/material.dart';

import '../data/dose_logic.dart';
import '../models/dose_event.dart';
import '../models/medication.dart';
import '../theme/app_theme.dart';
import '../theme/brand.dart';
import 'cap_color_dot.dart';

/// "Did I take my drop?" — a quick reassurance sheet showing the most recent
/// logged status for each medication today.
Future<void> showDidITakeIt(
  BuildContext context,
  List<Medication> meds,
  List<DoseEvent> todayEvents,
) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => _DidITakeItSheet(meds: meds, events: todayEvents),
  );
}

class _DidITakeItSheet extends StatelessWidget {
  final List<Medication> meds;
  final List<DoseEvent> events;
  const _DidITakeItSheet({required this.meds, required this.events});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      decoration: const BoxDecoration(
        color: BrandColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: 16 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: BrandColors.hairline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Did I take my drop?',
              style: AppTypography.display(22, weight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('Most recent status today',
              style: AppTypography.body(13, weight: FontWeight.w500, color: BrandColors.inkFaint)),
          const SizedBox(height: 16),
          Flexible(
            child: meds.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text('No medications yet.',
                        style: AppTypography.body(14, color: BrandColors.inkFaint)),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: meds.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _row(meds[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _row(Medication med) {
    final medEvents = events.where((e) => e.medicationId == med.id).toList()
      ..sort((a, b) => b.responseTime.compareTo(a.responseTime));
    final last = medEvents.isNotEmpty ? medEvents.first : null;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: BrandColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BrandColors.hairline),
      ),
      child: Row(
        children: [
          CapColorDot(colorKey: med.bottleCapColor, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(med.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body(15, weight: FontWeight.w700)),
                Text(med.eye.label,
                    style: AppTypography.body(12, weight: FontWeight.w500, color: BrandColors.inkFaint)),
              ],
            ),
          ),
          if (last != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(last.response.emoji, style: const TextStyle(fontSize: 20)),
                Text(DoseLogic.formatIsoTimeShort(last.responseTime),
                    style: AppTypography.body(11, weight: FontWeight.w500, color: BrandColors.inkFaint)),
              ],
            )
          else
            Text('No record today',
                style: AppTypography.body(12, weight: FontWeight.w500, color: BrandColors.inkFaint)),
        ],
      ),
    );
  }
}
