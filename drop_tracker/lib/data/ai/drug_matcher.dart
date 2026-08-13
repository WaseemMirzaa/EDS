import '../../models/drug_catalog_entry.dart';
import '../../models/scan.dart';

/// A resolved (or candidate) drug for a piece of scanned text.
class DrugMatch {
  final DrugCatalogEntry drug;
  final MatchMethod method;

  /// 0..1. Anything below [DrugMatcher.reviewThreshold] is shown as a
  /// suggestion the user must confirm rather than applied silently.
  final double score;

  const DrugMatch({required this.drug, required this.method, required this.score});

  bool get isConfident => score >= DrugMatcher.confidentThreshold;
}

/// Resolves free text from a label into a canonical catalog entry.
///
/// Implementations escalate through progressively more expensive strategies —
/// exact, alias, fuzzy, then (server-side) vector and LLM — and stop at the
/// first confident hit. [LocalDrugMatcher] covers the first three entirely
/// on-device, which resolves the large majority of real labels without a
/// network call or an inference cost.
abstract class DrugMatcher {
  /// At or above this, a match may be pre-applied to a draft.
  static const double confidentThreshold = 0.90;

  /// Below this, the field is left blank rather than guessed at.
  static const double reviewThreshold = 0.55;

  /// Best match, or null if nothing cleared [reviewThreshold].
  Future<DrugMatch?> match(String rawText);

  /// Ranked alternatives, for the "did you mean..." row in the review UI.
  Future<List<DrugMatch>> candidates(String rawText, {int limit = 5});
}

/// On-device matcher over a locally-held catalog.
///
/// Deliberately dependency-free and synchronous underneath: it runs before any
/// network or model call, and it keeps working with no connectivity — which
/// matters because a user scanning a bottle is often standing in a pharmacy.
class LocalDrugMatcher implements DrugMatcher {
  final List<DrugCatalogEntry> catalog;
  const LocalDrugMatcher(this.catalog);

  @override
  Future<DrugMatch?> match(String rawText) async {
    final ranked = await candidates(rawText, limit: 1);
    if (ranked.isEmpty) return null;
    return ranked.first.score >= DrugMatcher.reviewThreshold ? ranked.first : null;
  }

  @override
  Future<List<DrugMatch>> candidates(String rawText, {int limit = 5}) async {
    final needle = DrugCatalogEntry.normalize(rawText);
    if (needle.isEmpty) return const [];

    final results = <DrugMatch>[];
    for (final drug in catalog) {
      DrugMatch? best;
      for (final name in drug.matchableNames) {
        final hay = DrugCatalogEntry.normalize(name);
        if (hay.isEmpty) continue;

        MatchMethod method;
        double score;

        if (hay == needle) {
          method = name == drug.brandName ? MatchMethod.exact : MatchMethod.alias;
          score = 1.0;
        } else if (hay.contains(needle) || needle.contains(hay)) {
          // Labels carry extra tokens ("PRED FORTE 1% SUSP OP"), so containment
          // is a strong signal — scaled by how much of the longer string is
          // actually accounted for, to avoid short names matching everything.
          method = MatchMethod.alias;
          final shorter = hay.length < needle.length ? hay.length : needle.length;
          final longer = hay.length > needle.length ? hay.length : needle.length;
          score = 0.72 + 0.23 * (shorter / longer);
        } else {
          method = MatchMethod.trigram;
          score = _diceCoefficient(needle, hay);
        }

        if (best == null || score > best.score) {
          best = DrugMatch(drug: drug, method: method, score: score);
        }
      }
      if (best != null && best.score >= DrugMatcher.reviewThreshold) {
        results.add(best);
      }
    }

    results.sort((a, b) => b.score.compareTo(a.score));
    return results.take(limit).toList();
  }

  /// Sørensen–Dice over character bigrams: the same shape of similarity
  /// Postgres `pg_trgm` gives server-side, so on-device and server matching
  /// rank candidates consistently.
  static double _diceCoefficient(String a, String b) {
    if (a.length < 2 || b.length < 2) return a == b ? 1.0 : 0.0;
    final bigramsA = _bigrams(a);
    final bigramsB = _bigrams(b);
    var overlap = 0;
    final pool = List<String>.from(bigramsB);
    for (final g in bigramsA) {
      final i = pool.indexOf(g);
      if (i >= 0) {
        overlap++;
        pool.removeAt(i);
      }
    }
    return (2 * overlap) / (bigramsA.length + bigramsB.length);
  }

  static List<String> _bigrams(String s) =>
      [for (var i = 0; i < s.length - 1; i++) s.substring(i, i + 2)];
}
