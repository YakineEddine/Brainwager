import 'package:flutter_test/flutter_test.dart';
import 'package:brainwager/features/game_engine/reveal_policy.dart';

void main() {
  group('maySyncReadRevealed', () {
    test('jamais pendant question ouverte', () {
      expect(maySyncReadRevealed('question_open'), isFalse);
      expect(maySyncReadRevealed('final_wager'), isFalse);
      expect(maySyncReadRevealed('lobby'), isFalse);
    });

    test('jamais en question_locked (transition hôte séparée)', () {
      expect(maySyncReadRevealed('question_locked'), isFalse);
    });

    test('lecture autorisée une fois révélé', () {
      expect(maySyncReadRevealed('reveal'), isTrue);
      expect(maySyncReadRevealed('leaderboard'), isTrue);
      expect(maySyncReadRevealed('final_reveal'), isTrue);
      expect(maySyncReadRevealed('finished'), isTrue);
    });
  });

  group('mayTransitionReveal', () {
    test('hôte seul en question_locked', () {
      expect(
        mayTransitionReveal(status: 'question_locked', isHost: true),
        isTrue,
      );
      expect(
        mayTransitionReveal(status: 'question_locked', isHost: false),
        isFalse,
      );
    });

    test('aucune transition hors lock', () {
      for (final s in [
        'lobby',
        'question_open',
        'reveal',
        'leaderboard',
        'final_wager',
        'final_reveal',
        'finished',
      ]) {
        expect(
          mayTransitionReveal(status: s, isHost: true),
          isFalse,
          reason: s,
        );
      }
    });
  });
}
