import 'package:flutter_test/flutter_test.dart';
import 'package:brainwager/features/game_engine/auto_lock.dart';

void main() {
  test('une seule tentative par question', () {
    final t = AutoLockTracker();
    expect(t.shouldAttempt(3), isTrue);
    t.markAttempted(3);
    expect(t.shouldAttempt(3), isFalse);
  });

  test('positions indépendantes', () {
    final t = AutoLockTracker();
    t.markAttempted(3);
    expect(t.shouldAttempt(4), isTrue);
  });

  test('reset réautorise tout (nouvelle partie)', () {
    final t = AutoLockTracker();
    t.markAttempted(3);
    t.reset();
    expect(t.shouldAttempt(3), isTrue);
  });

  group('mayAttemptAutoLock (snapshot périmé)', () {
    const opened = '2026-09-20T12:00:00+00:00';

    bool decide({
      int localPos = 3,
      String? localOpened = opened,
      int freshPos = 3,
      String? freshOpened = opened,
      String freshStatus = 'question_open',
      bool due = true,
      bool fresh = true,
    }) =>
        mayAttemptAutoLock(
          localPosition: localPos,
          localOpenedAt: localOpened,
          freshPosition: freshPos,
          freshOpenedAt: freshOpened,
          freshStatus: freshStatus,
          lockDue: due,
          notYetAttempted: fresh,
        );

    test('même position + même opened_at + due => peut verrouiller', () {
      expect(decide(), isTrue);
    });

    test('position différente => ne doit pas verrouiller', () {
      expect(decide(freshPos: 4), isFalse);
    });

    test('même position mais opened_at différent => ne doit pas verrouiller',
        () {
      expect(
        decide(freshOpened: '2026-09-20T12:01:00+00:00'),
        isFalse,
      );
    });

    test('statut frais non ouvert => ne doit pas verrouiller', () {
      for (final s in ['reveal', 'leaderboard', 'lobby', 'question_locked']) {
        expect(decide(freshStatus: s), isFalse, reason: s);
      }
      expect(decide(freshStatus: 'final_wager'), isTrue);
    });

    test('pas due ou déjà tenté => ne doit pas verrouiller', () {
      expect(decide(due: false), isFalse);
      expect(decide(fresh: false), isFalse);
    });
  });
}
