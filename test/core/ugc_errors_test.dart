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
      'Chaque question doit faire 2 à 500 caractères (FR et EN).',
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
}
