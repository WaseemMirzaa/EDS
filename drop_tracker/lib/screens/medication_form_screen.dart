import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/dose_logic.dart';
import '../data/drop_store.dart';
import '../models/enums.dart';
import '../models/instructions.dart';
import '../models/medication.dart';
import '../models/taper_step.dart';
import '../theme/app_theme.dart';
import '../theme/brand.dart';
import '../widgets/cap_color_dot.dart';
import '../widgets/common.dart';
import '../widgets/motion.dart';

class MedicationFormScreen extends StatefulWidget {
  final Medication? existing;
  const MedicationFormScreen({super.key, this.existing});

  @override
  State<MedicationFormScreen> createState() => _MedicationFormScreenState();
}

class _MedicationFormScreenState extends State<MedicationFormScreen> {
  late TextEditingController _name;
  late TextEditingController _notes;
  late TextEditingController _everyN;

  String _cap = 'white';
  Eye _eye = Eye.both;
  FrequencyType _freq = FrequencyType.fourDaily;
  List<String> _times = ['07:00', '11:00', '15:00', '19:00'];
  String _startDate = DoseLogic.todayStr();
  String? _endDate;
  bool _ongoing = false;
  Instructions _instr = const Instructions();
  List<TaperStep> _taper = [];

  bool get _isEdit => widget.existing != null;
  String get _wStart => context.read<DropStore>().user.wakingStart;
  String get _wEnd => context.read<DropStore>().user.wakingEnd;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _notes = TextEditingController(text: e?.instructions.notes ?? '');
    _everyN = TextEditingController(text: (e?.frequencyValue ?? 4).toString());
    if (e != null) {
      _cap = e.bottleCapColor;
      _eye = e.eye;
      _freq = e.frequencyType;
      _times = List.of(e.doseTimes.isNotEmpty ? e.doseTimes : ['07:00']);
      _startDate = e.startDate ?? DoseLogic.todayStr();
      _endDate = e.endDate;
      _ongoing = e.ongoing;
      _instr = e.instructions;
      _taper = List.of(e.taperSteps);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    _everyN.dispose();
    super.dispose();
  }

  // ---- logic ----------------------------------------------------------------

  void _onFreqChange(FrequencyType f) {
    HapticFeedback.selectionClick();
    setState(() {
      _freq = f;
      if (f == FrequencyType.everyNHours) {
        final n = int.tryParse(_everyN.text) ?? 4;
        _times = DoseLogic.timesForEveryNHours(n, wakingStart: _wStart, wakingEnd: _wEnd);
      } else if (f != FrequencyType.customTimes) {
        _times = DoseLogic.suggestTimes(f, wakingStart: _wStart, wakingEnd: _wEnd);
      }
    });
  }

