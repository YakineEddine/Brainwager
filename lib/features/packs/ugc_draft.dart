// Domaine UGC Phase 3C (pur Dart) : brouillons, validation miroir 0012
// trilingue, payloads RPC exacts, opérations de liste. Aucun import
// Flutter/Supabase.
// La détection numérique utilise le normaliseur partagé du matcher de jeu.
import '../../core/utils/arabic_text.dart' show isNumericAnswer;

/// Une question du brouillon éditeur (immuable, trilingue).
class UgcQuestionDraft {
  final String promptFr;
  final String promptEn;
  final String promptAr;
  final String answerMainFr;
  final String answerMainEn;
  final String answerMainAr;
  final List<String> aliasesFr;
  final List<String> aliasesEn;
  final List<String> aliasesAr;
  final String category;
  final int difficulty;
  final String matchMode; // 'exact' | 'fuzzy' (choix UI, voir effectif)

  const UgcQuestionDraft({
    required this.promptFr,
    required this.promptEn,
    required this.promptAr,
    required this.answerMainFr,
    required this.answerMainEn,
    required this.answerMainAr,
    required this.aliasesFr,
    required this.aliasesEn,
    required this.aliasesAr,
    required this.category,
    required this.difficulty,
    required this.matchMode,
  });

  factory UgcQuestionDraft.blank() => const UgcQuestionDraft(
        promptFr: '',
        promptEn: '',
        promptAr: '',
        answerMainFr: '',
        answerMainEn: '',
        answerMainAr: '',
        aliasesFr: [],
        aliasesEn: [],
        aliasesAr: [],
        category: 'general',
        difficulty: 1,
        matchMode: 'fuzzy',
      );

  UgcQuestionDraft copyWith({
    String? promptFr,
    String? promptEn,
    String? promptAr,
    String? answerMainFr,
    String? answerMainEn,
    String? answerMainAr,
    List<String>? aliasesFr,
    List<String>? aliasesEn,
    List<String>? aliasesAr,
    String? category,
    int? difficulty,
    String? matchMode,
  }) {
    return UgcQuestionDraft(
      promptFr: promptFr ?? this.promptFr,
      promptEn: promptEn ?? this.promptEn,
      promptAr: promptAr ?? this.promptAr,
      answerMainFr: answerMainFr ?? this.answerMainFr,
      answerMainEn: answerMainEn ?? this.answerMainEn,
      answerMainAr: answerMainAr ?? this.answerMainAr,
      aliasesFr: aliasesFr ?? this.aliasesFr,
      aliasesEn: aliasesEn ?? this.aliasesEn,
      aliasesAr: aliasesAr ?? this.aliasesAr,
      category: category ?? this.category,
      difficulty: difficulty ?? this.difficulty,
      matchMode: matchMode ?? this.matchMode,
    );
  }

