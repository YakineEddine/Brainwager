// Aperçu pack Phase 3A (pur Dart) : lignes servies par get_pack_preview.
// ANTI-TRICHE : jamais de réponses/alias ici (le RPC ne les renvoie pas).
// match_mode peut être ABSENT des lignes officielles : le parser le tolère.
class PackPreviewQuestion {
  final int idx;
  final String promptFr;
  final String promptEn;
  final String category;
  final int difficulty;
  final String? matchMode;

  const PackPreviewQuestion({
    required this.idx,
    required this.promptFr,
    required this.promptEn,
    required this.category,
    required this.difficulty,
    required this.matchMode,
  });

  String localizedPrompt(String languageCode) =>
      languageCode == 'en' ? promptEn : promptFr;
}

/// Parse défensif des lignes RPC (liste JSON). Les lignes incomplètes
/// (sans idx ni énoncés) sont ignorées ; le reste prend des défauts sûrs.
List<PackPreviewQuestion> parsePackPreview(List<dynamic> rows) {
  final out = <PackPreviewQuestion>[];
  for (final r in rows) {
    if (r is! Map) continue;
    final m = Map<String, dynamic>.from(r);
    final idx = m['idx'] as int?;
    final fr = m['prompt_fr'] as String?;
    final en = m['prompt_en'] as String?;
    if (idx == null || fr == null || en == null) continue;
    out.add(PackPreviewQuestion(
      idx: idx,
      promptFr: fr,
      promptEn: en,
      category: (m['category'] as String?) ?? 'general',
      difficulty: (m['difficulty'] as int?) ?? 1,
      matchMode: m['match_mode'] as String?,
    ));
  }
  out.sort((a, b) => a.idx.compareTo(b.idx));
  return out;
}
