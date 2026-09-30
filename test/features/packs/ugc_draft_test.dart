import 'package:flutter_test/flutter_test.dart';
import 'package:brainwager/features/packs/ugc_draft.dart';
import 'package:brainwager/features/packs/ugc_repository.dart';

UgcQuestionDraft _q({
  String promptFr = 'Question ?',
  String promptEn = 'Question?',
  String answerFr = 'Réponse',
  String answerEn = 'Answer',
  List<String> aliasesFr = const [],
  List<String> aliasesEn = const [],
  String category = 'general',
  int difficulty = 1,
  String matchMode = 'fuzzy',
}) =>
    UgcQuestionDraft(
      promptFr: promptFr,
      promptEn: promptEn,
      answerMainFr: answerFr,
      answerMainEn: answerEn,
      aliasesFr: aliasesFr,
      aliasesEn: aliasesEn,
      category: category,
      difficulty: difficulty,
      matchMode: matchMode,
    );

UgcPackDraft _pack(List<UgcQuestionDraft> questions) => UgcPackDraft(
      titleFr: 'Titre',
      titleEn: 'Title',
      descFr: '',
      descEn: '',
      questions: questions,
    );

List<UgcQuestionDraft> _eleven() =>
    List.generate(11, (_) => _q());

void main() {
  group('parse get_ugc_pack_for_edit', () {
    test('A) réponses + alias + share_code préservés', () {
      final doc = {
        'id': 'pack-1',
        'title_fr': 'Titre',
        'title_en': 'Title',
        'desc_fr': '',
        'desc_en': '',
        'share_code': 'PK-AB12',
        'questions': [
          {
            'idx': 0,
            'prompt_fr': 'Q ?',
            'prompt_en': 'Q?',
            'category': 'g',
            'difficulty': 2,
            'match_mode': 'exact',
            'answer_main_fr': 'R',
            'answer_main_en': 'A',
            'aliases_fr': ['r1', 'r2'],
            'aliases_en': [],
          },
        ],
      };
      final draft = parseUgcPackForEdit(doc);
      expect(draft.packId, 'pack-1');
      expect(draft.shareCode, 'PK-AB12');
      expect(draft.questions.length, 1);
      final q = draft.questions.first;
      expect(q.answerMainFr, 'R');
      expect(q.aliasesFr, ['r1', 'r2']);
      expect(q.matchMode, 'exact');
    });

    test('R) share_code conservé tel quel', () {
      final draft = parseUgcPackForEdit({
        'id': 'p',
        'share_code': 'PK-ZZ99',
        'questions': [],
      });
      expect(draft.shareCode, 'PK-ZZ99');
    });
  });

  group('toRpcJson', () {
    test('B) jeu de clés exact', () {
      final json = _q().toRpcJson();
      expect(
        json.keys.toSet(),
        {
          'prompt_fr',
          'prompt_en',
          'answer_main_fr',
          'answer_main_en',
          'aliases_fr',
          'aliases_en',
          'category',
          'difficulty',
          'match_mode',
        },
      );
    });

    test('C) aucun id/idx/image/flag/share', () {
      final json = _q().toRpcJson();
      for (final forbidden in [
        'id',
        'question_id',
        'idx',
        'image_url',
        'pack_id',
        'is_official',
        'is_premium',
        'is_hidden',
        'share_code',
        'price_sku',
      ]) {
        expect(json.containsKey(forbidden), isFalse, reason: forbidden);
      }
    });
  });

  group('effectiveMatchMode', () {
    test('D) réponse FR numérique force exact', () {
      expect(
        effectiveMatchMode(
            answerFr: '1984', answerEn: 'Year', selected: 'fuzzy'),
        'exact',
      );
    });

    test('E) réponse EN numérique force exact', () {
      expect(
        effectiveMatchMode(
            answerFr: 'Année', answerEn: '-12,5', selected: 'fuzzy'),
        'exact',
      );
    });

    test('F) non numérique préserve fuzzy', () {
      expect(
        effectiveMatchMode(
            answerFr: 'Paris', answerEn: 'Paris', selected: 'fuzzy'),
        'fuzzy',
      );
      expect(
        effectiveMatchMode(
            answerFr: 'Paris', answerEn: 'Paris', selected: 'exact'),
        'exact',
      );
    });

    test('toRpcJson applique le forçage exact', () {
      final json = _q(answerFr: '11', matchMode: 'fuzzy').toRpcJson();
      expect(json['match_mode'], 'exact');
    });
  });

  group('validateUgcPack', () {
    test('G) 10 questions => échec', () {
      final errors = validateUgcPack(
        _pack(List.generate(10, (_) => _q())),
      );
      expect(errors, contains('pack-too-small'));
    });

    test('H) 11 valides => succès', () {
      expect(validateUgcPack(_pack(_eleven())), isEmpty);
    });

    test('I) 101 questions => échec', () {
      final errors = validateUgcPack(
        _pack(List.generate(101, (_) => _q())),
      );
      expect(errors, contains('pack-too-large'));
    });

    test('J) titres limites', () {
      expect(
        validateUgcPack(_pack(_eleven()).copyWith(titleFr: 'A')),
        contains('invalid-title'),
      );
      expect(
        validateUgcPack(
          _pack(_eleven()).copyWith(titleEn: List.filled(81, 'x').join()),
        ),
        contains('invalid-title'),
      );
    });

    test('K) prompt/réponse/catégorie invalides', () {
      final bad = _eleven();
      bad[3] = _q(promptFr: 'x', answerEn: '', category: '');
      final errors = validateUgcPack(_pack(bad));
      expect(errors.any((e) => e.startsWith('invalid-question:')), isTrue);
      expect(errors.any((e) => e.startsWith('invalid-answer:')), isTrue);
      expect(errors.any((e) => e.startsWith('invalid-category:')), isTrue);
      final badDif = _eleven();
      badDif[0] = _q(difficulty: 9);
      expect(
        validateUgcPack(_pack(badDif))
            .any((e) => e.startsWith('invalid-difficulty:')),
        isTrue,
      );
    });

    test('L) >20 alias rejetés', () {
      final bad = _eleven();
      bad[0] = _q(aliasesFr: List.filled(21, 'a'));
      expect(
        validateUgcPack(_pack(bad))
            .any((e) => e.startsWith('too-many-aliases:')),
        isTrue,
      );
    });

    test('M) alias >100 chars rejeté', () {
      final bad = _eleven();
      bad[0] = _q(aliasesEn: [List.filled(101, 'x').join()]);
      expect(
        validateUgcPack(_pack(bad))
            .any((e) => e.startsWith('invalid-aliases:')),
        isTrue,
      );
    });
  });

  group('aliases', () {
    test('N) lignes vides rognées', () {
      expect(
        parseAliasesLines('  alpha \n\n  \nbeta\n'),
        ['alpha', 'beta'],
      );
    });
  });

  group('opérations de liste', () {
    test('O) add/remove/reorder préservent l’ordre', () {
      var list = List.generate(
        11,
        (i) => _q(promptFr: 'Q$i'),
      );
      list = addBlankQuestion(list);
      expect(list.length, 12);
      list = removeQuestionAt(list, 0);
      expect(list.length, 11);
      expect(list.first.promptFr, 'Q1');
      // Plancher à 11 : refusé.
      expect(identical(removeQuestionAt(list, 0), list), isTrue);
      // Plafond à 100.
      var big = list;
      for (var i = 0; i < 200; i++) {
        big = addBlankQuestion(big);
      }
      expect(big.length, 100);
      // Reorder : Q1 Q2 Q3, move 0 -> 2 => Q2 Q3 Q1.
      final moved = moveQuestion(list, 0, 2);
      expect(moved[0].promptFr, 'Q2');
      expect(moved[1].promptFr, 'Q3');
      expect(moved[2].promptFr, 'Q1');
      // Hors bornes : inchangé.
      expect(identical(moveQuestion(list, 0, 0), list), isTrue);
      expect(identical(moveQuestion(list, -1, 2), list), isTrue);
      expect(identical(moveQuestion(list, 0, 99), list), isTrue);
    });
  });

  group('canEditPack', () {
    test('S) vrai seulement pour pack personnel non officiel', () {
      expect(
        canEditPack(isOfficial: false, isOwned: true),
        isTrue,
      );
      expect(
        canEditPack(isOfficial: true, isOwned: false),
        isFalse,
      );
      expect(
        canEditPack(isOfficial: false, isOwned: false),
        isFalse,
      );
      expect(
        canEditPack(isOfficial: true, isOwned: true),
        isFalse,
      );
    });
  });

  group('paramètres RPC', () {
    test('P) create inclut p_accept_terms + payload exact', () {
      final params = buildCreateUgcParams(
        _pack([_q()]),
        acceptTerms: true,
      );
      expect(params['p_accept_terms'], isTrue);
      expect(params['p_title_fr'], 'Titre');
      final questions = params['p_questions'] as List;
      expect(questions.length, 1);
      expect(
        (questions.first as Map).keys.toSet(),
        {
          'prompt_fr',
          'prompt_en',
          'answer_main_fr',
          'answer_main_en',
          'aliases_fr',
          'aliases_en',
          'category',
          'difficulty',
          'match_mode',
        },
      );
    });

    test('Q) update sans p_accept_terms', () {
      final params = buildUpdateUgcParams('pack-1', _pack([_q()]));
      expect(params['p_pack'], 'pack-1');
      expect(params.containsKey('p_accept_terms'), isFalse);
      expect((params['p_questions'] as List).length, 1);
    });
  });
}
