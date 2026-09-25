// Machine à états minimale de partie (garde-fous UI + tests).
enum GamePhase { lobby, questionOpen, questionLocked, reveal, leaderboard, finished }

class GameFsm {
  GamePhase phase;
  GameFsm([this.phase = GamePhase.lobby]);

  static const _allowed = {
    GamePhase.lobby: {GamePhase.questionOpen},
    GamePhase.questionOpen: {GamePhase.questionLocked},
    GamePhase.questionLocked: {GamePhase.reveal},
    GamePhase.reveal: {GamePhase.leaderboard, GamePhase.finished},
    GamePhase.leaderboard: {GamePhase.questionOpen, GamePhase.finished},
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
