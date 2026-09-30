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

  test('erreurs de course/serveur -> messages FR, jamais de brut', () {
    expect(
      friendlyGameError(Exception('not-allowed-yet')),
      'Verrouillage trop tôt : attends la fin du timer.',
    );
    expect(
      friendlyGameError(Exception('locked')),
      'Temps écoulé : question verrouillée.',
    );
    expect(
      friendlyGameError(Exception('empty-answer')),
      'Écris une réponse avant de valider.',
    );
    expect(
      friendlyGameError(Exception('invalid-wager')),
      'Mise invalide pour cette question.',
    );
    expect(
      friendlyGameError(Exception('invalid-final-wager')),
      'Mise finale : 0, 10 ou 20 uniquement.',
    );
    expect(
      friendlyGameError(Exception('wrong-index')),
      'Question périmée : recharge l’état.',
    );
    expect(
      friendlyGameError(Exception('bad-transition')),
      'Action impossible dans l’état actuel.',
    );
  });

  test('AC) pack-language-unavailable FR/EN/AR', () {
    expect(
      friendlyGameError(Exception('pack-language-unavailable'), 'fr'),
      'Ce pack n’est pas disponible en arabe.',
    );
    expect(
      friendlyGameError(Exception('pack-language-unavailable'), 'en'),
      'This pack is not available in Arabic.',
    );
    expect(
      friendlyGameError(Exception('pack-language-unavailable'), 'ar'),
      'هذه الحزمة غير متاحة باللغة العربية.',
    );
  });

  test('erreurs jeu de base en AR (échantillon)', () {
    expect(
      friendlyGameError(Exception('game-not-found'), 'ar'),
      'اللعبة غير موجودة. تحقق من الرمز.',
    );
    expect(
      friendlyGameError(Exception('not-member'), 'ar'),
      'لست عضوًا في هذه اللعبة.',
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
