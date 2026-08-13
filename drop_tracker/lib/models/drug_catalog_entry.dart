import 'enums.dart';
import 'instructions.dart';

/// A canonical drug in the reference catalog (`drug_catalog`).
///
/// This is what turns the free text on a bottle label into something the app
/// can reason about: once a scan resolves to a catalog entry, the medication
/// form can pre-fill category, cap colour, a typical frequency and the
/// instructions that usually apply (shake, refrigerate, and so on).
///
/// Phase 1 medications simply carry a null [Medication.drugId] and behave
/// exactly as they do today — the catalog is additive.
class DrugCatalogEntry {
  final String id;
  final String brandName;
  final String? genericName;
  final String? strength; // '1%', '0.5 mg/mL'
  final String? form; // solution | suspension | gel | ointment
  final String? din; // Canadian Drug Identification Number
  final String? ndc; // US National Drug Code
  final Category category;

  /// Defaults applied when this drug is recognised from a scan.
  final String? defaultCapColor;
  final FrequencyType? typicalFrequency;
  final Instructions typicalInstructions;
  final bool requiresTaper;

  /// Alternate spellings, generic names and the mis-reads OCR reliably
  /// produces. Matching walks these before consulting any model.
  final List<String> aliases;

  const DrugCatalogEntry({
    required this.id,
    required this.brandName,
    this.genericName,
    this.strength,
    this.form,
    this.din,
    this.ndc,
    this.category = Category.other,
    this.defaultCapColor,
    this.typicalFrequency,
    this.typicalInstructions = const Instructions(),
    this.requiresTaper = false,
    this.aliases = const [],
  });

  /// Label shown in pickers and on a matched draft.
  String get displayName =>
      strength == null || strength!.isEmpty ? brandName : '$brandName $strength';

  /// Case- and punctuation-insensitive form, mirroring the generated
  /// `drug_aliases.normalized` column so client and server agree on a match.
  static String normalize(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  /// Every string this drug can legitimately be matched against.
  Iterable<String> get matchableNames => [
        brandName,
        if (genericName != null && genericName!.isNotEmpty) genericName!,
        ...aliases,
      ];

  Map<String, dynamic> toJson() => {
        'id': id,
        'brand_name': brandName,
        'generic_name': genericName,
        'strength': strength,
        'form': form,
        'din': din,
        'ndc': ndc,
        'category': category.code,
        'default_cap_color': defaultCapColor,
        'typical_frequency': typicalFrequency?.code,
        'typical_instructions': typicalInstructions.toJson(),
        'requires_taper': requiresTaper,
        'aliases': aliases,
      };

  factory DrugCatalogEntry.fromJson(Map<String, dynamic> j) => DrugCatalogEntry(
        id: j['id'] as String,
        brandName: (j['brand_name'] ?? '') as String,
        genericName: j['generic_name'] as String?,
        strength: j['strength'] as String?,
        form: j['form'] as String?,
        din: j['din'] as String?,
        ndc: j['ndc'] as String?,
        category: Category.fromCode(j['category'] as String?),
        defaultCapColor: j['default_cap_color'] as String?,
        typicalFrequency: j['typical_frequency'] == null
            ? null
            : FrequencyType.fromCode(j['typical_frequency'] as String?),
        typicalInstructions:
            Instructions.fromJson(j['typical_instructions'] as Map<String, dynamic>?),
        requiresTaper: j['requires_taper'] == true,
        aliases: ((j['aliases'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
      );
}
