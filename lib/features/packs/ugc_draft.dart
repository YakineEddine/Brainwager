// Domaine UGC Phase 3C (pur Dart) : brouillons, validation miroir 0011,
// payloads RPC exacts, opérations de liste. Aucun import Flutter/Supabase.

/// Une question du brouillon éditeur (immuable).
class UgcQuestionDraft {
  final String promptFr;
  final String promptEn;
  final String answerMainFr;
  final String answerMainEn;
  final List<String> aliasesFr;
  final List<String> aliasesEn;
  final String category;
  final int difficulty;
  final String matchMode; // 'exact' | 'fuzzy' (choix UI, voir effectif)

  const UgcQuestionDraft({
    required this.promptFr,
    required this.promptEn,
    required this.answerMainFr,
    required this.answerMainEn,
    required this.aliasesFr,
    required this.aliasesEn,
    required this.category,
    required this.difficulty,
    required this.matchMode,
  });

  factory UgcQuestionDraft.blank() => const UgcQuestionDraft(
        promptFr: '',
        promptEn: '',
        answerMainFr: '',
        answerMainEn: '',
        aliasesFr: [],
        aliasesEn: [],
        category: 'general',
        difficulty: 1,
        matchMode: 'fuzzy',
      );

  UgcQuestionDraft copyWith({
    String? promptFr,
    String? promptEn,
    String? answerMainFr,
    String? answerMainEn,
    List<String>? aliasesFr,
    List<String>? aliasesEn,
    String? category,
    int? difficulty,
    String? matchMode,
  }) {
    return UgcQuestionDraft(
      promptFr: promptFr ?? this.promptFr,
      promptEn: promptEn ?? this.promptEn,
      answerMainFr: answerMainFr ?? this.answerMainFr,
      answerMainEn: answerMainEn ?? this.answerMainEn,
      aliasesFr: aliasesFr ?? this.aliasesFr,
      aliasesEn: aliasesEn ?? this.aliasesEn,
      category: category ?? this.category,
      difficulty: difficulty ?? this.difficulty,
      matchMode: matchMode ?? this.matchMode,
    );
  }

  /// Payload RPC EXACT : uniquement ces 9 clés (idx dérivé de l'ordre).
  Map<String, dynamic> toRpcJson() {
    return {
      'prompt_fr': promptFr.trim(),
      'prompt_en': promptEn.trim(),
      'answer_main_fr': answerMainFr.trim(),
      'answer_main_en': answerMainEn.trim(),
      'aliases_fr': List<String>.from(aliasesFr),
      'aliases_en': List<String>.from(aliasesEn),
      'category': category.trim(),
      'difficulty': difficulty,
      'match_mode': effectiveMatchMode(
        answerFr: answerMainFr,
        answerEn: answerMainEn,
        selected: matchMode,
      ),
    };
  }
}

/// Pack brouillon (création : sans id/code ; édition chargée : avec).
class UgcPackDraft {
  final String? packId;
  final String? shareCode;
  final String titleFr;
  final String titleEn;
  final String descFr;
  final String descEn;
  final List<UgcQuestionDraft> questions;

  const UgcPackDraft({
    required this.titleFr,
    required this.titleEn,
    required this.descFr,
    required this.descEn,
    required this.questions,
    this.packId,
    this.shareCode,
  });

  factory UgcPackDraft.blank({int count = 11}) => UgcPackDraft(
        titleFr: '',
        titleEn: '',
        descFr: '',
        descEn: '',
        questions:
            List<UgcQuestionDraft>.generate(count, (_) => UgcQuestionDraft.blank()),
      );

  UgcPackDraft copyWith({
    String? titleFr,
    String? titleEn,
    String? descFr,
    String? descEn,
    List<UgcQuestionDraft>? questions,
  }) {
    return UgcPackDraft(
      packId: packId,
      shareCode: shareCode,
      titleFr: titleFr ?? this.titleFr,
      titleEn: titleEn ?? this.titleEn,
      descFr: descFr ?? this.descFr,
      descEn: descEn ?? this.descEn,
      questions: questions ?? this.questions,
    );
  }
}

/// Réponse primaire numérique ? (nombres + années, miroir serveur/Dart).
bool isNumericAnswer(String raw) {
  final v = raw.trim();
  return RegExp(r'^-?[0-9]+([.,][0-9]+)?$').hasMatch(v);
}

/// Match mode effectif : toute réponse primaire numérique force exact,
/// même si fuzzy était sélectionné (le serveur tranche de toute façon).
String effectiveMatchMode({
  required String answerFr,
  required String answerEn,
  required String selected,
}) {
  if (isNumericAnswer(answerFr) || isNumericAnswer(answerEn)) return 'exact';
  return selected == 'exact' ? 'exact' : 'fuzzy';
}

/// Aliases : une ligne par alias, lignes vides rognées.
List<String> parseAliasesLines(String text) {
  return text
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();
}

String aliasesToLines(List<String> aliases) => aliases.join('\n');

