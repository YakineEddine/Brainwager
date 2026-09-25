import 'package:flutter_test/flutter_test.dart';
import 'package:brainwager/features/game_engine/scoring.dart';
import 'package:brainwager/features/game_engine/models.dart';
import 'package:brainwager/core/config/game_config.dart';

void main() {
  const config = GameConfig();

  test('bonne Q normale gagne la mise, mauvaise vaut 0', () {
    expect(
      scoreForTurn(
        const PlayerTurn(questionIndex: 0, answerText: 'x', wager: 7, isCorrect: true),
        config,
      ),
      7,
    );
    expect(
      scoreForTurn(
        const PlayerTurn(questionIndex: 0, answerText: 'x', wager: 7, isCorrect: false),
        config,
      ),
      0,
    );
  });

  test('finale : bonne +mise, mauvaise −mise', () {
    expect(
      scoreForTurn(
        PlayerTurn(questionIndex: config.finalQuestionIndex, answerText: 'x', wager: 20, isCorrect: true),
        config,
      ),
      20,
    );
    expect(
      scoreForTurn(
        PlayerTurn(questionIndex: config.finalQuestionIndex, answerText: 'x', wager: 20, isCorrect: false),
        config,
      ),
      -20,
    );
    expect(
      scoreForTurn(
        PlayerTurn(questionIndex: config.finalQuestionIndex, answerText: 'x', wager: 0, isCorrect: false),
        config,
      ),
      0,
    );
  });

  test('recompute depuis historique (override change tout)', () {
    final turns = [
      const PlayerTurn(questionIndex: 0, answerText: 'a', wager: 5, isCorrect: true),
      const PlayerTurn(questionIndex: 1, answerText: 'b', wager: 8, isCorrect: true),
      const PlayerTurn(questionIndex: 2, answerText: 'c', wager: 3, isCorrect: false),
      PlayerTurn(questionIndex: config.finalQuestionIndex, answerText: 'd', wager: 10, isCorrect: false),
    ];
    final stats = recomputePlayerStats(turns, config);
    // 5 + 8 + 0 − 10 = 3 ; série max 2 ; plus gros pari gagné 8.
    expect(stats.score, 3);
    expect(stats.bestStreak, 2);
    expect(stats.biggestWagerWon, 8);
  });

  test('override : passer une réponse à correcte recalcule tout', () {
    final before = [
      const PlayerTurn(questionIndex: 0, answerText: 'a', wager: 5, isCorrect: false),
      const PlayerTurn(questionIndex: 1, answerText: 'b', wager: 8, isCorrect: true),
    ];
    final after = [
      const PlayerTurn(questionIndex: 0, answerText: 'a', wager: 5, isCorrect: true, isOverridden: true),
      const PlayerTurn(questionIndex: 1, answerText: 'b', wager: 8, isCorrect: true),
    ];
    expect(recomputePlayerStats(before, config).score, 8);
    final fixed = recomputePlayerStats(after, config);
    expect(fixed.score, 13);
    expect(fixed.bestStreak, 2);
    expect(fixed.biggestWagerWon, 8);
  });
}
