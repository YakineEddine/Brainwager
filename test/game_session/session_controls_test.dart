import 'package:flutter_test/flutter_test.dart';
import 'package:brainwager/features/game_session/game_screen.dart';

void main() {
  group('contrôles pilotés par le statut', () {
    test('réponse active uniquement sur question ouverte', () {
      expect(canAnswerIn('question_open'), isTrue);
      expect(canAnswerIn('final_wager'), isTrue);
      for (final s in [
        'lobby',
        'question_locked',
        'reveal',
        'leaderboard',
        'final_reveal',
        'finished',
      ]) {
        expect(canAnswerIn(s), isFalse, reason: s);
      }
    });

    test('Reveal : hôte seul en question_locked', () {
      expect(
        showRevealFor(status: 'question_locked', isHost: true),
        isTrue,
      );
      expect(
        showRevealFor(status: 'question_locked', isHost: false),
        isFalse,
      );
      expect(showRevealFor(status: 'reveal', isHost: true), isFalse);
    });

    test('Leaderboard : hôte seul en reveal', () {
      expect(showBoardFor(status: 'reveal', isHost: true), isTrue);
      expect(showBoardFor(status: 'reveal', isHost: false), isFalse);
      expect(showBoardFor(status: 'leaderboard', isHost: true), isFalse);
    });

    test('Next : hôte seul en leaderboard hors finale', () {
      expect(
        showNextFor(status: 'leaderboard', isHost: true, position: 4),
        isTrue,
      );
      expect(
        showNextFor(status: 'leaderboard', isHost: true, position: 10),
        isFalse,
      );
      expect(
        showNextFor(status: 'reveal', isHost: true, position: 4),
        isFalse,
      );
      expect(
        showNextFor(status: 'leaderboard', isHost: false, position: 4),
        isFalse,
      );
    });

    test('Finish : hôte seul en final_reveal', () {
      expect(showFinishFor(status: 'final_reveal', isHost: true), isTrue);
      expect(showFinishFor(status: 'final_reveal', isHost: false), isFalse);
      expect(showFinishFor(status: 'finished', isHost: true), isFalse);
    });

    test('Start : éligible à 2+ membres', () {
      expect(startEnabledFor(memberCount: 1, minPlayers: 2), isFalse);
      expect(startEnabledFor(memberCount: 2, minPlayers: 2), isTrue);
      expect(startEnabledFor(memberCount: 50, minPlayers: 2), isTrue);
    });
  });

  group('fixWagerForQuestion', () {
    test('normale : sélection libre conservée', () {
      expect(
        fixWagerForQuestion(current: 5, position: 0, usedNormal: {1, 2}),
        5,
      );
    });

    test('normale : repli sur première mise libre', () {
      expect(
        fixWagerForQuestion(current: 5, position: 3, usedNormal: {5, 1}),
        2,
      );
    });

    test('finale : jamais le 5 périmé, défaut 0', () {
      expect(
        fixWagerForQuestion(current: 5, position: 10, usedNormal: {}),
        0,
      );
      expect(
        fixWagerForQuestion(current: 20, position: 10, usedNormal: {}),
        20,
      );
      expect(
        fixWagerForQuestion(current: 0, position: 10, usedNormal: {}),
        0,
      );
    });
  });
}
