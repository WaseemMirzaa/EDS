/// Phase 2 capture models — the record of scanning a bottle label or
/// prescription, the model runs performed against it, and the field-level
/// results a user reviews before anything becomes a medication.
///
/// Mirrors `db/migrations/003_phase2_ai_ocr.sql`.
library;

/// What was photographed.
enum ScanKind {
  bottleLabel('bottle_label', 'Bottle label'),
  prescription('prescription', 'Prescription'),
  pharmacyPrintout('pharmacy_printout', 'Pharmacy printout'),
  box('box', 'Carton');

  const ScanKind(this.code, this.label);
  final String code;
  final String label;

  static ScanKind fromCode(String? c) =>
      ScanKind.values.firstWhere((e) => e.code == c, orElse: () => ScanKind.bottleLabel);
}

/// Lifecycle of a single capture.
enum ScanStatus {
  uploaded('uploaded'),
  processing('processing'),
  extracted('extracted'),
  needsReview('needs_review'),
  confirmed('confirmed'),
  failed('failed'),
  discarded('discarded');

  const ScanStatus(this.code);
  final String code;

  bool get isTerminal =>
      this == confirmed || this == discarded || this == failed;

  static ScanStatus fromCode(String? c) =>
      ScanStatus.values.firstWhere((e) => e.code == c, orElse: () => ScanStatus.uploaded);
}

/// How a drug name was resolved to a catalog entry, cheapest first.
enum MatchMethod {
  exact('exact'),
  alias('alias'),
  trigram('trigram'),
  vector('vector'),
  llm('llm'),
  manual('manual');

  const MatchMethod(this.code);
  final String code;

  static MatchMethod fromCode(String? c) =>
      MatchMethod.values.firstWhere((e) => e.code == c, orElse: () => MatchMethod.manual);
}

/// Field keys an extraction can produce. Kept as constants rather than an enum
/// so a new model returning an unrecognised key is stored rather than dropped.
class ScanField {
  ScanField._();
  static const drugName = 'drug_name';
  static const strength = 'strength';
  static const form = 'form';
  static const eye = 'eye';
  static const frequency = 'frequency';
  static const doseTimes = 'dose_times';
  static const instructions = 'instructions';
  static const startDate = 'start_date';
  static const endDate = 'end_date';
  static const prescriber = 'prescriber';
  static const rxNumber = 'rx_number';
  static const expiry = 'expiry';
}

/// A capture. The image itself lives in object storage; this holds the pointer.
class Scan {
  final String id;
  final String userId;
  final ScanKind kind;
  final ScanStatus status;

  final String storagePath;
  final String? thumbnailPath;
  final String? checksum;

  final DateTime? capturedAt;
  final String? errorCode;
  final String? errorMessage;

  /// Set once the source photo has been purged under the retention policy. The
  /// structured extraction is kept; the image — which may carry a name, an Rx
  /// number and a prescriber — is not retained indefinitely.
  final DateTime? redactedAt;

  final DateTime createdAt;

  const Scan({
    required this.id,
    required this.userId,
    required this.storagePath,
    this.kind = ScanKind.bottleLabel,
    this.status = ScanStatus.uploaded,
    this.thumbnailPath,
    this.checksum,
    this.capturedAt,
    this.errorCode,
    this.errorMessage,
    this.redactedAt,
    required this.createdAt,
  });

  bool get imageAvailable => redactedAt == null;

  Scan copyWith({ScanStatus? status, String? errorCode, String? errorMessage}) => Scan(
        id: id,
        userId: userId,
        storagePath: storagePath,
        kind: kind,
        status: status ?? this.status,
        thumbnailPath: thumbnailPath,
        checksum: checksum,
        capturedAt: capturedAt,
        errorCode: errorCode ?? this.errorCode,
        errorMessage: errorMessage ?? this.errorMessage,
        redactedAt: redactedAt,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'kind': kind.code,
        'status': status.code,
        'storage_path': storagePath,
        'thumbnail_path': thumbnailPath,
        'checksum': checksum,
        'captured_at': capturedAt?.toIso8601String(),
        'error_code': errorCode,
        'error_message': errorMessage,
        'redacted_at': redactedAt?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
      };