  /// Payload RPC EXACT : uniquement ces 12 clés (idx dérivé de l'ordre).
  Map<String, dynamic> toRpcJson() {
    return {
      'prompt_fr': promptFr.trim(),
      'prompt_en': promptEn.trim(),
      'prompt_ar': promptAr.trim(),
      'answer_main_fr': answerMainFr.trim(),
      'answer_main_en': answerMainEn.trim(),
      'answer_main_ar': answerMainAr.trim(),
      'aliases_fr': List<String>.from(aliasesFr),
      'aliases_en': List<String>.from(aliasesEn),
      'aliases_ar': List<String>.from(aliasesAr),
      'category': category.trim(),
      'difficulty': difficulty,
      'match_mode': effectiveMatchMode(
        answerFr: answerMainFr,
        answerEn: answerMainEn,
        answerAr: answerMainAr,
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
  final String titleAr;
  final String descFr;
  final String descEn;
  final String descAr;
  final List<UgcQuestionDraft> questions;

  const UgcPackDraft({
    required this.titleFr,
    required this.titleEn,
    required this.titleAr,
    required this.descFr,
    required this.descEn,
    required this.descAr,
    required this.questions,
    this.packId,
    this.shareCode,
  });

  factory UgcPackDraft.blank({int count = 11}) => UgcPackDraft(
        titleFr: '',
        titleEn: '',
        titleAr: '',
        descFr: '',
        descEn: '',
        descAr: '',
        questions:
            List<UgcQuestionDraft>.generate(count, (_) => UgcQuestionDraft.blank()),
      );

  UgcPackDraft copyWith({
    String? titleFr,
    String? titleEn,
    String? titleAr,
    String? descFr,
    String? descEn,
    String? descAr,
    List<UgcQuestionDraft>? questions,
  }) {
    return UgcPackDraft(
      packId: packId,
      shareCode: shareCode,
      titleFr: titleFr ?? this.titleFr,
      titleEn: titleEn ?? this.titleEn,
      titleAr: titleAr ?? this.titleAr,
      descFr: descFr ?? this.descFr,
      descEn: descEn ?? this.descEn,
      descAr: descAr ?? this.descAr,
      questions: questions ?? this.questions,
    );
  }
}

/// Match mode effectif : TOUTE réponse primaire numérique (FR, EN ou AR)
/// force exact, même si fuzzy était sélectionné (le serveur tranche aussi).
/// Détection via le normaliseur numérique partagé avec le matcher de jeu
/// (chiffres ASCII + arabes/persans, ex. 1984, ١٩٨٤, ۱۹۸۴, -12,5, -١٢٫٥).
String effectiveMatchMode({
  required String answerFr,
  required String answerEn,
  String answerAr = '',
  required String selected,
}) {
  if (isNumericAnswer(answerFr) ||
      isNumericAnswer(answerEn) ||
      (answerAr.trim().isNotEmpty && isNumericAnswer(answerAr))) {
    return 'exact';
  }
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
        promptAr: (m['prompt_ar'] as String?) ?? '',
        answerMainFr: (m['answer_main_fr'] as String?) ?? '',
        answerMainEn: (m['answer_main_en'] as String?) ?? '',
        answerMainAr: (m['answer_main_ar'] as String?) ?? '',
        aliasesFr: _stringList(m['aliases_fr']),
        aliasesEn: _stringList(m['aliases_en']),
        aliasesAr: _stringList(m['aliases_ar']),
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
    titleAr: (doc['title_ar'] as String?) ?? '',
    descFr: (doc['desc_fr'] as String?) ?? '',
    descEn: (doc['desc_en'] as String?) ?? '',
    descAr: (doc['desc_ar'] as String?) ?? '',
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

/// Validation miroir 0012 trilingue : retourne des codes d'erreur.
/// Le serveur reste l'autorité ; l'UI bloque Save si non vide.
List<String> validateUgcPack(UgcPackDraft draft) {
  final errors = <String>[];
  final tfr = draft.titleFr.trim();
  final ten = draft.titleEn.trim();
  if (tfr.length < 2 || tfr.length > 80) errors.add('invalid-title');
  if (ten.length < 2 || ten.length > 80) {
    if (!errors.contains('invalid-title')) errors.add('invalid-title');
  }
  final tar = draft.titleAr.trim();
  if (tar.length < 2 || tar.length > 80) {
    if (!errors.contains('invalid-title')) errors.add('invalid-title');
  }
  if (draft.descFr.trim().length > 500 ||
      draft.descEn.trim().length > 500 ||
      draft.descAr.trim().length > 500) {
    errors.add('invalid-description');
  }
  final n = draft.questions.length;
  if (n < 11) errors.add('pack-too-small');
  if (n > 100) errors.add('pack-too-large');
  for (var i = 0; i < n; i++) {
    final q = draft.questions[i];
    final pfr = q.promptFr.trim();
    final pen = q.promptEn.trim();
    final par = q.promptAr.trim();
    if (pfr.length < 2 ||
        pfr.length > 500 ||
        pen.length < 2 ||
        pen.length > 500 ||
        par.length < 2 ||
        par.length > 500) {
      errors.add('invalid-question:$i');
    }
    final afr = q.answerMainFr.trim();
    final aen = q.answerMainEn.trim();
    final aar = q.answerMainAr.trim();
    if (afr.isEmpty ||
        afr.length > 200 ||
        aen.isEmpty ||
        aen.length > 200 ||
        aar.isEmpty ||
        aar.length > 200) {
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
    for (final aliases in [q.aliasesFr, q.aliasesEn, q.aliasesAr]) {
      if (aliases.length > 20) errors.add('too-many-aliases:$i');
      if (aliases.any((a) => a.length > 100)) {
        errors.add('invalid-aliases:$i');
      }
    }
  }
  return errors;
}
