import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/auth_controller.dart';
import '../data/drop_store.dart';
import '../theme/app_theme.dart';
import '../theme/brand.dart';
import '../widgets/common.dart';

/// Profile & preferences — editable name and waking hours, saved here.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile saved')));
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final initial = (_name.text.isNotEmpty ? _name.text : (auth.email ?? 'U'))[0].toUpperCase();

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Center(
              child: Column(
                children: [
                  Container(
                    width: 84,
                    height: 84,
                    decoration: const BoxDecoration(color: BrandColors.cloud, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Text(initial, style: AppTypography.display(34, weight: FontWeight.w700, color: BrandColors.primary)),
                  ),
                  const Gap(12),
                  if (auth.email != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_providerIcon(auth), size: 15, color: BrandColors.inkFaint),
                        const SizedBox(width: 6),
                        Text(auth.email!, style: AppTypography.body(14, weight: FontWeight.w500, color: BrandColors.inkSoft)),
                      ],
                    ),
                ],
              ),
            ),
            const Gap(28),
            const SectionLabel('Personal'),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Your name', style: AppTypography.body(13.5, weight: FontWeight.w600, color: BrandColors.inkSoft)),
                  const Gap(7),
                  AppField(controller: _name, hint: 'Your first name', capitalization: TextCapitalization.words),
                ],
              ),
            ),
            const Gap(16),
            const SectionLabel('Waking hours'),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: _timeField('Wake up', _wake, (t) => setState(() => _wake = t))),
                      const SizedBox(width: 12),
                      Expanded(child: _timeField('Bed time', _bed, (t) => setState(() => _bed = t))),
                    ],
                  ),
                  const Gap(10),
                  Text('Used to auto-suggest evenly spaced dose times across the app.',
                      style: AppTypography.body(12.5, color: BrandColors.inkFaint, height: 1.4)),
                ],
              ),
            ),
            const Gap(28),
            PrimaryButton(label: 'Save', loading: _saving, onPressed: _save),
          ],
        ),
      ),
    );
  }

  IconData _providerIcon(AuthController auth) => switch (auth.provider) {
        AuthProvider.google => Icons.g_mobiledata_rounded,
        AuthProvider.apple => Icons.apple,
        AuthProvider.email => Icons.mail_outline_rounded,
      };

  Widget _timeField(String label, TimeOfDay value, ValueChanged<TimeOfDay> onChange) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.body(13.5, weight: FontWeight.w600, color: BrandColors.inkSoft)),
        const SizedBox(height: 7),
        InkWell(
          onTap: () async {
            final picked = await showTimePicker(context: context, initialTime: value);
            if (picked != null) onChange(picked);
          },
          borderRadius: BorderRadius.circular(AppRadius.input),
          child: Container(
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: BrandColors.fill,
              borderRadius: BorderRadius.circular(AppRadius.input),
            ),
            child: Text(value.format(context), style: AppTypography.body(16, weight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }
}
