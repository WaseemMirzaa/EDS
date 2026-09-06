import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/auth_controller.dart';
import '../data/device_reliability_service.dart';
import '../data/drop_store.dart';
import '../data/ics_generator.dart';
import '../data/notification_service.dart';
import '../data/shop.dart';
import '../data/trusted_clock.dart';
import '../theme/app_theme.dart';
import '../theme/brand.dart';
import '../widgets/common.dart';
import '../widgets/disclaimer_banner.dart';
import '../widgets/drop_logo.dart';
import '../widgets/motion.dart';
import '../widgets/shop_banner.dart';
import 'background_reliability_screen.dart';
import 'battery_optimization_screen.dart';
import 'profile_screen.dart';

// Placeholder brand URLs — swap for the live legal pages before store submission.
const _privacyUrl = 'https://eyedropshop.com/privacy';
const _termsUrl = 'https://eyedropshop.com/terms';
const _accountDeletionUrl = 'https://eyedropshop.com/account-deletion';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _open(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open $url')));
      }
    }
  }

  /// Exports every medication's reminders as one combined .ics and opens the
  /// share sheet. Guards the two ways this silently "did nothing" before:
  /// no medications to export, and any failure (file write, or the iPad
  /// share-sheet popover crash when no anchor rect is given) going
  /// unreported.
  Future<void> _exportIcs(BuildContext context, DropStore store) async {
    if (store.medications.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Add a medication first, then export reminders.')));
      return;
    }
    try {
      final box = context.findRenderObject() as RenderBox?;
      final origin = box != null
          ? box.localToGlobal(Offset.zero) & box.size
          : null;
      await IcsGenerator.share(
        'drop-tracker-reminders.ics',
        IcsGenerator.forAll(store.medications, store.user),
        sharePositionOrigin: origin,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not export reminders: $e')));
      }
    }
  }

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete account & data?'),
        content: const Text(
            'This permanently erases all your medications, history and settings from this device, and cancels every reminder. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: BrandColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete everything'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await context.read<DropStore>().deleteAllData();
      if (context.mounted) await context.read<AuthController>().signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<DropStore>();
    final auth = context.watch<AuthController>();
    final name = store.user.firstName;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            Text('Settings', style: AppTypography.display(32, weight: FontWeight.w700)),
            const Gap(20),

            // Profile navigation
            AppCard(
              padding: const EdgeInsets.all(16),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileScreen())),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: const BoxDecoration(color: BrandColors.cloud, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Text(
                      (name.isNotEmpty ? name : (auth.email ?? 'U'))[0].toUpperCase(),
                      style: AppTypography.display(24, weight: FontWeight.w700, color: BrandColors.primary),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name.isNotEmpty ? name : 'Set up your profile',
                            style: AppTypography.body(17, weight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(auth.email ?? 'Name & waking hours',
                            style: AppTypography.body(13.5, weight: FontWeight.w500, color: BrandColors.inkSoft)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: BrandColors.inkFaint),
                ],
              ),
            ),
            if (store.pendingSyncCount > 0) ...[
              const Gap(10),
              _SyncPendingBanner(count: store.pendingSyncCount),
            ],
            const Gap(24),

            // Shop
            const SectionLabel('Eye Drop Shop'),
            ShopRestockCard(
              title: 'Shop eye care essentials',
              subtitle: 'Over-the-counter dry-eye care at ${Shop.displayDomain}',
              campaign: 'settings_shop',
            ),
            const Gap(24),

            // Reminders
            const SectionLabel('Reminders'),
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  _tile(
                    icon: Icons.notifications_active_rounded,
                    title: 'Notification permissions',
                    subtitle: 'Allow Drop Tracker to remind you on time.',
                    onTap: () async {
                      final granted = await NotificationService.instance.requestPermissions();
                      if (!context.mounted) return;
                      await context.read<AuthController>().refreshPermissionStatus();
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(granted
                              ? 'Notifications enabled.'
                              : 'Notifications are turned off in system settings.')));
                    },
                  ),
                  // Battery unrestricted is Android-only (not applicable on iOS).
                  if (Platform.isAndroid) ...[
                    const Divider(height: 1),
                    _tile(
                      icon: Icons.battery_charging_full_rounded,
                      title: 'Keep reminders reliable',
                      subtitle: 'Battery-optimisation guidance for your device.',
                      onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const BatteryOptimizationScreen())),
                    ),
                  ],
                  if (DeviceReliabilityService.instance
                      .needsManualBackgroundSetup) ...[
                    const Divider(height: 1),
                    _tile(
                      icon: Icons.shield_moon_rounded,
                      title:
                          '${DeviceReliabilityService.instance.oemLabel} background setup',
                      subtitle: 'Autostart, battery saver & lock — revisit the steps.',
                      onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const BackgroundReliabilityScreen())),
                    ),
                  ],
                  const Divider(height: 1),
                  _tile(
                    icon: Icons.event_available_rounded,
                    title: 'Add all reminders to Calendar',
                    subtitle: 'Export a combined .ics file.',
                    onTap: () => _exportIcs(context, store),
                  ),
                ],
              ),
            ),
            const _ReminderDiagnosticsBanner(),
            const Gap(24),

            // Safety
            const SectionLabel('Safety'),
            const DisclaimerBanner(),
            const Gap(24),

            // About & legal
            const SectionLabel('About & legal'),
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  _tile(icon: Icons.privacy_tip_outlined, title: 'Privacy Policy', trailing: Icons.open_in_new_rounded, onTap: () => _open(context, _privacyUrl)),
                  const Divider(height: 1),
                  _tile(icon: Icons.article_outlined, title: 'Terms of Service', trailing: Icons.open_in_new_rounded, onTap: () => _open(context, _termsUrl)),
                ],
              ),
            ),
            const Gap(24),

            // Account
            const SectionLabel('Account'),
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  _tile(
                    icon: Icons.replay_rounded,
                    title: 'Restart onboarding',
                    subtitle: 'Replay the intro without deleting medications.',
                    onTap: () => context.read<DropStore>().updateUser(onboarded: false),
                  ),
                  const Divider(height: 1),
                  _tile(
                    icon: Icons.delete_forever_outlined,
                    title: 'Delete account & data',
                    subtitle: 'Erase everything on this device.',
                    color: BrandColors.danger,
                    onTap: () => _confirmDeleteAccount(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text('On Android you can also request deletion via our web portal.',
                style: AppTypography.body(12, color: BrandColors.inkFaint)),
            TextButton(
              onPressed: () => _open(context, _accountDeletionUrl),
              style: TextButton.styleFrom(
                  padding: EdgeInsets.zero, minimumSize: const Size(0, 32), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              child: Text('Open account-deletion portal',
                  style: AppTypography.body(12, weight: FontWeight.w700, color: BrandColors.secondary)),
            ),
            const Gap(16),
            SecondaryButton(
              label: 'Log Out',
              icon: Icons.logout_rounded,
              color: BrandColors.danger,
              onPressed: () => context.read<AuthController>().signOut(),
            ),
            const Gap(24),

            Center(
              child: Opacity(
                opacity: 0.55,
                child: Column(
                  children: [
                    DropWordmark(height: 20, textColor: BrandColors.inkSoft, ringColor: BrandColors.primary),
                    const SizedBox(height: 8),
                    Text('Drop Tracker v1.0.0 · by eye doctors, for you',
                        style: AppTypography.body(11, color: BrandColors.inkFaint)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile({
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
    Color color = BrandColors.ink,
    IconData trailing = Icons.chevron_right_rounded,
  }) {
    final isDanger = color == BrandColors.danger;
    final iconColor = color == BrandColors.ink ? BrandColors.primary : color;
    return Pressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        constraints: const BoxConstraints(minHeight: 60),
        padding: const EdgeInsets.symmetric(vertical: 10),
        color: Colors.transparent,
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: (isDanger ? BrandColors.danger : BrandColors.primary).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.body(15.5, weight: FontWeight.w600, color: color)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 1),
                    Text(subtitle, style: AppTypography.body(12.5, color: BrandColors.inkFaint)),
                  ],
                ],
              ),
            ),
            Icon(trailing, size: 20, color: BrandColors.inkFaint),
          ],
        ),
      ),
    );
  }
}

