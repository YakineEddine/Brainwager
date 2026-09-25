// Score équipe : somme ou moyenne (moyenne par défaut, doc 04).
import '../../core/config/game_config.dart';

double teamScore(List<int> memberScores, GameConfig config) {
  if (memberScores.isEmpty) return 0;
  final sum = memberScores.reduce((a, b) => a + b);
  if (config.teamScoring == TeamScoringMode.sum) return sum.toDouble();
  return sum / memberScores.length;
}
