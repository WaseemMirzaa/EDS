import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/drop_store.dart';
import '../data/notification_service.dart';
import '../data/presets.dart';
import '../theme/app_theme.dart';
import '../theme/brand.dart';
import '../widgets/brand_background.dart';
import '../widgets/common.dart';
import '../widgets/drop_logo.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _step = 0;
  bool _acknowledged = false;
  bool _applying = false;

  final _nameCtrl = TextEditingController();
  TimeOfDay _wake = const TimeOfDay(hour: 7, minute: 0);
  TimeOfDay _bed = const TimeOfDay(hour: 21, minute: 0);

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  String _hhmm(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _finish(Preset? preset) async {
    setState(() => _applying = true);
    final store = context.read<DropStore>();
    await store.updateUser(
      firstName: _nameCtrl.text.trim(),
      wakingStart: _hhmm(_wake),
      wakingEnd: _hhmm(_bed),
      onboarded: true,
      hasSeenDisclaimer: true,
    );
    if (preset != null) {
      await store.applyPreset(preset);
    }
    // Ask for reminder permission right as the app becomes useful.
    await NotificationService.instance.requestPermissions();
    // The root gate will now render the main shell automatically.
  }

  @override
  Widget build(BuildContext context) {
    // Step 0 uses the immersive branded background; the rest use the light UI.
    if (_step == 0) return _welcomeStep();
    return Scaffold(
      backgroundColor: BrandColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _dots(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: _step == 1 ? _personalizeStep() : _quickStartStep(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dots() {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(3, (i) {
          final active = i == _step;
          final done = i < _step;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            height: 8,
            width: active ? 28 : 8,
            decoration: BoxDecoration(
              color: active
                  ? BrandColors.ocean
                  : done
                      ? BrandColors.waves
                      : BrandColors.hairline,
              borderRadius: BorderRadius.circular(999),
            ),
          );
        }),
      ),
    );
  }

  // ---- Step 1: Welcome / Disclaimer ----------------------------------------

  Widget _welcomeStep() {
    return Scaffold(
      body: BrandBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 16),
                Row(children: List.generate(3, (i) {
                  final active = i == 0;
                  return Container(
                    margin: const EdgeInsets.only(right: 8),
                    height: 8,
                    width: active ? 28 : 8,
                    decoration: BoxDecoration(
                      color: active ? BrandColors.sunshine : Colors.white24,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  );
                })),
                const Spacer(),
                const DropBadge(
                  size: 96,
                  ringColor: Colors.white,
                  dropColor: BrandColors.sunshine,
                ),
                const SizedBox(height: 24),
                Text('Drop Tracker',
                    style: AppTypography.display(40, weight: FontWeight.w600, color: Colors.white)),
                const SizedBox(height: 10),
                Text(
                  'Never wonder "did I take my drop?" again. Track your eye-drop schedule with confidence.',
                  textAlign: TextAlign.center,
                  style: AppTypography.body(16, weight: FontWeight.w500, color: Colors.white70, height: 1.5),
                ),
                const SizedBox(height: 28),
                _disclaimerCard(),
                const Spacer(),
                PrimaryButton(
                  label: 'Get Started',
                  icon: Icons.arrow_forward_rounded,
                  color: BrandColors.sunshine,
                  foreground: BrandColors.ocean,
                  onPressed: _acknowledged ? () => setState(() => _step = 1) : null,
                ),
                const SizedBox(height: 20),
                Opacity(
                  opacity: 0.75,
                  child: DropWordmark(
                    height: 22,
                    textColor: Colors.white,
                    ringColor: Colors.white,
                    dropColor: BrandColors.sunshine,
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _disclaimerCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Drop Tracker is a reminder and tracking tool only. It is not a medical device and does not provide medical advice. Always follow your eye doctor\'s instructions.',
            style: AppTypography.body(13, weight: FontWeight.w500, color: Colors.white, height: 1.5),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () => setState(() => _acknowledged = !_acknowledged),
            borderRadius: BorderRadius.circular(10),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: _acknowledged ? BrandColors.sunshine : Colors.transparent,
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: Colors.white70, width: 2),
                  ),
                  child: _acknowledged
                      ? const Icon(Icons.check, size: 16, color: BrandColors.ocean)
                      : null,
                ),
                const SizedBox(width: 10),
                Text('I understand',
                    style: AppTypography.body(15, weight: FontWeight.w700, color: Colors.white)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---- Step 2: Personalize --------------------------------------------------

  Widget _personalizeStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Let\'s personalize', style: AppTypography.display(28, weight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text('This helps us suggest the right dose times for you.',
            style: AppTypography.body(15, weight: FontWeight.w500, color: BrandColors.inkSoft)),
        const SizedBox(height: 24),
        Text('Your first name', style: AppTypography.body(14, weight: FontWeight.w600, color: BrandColors.inkSoft)),
        const SizedBox(height: 6),
        TextField(
          controller: _nameCtrl,
          textCapitalization: TextCapitalization.words,
          decoration: _inputDecoration('e.g. Margaret'),
          style: AppTypography.body(17, weight: FontWeight.w600),
        ),
        const SizedBox(height: 20),
        Text('When do you usually wake up and go to bed?',
            style: AppTypography.body(14, weight: FontWeight.w600, color: BrandColors.inkSoft)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _timeField('Wake', _wake, (t) => setState(() => _wake = t))),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text('to'),
            ),
            Expanded(child: _timeField('Bed', _bed, (t) => setState(() => _bed = t))),
          ],
        ),
        const SizedBox(height: 32),
        Row(
          children: [
            SizedBox(
              height: 56,
              child: OutlinedButton(
                onPressed: () => setState(() => _step = 0),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: BrandColors.hairline, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                ),
                child: const Row(children: [Icon(Icons.arrow_back_rounded, size: 20), SizedBox(width: 4), Text('Back')]),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: PrimaryButton(
                label: 'Continue',
                icon: Icons.arrow_forward_rounded,
                onPressed: () => setState(() => _step = 2),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _timeField(String label, TimeOfDay value, ValueChanged<TimeOfDay> onChange) {
    return InkWell(
      onTap: () async {
        final picked = await showTimePicker(context: context, initialTime: value);
        if (picked != null) onChange(picked);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: BrandColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: BrandColors.hairlineCool, width: 1.5),
        ),
        child: Text(value.format(context),
            style: AppTypography.body(17, weight: FontWeight.w700)),
      ),
    );
  }

  // ---- Step 3: Quick Start --------------------------------------------------

  Widget _quickStartStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick start', style: AppTypography.display(28, weight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text('Just had cataract surgery? Start with a typical post-op regimen you can edit anytime.',
            style: AppTypography.body(15, weight: FontWeight.w500, color: BrandColors.inkSoft, height: 1.5)),
        const SizedBox(height: 20),
        ...kPresets.map((preset) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AppCard(
                onTap: _applying ? null : () => _finish(preset),
                borderColor: BrandColors.waves.withValues(alpha: 0.4),
                child: Row(
                  children: [
                    const DropBadge(size: 44),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(preset.label, style: AppTypography.body(17, weight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text(preset.description,
                              style: AppTypography.body(13, weight: FontWeight.w500, color: BrandColors.inkSoft, height: 1.4)),
                          const SizedBox(height: 6),
                          Pill('Includes ${preset.medicationCount} medications',
                              color: BrandColors.waves, bg: BrandColors.cloud),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )),
        AppCard(
          onTap: _applying ? null : () => _finish(null),
          color: BrandColors.background,
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: BrandColors.cloud,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.add_rounded, color: BrandColors.ocean),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('I\'ll add my own', style: AppTypography.body(17, weight: FontWeight.w700)),
                    Text('Skip the preset and add medications manually.',
                        style: AppTypography.body(13, weight: FontWeight.w500, color: BrandColors.inkSoft)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextButton.icon(
          onPressed: _applying ? null : () => setState(() => _step = 1),
          icon: const Icon(Icons.arrow_back_rounded, size: 20),
          label: const Text('Back'),
          style: TextButton.styleFrom(foregroundColor: BrandColors.inkSoft),
        ),
        if (_applying)
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Center(child: CircularProgressIndicator(color: BrandColors.ocean)),
          ),
      ],
    );
  }

  InputDecoration _inputDecoration(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: BrandColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: BrandColors.hairlineCool, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: BrandColors.ocean, width: 1.8),
        ),
      );
}
