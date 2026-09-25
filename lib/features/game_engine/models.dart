// Modèles purs du moteur (aucun import Flutter/Supabase).
// match_mode par question : exact | fuzzy. Nombres/années toujours exact.

enum MatchMode { exact, fuzzy }

class GameQuestion {
  final String id;
  final int difficulty; // 1..3
  final MatchMode matchMode;
  const GameQuestion({
    required this.id,
    required this.difficulty,
    this.matchMode = MatchMode.fuzzy,
  });
}

/// Réponse + mise d'un joueur pour une question (index 0-based).
class PlayerTurn {
  final int questionIndex;
  final String answerText;
  final int wager;
  final bool? isCorrect; // null = non corrigé
  final bool isOverridden;
  const PlayerTurn({
    required this.questionIndex,
    required this.answerText,
    required this.wager,
    this.isCorrect,
    this.isOverridden = false,
  });
}

/// Stats recalculées depuis l'historique complet (correction 7).
class PlayerStats {
  final int score;
  final int bestStreak;
  final int biggestWagerWon;
  const PlayerStats({
    required this.score,
    required this.bestStreak,
    required this.biggestWagerWon,
  });
}
