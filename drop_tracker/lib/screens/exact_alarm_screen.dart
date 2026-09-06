import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/auth_controller.dart';
import '../data/permission_service.dart';
import '../theme/app_theme.dart';
import '../theme/brand.dart';
import '../widgets/common.dart';
import '../widgets/drop_logo.dart';

/// Android-only (API 31+) mandatory gate: "Alarms & reminders" access.
///
/// This is a *separate* permission from notifications and from battery
/// optimisation — Android only grants it via a dedicated system Settings
/// screen, never a runtime dialog, and without it every scheduled reminder
/// silently falls back to an inexact alarm the OS is free to delay by
/// minutes or more. Confirmed on a real MIUI device: a dose reminder sat
/// overdue in AlarmManager's queue well past its due time because this was
/// never granted, even though notification permission and battery
/// unrestricted were both already in place.
class ExactAlarmScreen extends StatefulWidget {
  const ExactAlarmScreen({super.key});

  @override
  State<ExactAlarmScreen> createState() => _ExactAlarmScreenState();
}

class _ExactAlarmScreenState extends State<ExactAlarmScreen>
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
    await context.read<AuthController>().markExactAlarmsDone();
  }

  Future<void> _allow() async {
    setState(() => _busy = true);
    // This opens system Settings rather than a dialog, so its own return
    // value is stale by the time the user comes back — the real check
    // happens in didChangeAppLifecycleState/_recheck on resume.
    await PermissionService.instance.requestExactAlarms();
    if (!mounted) return;
    final ok = await context.read<AuthController>().markExactAlarmsDone();
    if (!mounted) return;
    if (ok) return;
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
                child: const Icon(Icons.alarm_on_rounded,
                    size: 40, color: BrandColors.primary),
              ),
              const Gap(28),
              Text('Allow precise reminder timing',
                  style: AppTypography.display(30, weight: FontWeight.w700)),
              const Gap(12),
              Text(
                'Android treats exact-time alarms as a separate permission from notifications. Without it, your dose reminders can arrive minutes late — or be delayed indefinitely by your phone\'s battery manager.',
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
                            'Still off. Open Settings ▸ Alarms & reminders and allow Drop Tracker, then return here.',
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
                  onPressed: _allow,
                ),
                const Gap(10),
                PrimaryButton(
                  label: 'I\'ve allowed it',
                  loading: _busy,
                  onPressed: () => _recheck(autoAdvance: true),
                ),
              ] else
                PrimaryButton(
                  label: 'Allow exact alarms',
                  icon: Icons.alarm_on_rounded,
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
    'Tap “Allow exact alarms” below',
    'On the system screen, turn on “Allow setting alarms and reminders” for Drop Tracker',
    'Come back — Drop Tracker picks it up automatically',
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
