import '../../models/scan.dart';

/// One value read from an image, before it has been reconciled with the drug
/// catalog or shown to the user.
class OcrField {
  final String fieldKey; // see ScanField
  final String? valueText;
  final Map<String, dynamic>? valueJson;
  final double confidence; // 0..1
  final Map<String, dynamic>? boundingBox;

  const OcrField({
    required this.fieldKey,
    this.valueText,
    this.valueJson,
    this.confidence = 0,
    this.boundingBox,
  });
}

/// The outcome of running one model against one image.
class OcrResult {
  final String provider;
  final String modelName;
  final String? modelVersion;
  final String? rawText;
  final List<OcrField> fields;
  final double overallConfidence;
  final int latencyMs;

  const OcrResult({
    required this.provider,
    required this.modelName,
    this.modelVersion,
    this.rawText,
    this.fields = const [],
    this.overallConfidence = 0,
    this.latencyMs = 0,
  });

  OcrField? field(String key) {
    for (final f in fields) {
      if (f.fieldKey == key) return f;
    }
    return null;
  }

  /// True when every field cleared the bar and the app may pre-fill a draft
  /// without flagging it. Even then the user still confirms before a schedule
  /// is created — this only controls how much the review screen highlights.
  bool get isHighConfidence =>
      overallConfidence >= 0.85 && fields.every((f) => f.confidence >= 0.7);
}

/// Reads structured medication data from a captured image.
///
/// Deliberately an interface with no provider baked in. The pipeline is
/// expected to change: an on-device pass (Apple Vision / ML Kit) is cheap,
/// private and offline, while a hosted document or vision model is far better
/// on a handwritten prescription. Both satisfy this contract, and
/// [scan_extractions] records which one produced a given result, so they can be
/// swapped or run side by side without touching the UI.
abstract class OcrService {
  /// Whether this implementation can run right now (permissions, connectivity,
  /// model availability).
  Future<bool> isAvailable();

  /// Runs recognition against an image already persisted at [storagePath].
  Future<OcrResult> extract({
    required String storagePath,
    ScanKind kind = ScanKind.bottleLabel,
  });
}

/// Phase 1 default: scanning is not wired up yet.
///
/// Registered so the capture surface can be built, gated and tested against a
/// real interface now, and a provider dropped in for Phase 2 without any
/// call-site changes.
class UnavailableOcrService implements OcrService {
  const UnavailableOcrService();

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<OcrResult> extract({
    required String storagePath,
    ScanKind kind = ScanKind.bottleLabel,
  }) async {
    throw UnsupportedError(
      'OCR scanning ships in Phase 2. Register a concrete OcrService '
      '(on-device or hosted) to enable it.',
    );
  }
}
