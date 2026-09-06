import 'package:flutter/material.dart';

import '../data/permission_service.dart';
import '../theme/app_theme.dart';
import '../theme/brand.dart';
import '../widgets/common.dart';

/// Android battery-optimisation guidance (Proposal §04). iOS does not use
/// battery optimisation — open this screen only from Android Settings.
class BatteryOptimizationScreen extends StatelessWidget {
  const BatteryOptimizationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reliable reminders')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: BrandColors.oceanGradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(Icons.battery_charging_full_rounded,
                      color: BrandColors.sunshine, size: 34),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'To make sure your drop reminders always arrive on time, allow Drop Tracker to run without battery restrictions.',
                      style: AppTypography.body(14,
                          weight: FontWeight.w600,
                          color: Colors.white,
                          height: 1.45),
                    ),
                  ),
                ],
              ),
            ),
            const Gap(20),
            ..._androidSteps(),
            const Gap(20),
            AppCard(
              color: BrandColors.notSureBg,
              borderColor: BrandColors.notSure.withValues(alpha: 0.3),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: BrandColors.notSure, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'These settings live in your phone\'s system settings and vary by device model. The steps above cover the most common path.',
                      style: AppTypography.body(13,
                          weight: FontWeight.w500,
                          color: BrandColors.ink,
                          height: 1.45),
                    ),
                  ),
                ],
              ),
            ),
            const Gap(16),
            PrimaryButton(
              label: 'Allow unrestricted battery',
              icon: Icons.battery_charging_full_rounded,
              onPressed: () async {
                final ok = await PermissionService.instance
                    .requestUnrestrictedBattery();
                if (!context.mounted) return;
                if (!ok) {
                  await PermissionService.instance.openSystemSettings();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Battery unrestricted — reminders can run on time.')),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _androidSteps() => const [
        _Step(1, 'Open Settings ▸ Apps ▸ Drop Tracker.'),
        _Step(2, 'Tap Battery ▸ Unrestricted (or "Don\'t optimise").'),
        _Step(3, 'Enable Notifications and Allow alarms & reminders if asked.'),
        _Step(4,
            'On Samsung / Xiaomi / Huawei: also add Drop Tracker to "Never sleeping apps" or turn off aggressive battery saving.'),
      ];
}

class _Step extends StatelessWidget {
  final int n;
  final String text;
  const _Step(this.n, this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration:
                const BoxDecoration(color: BrandColors.cloud, shape: BoxShape.circle),
            child: Text('$n',
                style: AppTypography.body(14,
                    weight: FontWeight.w700, color: BrandColors.ocean)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(text,
                  style: AppTypography.body(14,
                      weight: FontWeight.w500, height: 1.45)),
            ),
          ),
        ],
      ),
    );
  }
}
