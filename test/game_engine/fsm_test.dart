import 'package:flutter_test/flutter_test.dart';
import 'package:brainwager/features/game_engine/game_fsm.dart';

void main() {
  test('cycle nominal accepté', () {
    final fsm = GameFsm();
    fsm.go(GamePhase.questionOpen);
    fsm.go(GamePhase.questionLocked);
    fsm.go(GamePhase.reveal);
    fsm.go(GamePhase.leaderboard);
    fsm.go(GamePhase.finished);
    expect(fsm.phase, GamePhase.finished);
  });

  test('transition illégale rejetée', () {
    final fsm = GameFsm();
    expect(() => fsm.go(GamePhase.reveal), throwsStateError);
  });
}
