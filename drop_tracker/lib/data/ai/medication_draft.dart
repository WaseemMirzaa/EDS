import '../../models/drug_catalog_entry.dart';
import '../../models/enums.dart';
import '../../models/instructions.dart';
import '../../models/medication.dart';
import '../../models/scan.dart';
import '../dose_logic.dart';
import 'drug_matcher.dart';
import 'ocr_service.dart';

/// One proposed field on a draft, carrying where it came from and how sure the
/// pipeline is. The review screen renders these directly: a low-confidence
/// field is highlighted for attention, a missing one is left for the user.
class DraftField<T> {
  final T? value;
  final double confidence;
  final String? sourceText; // what was actually read off the label
  final Map<String, dynamic>? boundingBox;

  const DraftField({this.value, this.confidence = 0, this.sourceText, this.boundingBox});

  bool get hasValue => value != null;
  bool get needsAttention => !hasValue || confidence < DrugMatcher.confidentThreshold;

  static const DraftField<Never> empty = DraftField<Never>();
}

/// A medication proposed from a scan, staged for user confirmation.
///
/// This type is the reason the pipeline is safe: an [OcrResult] never becomes a
/// [Medication] directly. It becomes a draft, the user reviews it, and only
/// then is a dosing schedule created. Medication data is not something to infer
/// silently from a photograph.
class MedicationDraft {
  final String? scanId;
  final DrugCatalogEntry? matchedDrug;
  final MatchMethod? matchMethod;

  final DraftField<String> name;
  final DraftField<Eye> eye;
  final DraftField<FrequencyType> frequency;
  final DraftField<List<String>> doseTimes;
  final DraftField<Instructions> instructions;

  /// Mean confidence across the fields that were actually populated.
  final double overallConfidence;

  const MedicationDraft({
    this.scanId,
    this.matchedDrug,
    this.matchMethod,
    this.name = const DraftField<String>(),
    this.eye = const DraftField<Eye>(),
    this.frequency = const DraftField<FrequencyType>(),
    this.doseTimes = const DraftField<List<String>>(),
    this.instructions = const DraftField<Instructions>(),
    this.overallConfidence = 0,
  });

  /// Fields the user should look at before saving.
  List<String> get fieldsNeedingReview => [
        if (name.needsAttention) 'Medication name',
        if (eye.needsAttention) 'Which eye',
        if (frequency.needsAttention) 'Frequency',
        if (doseTimes.needsAttention) 'Dose times',
      ];

  bool get requiresReview => fieldsNeedingReview.isNotEmpty;

  /// Materialises the draft into a real [Medication] for the edit form.
  ///
  /// Anything the scan could not establish falls back to the same defaults a
  /// manually-added medication starts with, so the user is never handed a
  /// half-built form.
  Medication toMedication({
    required String wakingStart,
    required String wakingEnd,
  }) {
    final freq = frequency.value ?? FrequencyType.fourDaily;
    return Medication(
      id: '',
      name: name.value ?? '',
      bottleCapColor: matchedDrug?.defaultCapColor ?? 'white',
      eye: eye.value ?? Eye.both,
      frequencyType: freq,
      doseTimes: doseTimes.value ??
          DoseLogic.suggestTimes(freq, wakingStart: wakingStart, wakingEnd: wakingEnd),
      startDate: DoseLogic.todayStr(),
      ongoing: false,
      instructions: instructions.value ??
          matchedDrug?.typicalInstructions ??
          const Instructions(),
      category: matchedDrug?.category ?? Category.other,
    );
  }
}

/// Assembles a [MedicationDraft] from a raw [OcrResult].
///
/// Kept separate from both the OCR provider and the UI so the interpretation
/// rules — thresholds, catalog defaults, how a frequency string maps to a mode
/// — live in one testable place, independent of which model produced the text.
class MedicationDraftBuilder {
  final DrugMatcher matcher;
  const MedicationDraftBuilder(this.matcher);

