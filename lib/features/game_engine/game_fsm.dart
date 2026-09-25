// Machine à états de partie (garde-fous UI + tests).
// Miroir strict de la FSM serveur (migrations Supabase) :
//   lobby → questionOpen → questionLocked → reveal → leaderboard
//     → questionOpen (suivante) | finalWager → questionLocked
//     → finalReveal → finished.
// Note : questionLocked → reveal | finalReveal dépend de l'index côté serveur
// (finale = idx 10) ; la FSM Dart, sans index, autorise les deux.
enum GamePhase {
  lobby,
  questionOpen,
  questionLocked,
  reveal,
  leaderboard,
  finalWager,
  finalReveal,
  finished,
}

class GameFsm {
  GamePhase phase;
  GameFsm([this.phase = GamePhase.lobby]);

  static const _allowed = {
    GamePhase.lobby: {GamePhase.questionOpen},
    GamePhase.questionOpen: {GamePhase.questionLocked},
    GamePhase.questionLocked: {GamePhase.reveal, GamePhase.finalReveal},
    GamePhase.reveal: {GamePhase.leaderboard},
    GamePhase.leaderboard: {GamePhase.questionOpen, GamePhase.finalWager},
    GamePhase.finalWager: {GamePhase.questionLocked},
    GamePhase.finalReveal: {GamePhase.finished},
    GamePhase.finished: <GamePhase>{},
  };

  bool canGo(GamePhase next) => _allowed[phase]!.contains(next);

  void go(GamePhase next) {
    if (!canGo(next)) {
      throw StateError('illegal transition $phase -> $next');
    }
    phase = next;
  }
}
