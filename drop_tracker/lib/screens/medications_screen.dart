import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/dose_logic.dart';
import '../data/drop_store.dart';
import '../models/dose.dart';
import '../models/enums.dart';
import '../models/medication.dart';
import '../theme/app_theme.dart';
import '../theme/brand.dart';
import '../widgets/cap_color_dot.dart';
import '../widgets/common.dart';
import '../widgets/drop_logo.dart';
import '../widgets/motion.dart';
import '../widgets/shop_banner.dart';
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
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
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

  Future<void> _markTaken(BuildContext context, DropStore store, Medication med, String today) async {
    final doses = store.dosesFor(today).where((d) => d.medicationId == med.id).toList();
    final events = store.eventsOn(today);
    Dose? pending;
    for (final d in doses) {
      if (DoseLogic.matchDoseToEvent(d, events) == null) {
        pending = d;
        break;
      }
    }
    if (pending == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${med.name}: all of today\'s doses are logged.')),
      );
      return;
    }
    HapticFeedback.mediumImpact();
    await store.logResponse(pending, DoseResponse.tookIt);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Marked taken · ${DoseLogic.formatTime(pending.scheduledHhmm)}')),
      );
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
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Medications', style: AppTypography.display(32, weight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text('Manage your daily eye medications',
                            style: AppTypography.body(15, weight: FontWeight.w500, color: BrandColors.inkSoft)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _AddButton(
                    onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const MedicationFormScreen())),
                  ),
                ],
              ),
            ),
            Expanded(
              child: meds.isEmpty
                  ? _empty(context)
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                      itemCount: meds.length + 1,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (_, i) {
                        if (i == meds.length) {
                          return FadeSlideIn(
                            delay: Duration(milliseconds: 60 * i),
                            child: const ShopRestockCard(campaign: 'meds_restock'),
                          );
                        }
                        return FadeSlideIn(
                          delay: Duration(milliseconds: 60 * i),
                          child: _medCard(context, store, meds[i], today),
                        );
                      },
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
            Container(
              width: 96,
              height: 96,
              decoration: const BoxDecoration(color: BrandColors.cloud, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: DropMark(size: 46, color: BrandColors.secondary, filled: true),
            ),
            const Gap(20),
            Text('No medications yet', style: AppTypography.display(22, weight: FontWeight.w700)),
            const Gap(8),
            Text('Add your prescriptions to receive reminders and track your treatment.',
                textAlign: TextAlign.center,
                style: AppTypography.body(15, weight: FontWeight.w500, color: BrandColors.inkSoft, height: 1.45)),
            const Gap(24),
            PrimaryButton(
              label: 'Add Medication',
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
        wakingStart: store.user.wakingStart, wakingEnd: store.user.wakingEnd);

    return Opacity(
      opacity: active ? 1 : 0.62,
      child: AppCard(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                MedPill(colorKey: med.bottleCapColor, size: 52),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(med.name,
                          style: AppTypography.display(21, weight: FontWeight.w700),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.visibility_outlined, size: 15, color: BrandColors.inkFaint),
                          const SizedBox(width: 5),
                          Text(med.eye.label,
                              style: AppTypography.body(14, weight: FontWeight.w500, color: BrandColors.inkSoft)),
                          const SizedBox(width: 8),
                          Text('·', style: AppTypography.body(14, color: BrandColors.inkFaint)),
                          const SizedBox(width: 8),
                          Icon(Icons.autorenew_rounded, size: 15, color: BrandColors.inkFaint),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(med.frequencyType.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.body(14, weight: FontWeight.w500, color: BrandColors.inkSoft)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (times.isNotEmpty) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: times.map((t) => _TimeChip(DoseLogic.formatTime(t))).toList(),
              ),
            ],
            if (med.taperSteps.isNotEmpty) ...[
              const SizedBox(height: 12),
              Capsule('Taper · ${med.taperSteps.length} ${med.taperSteps.length == 1 ? "step" : "steps"}',
                  color: BrandColors.secondary, icon: Icons.stairs_rounded),
            ],
            if (!active) ...[
              const SizedBox(height: 12),
              Capsule('Inactive today', color: BrandColors.inkFaint, icon: Icons.pause_rounded),
            ],
            const SizedBox(height: 18),
            Divider(height: 1, color: BrandColors.border),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    icon: Icons.check_circle_outline_rounded,
                    label: 'Mark Taken',
                    fg: BrandColors.primary,
                    bg: BrandColors.primary.withValues(alpha: 0.09),
                    onTap: () => _markTaken(context, store, med, today),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ActionButton(
                    icon: Icons.edit_outlined,
                    label: 'Edit',
                    fg: BrandColors.inkSoft,
                    bg: BrandColors.fill,
                    onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => MedicationFormScreen(existing: med))),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ActionButton(
                    icon: Icons.delete_outline_rounded,
                    label: 'Delete',
                    fg: BrandColors.danger,
                    bg: BrandColors.danger.withValues(alpha: 0.08),
                    onTap: () => _confirmDelete(context, med),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(AppRadius.button),
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: BrandColors.primary,
          borderRadius: BorderRadius.circular(AppRadius.button),
          boxShadow: [
            BoxShadow(color: BrandColors.primary.withValues(alpha: 0.28), blurRadius: 16, offset: const Offset(0, 8), spreadRadius: -6),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), shape: BoxShape.circle),
              child: const Icon(Icons.add_rounded, size: 17, color: Colors.white),
            ),
            const SizedBox(width: 9),
            Text('Add', style: AppTypography.body(16, weight: FontWeight.w700, color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

class _TimeChip extends StatelessWidget {
  final String time;
  const _TimeChip(this.time);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: BrandColors.fill,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule_rounded, size: 14, color: BrandColors.secondary),
          const SizedBox(width: 6),
          Text(time,
              style: AppTypography.body(13.5,
                  weight: FontWeight.w600, color: BrandColors.inkSoft, letterSpacing: 0)),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color fg;
  final Color bg;
  final VoidCallback onTap;
  const _ActionButton({required this.icon, required this.label, required this.fg, required this.bg, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 48,
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 19, color: fg),
            const SizedBox(width: 7),
            Flexible(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body(14, weight: FontWeight.w700, color: fg)),
            ),
          ],
        ),
      ),
    );
  }
}
