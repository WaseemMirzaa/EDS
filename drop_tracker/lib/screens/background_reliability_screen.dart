import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/auth_controller.dart';
import '../data/device_reliability_service.dart';
import '../theme/app_theme.dart';
import '../theme/brand.dart';
import '../widgets/common.dart';
import '../widgets/drop_logo.dart';

/// Mandatory gate shown only on OEMs with well-documented background-kill
/// behaviour beyond stock Android (MIUI/HyperOS, ColorOS, FuntouchOS, EMUI,
/// ...) — see [DeviceReliabilityService]. Walks through Autostart, battery
/// saver, and locking the app in Recent Apps, since none of these can be
/// verified via a public API and must be confirmed by the user themselves.
class BackgroundReliabilityScreen extends StatefulWidget {
  const BackgroundReliabilityScreen({super.key});

  @override
  State<BackgroundReliabilityScreen> createState() =>
      _BackgroundReliabilityScreenState();
}

class _BackgroundReliabilityScreenState
    extends State<BackgroundReliabilityScreen> {
  bool _autostartOpened = false;
  bool _batteryOpened = false;
  bool _lockAcknowledged = false;
  bool _busy = false;

  bool get _allDone => _autostartOpened && _batteryOpened && _lockAcknowledged;

  Future<void> _continue() async {
    setState(() => _busy = true);
    await DeviceReliabilityService.instance.acknowledge();
    if (!mounted) return;
    await context.read<AuthController>().markBackgroundReliabilityDone();
  }

  @override
  Widget build(BuildContext context) {
    final oem = DeviceReliabilityService.instance.oemLabel;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Gap(12),
              Container(
                width: 84,
                height: 84,
                decoration: const BoxDecoration(
                    color: BrandColors.cloud, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: const Icon(Icons.shield_moon_rounded,
                    size: 40, color: BrandColors.primary),
              ),
              const Gap(28),
              Text('One more thing for $oem phones',
                  style: AppTypography.display(30, weight: FontWeight.w700)),
              const Gap(12),
              Text(
                '$oem\'s own battery manager can silently stop Drop Tracker in the background — even with every Android permission granted — which means reminders never fire. These 3 steps stop that. Please complete all of them.',
                style: AppTypography.body(16,
                    weight: FontWeight.w500,
                    color: BrandColors.inkSoft,
                    height: 1.5),
              ),
              const Gap(24),
              _stepCard(
                icon: Icons.rocket_launch_rounded,
                title: '1. Enable Autostart',
                body:
                    'Security app ▸ Permissions ▸ Autostart ▸ turn on for Drop Tracker.',
                done: _autostartOpened,
                buttonLabel: 'Open Autostart settings',
                onTap: () async {
                  await DeviceReliabilityService.instance
                      .openAutostartSettings();
                  if (mounted) setState(() => _autostartOpened = true);
                },
              ),
              const Gap(14),
              _stepCard(
                icon: Icons.battery_saver_rounded,
                title: '2. Battery saver — No restrictions',
                body:
                    'Battery saver ▸ Choose apps ▸ Drop Tracker ▸ No restrictions.',
                done: _batteryOpened,
                buttonLabel: 'Open battery settings',
                onTap: () async {
                  await DeviceReliabilityService.instance
                      .openBatterySettings();
                  if (mounted) setState(() => _batteryOpened = true);
                },
              ),
              const Gap(14),
              _stepCard(
                icon: Icons.push_pin_rounded,
                title: '3. Lock Drop Tracker in Recent Apps',
                body:
                    'Open Recent Apps ▸ long-press Drop Tracker\'s card ▸ Lock. This is the single biggest thing that keeps $oem from killing the app.',
                done: _lockAcknowledged,
                buttonLabel: 'I\'ve locked the app',
                onTap: () => setState(() => _lockAcknowledged = true),
              ),
              const Gap(24),
              PrimaryButton(
                label: 'Continue',
                icon: Icons.arrow_forward_rounded,
                loading: _busy,
                onPressed: _allDone ? _continue : null,
              ),
              if (!_allDone) ...[
                const Gap(10),
                Center(
                  child: Text(
                    'Complete all 3 steps above to continue.',
                    style: AppTypography.body(13,
                        weight: FontWeight.w500, color: BrandColors.inkFaint),
                  ),
                ),
              ],
              const Gap(16),
              Center(
                child: Opacity(
                  opacity: 0.5,
                  child: DropWordmark(
                      height: 18,
                      textColor: BrandColors.inkSoft,
                      ringColor: BrandColors.primary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepCard({
    required IconData icon,
    required String title,
    required String body,
    required bool done,
    required String buttonLabel,
    required VoidCallback onTap,
  }) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      borderColor: done ? BrandColors.success.withValues(alpha: 0.4) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: (done ? BrandColors.success : BrandColors.primary)
                      .withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon,
                    size: 19,
                    color: done ? BrandColors.success : BrandColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(title,
                    style: AppTypography.body(15.5, weight: FontWeight.w700)),
              ),
              if (done)
                const Icon(Icons.check_circle_rounded,
                    size: 20, color: BrandColors.success),
            ],
          ),
          const Gap(8),
          Text(body,
              style: AppTypography.body(13.5,
                  weight: FontWeight.w500,
                  color: BrandColors.inkSoft,
                  height: 1.4)),
          const Gap(12),
          SecondaryButton(
            label: done ? 'Done — open again' : buttonLabel,
            onPressed: onTap,
          ),
        ],
      ),
    );
  }
}
