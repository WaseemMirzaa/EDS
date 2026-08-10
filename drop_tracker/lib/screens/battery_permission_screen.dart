import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/auth_controller.dart';
import '../theme/app_theme.dart';
import '../theme/brand.dart';
import '../widgets/common.dart';
import '../widgets/drop_logo.dart';

/// Android-only gate shown right after the notification screen. Guides the
/// user to turn off battery restrictions so scheduled reminders aren't killed
/// by the OS (Proposal §04). iOS never reaches this screen.
class BatteryPermissionScreen extends StatelessWidget {
  const BatteryPermissionScreen({super.key});

  Future<void> _openSettings(BuildContext context) async {
    // Best-effort: opens the app's system settings page where "Unrestricted"
    // battery usage lives. (A real ignore-battery-optimizations intent is wired
    // with a platform channel in M2.)
    try {
      await launchUrl(Uri.parse('package:'), mode: LaunchMode.externalApplication);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Open Settings ▸ Apps ▸ Drop Tracker ▸ Battery.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(flex: 2),
              Container(
                width: 84,
                height: 84,
                decoration: const BoxDecoration(color: BrandColors.cloud, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: const Icon(Icons.battery_charging_full_rounded, size: 40, color: BrandColors.primary),
              ),
              const Gap(28),
              Text('Keep reminders reliable', style: AppTypography.display(32, weight: FontWeight.w700)),
              const Gap(12),
              Text(
                'Android can pause background apps to save power, which may delay or drop your dose reminders. Allow Drop Tracker to run unrestricted so alerts always arrive on time.',
                style: AppTypography.body(16, weight: FontWeight.w500, color: BrandColors.inkSoft, height: 1.5),
              ),
              const Gap(24),
              _step(1, 'Tap “Turn off restrictions” below'),
              _step(2, 'Open Battery and choose Unrestricted (or “Don’t optimise”)'),
              _step(3, 'On Samsung / Xiaomi / Huawei, add to “Never sleeping apps”'),
              const Spacer(flex: 3),
              PrimaryButton(
                label: 'Turn off restrictions',
                icon: Icons.settings_rounded,
                onPressed: () => _openSettings(context),
              ),
              const Gap(10),
              Center(
                child: TextButton(
                  onPressed: () => context.read<AuthController>().markBatteryDone(),
                  child: Text('Done — continue',
                      style: AppTypography.body(15, weight: FontWeight.w700, color: BrandColors.primary)),
                ),
              ),
              const Gap(4),
              Center(
                child: Opacity(
                  opacity: 0.5,
                  child: DropWordmark(height: 18, textColor: BrandColors.inkSoft, ringColor: BrandColors.primary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _step(int n, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: BrandColors.primary.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(9)),
            child: Text('$n', style: AppTypography.body(14, weight: FontWeight.w700, color: BrandColors.primary)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(text, style: AppTypography.body(14.5, weight: FontWeight.w500, height: 1.4)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Guard so callers can cheaply check whether this step applies.
bool get batteryStepApplies => Platform.isAndroid;
