// Scoring + recompute_player_stats : recalcule TOUT depuis l'historique.
// Bonne Q normale : +mise. Mauvaise : 0. Finale : +mise / −mise.
import '../../core/config/game_config.dart';
import 'models.dart';

int scoreForTurn(PlayerTurn turn, GameConfig config) {
  final isFinal = turn.questionIndex == config.finalQuestionIndex;
  final correct = turn.isCorrect ?? false;
  if (isFinal) {
    if (!correct) return config.allowNegativeFinal ? -turn.wager : 0;
    return turn.wager;
  }
  return correct ? turn.wager : 0;
}

/// Source de vérité après override hôte : rejoue tout l'historique trié
/// par questionIndex pour score, bestStreak et biggestWagerWon.
PlayerStats recomputePlayerStats(List<PlayerTurn> turns, GameConfig config) {
  final sorted = List<PlayerTurn>.of(turns)
    ..sort((a, b) => a.questionIndex.compareTo(b.questionIndex));
  var score = 0;
  var streak = 0;
  var best = 0;
  var biggest = 0;
  for (final t in sorted) {
    final pts = scoreForTurn(t, config);
    score += pts;
    if ((t.isCorrect ?? false)) {
      streak += 1;
      if (streak > best) best = streak;
      if (pts > biggest) biggest = pts;
    } else {
      streak = 0;
    }
  }
  return PlayerStats(score: score, bestStreak: best, biggestWagerWon: biggest);
}
