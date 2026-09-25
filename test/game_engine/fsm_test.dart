import 'package:flutter_test/flutter_test.dart';
import 'package:brainwager/features/game_engine/game_fsm.dart';

void main() {
  test('cycle nominal question normale', () {
    final fsm = GameFsm();
    fsm.go(GamePhase.questionOpen);
    fsm.go(GamePhase.questionLocked);
    fsm.go(GamePhase.reveal);
    fsm.go(GamePhase.leaderboard);
    expect(fsm.phase, GamePhase.leaderboard);
  });

  test('reveal normal → leaderboard → question suivante', () {
    final fsm = GameFsm(GamePhase.leaderboard);
    fsm.go(GamePhase.questionOpen);
    fsm.go(GamePhase.questionLocked);
    fsm.go(GamePhase.reveal);
    fsm.go(GamePhase.leaderboard);
    expect(fsm.phase, GamePhase.leaderboard);
  });

  test('finale : wager → lock → final reveal → finished', () {
    final fsm = GameFsm(GamePhase.leaderboard);
    fsm.go(GamePhase.finalWager);
    fsm.go(GamePhase.questionLocked);
    fsm.go(GamePhase.finalReveal);
    fsm.go(GamePhase.finished);
    expect(fsm.phase, GamePhase.finished);
  });

  test('sauts illégaux rejetés', () {
    expect(() => GameFsm().go(GamePhase.reveal), throwsStateError);
    expect(() => GameFsm().go(GamePhase.finalWager), throwsStateError);
    expect(() => GameFsm(GamePhase.questionOpen).go(GamePhase.leaderboard),
        throwsStateError);
    expect(() => GameFsm(GamePhase.questionOpen).go(GamePhase.reveal),
        throwsStateError);
    expect(() => GameFsm(GamePhase.reveal).go(GamePhase.questionOpen),
        throwsStateError);
    expect(() => GameFsm(GamePhase.reveal).go(GamePhase.finished),
        throwsStateError);
    expect(() => GameFsm(GamePhase.leaderboard).go(GamePhase.finished),
        throwsStateError);
    expect(() => GameFsm(GamePhase.leaderboard).go(GamePhase.reveal),
        throwsStateError);
    expect(() => GameFsm(GamePhase.finalWager).go(GamePhase.reveal),
        throwsStateError);
    expect(
        () => GameFsm(GamePhase.finalWager).go(GamePhase.leaderboard),
        throwsStateError);
    expect(() => GameFsm(GamePhase.questionLocked).go(GamePhase.leaderboard),
        throwsStateError);
    expect(() => GameFsm(GamePhase.finalReveal).go(GamePhase.leaderboard),
        throwsStateError);
  });

  test('aucune transition possible après finished', () {
    for (final next in GamePhase.values) {
      expect(() => GameFsm(GamePhase.finished).go(next), throwsStateError);
    }
    expect(GameFsm(GamePhase.finished).canGo(GamePhase.questionOpen), isFalse);
  });

  test('transition illégale rejetée (cas historique)', () {
    final fsm = GameFsm();
    expect(() => fsm.go(GamePhase.reveal), throwsStateError);
  });
}
