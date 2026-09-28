import 'package:flutter_test/flutter_test.dart';
import 'package:brainwager/core/utils/game_errors.dart';
import 'package:brainwager/core/network/supabase_client.dart';

void main() {
  test('codes serveur connus -> messages FR', () {
    expect(
      friendlyGameError(Exception('game-not-found')),
      'Partie introuvable. Vérifie le code.',
    );
    expect(
      friendlyGameError(Exception('game-already-started')),
      'La partie a déjà commencé.',
    );
    expect(
      friendlyGameError(Exception('nickname-taken')),
      'Ce pseudo est déjà pris dans cette partie.',
    );
    expect(
      friendlyGameError(Exception('game-full')),
      'Partie complète (50 joueurs max).',
    );
    expect(
      friendlyGameError(Exception('not-enough-players')),
      'Il faut au moins 2 joueurs pour démarrer.',
    );
    expect(friendlyGameError(Exception('not-member')),
        'Tu n’es pas membre de cette partie.');
    expect(
      friendlyGameError(Exception('not-open')),
      'Question fermée : attends la suivante.',
    );
    expect(
      friendlyGameError(Exception('wager-already-used')),
      'Mise déjà utilisée : choisis-en une autre.',
    );
  });

  test('erreur inconnue -> message générique (détail brut gardé en debug)',
      () {
    expect(
      friendlyGameError(Exception('weird-42P17')),
      'Erreur réseau ou serveur. Réessaie.',
    );
  });

  test('pas de sign-in anonyme si une session existe déjà', () {
    expect(needsAnonymousSignIn(hasSession: true), isFalse);
    expect(needsAnonymousSignIn(hasSession: false), isTrue);
  });
}
