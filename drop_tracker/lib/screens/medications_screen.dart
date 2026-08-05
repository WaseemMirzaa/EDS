import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/dose_logic.dart';
import '../data/drop_store.dart';
import '../data/ics_generator.dart';
import '../models/medication.dart';
import '../theme/app_theme.dart';
import '../theme/brand.dart';
import '../widgets/cap_color_dot.dart';
import '../widgets/common.dart';
import '../widgets/drop_logo.dart';
import 'medication_form_screen.dart';

class MedicationsScreen extends StatelessWidget {
  const MedicationsScreen({super.key});

  Future<void> _confirmDelete(BuildContext context, Medication med) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete medication?'),
        content: Text(
            'This permanently removes "${med.name}" and cancels its future reminders. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: BrandColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await context.read<DropStore>().deleteMedication(med.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Medication deleted')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<DropStore>();
    final meds = store.medications;
    final today = DoseLogic.todayStr();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Medications', style: AppTypography.display(28, weight: FontWeight.w600)),
                  ),
                  FilledButton.icon(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const MedicationFormScreen())),
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: const Text('Add'),
                    style: FilledButton.styleFrom(
                      backgroundColor: BrandColors.ocean,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: meds.isEmpty
                  ? _empty(context)
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: meds.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) => _medCard(context, store, meds[i], today),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _empty(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Opacity(opacity: 0.4, child: DropMark(size: 56, color: BrandColors.waves, filled: true)),
            const Gap(16),
            Text('No medications yet', style: AppTypography.body(17, weight: FontWeight.w700)),
            const Gap(6),
            Text('Add your first eye drop to start tracking.',
                textAlign: TextAlign.center,
                style: AppTypography.body(14, color: BrandColors.inkSoft)),
            const Gap(20),
            PrimaryButton(
              label: 'Add your first drop',
              icon: Icons.add_rounded,
              onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const MedicationFormScreen())),
            ),
          ],
        ),
      ),
    );
  }

  Widget _medCard(BuildContext context, DropStore store, Medication med, String today) {
    final active = DoseLogic.isMedicationActiveOn(med, today);
    final times = DoseLogic.getDoseTimesForDate(med, today,
            wakingStart: store.user.wakingStart, wakingEnd: store.user.wakingEnd)
        .map(DoseLogic.formatTime)
        .join(' · ');

    return Opacity(
      opacity: active ? 1 : 0.6,
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CapColorDot(colorKey: med.bottleCapColor, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(med.name, style: AppTypography.body(16, weight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text('${med.eye.label} · ${med.frequencyType.label}',
                          style: AppTypography.body(13, weight: FontWeight.w500, color: BrandColors.inkSoft)),
                      if (times.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(times,
                            style: AppTypography.body(12, weight: FontWeight.w500, color: BrandColors.inkFaint)),
                      ],
                      if (med.taperSteps.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Pill('Taper · ${med.taperSteps.length} steps',
                            color: BrandColors.waves, bg: BrandColors.cloud, icon: Icons.stairs_rounded),
                      ],
                      if (!active) ...[
                        const SizedBox(height: 6),
                        Text('Inactive today',
                            style: AppTypography.body(12, weight: FontWeight.w600, color: BrandColors.inkFaint)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _iconAction(
                  icon: Icons.event_available_rounded,
                  label: 'Calendar',
                  color: BrandColors.waves,
                  onTap: () => IcsGenerator.share(
                    '${med.name}-reminders.ics',
                    IcsGenerator.forMedication(med, store.user),
                  ),
                ),
                _iconAction(
                  icon: Icons.edit_rounded,
                  label: 'Edit',
                  color: BrandColors.inkSoft,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => MedicationFormScreen(existing: med))),
                ),
                _iconAction(
                  icon: Icons.delete_outline_rounded,
                  label: 'Delete',
                  color: BrandColors.danger,
                  onTap: () => _confirmDelete(context, med),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18, color: color),
      label: Text(label, style: AppTypography.body(13, weight: FontWeight.w600, color: color)),
      style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10)),
    );
  }
}