  Future<MedicationDraft> build(OcrResult result, {String? scanId}) async {
    final nameField = result.field(ScanField.drugName);
    final rawName = nameField?.valueText?.trim() ?? '';

    DrugMatch? match;
    if (rawName.isNotEmpty) {
      match = await matcher.match(rawName);
    }

    // Prefer the catalog's canonical name once matched — a label reading
    // "PRED-FORTE 1% SUSP OP" should become "Pred Forte 1%".
    final resolvedName = match?.drug.displayName ?? (rawName.isEmpty ? null : rawName);
    final nameConfidence = match != null
        ? ((nameField?.confidence ?? 0) + match.score) / 2
        : (nameField?.confidence ?? 0);

    final eyeField = result.field(ScanField.eye);
    final freqField = result.field(ScanField.frequency);
    final timesField = result.field(ScanField.doseTimes);

    final parsedEye = _parseEye(eyeField?.valueText);
    final parsedFreq =
        _parseFrequency(freqField?.valueText) ?? match?.drug.typicalFrequency;

    final parsedTimes = (timesField?.valueJson?['times'] as List?)
        ?.map((e) => e.toString())
        .where(_looksLikeTime)
        .toList();

    final confidences = <double>[
      if (resolvedName != null) nameConfidence,
      if (parsedEye != null) eyeField?.confidence ?? 0,
      if (parsedFreq != null) freqField?.confidence ?? 0,
      if (parsedTimes != null && parsedTimes.isNotEmpty) timesField?.confidence ?? 0,
    ];
    final overall = confidences.isEmpty
        ? 0.0
        : confidences.reduce((a, b) => a + b) / confidences.length;

    return MedicationDraft(
      scanId: scanId,
      matchedDrug: match?.drug,
      matchMethod: match?.method,
      name: DraftField<String>(
        value: resolvedName,
        confidence: nameConfidence,
        sourceText: rawName.isEmpty ? null : rawName,
        boundingBox: nameField?.boundingBox,
      ),
      eye: DraftField<Eye>(
        value: parsedEye,
        confidence: parsedEye == null ? 0 : (eyeField?.confidence ?? 0),
        sourceText: eyeField?.valueText,
      ),
      frequency: DraftField<FrequencyType>(
        value: parsedFreq,
        confidence: parsedFreq == null ? 0 : (freqField?.confidence ?? 0),
        sourceText: freqField?.valueText,
      ),
      doseTimes: DraftField<List<String>>(
        value: (parsedTimes != null && parsedTimes.isNotEmpty) ? parsedTimes : null,
        confidence: timesField?.confidence ?? 0,
        sourceText: timesField?.valueText,
      ),
      instructions: DraftField<Instructions>(
        value: match?.drug.typicalInstructions,
        confidence: match?.score ?? 0,
      ),
      overallConfidence: overall,
    );
  }

  /// Label vocabulary for laterality, including the Latin abbreviations that
  /// still appear on dispensing labels (OD / OS / OU).
  static Eye? _parseEye(String? raw) {
    if (raw == null) return null;
    final s = raw.toLowerCase();
    if (s.contains('both') || s.contains('each') || RegExp(r'\bou\b').hasMatch(s)) {
      return Eye.both;
    }
    if (s.contains('right') || RegExp(r'\bod\b').hasMatch(s)) return Eye.right;
    if (s.contains('left') || RegExp(r'\bos\b').hasMatch(s)) return Eye.left;
    return null;
  }

  static FrequencyType? _parseFrequency(String? raw) {
    if (raw == null) return null;
    final s = raw.toLowerCase();

    if (RegExp(r'\b(qid|four times|4 times|4x)\b').hasMatch(s)) {
      return FrequencyType.fourDaily;
    }
    if (RegExp(r'\b(tid|three times|3 times|3x)\b').hasMatch(s)) {
      return FrequencyType.threeDaily;
    }
    if (RegExp(r'\b(bid|twice|two times|2x)\b').hasMatch(s)) {
      return FrequencyType.twiceDaily;
    }
    if (RegExp(r'\b(qd|once|one time|daily|1x)\b').hasMatch(s)) {
      return FrequencyType.onceDaily;
    }
    if (RegExp(r'every\s+\d+\s*(h|hour)').hasMatch(s)) {
      return FrequencyType.everyNHours;
    }
    return null;
  }

  static bool _looksLikeTime(String s) => RegExp(r'^\d{1,2}:\d{2}$').hasMatch(s);
}