/// Quiet, only-when-noteworthy diagnostics for the reminder schedule:
/// * the rolling notification window is about to run dry (app hasn't been
///   opened in a while, so nothing has re-topped it up — see
///   [NotificationService.rescheduleAll]),
/// * the device clock looks meaningfully wrong (reminder times may be off),
/// * Android denied exact alarms, so timing may drift by a few minutes.
/// Shows nothing at all when everything is healthy.
class _ReminderDiagnosticsBanner extends StatefulWidget {
  const _ReminderDiagnosticsBanner();

  @override
  State<_ReminderDiagnosticsBanner> createState() =>
      _ReminderDiagnosticsBannerState();
}

class _ReminderDiagnosticsBannerState
    extends State<_ReminderDiagnosticsBanner> {
  DateTime? _scheduledThrough;
  bool _inexactFallback = false;
  String? _lastError;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final through = await NotificationService.instance.scheduledThroughDate();
    final fallback = await NotificationService.instance.usedInexactAlarmFallback();
    final error = await NotificationService.instance.lastScheduleError();
    if (!mounted) return;
    setState(() {
      _scheduledThrough = through;
      _inexactFallback = fallback;
      _lastError = error;
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();

    final staleReminders = _scheduledThrough == null ||
        _scheduledThrough!.isBefore(DateTime.now().add(const Duration(days: 2)));
    final clockSuspect = TrustedClock.instance.isSynced &&
        !TrustedClock.instance.isStale &&
        TrustedClock.instance.deviceClockSuspect;

    final notices = <String>[
      if (_lastError != null)
        'Reminders failed to schedule last time — reopen the app to retry. ($_lastError)',
      if (staleReminders && _lastError == null)
        'Reminders are only scheduled a little way ahead — open Drop Tracker every so often to keep them current.',
      if (clockSuspect)
        "Your device clock looks off — reminder times may be shifted until it's corrected.",
      if (_inexactFallback && Platform.isAndroid)
        'Exact alarms are off for this app, so reminder timing may drift by a few minutes. Allow exact alarms in system settings for precise timing.',
    ];
    if (notices.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: BrandColors.warningBg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final n in notices)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 1),
                      child: Icon(Icons.info_outline_rounded,
                          size: 16, color: BrandColors.warningText),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(n,
                          style: AppTypography.body(12.5,
                              weight: FontWeight.w600,
                              color: BrandColors.warningText)),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A small, quiet indicator that some changes are queued for background sync
/// (see SyncOutbox) — reassurance that nothing was lost while offline, not an
/// error state. Clears itself the next time DropStore rebuilds after a
/// successful flush.
class _SyncPendingBanner extends StatelessWidget {
  final int count;
  const _SyncPendingBanner({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: BrandColors.warningBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_sync_outlined, size: 18, color: BrandColors.warningText),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              count == 1
                  ? '1 change waiting to sync'
                  : '$count changes waiting to sync',
              style: AppTypography.body(13, weight: FontWeight.w600, color: BrandColors.warningText),
            ),
          ),
        ],
      ),
    );
  }
}
