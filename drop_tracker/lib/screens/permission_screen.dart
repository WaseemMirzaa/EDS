import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/auth_controller.dart';
import '../data/notification_service.dart';
import '../theme/app_theme.dart';
import '../theme/brand.dart';
import '../widgets/common.dart';
import '../widgets/drop_logo.dart';

/// Mandatory permission gate. The app is a reminder tool, so notifications are
/// required before continuing to auth / home.
class PermissionScreen extends StatefulWidget {
  const PermissionScreen({super.key});

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen> with WidgetsBindingObserver {
  bool _busy = false;
  bool _denied = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // If the user enabled notifications in system Settings and returned,
    // detect it and proceed.
    if (state == AppLifecycleState.resumed && _denied) _recheck();
  }

  Future<void> _recheck() async {
    final granted = await NotificationService.instance.requestPermissions();
    if (granted && mounted) context.read<AuthController>().markPermissionsDone();
  }

  Future<void> _enable() async {
    setState(() => _busy = true);
    final granted = await NotificationService.instance.requestPermissions();
    if (!mounted) return;
    if (granted) {
      await context.read<AuthController>().markPermissionsDone();
    } else {
      setState(() {
        _busy = false;
        _denied = true;
      });
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
                child: const Icon(Icons.notifications_active_rounded, size: 40, color: BrandColors.primary),
              ),
              const Gap(28),
              Text('Turn on reminders', style: AppTypography.display(32, weight: FontWeight.w700)),
              const Gap(12),
              Text(
                'Drop Tracker reminds you the moment each dose is due. Allow notifications so a reminder can reach you even when the app is closed.',
                style: AppTypography.body(16, weight: FontWeight.w500, color: BrandColors.inkSoft, height: 1.5),
              ),
              const Gap(24),
              AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                child: Column(
                  children: [
                    _featureRow(Icons.schedule_rounded, 'On-time alerts', 'A reminder for every scheduled dose.'),
                    const _RowDivider(),
                    _featureRow(Icons.bedtime_off_rounded, 'Works in the background', 'Nothing missed while the app is closed.'),
                    const _RowDivider(),
                    _featureRow(Icons.lock_outline_rounded, 'Private by design', 'Everything stays on your device.'),
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
                      const Icon(Icons.info_outline_rounded, size: 20, color: BrandColors.warningText),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text('Notifications are off. Enable them in Settings, then come back.',
                            style: AppTypography.body(13.5, weight: FontWeight.w500, color: BrandColors.warningText, height: 1.4)),
                      ),
                    ],
                  ),
                ),
                const Gap(14),
                PrimaryButton(label: 'Open Settings', icon: Icons.settings_rounded, onPressed: _openSettings),
                const Gap(10),
                Center(
                  child: TextButton(
                    onPressed: () => context.read<AuthController>().markPermissionsDone(),
                    child: Text('Continue without reminders',
                        style: AppTypography.body(14, weight: FontWeight.w600, color: BrandColors.inkFaint)),
                  ),
                ),
              ] else
                PrimaryButton(label: 'Enable notifications', loading: _busy, onPressed: _enable),
              const Gap(8),
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

  Widget _featureRow(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: BrandColors.primary.withValues(alpha: 0.09), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, size: 21, color: BrandColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.body(15.5, weight: FontWeight.w700, color: BrandColors.ink)),
                const SizedBox(height: 2),
                Text(subtitle, style: AppTypography.body(13, weight: FontWeight.w500, color: BrandColors.inkSoft, height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openSettings() async {
    final uri = Uri.parse(Platform.isIOS ? 'app-settings:' : 'package:');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }
}

/// Hairline divider between rows inside a feature/step card.
class _RowDivider extends StatelessWidget {
  const _RowDivider();
  @override
  Widget build(BuildContext context) =>
      Divider(height: 1, thickness: 1, color: BrandColors.border.withValues(alpha: 0.7));
}
