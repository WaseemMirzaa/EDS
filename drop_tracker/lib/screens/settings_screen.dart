import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/drop_store.dart';
import '../data/ics_generator.dart';
import '../data/notification_service.dart';
import '../theme/app_theme.dart';
import '../theme/brand.dart';
import '../widgets/common.dart';
import '../widgets/disclaimer_banner.dart';
import '../widgets/drop_logo.dart';
import '../widgets/motion.dart';
import 'battery_optimization_screen.dart';

// Placeholder brand URLs — swap for the live legal pages before store submission.
const _privacyUrl = 'https://eyedropshop.ca/privacy';
const _termsUrl = 'https://eyedropshop.ca/terms';
const _accountDeletionUrl = 'https://eyedropshop.ca/account-deletion';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _name;
  TimeOfDay _wake = const TimeOfDay(hour: 7, minute: 0);
  TimeOfDay _bed = const TimeOfDay(hour: 21, minute: 0);
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final u = context.read<DropStore>().user;
    _name = TextEditingController(text: u.firstName);
    _wake = _parse(u.wakingStart);
    _bed = _parse(u.wakingEnd);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  TimeOfDay _parse(String hhmm) {
    final p = hhmm.split(':').map(int.parse).toList();
    return TimeOfDay(hour: p[0], minute: p[1]);
  }

  String _hhmm(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _save() async {
    setState(() => _saving = true);
    await context.read<DropStore>().updateUser(
          firstName: _name.text.trim(),
          wakingStart: _hhmm(_wake),
          wakingEnd: _hhmm(_bed),
        );
    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Settings saved')));
    }
  }

  Future<void> _open(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not open $url')));
      }
    }
  }

  Future<void> _confirmDeleteAccount() async {
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
    if (ok == true && mounted) {
      await context.read<DropStore>().deleteAllData();
      // Root gate returns to onboarding automatically.
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<DropStore>();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Text('Settings', style: AppTypography.display(28, weight: FontWeight.w600)),
            const Gap(16),

            // Profile
            _section('Your profile'),
            _label('Your name'),
            AppField(
              controller: _name,
              hint: 'Your first name',
              capitalization: TextCapitalization.words,
            ),
            const Gap(14),
            _label('Waking hours'),
            Row(
              children: [
                Expanded(child: _timeField(_wake, (t) => setState(() => _wake = t))),
                const Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('to')),
                Expanded(child: _timeField(_bed, (t) => setState(() => _bed = t))),
              ],
            ),
            const SizedBox(height: 6),
            Text('Used to auto-suggest evenly spaced dose times.',
                style: AppTypography.body(12, color: BrandColors.inkFaint)),
            const Gap(12),
            PrimaryButton(label: 'Save Settings', loading: _saving, onPressed: _save),
            const Gap(24),

            // Reminders
            _section('Reminders'),
            AppCard(
              child: Column(
                children: [
                  _tile(
                    icon: Icons.notifications_active_rounded,
                    title: 'Notification permissions',
                    subtitle: 'Allow Drop Tracker to remind you on time.',
                    onTap: () async {
                      final granted =
                          await NotificationService.instance.requestPermissions();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(granted
                                ? 'Notifications enabled.'
                                : 'Notifications are turned off in system settings.')));
                      }
                    },
                  ),
                  const Divider(height: 1),
                  _tile(
                    icon: Icons.battery_charging_full_rounded,
                    title: 'Keep reminders reliable',
                    subtitle: 'Battery-optimisation guidance for your device.',
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const BatteryOptimizationScreen())),
                  ),
                  const Divider(height: 1),
                  _tile(
                    icon: Icons.event_available_rounded,
                    title: 'Add all reminders to Calendar',
                    subtitle: 'Export a combined .ics file.',
                    onTap: () => IcsGenerator.share(
                      'drop-tracker-reminders.ics',
                      IcsGenerator.forAll(store.medications, store.user),
                    ),
                  ),
                ],
              ),
            ),
            const Gap(24),

            // Safety
            _section('Safety'),
            const DisclaimerBanner(),
            const Gap(24),

            // About & legal
            _section('About & legal'),
            AppCard(
              child: Column(
                children: [
                  _tile(
                    icon: Icons.privacy_tip_outlined,
                    title: 'Privacy Policy',
                    onTap: () => _open(_privacyUrl),
                    trailing: Icons.open_in_new_rounded,
                  ),
                  const Divider(height: 1),
                  _tile(
                    icon: Icons.article_outlined,
                    title: 'Terms of Service',
                    onTap: () => _open(_termsUrl),
                    trailing: Icons.open_in_new_rounded,
                  ),
                ],
              ),
            ),
            const Gap(24),

            // Account
            _section('Account'),
            AppCard(
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
                    onTap: _confirmDeleteAccount,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'On Android you can also request deletion via our web portal.',
              style: AppTypography.body(12, color: BrandColors.inkFaint),
            ),
            TextButton(
              onPressed: () => _open(_accountDeletionUrl),
              style: TextButton.styleFrom(
                  padding: EdgeInsets.zero, minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              child: Text('Open account-deletion portal',
                  style: AppTypography.body(12, weight: FontWeight.w700, color: BrandColors.waves)),
            ),
            const Gap(16),
            SecondaryButton(
              label: 'Log Out',
              icon: Icons.logout_rounded,
              color: BrandColors.danger,
              onPressed: () => context.read<DropStore>().logOut(),
            ),
            const Gap(24),

            Center(
              child: Opacity(
                opacity: 0.6,
                child: Column(
                  children: [
                    const DropWordmark(height: 20),
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

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(title.toUpperCase(),
            style: AppTypography.body(12, weight: FontWeight.w700, color: BrandColors.inkFaint)
                .copyWith(letterSpacing: 0.6)),
      );

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(t, style: AppTypography.body(14, weight: FontWeight.w600, color: BrandColors.inkSoft)),
      );

  Widget _timeField(TimeOfDay value, ValueChanged<TimeOfDay> onChange) {
    return InkWell(
      onTap: () async {
        final picked = await showTimePicker(context: context, initialTime: value);
        if (picked != null) onChange(picked);
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: BrandColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: BrandColors.hairlineCool, width: 1.5),
        ),
        child: Text(value.format(context),
            style: AppTypography.body(16, weight: FontWeight.w700)),
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
