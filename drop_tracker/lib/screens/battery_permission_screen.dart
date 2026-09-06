import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/auth_controller.dart';
import '../data/permission_service.dart';
import '../theme/app_theme.dart';
import '../theme/brand.dart';
import '../widgets/common.dart';
import '../widgets/drop_logo.dart';

/// Android-only mandatory gate: unrestricted battery so scheduled reminders
/// aren't delayed or killed. Must grant via the native system dialog (or
/// Settings) before the rest of the app is reachable.
class BatteryPermissionScreen extends StatefulWidget {
  const BatteryPermissionScreen({super.key});

  @override
  State<BatteryPermissionScreen> createState() =>
      _BatteryPermissionScreenState();
}

class _BatteryPermissionScreenState extends State<BatteryPermissionScreen>
    with WidgetsBindingObserver {
  bool _busy = false;
  bool _denied = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _recheck(autoAdvance: true));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _recheck(autoAdvance: true);
    }
  }

  Future<void> _recheck({bool autoAdvance = false}) async {
    await context.read<AuthController>().markBatteryDone();
  }

  Future<void> _allow() async {
    setState(() => _busy = true);
    final granted =
        await PermissionService.instance.requestUnrestrictedBattery();
    if (!mounted) return;
    final ok = await context.read<AuthController>().markBatteryDone();
    if (!mounted) return;
    if (granted && ok) return;
    setState(() {
      _busy = false;
      _denied = true;
    });
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
                decoration: const BoxDecoration(
                    color: BrandColors.cloud, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: const Icon(Icons.battery_charging_full_rounded,
                    size: 40, color: BrandColors.primary),
              ),
              const Gap(28),
              Text('Keep reminders reliable',
                  style: AppTypography.display(32, weight: FontWeight.w700)),
              const Gap(12),
              Text(
                'Android can pause background apps to save power, which may delay or drop your dose reminders. Allow Drop Tracker to run unrestricted so alerts always arrive on time.',
                style: AppTypography.body(16,
                    weight: FontWeight.w500,
                    color: BrandColors.inkSoft,
                    height: 1.5),
              ),
              const Gap(24),
              AppCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                child: Column(
                  children: [
                    for (var i = 0; i < _steps.length; i++) ...[
                      if (i > 0)
                        Divider(
                            height: 1,
                            thickness: 1,
                            color: BrandColors.border.withValues(alpha: 0.7)),
                      _step(i + 1, _steps[i]),
                    ],
                  ],
                ),
              ),
              const Spacer(flex: 3),
              if (_denied) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: BrandColors.warningBg,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          size: 20, color: BrandColors.warningText),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                            'Unrestricted battery is required. Open Settings ▸ Apps ▸ Drop Tracker ▸ Battery and choose Unrestricted, then return.',
                            style: AppTypography.body(13.5,
                                weight: FontWeight.w500,
                                color: BrandColors.warningText,
                                height: 1.4)),
                      ),
                    ],
                  ),
                ),
                const Gap(14),
                PrimaryButton(
                  label: 'Open Settings',
                  icon: Icons.settings_rounded,
                  onPressed: () =>
                      PermissionService.instance.openSystemSettings(),
                ),
                const Gap(10),
                PrimaryButton(
                  label: 'Try again',
                  loading: _busy,
                  onPressed: _allow,
                ),
              ] else
                PrimaryButton(
                  label: 'Allow without restrictions',
                  icon: Icons.battery_charging_full_rounded,
                  loading: _busy,
                  onPressed: _allow,
                ),
              const Gap(8),
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

  static const _steps = [
    'Tap “Allow without restrictions” below',
    'Confirm Unrestricted (or “Don’t optimise”) in the system dialog',
    'On Samsung / Xiaomi / Huawei, also add to “Never sleeping apps” if asked',
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
            decoration: BoxDecoration(
                color: BrandColors.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(9)),
            child: Text('$n',
                style: AppTypography.body(14,
                    weight: FontWeight.w700, color: BrandColors.primary)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(text,
                  style: AppTypography.body(14.5,
                      weight: FontWeight.w500, height: 1.4)),
            ),
          ),
        ],
      ),
    );
  }
}