  Future<void> _pickTime(int idx) async {
    final parts = _times[idx].split(':').map(int.parse).toList();
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: parts[0], minute: parts[1]),
    );
    if (picked != null) {
      setState(() => _times[idx] =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}');
    }
  }

  Future<void> _pickDate(String current, ValueChanged<String> onPick) async {
    final init = DoseLogic.strToDate(current);
    final picked = await showDatePicker(
      context: context,
      initialDate: init,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) onPick(DoseLogic.dateToStr(picked));
  }

  void _save() {
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a medication name.')),
      );
      return;
    }
    final store = context.read<DropStore>();
    final med = Medication(
      id: widget.existing?.id ?? '',
      name: _name.text.trim(),
      bottleCapColor: _cap,
      eye: _eye,
      frequencyType: _freq,
      frequencyValue: _freq == FrequencyType.everyNHours ? (int.tryParse(_everyN.text) ?? 4) : null,
      doseTimes: _times,
      startDate: _startDate,
      endDate: _ongoing ? null : _endDate,
      ongoing: _ongoing,
      instructions: _instr.copyWith(notes: _notes.text),
      taperSteps: _taper,
      category: widget.existing?.category ?? Category.other,
    );
    if (_isEdit) {
      store.updateMedication(med.id, med);
    } else {
      store.addMedication(med);
    }
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_isEdit ? 'Medication updated' : 'Medication added')),
    );
  }

  void _addTaperStep() {
    setState(() {
      _taper.add(TaperStep(
        startDate: _startDate,
        frequencyType: FrequencyType.twiceDaily,
        doseTimes: DoseLogic.suggestTimes(FrequencyType.twiceDaily, wakingStart: _wStart, wakingEnd: _wEnd),
      ));
    });
  }

  // ---- build ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit Medication' : 'Add Medication')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            // ---- Details ----
            _sectionCard('Medication', [
              _fieldLabel('Name'),
              AppField(controller: _name, hint: 'e.g. Pred Forte', capitalization: TextCapitalization.words),
              const Gap(18),
              _fieldLabel('Bottle cap colour'),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: kCapColors.keys.map((key) {
                  return Pressable(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _cap = key);
                    },
                    child: CapColorDot(colorKey: key, size: 40, selected: _cap == key),
                  );
                }).toList(),
              ),
              const Gap(18),
              _fieldLabel('Which eye?'),
              _segmented<Eye>(Eye.values, _eye, (e) => e.label, (e) => setState(() => _eye = e)),
            ]),
            const Gap(16),

            // ---- Schedule ----
            _sectionCard('Schedule', [
              _fieldLabel('Frequency'),
              _freqGrid(),
              if (_freq == FrequencyType.everyNHours) ...[
                const Gap(12),
                Row(
                  children: [
                    Text('Every', style: AppTypography.body(15, color: BrandColors.inkSoft)),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 76,
                      child: AppField(
                        controller: _everyN,
                        keyboardType: TextInputType.number,
                        formatters: [FilteringTextInputFormatter.digitsOnly],
                        textAlign: TextAlign.center,
                        onChanged: (v) {
                          final n = int.tryParse(v) ?? 1;
                          setState(() => _times = DoseLogic.timesForEveryNHours(n, wakingStart: _wStart, wakingEnd: _wEnd));
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text('hours', style: AppTypography.body(15, color: BrandColors.inkSoft)),
                  ],
                ),
              ],
              const Gap(18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _fieldLabel('Dose times', bottom: 0),
                  _addChip('Add time', () => setState(() => _times.add('12:00'))),
                ],
              ),
              const Gap(10),
              ..._times.asMap().entries.map((e) => _timeRow(e.key)),
              const Gap(6),
              _fieldLabel('Start date'),
              _dateTile(_startDate, () => _pickDate(_startDate, (d) => setState(() => _startDate = d))),
              const Gap(14),
              _switchRow('Ongoing (no end date)', _ongoing, (v) => setState(() {
                    _ongoing = v;
                    if (!v && _endDate == null) {
                      _endDate = DoseLogic.dateToStr(DoseLogic.strToDate(_startDate).add(const Duration(days: 7)));
                    }
                  })),
              if (!_ongoing) ...[
                const Gap(12),
                _fieldLabel('End date'),
                _dateTile(_endDate ?? _startDate, () => _pickDate(_endDate ?? _startDate, (d) => setState(() => _endDate = d))),
              ],
            ]),
            const Gap(16),

            // ---- Instructions ----
            _sectionCard('Instructions', [
              _instrTile('Shake bottle', Icons.vibration_rounded, _instr.shake, (v) => setState(() => _instr = _instr.copyWith(shake: v))),
              _instrTile('Refrigerate', Icons.ac_unit_rounded, _instr.refrigerate, (v) => setState(() => _instr = _instr.copyWith(refrigerate: v))),
              _instrTile('Wait 5 min before next drop', Icons.hourglass_bottom_rounded, _instr.wait5min, (v) => setState(() => _instr = _instr.copyWith(wait5min: v))),
              _instrTile('Remove contact lenses', Icons.remove_red_eye_outlined, _instr.removeContacts, (v) => setState(() => _instr = _instr.copyWith(removeContacts: v))),
              _instrTile('Press tear duct after', Icons.touch_app_outlined, _instr.pressTearDuct, (v) => setState(() => _instr = _instr.copyWith(pressTearDuct: v)), last: true),
              const Gap(12),
              _fieldLabel('Additional notes'),
              AppField(controller: _notes, hint: 'e.g. "only in right eye"', minLines: 2, maxLines: 4),
            ]),
            const Gap(16),

            // ---- Taper ----
            _sectionCard('Taper schedule', [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text('Optional — reduce doses over time (e.g. post-surgery steroids).',
                        style: AppTypography.body(13, color: BrandColors.inkSoft, height: 1.4)),
                  ),
                  const SizedBox(width: 10),
                  _addChip('Add step', _addTaperStep),
                ],
              ),
              ..._taper.asMap().entries.map((e) => _taperCard(e.key)),
            ]),
            const Gap(26),

            PrimaryButton(
              label: _isEdit ? 'Update Medication' : 'Save Medication',
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }

  // ---- section helpers ------------------------------------------------------

  Widget _sectionCard(String title, List<Widget> children) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.display(18, weight: FontWeight.w700)),
          const Gap(14),
          ...children,
        ],
      ),
    );
  }

  Widget _fieldLabel(String text, {double bottom = 8}) => Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: Text(text, style: AppTypography.body(13.5, weight: FontWeight.w600, color: BrandColors.inkSoft)),
      );

  Widget _addChip(String label, VoidCallback onTap) {
    return Pressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(color: BrandColors.primary.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(999)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add_rounded, size: 16, color: BrandColors.primary),
            const SizedBox(width: 4),
            Text(label, style: AppTypography.body(13, weight: FontWeight.w700, color: BrandColors.primary)),
          ],
        ),
      ),
    );
  }

  Widget _timeRow(int idx) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Pressable(
              onTap: () => _pickTime(idx),
              borderRadius: BorderRadius.circular(AppRadius.chip),
              child: Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(
                  color: BrandColors.fill,
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                  border: Border.all(color: BrandColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.schedule_rounded, size: 18, color: BrandColors.secondary),
                    const SizedBox(width: 10),
                    Text(DoseLogic.formatTime(_times[idx]),
                        style: AppTypography.body(16, weight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ),
          if (_times.length > 1)
            Pressable(
              onTap: () => setState(() => _times.removeAt(idx)),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                margin: const EdgeInsets.only(left: 8),
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: BrandColors.dangerBg, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.close_rounded, color: BrandColors.danger, size: 20),
              ),
            ),
        ],
      ),
    );
  }

  Widget _dateTile(String date, VoidCallback onTap) {
    final d = DoseLogic.strToDate(date);
    final label = '${DoseLogic.monthName(d.month - 1)} ${d.day}, ${d.year}';
    return Pressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.chip),
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: BrandColors.fill,
          borderRadius: BorderRadius.circular(AppRadius.chip),
          border: Border.all(color: BrandColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_rounded, size: 16, color: BrandColors.secondary),
            const SizedBox(width: 10),
            Text(label, style: AppTypography.body(15, weight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _switchRow(String label, bool value, ValueChanged<bool> onChange) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(child: Text(label, style: AppTypography.body(15, weight: FontWeight.w600))),
        Switch.adaptive(
          value: value,
          activeTrackColor: BrandColors.primary,
          onChanged: (v) {
            HapticFeedback.selectionClick();
            onChange(v);
          },
        ),
      ],
    );
  }

  Widget _segmented<T>(List<T> values, T current, String Function(T) labelOf, ValueChanged<T> onChange) {
    return Row(
      children: [
        for (final v in values) ...[
          Expanded(
            child: Pressable(
              onTap: () {
                HapticFeedback.selectionClick();
                onChange(v);
              },
              borderRadius: BorderRadius.circular(AppRadius.chip),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: v == current ? BrandColors.primary : BrandColors.fill,
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                  border: Border.all(color: v == current ? BrandColors.primary : BrandColors.border),
                ),
                child: Text(labelOf(v),
                    style: AppTypography.body(13.5,
                        weight: FontWeight.w600, color: v == current ? Colors.white : BrandColors.inkSoft)),
              ),
            ),
          ),
          if (v != values.last) const SizedBox(width: 8),
        ],
      ],
    );
  }

  Widget _freqGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 3.1,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: FrequencyType.values.map((f) {
        final sel = _freq == f;
        return Pressable(
          onTap: () => _onFreqChange(f),
          borderRadius: BorderRadius.circular(AppRadius.chip),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: sel ? BrandColors.primary : BrandColors.fill,
              borderRadius: BorderRadius.circular(AppRadius.chip),
              border: Border.all(color: sel ? BrandColors.primary : BrandColors.border),
            ),
            child: Text(f.label,
                style: AppTypography.body(14, weight: FontWeight.w600, color: sel ? Colors.white : BrandColors.inkSoft)),
          ),
        );
      }).toList(),
    );
  }

  Widget _instrTile(String label, IconData icon, bool value, ValueChanged<bool> onChange, {bool last = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 8),
      child: Pressable(
        onTap: () {
          HapticFeedback.selectionClick();
          onChange(!value);
        },
        borderRadius: BorderRadius.circular(AppRadius.chip),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: value ? BrandColors.cloud : BrandColors.fill,
            borderRadius: BorderRadius.circular(AppRadius.chip),
            border: Border.all(color: value ? BrandColors.secondary.withValues(alpha: 0.35) : BrandColors.border),
          ),
          child: Row(
            children: [
              Icon(icon, size: 19, color: value ? BrandColors.primary : BrandColors.inkFaint),
              const SizedBox(width: 12),
              Expanded(child: Text(label, style: AppTypography.body(14.5, weight: FontWeight.w600))),
              _check(value),
            ],
          ),
        ),
      ),
    );
  }

  Widget _check(bool value) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: value ? BrandColors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: value ? BrandColors.primary : BrandColors.inkFaint, width: 1.8),
      ),
      child: value ? const Icon(Icons.check_rounded, size: 16, color: Colors.white) : null,
    );
  }

  Widget _taperCard(int idx) {
    final step = _taper[idx];
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: BrandColors.fill,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(color: BrandColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Step ${idx + 1}',
                  style: AppTypography.body(12.5, weight: FontWeight.w700, color: BrandColors.secondary)),
              Pressable(
                onTap: () => setState(() => _taper.removeAt(idx)),
                child: const Icon(Icons.close_rounded, size: 18, color: BrandColors.inkFaint),
              ),
            ],
          ),
          const Gap(10),
          _dateTile(step.startDate, () => _pickDate(step.startDate, (d) => setState(() => _taper[idx] = step.copyWith(startDate: d)))),
          const Gap(8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: BrandColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.chip),
              border: Border.all(color: BrandColors.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<FrequencyType>(
                isExpanded: true,
                value: step.frequencyType,
                borderRadius: BorderRadius.circular(16),
                items: FrequencyType.values.map((f) => DropdownMenuItem(value: f, child: Text(f.label))).toList(),
                onChanged: (f) {
                  if (f == null) return;
                  setState(() {
                    var updated = step.copyWith(frequencyType: f);
                    if (f != FrequencyType.customTimes && f != FrequencyType.everyNHours) {
                      updated = updated.copyWith(doseTimes: DoseLogic.suggestTimes(f, wakingStart: _wStart, wakingEnd: _wEnd));
                    }
                    _taper[idx] = updated;
                  });
                },
              ),
            ),
          ),
          const Gap(8),
          Text('Times: ${step.doseTimes.map(DoseLogic.formatTime).join(', ')}',
              style: AppTypography.body(12.5, color: BrandColors.inkFaint)),
        ],
      ),
    );
  }
}
