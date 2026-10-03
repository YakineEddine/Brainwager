// Classement autoritaire Phase UI-2 (pur Dart) : les scores viennent
// du serveur (players.score) ; le client trie et affiche seulement.
// Égalités : même rang affiché (1,1,3) ; le pseudo n'ordonne que
// l'affichage (AUCUNE règle de départage gameplay inventée).
class GameStanding {
  final String playerId;
  final String nickname;
  final int score;
  final int bestStreak;
  final int biggestWagerWon;
  const GameStanding({
    required this.playerId,
    required this.nickname,
    required this.score,
    required this.bestStreak,
    required this.biggestWagerWon,
  });

  factory GameStanding.fromRow(Map<String, dynamic> row) {
    return GameStanding(
      playerId: (row['id'] as String?) ?? '',
      nickname: (row['nickname'] as String?) ?? '',
      score: (row['score'] as num?)?.toInt() ?? 0,
      bestStreak: (row['best_streak'] as num?)?.toInt() ?? 0,
      biggestWagerWon: (row['biggest_wager_won'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Tri autoritaire : score décroissant ; pseudo pour un affichage
/// déterministe uniquement (pas de tiebreak de jeu).
List<GameStanding> sortStandings(Iterable<GameStanding> rows) {
  final list = rows.toList();
  list.sort((a, b) {
    final byScore = b.score.compareTo(a.score);
    if (byScore != 0) return byScore;
    return a.nickname.compareTo(b.nickname);
  });
  return list;
}

/// Rangs affichés (competition ranking) : 100,100,80 -> 1,1,3.
/// Même score => même rang ; jamais de faux ordre entre ex æquo.
List<int> displayRanks(List<GameStanding> sorted) {
  final ranks = <int>[];
  var rank = 0;
  int? previousScore;
  for (var i = 0; i < sorted.length; i++) {
    if (previousScore == null || sorted[i].score != previousScore) {
      rank = i + 1;
      previousScore = sorted[i].score;
    }
    ranks.add(rank);
  }
  return ranks;
}
