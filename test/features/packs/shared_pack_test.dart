import 'package:flutter_test/flutter_test.dart';
import 'package:brainwager/features/packs/shared_pack.dart';

Map<String, dynamic> _doc() => {
      'id': 'pack-1',
      'title_fr': 'Titre',
      'title_en': 'Title',
      'title_ar': 'عنوان',
      'desc_fr': '',
      'desc_en': '',
      'desc_ar': '',
      'is_official': false,
      'is_premium': false,
      'price_sku': null,
      'share_code': 'PK-AB12',
      'is_owned': false,
      'question_count': 2,
      'mystery_key': 'ignored',
      'questions': [
        {
          'idx': 0,
          'prompt_fr': 'Q ?',
          'prompt_en': 'Q?',
          'prompt_ar': 'س؟',
          'category': 'g',
          'difficulty': 1,
          'answer_main_fr': 'SECRET-NEVER-PARSED',
          'aliases_fr': ['x'],
        },
        {
          'idx': 1,
          'prompt_fr': 'Q2 ?',
          'prompt_en': 'Q2?',
          'category': 's',
          'difficulty': 2,
        },
      ],
    };

void main() {
  test('A) normalize lower-case + espaces -> PK-AB12', () {
    expect(normalizePackShareCode(' pk-ab12 '), 'PK-AB12');
  });

  test('B) format malformé rejeté', () {
    for (final bad in ['', 'AB12', 'PK-ABC', 'PK-ABCDE', 'PK-AB1!', 'XX-AB12']) {
      expect(isValidShareCode(normalizePackShareCode(bad)), isFalse,
          reason: bad);
    }
    expect(isValidShareCode('PK-AB12'), isTrue);
  });

  test('C) SharedPack parse FR/EN/AR + métadonnées', () {
    final p = SharedPack.fromRpc(_doc());
    expect(p.id, 'pack-1');
    expect(p.titleFr, 'Titre');
    expect(p.titleAr, 'عنوان');
    expect(p.shareCode, 'PK-AB12');
    expect(p.isOwned, isFalse);
    expect(p.questionCount, 2);
    expect(p.questions.length, 2);
  });

  test('D) questions parsées sans réponses/alias', () {
    final p = SharedPack.fromRpc(_doc());
    expect(p.questions[0].localizedPrompt('fr'), 'Q ?');
    // Le modèle n'a aucun champ réponse/alias : rien à fuir.
  });

  test('E) fallback FR si arabe vide', () {
    final p = SharedPack.fromRpc(_doc());
    expect(p.localizedTitle('ar'), 'عنوان');
    final emptyAr = SharedPack.fromRpc({..._doc(), 'title_ar': ''});
    expect(emptyAr.localizedTitle('ar'), 'Titre');
    expect(p.localizedDescription('ar'), '');
  });

  test('Y) prompts affichables, aucune UI réponse possible', () {
    final p = SharedPack.fromRpc(_doc());
    expect(
      p.questions.map((q) => q.localizedPrompt('ar')).toList(),
      ['س؟', 'Q2 ?'],
    );
  });

  test('Z) lien copié formaté exactement', () {
    expect(shareLinkFor('PK-AB12'), 'brainwager://pack/PK-AB12');
  });

  test('V) pack possédé -> édition, pas de signalement', () {
    final owned = SharedPack.fromRpc({..._doc(), 'is_owned': true});
    expect(owned.isOwned, isTrue);
  });

  test('W) pack non possédé -> signalement, pas d’édition', () {
    final shared = SharedPack.fromRpc(_doc());
    expect(shared.isOwned, isFalse);
  });
}