/// Parse du document get_ugc_pack_for_edit (seule voie réponses/alias).
/// Réponses + alias préservés tels quels pour l'édition propriétaire.
UgcPackDraft parseUgcPackForEdit(Map<String, dynamic> doc) {
  final rawQuestions = doc['questions'];
  final questions = <UgcQuestionDraft>[];
  if (rawQuestions is List) {
    for (final r in rawQuestions) {
      if (r is! Map) continue;
      final m = Map<String, dynamic>.from(r);
      questions.add(UgcQuestionDraft(
        promptFr: (m['prompt_fr'] as String?) ?? '',
        promptEn: (m['prompt_en'] as String?) ?? '',
        answerMainFr: (m['answer_main_fr'] as String?) ?? '',
        answerMainEn: (m['answer_main_en'] as String?) ?? '',
        aliasesFr: _stringList(m['aliases_fr']),
        aliasesEn: _stringList(m['aliases_en']),
        category: (m['category'] as String?) ?? 'general',
        difficulty: (m['difficulty'] as int?) ?? 1,
        matchMode: (m['match_mode'] as String?) ?? 'fuzzy',
      ));
    }
  }
  // L'ordre RPC (par idx) est conservé tel quel : pas de tri client.
  return UgcPackDraft(
    packId: doc['id'] as String?,
    shareCode: doc['share_code'] as String?,
    titleFr: (doc['title_fr'] as String?) ?? '',
    titleEn: (doc['title_en'] as String?) ?? '',
    descFr: (doc['desc_fr'] as String?) ?? '',
    descEn: (doc['desc_en'] as String?) ?? '',
    questions: questions,
  );
}

List<String> _stringList(dynamic v) {
  if (v is! List) return [];
  return [for (final e in v) if (e is String) e];
}

/// Éditable par le client : pack personnel non officiel uniquement.
/// Jamais d'UUID propriétaire exposé : le booléen suffit à l'UI.
bool canEditPack({required bool isOfficial, required bool isOwned}) =>
    !isOfficial && isOwned;

/// Opérations de liste pures (l'ordre du tableau = idx serveur).
/// Ajout plafonné à 100, retrait plancher à 11.
List<UgcQuestionDraft> addBlankQuestion(List<UgcQuestionDraft> questions) {
  if (questions.length >= 100) return questions;
  return [...questions, UgcQuestionDraft.blank()];
}

List<UgcQuestionDraft> removeQuestionAt(
    List<UgcQuestionDraft> questions, int index) {
  if (questions.length <= 11) return questions;
  if (index < 0 || index >= questions.length) return questions;
  final out = [...questions];
  out.removeAt(index);
  return out;
}

List<UgcQuestionDraft> moveQuestion(
    List<UgcQuestionDraft> questions, int from, int to) {
  if (from < 0 ||
      from >= questions.length ||
      to < 0 ||
      to >= questions.length ||
      from == to) {
    return questions;
  }
  final out = [...questions];
  final item = out.removeAt(from);
  out.insert(to, item);
  return out;
}

/// Validation miroir 0011 : retourne des codes d'erreur ('' = valide).
/// Le serveur reste l'autorité ; l'UI bloque Save si non vide.
List<String> validateUgcPack(UgcPackDraft draft) {
  final errors = <String>[];
  final tfr = draft.titleFr.trim();
  final ten = draft.titleEn.trim();
  if (tfr.length < 2 || tfr.length > 80) errors.add('invalid-title');
  if (ten.length < 2 || ten.length > 80) {
    if (!errors.contains('invalid-title')) errors.add('invalid-title');
  }
  if (draft.descFr.trim().length > 500 ||
      draft.descEn.trim().length > 500) {
    errors.add('invalid-description');
  }
  final n = draft.questions.length;
  if (n < 11) errors.add('pack-too-small');
  if (n > 100) errors.add('pack-too-large');
  for (var i = 0; i < n; i++) {
    final q = draft.questions[i];
    final pfr = q.promptFr.trim();
    final pen = q.promptEn.trim();
    if (pfr.length < 2 ||
        pfr.length > 500 ||
        pen.length < 2 ||
        pen.length > 500) {
      errors.add('invalid-question:$i');
    }
    final afr = q.answerMainFr.trim();
    final aen = q.answerMainEn.trim();
    if (afr.isEmpty ||
        afr.length > 200 ||
        aen.isEmpty ||
        aen.length > 200) {
      errors.add('invalid-answer:$i');
    }
    final cat = q.category.trim();
    if (cat.isEmpty || cat.length > 40) errors.add('invalid-category:$i');
    if (q.difficulty < 1 || q.difficulty > 3) {
      errors.add('invalid-difficulty:$i');
    }
    if (q.matchMode != 'exact' && q.matchMode != 'fuzzy') {
      errors.add('invalid-match-mode:$i');
    }
    for (final aliases in [q.aliasesFr, q.aliasesEn]) {
      if (aliases.length > 20) errors.add('too-many-aliases:$i');
      if (aliases.any((a) => a.length > 100)) {
        errors.add('invalid-aliases:$i');
      }
    }
  }
  return errors;
}
