import 'package:flutter_test/flutter_test.dart';

import 'package:drop_tracker/data/ai/drug_catalog_seed.dart';
import 'package:drop_tracker/data/ai/drug_matcher.dart';
import 'package:drop_tracker/data/ai/medication_draft.dart';
import 'package:drop_tracker/data/ai/ocr_service.dart';
import 'package:drop_tracker/models/enums.dart';
import 'package:drop_tracker/models/scan.dart';

/// Builds an OcrResult the way a provider would return one, so the draft
/// builder is exercised end-to-end without a real model.
OcrResult _result({
  String? drugName,
  String? eye,
  String? frequency,
  List<String>? times,
  double confidence = 0.95,
}) {
  return OcrResult(
    provider: 'test',
    modelName: 'fixture',
    overallConfidence: confidence,
    fields: [
      if (drugName != null)
        OcrField(fieldKey: ScanField.drugName, valueText: drugName, confidence: confidence),
      if (eye != null)
        OcrField(fieldKey: ScanField.eye, valueText: eye, confidence: confidence),
      if (frequency != null)
        OcrField(fieldKey: ScanField.frequency, valueText: frequency, confidence: confidence),
      if (times != null)
        OcrField(
          fieldKey: ScanField.doseTimes,
          valueJson: {'times': times},
          confidence: confidence,
        ),
    ],
  );
}

void main() {
  const matcher = LocalDrugMatcher(kDrugCatalogSeed);
  const builder = MedicationDraftBuilder(matcher);

  group('drug matching', () {
    test('exact brand name resolves with full confidence', () async {
      final m = await matcher.match('Pred Forte');
      expect(m, isNotNull);
      expect(m!.drug.id, 'seed-pred-forte');
      expect(m.method, MatchMethod.exact);
      expect(m.score, 1.0);
    });

    test('generic name resolves via alias', () async {
      final m = await matcher.match('latanoprost');
      expect(m!.drug.id, 'seed-xalatan');
      expect(m.method, MatchMethod.alias);
    });

    test('label noise around the name still matches', () async {
      // Real labels carry strength, form and route alongside the name.
      final m = await matcher.match('PRED-FORTE 1% SUSP OP');
      expect(m, isNotNull);
      expect(m!.drug.id, 'seed-pred-forte');
      expect(m.score, greaterThan(DrugMatcher.reviewThreshold));
    });

    test('common OCR mis-read is recovered', () async {
      // 'rn' misread as 'm' is the classic small-label failure.
      final m = await matcher.match('Vigarnox');
      expect(m!.drug.id, 'seed-vigamox');
    });

    test('unknown text does not force a match', () async {
      final m = await matcher.match('zzzz not a real drug qqqq');
      expect(m, isNull);
    });

    test('candidates come back ranked', () async {
      final list = await matcher.candidates('tears', limit: 5);
      expect(list, isNotEmpty);
      for (var i = 1; i < list.length; i++) {
        expect(list[i - 1].score, greaterThanOrEqualTo(list[i].score));
      }
    });
  });

  group('draft building', () {
    test('a clean label produces a confident, ready draft', () async {
      final draft = await builder.build(_result(
        drugName: 'Pred Forte',
        eye: 'both eyes',
        frequency: 'QID',
        times: ['07:00', '11:00', '15:00', '19:00'],
      ));

      expect(draft.name.value, 'Pred Forte 1%'); // canonicalised from the catalog
      expect(draft.eye.value, Eye.both);
      expect(draft.frequency.value, FrequencyType.fourDaily);
      expect(draft.doseTimes.value, hasLength(4));
      expect(draft.matchedDrug?.id, 'seed-pred-forte');
      expect(draft.requiresReview, isFalse);
    });

    test('Latin laterality abbreviations are understood', () async {
      expect((await builder.build(_result(drugName: 'Systane', eye: 'OD'))).eye.value,
          Eye.right);
      expect((await builder.build(_result(drugName: 'Systane', eye: 'OS'))).eye.value,
          Eye.left);
      expect((await builder.build(_result(drugName: 'Systane', eye: 'OU'))).eye.value,
          Eye.both);
    });

    test('frequency shorthand maps to the app modes', () async {
      Future<FrequencyType?> freq(String s) async =>
          (await builder.build(_result(drugName: 'Systane', frequency: s))).frequency.value;

      expect(await freq('QID'), FrequencyType.fourDaily);
      expect(await freq('TID'), FrequencyType.threeDaily);
      expect(await freq('BID'), FrequencyType.twiceDaily);
      expect(await freq('once daily'), FrequencyType.onceDaily);
      expect(await freq('every 4 hours'), FrequencyType.everyNHours);
    });

    test('missing fields are flagged for review, never invented', () async {
      final draft = await builder.build(_result(drugName: 'Vigamox'));

      expect(draft.eye.value, isNull);
      expect(draft.doseTimes.value, isNull);
      expect(draft.requiresReview, isTrue);
      expect(draft.fieldsNeedingReview, contains('Which eye'));
      expect(draft.fieldsNeedingReview, contains('Dose times'));
    });

    test('an unmatched name is kept verbatim rather than dropped', () async {
      final draft = await builder.build(_result(drugName: 'Compounded XYZ 3%'));
      expect(draft.matchedDrug, isNull);
      expect(draft.name.value, 'Compounded XYZ 3%');
    });

    test('draft materialises into a usable medication', () async {
      final draft = await builder.build(_result(
        drugName: 'Vigamox',
        eye: 'both',
        frequency: 'QID',
      ));
      final med = draft.toMedication(wakingStart: '07:00', wakingEnd: '21:00');

      expect(med.name, 'Vigamox 0.5%');
      expect(med.eye, Eye.both);
      expect(med.frequencyType, FrequencyType.fourDaily);
      expect(med.category, Category.antibiotic);
      expect(med.bottleCapColor, 'blue');          // catalog default applied
      expect(med.doseTimes, hasLength(4));         // filled from waking hours
      expect(med.instructions.wait5min, isTrue);   // catalog instructions applied
    });

    test('low-confidence extraction is surfaced as needing review', () async {
      final draft = await builder.build(_result(
        drugName: 'Pred Forte',
        eye: 'both',
        frequency: 'QID',
        times: ['07:00'],
        confidence: 0.42,
      ));
      expect(draft.overallConfidence, lessThan(DrugMatcher.confidentThreshold));
      expect(draft.requiresReview, isTrue);
    });
  });

  group('phase 1 default', () {
    test('OCR is unavailable until a provider is registered', () async {
      const service = UnavailableOcrService();
      expect(await service.isAvailable(), isFalse);
      expect(
        () => service.extract(storagePath: 'x'),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });
}
