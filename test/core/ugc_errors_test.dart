import 'package:flutter_test/flutter_test.dart';
import 'package:brainwager/core/utils/game_errors.dart';

void main() {
  test('T) pack-in-use FR + EN', () {
    expect(
      friendlyUgcError(Exception('pack-in-use'), 'fr'),
      'Ce pack est utilisé par une partie existante et ne peut pas encore être modifié.',
    );
    expect(
      friendlyUgcError(Exception('pack-in-use'), 'en'),
      'This pack is used by an existing game and cannot be edited yet.',
    );
  });

  test('T) pack-not-editable FR + EN', () {
    expect(
      friendlyUgcError(Exception('pack-not-editable'), 'fr'),
      'Seul le propriétaire peut modifier ce pack.',
    );
    expect(
      friendlyUgcError(Exception('pack-not-editable'), 'en'),
      'Only the owner can edit this pack.',
    );
  });

  test('codes indexés + termes requis + inconnu', () {
    expect(
      friendlyUgcError(Exception('invalid-question:4'), 'fr'),
      'Chaque question doit faire 2 à 500 caractères (FR, EN, AR).',
    );
    expect(
      friendlyUgcError(Exception('terms-required'), 'en'),
      'You must accept the content terms to create a pack.',
    );
    expect(
      friendlyUgcError(Exception('something-else'), 'fr'),
      'Erreur réseau ou serveur. Réessaie.',
    );
  });

  test('not-authenticated FR/EN/AR (partage/signalement)', () {
    expect(
      friendlyUgcError(Exception('not-authenticated'), 'fr'),
      'Session perdue : reconnecte-toi.',
    );
    expect(
      friendlyUgcError(Exception('not-authenticated'), 'en'),
      'Session lost: please sign in again.',
    );
    expect(
      friendlyUgcError(Exception('not-authenticated'), 'ar'),
      'فُقدت الجلسة: سجل الدخول مجددًا.',
    );
  });
  test('AD) erreurs arabes en AR', () {
    expect(
      friendlyUgcError(Exception('arabic-content-required'), 'ar'),
      'تحتوي هذه الحزمة على محتوى عربي: الحقول العربية مطلوبة.',
    );
    expect(
      friendlyUgcError(Exception('invalid-arabic-content'), 'ar'),
      'يجب تقديم السؤال والإجابة بالعربية معًا.',
    );
    expect(
      friendlyUgcError(Exception('pack-language-unavailable'), 'ar'),
      'هذه الحزمة غير متاحة باللغة العربية.',
    );
    expect(
      friendlyUgcError(Exception('pack-in-use'), 'ar'),
      'هذه الحزمة مستخدمة في لعبة حالية ولا يمكن تعديلها بعد.',
    );
  });
}
