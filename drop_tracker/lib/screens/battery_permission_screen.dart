import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/auth_controller.dart';
import '../theme/app_theme.dart';
import '../theme/brand.dart';
import '../widgets/common.dart';
import '../widgets/drop_logo.dart';

/// Mandatory "no restrictions" gate shown right after the notification screen,
/// on BOTH platforms. Guides the user to let reminders run unrestricted so
/// scheduled doses aren't delayed or dropped (Proposal §04):
///  • iOS   → Time-Sensitive alerts + Focus + Low Power
///  • Android → unrestricted battery usage
class BatteryPermissionScreen extends StatelessWidget {
  const BatteryPermissionScreen({super.key});

  Future<void> _openSettings(BuildContext context) async {
    // iOS → app settings (Notifications live here); Android → app details
    // page where "Unrestricted" battery usage lives.
    final uri = Uri.parse(Platform.isIOS ? 'app-settings:' : 'package:');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(Platform.isIOS
              ? 'Open Settings ▸ Drop Tracker ▸ Notifications.'
              : 'Open Settings ▸ Apps ▸ Drop Tracker ▸ Battery.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isIOS = Platform.isIOS;
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
                child: Icon(isIOS ? Icons.notifications_active_rounded : Icons.battery_charging_full_rounded,
                    size: 40, color: BrandColors.primary),
              ),
              const Gap(28),
              Text('Keep reminders reliable', style: AppTypography.display(32, weight: FontWeight.w700)),
              const Gap(12),
              Text(
                isIOS
                    ? 'iOS can hold back notifications during Focus or Low Power Mode, which may delay a dose reminder. Allow Drop Tracker to alert you without restrictions so reminders always break through.'
                    : 'Android can pause background apps to save power, which may delay or drop your dose reminders. Allow Drop Tracker to run unrestricted so alerts always arrive on time.',
                style: AppTypography.body(16, weight: FontWeight.w500, color: BrandColors.inkSoft, height: 1.5),
              ),
              const Gap(24),
              AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                child: Column(
                  children: [
                    for (var i = 0; i < _steps(isIOS).length; i++) ...[
                      if (i > 0) Divider(height: 1, thickness: 1, color: BrandColors.border.withValues(alpha: 0.7)),
                      _step(i + 1, _steps(isIOS)[i]),
                    ],
                  ],
                ),
              ),
              const Spacer(flex: 3),
              PrimaryButton(
                label: 'Allow without restrictions',
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

  List<String> _steps(bool isIOS) => isIOS
      ? const [
          'Tap “Allow without restrictions” below',
          'Turn on Allow Notifications and Time-Sensitive Notifications',
          'Add Drop Tracker to any Focus so alerts still come through, and avoid relying on Low Power Mode',
        ]
      : const [
          'Tap “Allow without restrictions” below',
          'Open Battery and choose Unrestricted (or “Don’t optimise”)',
          'On Samsung / Xiaomi / Huawei, add to “Never sleeping apps”',
        ];

  Widget _step(int n, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
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
              padding: const EdgeInsets.only(top: 3),
              child: Text(text, style: AppTypography.body(14.5, weight: FontWeight.w500, height: 1.4)),
            ),
          ),
        ],
      ),
    );
  }
}