  factory Scan.fromJson(Map<String, dynamic> j) => Scan(
        id: j['id'] as String,
        userId: (j['user_id'] ?? '') as String,
        kind: ScanKind.fromCode(j['kind'] as String?),
        status: ScanStatus.fromCode(j['status'] as String?),
        storagePath: (j['storage_path'] ?? '') as String,
        thumbnailPath: j['thumbnail_path'] as String?,
        checksum: j['checksum'] as String?,
        capturedAt: DateTime.tryParse((j['captured_at'] ?? '') as String),
        errorCode: j['error_code'] as String?,
        errorMessage: j['error_message'] as String?,
        redactedAt: DateTime.tryParse((j['redacted_at'] ?? '') as String),
        createdAt:
            DateTime.tryParse((j['created_at'] ?? '') as String) ?? DateTime.now(),
      );
}

/// One model run against a scan. Runs are appended, never overwritten, so a
/// newer model can be compared against the one that shipped.
class ScanExtraction {
  final String id;
  final String scanId;
  final String provider; // apple_vision | ml_kit | google_docai | openai | anthropic
  final String modelName;
  final String? modelVersion;
  final bool isPrimary;
  final String? rawText;
  final double? overallConfidence;
  final int? latencyMs;
  final List<ExtractedField> fields;
  final DateTime createdAt;

  const ScanExtraction({
    required this.id,
    required this.scanId,
    required this.provider,
    required this.modelName,
    this.modelVersion,
    this.isPrimary = false,
    this.rawText,
    this.overallConfidence,
    this.latencyMs,
    this.fields = const [],
    required this.createdAt,
  });

  ExtractedField? field(String key) {
    for (final f in fields) {
      if (f.fieldKey == key) return f;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'scan_id': scanId,
        'provider': provider,
        'model_name': modelName,
        'model_version': modelVersion,
        'is_primary': isPrimary,
        'raw_text': rawText,
        'overall_confidence': overallConfidence,
        'latency_ms': latencyMs,
        'created_at': createdAt.toIso8601String(),
      };
}

/// A single value the model claims to have read, with where it came from, how
/// sure it is, and — once reviewed — what the user changed it to.
///
/// The [valueText] / [correctedValueText] pairing is the evaluation set for the
/// next model: every correction is a labelled example of a mistake.
class ExtractedField {
  final String id;
  final String extractionId;
  final String scanId;
  final String fieldKey;
  final String? valueText;
  final Map<String, dynamic>? valueJson;
  final double? confidence;

  /// Where on the image this was read from, so the review UI can highlight it.
  final Map<String, dynamic>? boundingBox;

  // Drug resolution (fieldKey == ScanField.drugName)
  final String? candidateDrugId;
  final MatchMethod? matchMethod;
  final double? matchScore;

  /// null until the user has reviewed this field.
  final bool? accepted;
  final String? correctedValueText;

  const ExtractedField({
    required this.id,
    required this.extractionId,
    required this.scanId,
    required this.fieldKey,
    this.valueText,
    this.valueJson,
    this.confidence,
    this.boundingBox,
    this.candidateDrugId,
    this.matchMethod,
    this.matchScore,
    this.accepted,
    this.correctedValueText,
  });

  bool get isReviewed => accepted != null;
  bool get wasCorrected => correctedValueText != null;

  /// The value that should actually be used — the human's, when there is one.
  String? get effectiveValue => correctedValueText ?? valueText;

  Map<String, dynamic> toJson() => {
        'id': id,
        'extraction_id': extractionId,
        'scan_id': scanId,
        'field_key': fieldKey,
        'value_text': valueText,
        'value_json': valueJson,
        'confidence': confidence,
        'bounding_box': boundingBox,
        'candidate_drug_id': candidateDrugId,
        'match_method': matchMethod?.code,
        'match_score': matchScore,
        'accepted': accepted,
        'corrected_value_text': correctedValueText,
      };

  factory ExtractedField.fromJson(Map<String, dynamic> j) => ExtractedField(
        id: j['id'] as String,
        extractionId: (j['extraction_id'] ?? '') as String,
        scanId: (j['scan_id'] ?? '') as String,
        fieldKey: (j['field_key'] ?? '') as String,
        valueText: j['value_text'] as String?,
        valueJson: j['value_json'] as Map<String, dynamic>?,
        confidence: (j['confidence'] as num?)?.toDouble(),
        boundingBox: j['bounding_box'] as Map<String, dynamic>?,
        candidateDrugId: j['candidate_drug_id'] as String?,
        matchMethod: j['match_method'] == null
            ? null
            : MatchMethod.fromCode(j['match_method'] as String?),
        matchScore: (j['match_score'] as num?)?.toDouble(),
        accepted: j['accepted'] as bool?,
        correctedValueText: j['corrected_value_text'] as String?,
      );
}
