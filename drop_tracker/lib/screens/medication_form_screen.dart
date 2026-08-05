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

  // ---- helpers --------------------------------------------------------------

  void _onFreqChange(FrequencyType f) {
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
      frequencyValue: _freq == FrequencyType.everyNHours
          ? (int.tryParse(_everyN.text) ?? 4)
          : null,
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

  // ---- build ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Medication' : 'Add Medication'),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _label('Medication name'),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: _dec('e.g. Pred Forte'),
              style: AppTypography.body(16, weight: FontWeight.w600),
            ),
            const Gap(22),

            _label('Bottle cap colour'),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: kCapColors.keys.map((key) {
                return GestureDetector(
                  onTap: () => setState(() => _cap = key),
                  child: CapColorDot(colorKey: key, size: 40, selected: _cap == key),
                );
              }).toList(),
            ),
            const Gap(22),

            _label('Which eye?'),
            _segmented<Eye>(
              values: Eye.values,
              current: _eye,
              labelOf: (e) => e.label,
              onChange: (e) => setState(() => _eye = e),
            ),
            const Gap(22),

            _label('Frequency'),
            _freqGrid(),
            if (_freq == FrequencyType.everyNHours) ...[
              const Gap(10),
              Row(
                children: [
                  Text('Every', style: AppTypography.body(14, color: BrandColors.inkSoft)),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 72,
                    child: TextField(
                      controller: _everyN,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      textAlign: TextAlign.center,
                      decoration: _dec(''),
                      onChanged: (v) {
                        final n = int.tryParse(v) ?? 1;
                        setState(() => _times =
                            DoseLogic.timesForEveryNHours(n, wakingStart: _wStart, wakingEnd: _wEnd));
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text('hours', style: AppTypography.body(14, color: BrandColors.inkSoft)),
                ],
              ),
            ],
            const Gap(22),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _label('Dose times', bottom: 0),
                TextButton.icon(
                  onPressed: () => setState(() => _times.add('12:00')),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add time'),
                  style: TextButton.styleFrom(foregroundColor: BrandColors.ocean),
                ),
              ],
            ),
            const Gap(8),
            ..._times.asMap().entries.map((e) => _timeRow(e.key)),
            const Gap(14),

            _label('Start date'),
            _dateTile(_startDate, () => _pickDate(_startDate, (d) => setState(() => _startDate = d))),
            const Gap(14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _label('Ongoing (no end date)', bottom: 0),
                Switch(
                  value: _ongoing,
                  activeTrackColor: BrandColors.ocean,
                  onChanged: (v) => setState(() {
                    _ongoing = v;
                    if (!v && _endDate == null) {
                      _endDate = DoseLogic.dateToStr(
                          DoseLogic.strToDate(_startDate).add(const Duration(days: 7)));
                    }
                  }),
                ),
              ],
            ),
            if (!_ongoing) ...[
              const Gap(8),
              _label('End date'),
              _dateTile(_endDate ?? _startDate,
                  () => _pickDate(_endDate ?? _startDate, (d) => setState(() => _endDate = d))),
            ],
            const Gap(22),

            _label('Special instructions'),
            _instrTile('Shake bottle', _instr.shake, (v) => setState(() => _instr = _instr.copyWith(shake: v))),
            _instrTile('Refrigerate', _instr.refrigerate, (v) => setState(() => _instr = _instr.copyWith(refrigerate: v))),
            _instrTile('Wait 5 min before next drop', _instr.wait5min, (v) => setState(() => _instr = _instr.copyWith(wait5min: v))),
            _instrTile('Remove contact lenses', _instr.removeContacts, (v) => setState(() => _instr = _instr.copyWith(removeContacts: v))),
            _instrTile('Press tear duct after', _instr.pressTearDuct, (v) => setState(() => _instr = _instr.copyWith(pressTearDuct: v))),
            const Gap(10),
            TextField(
              controller: _notes,
              minLines: 2,
              maxLines: 4,
              decoration: _dec('Additional notes (e.g. "only in right eye")'),
              style: AppTypography.body(14),
            ),
            const Gap(22),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _label('Taper schedule (optional)', bottom: 0),
                TextButton.icon(
                  onPressed: _addTaperStep,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add step'),
                  style: TextButton.styleFrom(foregroundColor: BrandColors.ocean),
                ),
              ],
            ),
            if (_taper.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('For reducing doses over time (e.g. post-surgery steroids).',
                    style: AppTypography.body(12, color: BrandColors.inkFaint)),
              ),
            ..._taper.asMap().entries.map((e) => _taperCard(e.key)),
            const Gap(28),

            PrimaryButton(
              label: _isEdit ? 'Update Medication' : 'Save Medication',
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }

  // ---- taper ----------------------------------------------------------------

  void _addTaperStep() {
    setState(() {
      _taper.add(TaperStep(
        startDate: _startDate,
        frequencyType: FrequencyType.twiceDaily,
        doseTimes: DoseLogic.suggestTimes(FrequencyType.twiceDaily, wakingStart: _wStart, wakingEnd: _wEnd),
      ));
    });
  }

  Widget _taperCard(int idx) {
    final step = _taper[idx];
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: BrandColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BrandColors.hairlineCool, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Step ${idx + 1}',
                  style: AppTypography.body(12, weight: FontWeight.w700, color: BrandColors.inkFaint)),
              InkWell(
                onTap: () => setState(() => _taper.removeAt(idx)),
                child: const Icon(Icons.close_rounded, size: 18, color: BrandColors.inkFaint),
              ),
            ],
          ),
          const Gap(8),
          _dateTile(step.startDate,
              () => _pickDate(step.startDate, (d) => setState(() => _taper[idx] = step.copyWith(startDate: d)))),
          const Gap(8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: BrandColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: BrandColors.hairlineCool),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<FrequencyType>(
                isExpanded: true,
                value: step.frequencyType,
                items: FrequencyType.values
                    .map((f) => DropdownMenuItem(value: f, child: Text(f.label)))
                    .toList(),
                onChanged: (f) {
                  if (f == null) return;
                  setState(() {
                    var updated = step.copyWith(frequencyType: f);
                    if (f != FrequencyType.customTimes && f != FrequencyType.everyNHours) {
                      updated = updated.copyWith(
                          doseTimes: DoseLogic.suggestTimes(f, wakingStart: _wStart, wakingEnd: _wEnd));
                    }
                    _taper[idx] = updated;
                  });
                },
              ),
            ),
          ),
          const Gap(6),
          Text('Times: ${step.doseTimes.map(DoseLogic.formatTime).join(', ')}',
              style: AppTypography.body(12, color: BrandColors.inkFaint)),
        ],
      ),
    );
  }

  // ---- small building blocks ------------------------------------------------

  Widget _label(String text, {double bottom = 8}) => Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: Text(text, style: AppTypography.body(15, weight: FontWeight.w700, color: BrandColors.ink)),
      );

  Widget _timeRow(int idx) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => _pickTime(idx),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(
                  color: BrandColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: BrandColors.hairlineCool, width: 1.5),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.schedule_rounded, size: 18, color: BrandColors.inkFaint),
                    const SizedBox(width: 10),
                    Text(DoseLogic.formatTime(_times[idx]),
                        style: AppTypography.body(16, weight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ),
          if (_times.length > 1)
            IconButton(
              onPressed: () => setState(() => _times.removeAt(idx)),
              icon: const Icon(Icons.close_rounded, color: BrandColors.inkFaint),
            ),
        ],
      ),
    );
  }

  Widget _dateTile(String date, VoidCallback onTap) {
    final d = DoseLogic.strToDate(date);
    final label = '${DoseLogic.monthName(d.month - 1)} ${d.day}, ${d.year}';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: BrandColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: BrandColors.hairlineCool, width: 1.5),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_rounded, size: 16, color: BrandColors.inkFaint),
            const SizedBox(width: 10),
            Text(label, style: AppTypography.body(15, weight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _segmented<T>({
    required List<T> values,
    required T current,
    required String Function(T) labelOf,
    required ValueChanged<T> onChange,
  }) {
    return Row(
      children: [
        for (final v in values) ...[
          Expanded(
            child: GestureDetector(
              onTap: () => onChange(v),
              child: Container(
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: v == current ? BrandColors.ocean : BrandColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: v == current ? BrandColors.ocean : BrandColors.hairlineCool,
                    width: 1.5,
                  ),
                ),
                child: Text(labelOf(v),
                    style: AppTypography.body(13,
                        weight: FontWeight.w600,
                        color: v == current ? Colors.white : BrandColors.inkSoft)),
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
      childAspectRatio: 3.0,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: FrequencyType.values.map((f) {
        final sel = _freq == f;
        return GestureDetector(
          onTap: () => _onFreqChange(f),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: sel ? BrandColors.ocean : BrandColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: sel ? BrandColors.ocean : BrandColors.hairlineCool,
                width: 1.5,
              ),
            ),
            child: Text(f.label,
                style: AppTypography.body(14,
                    weight: FontWeight.w600,
                    color: sel ? Colors.white : BrandColors.inkSoft)),
          ),
        );
      }).toList(),
    );
  }

  Widget _instrTile(String label, bool value, ValueChanged<bool> onChange) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => onChange(!value),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: value ? BrandColors.cloud : BrandColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: value ? BrandColors.waves.withValues(alpha: 0.4) : BrandColors.hairlineCool,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: value ? BrandColors.ocean : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: value ? BrandColors.ocean : BrandColors.inkFaint,
                    width: 1.8,
                  ),
                ),
                child: value ? const Icon(Icons.check, size: 15, color: Colors.white) : null,
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(label, style: AppTypography.body(14, weight: FontWeight.w500))),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: BrandColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: BrandColors.hairlineCool, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: BrandColors.ocean, width: 1.8),
        ),
      );
}
