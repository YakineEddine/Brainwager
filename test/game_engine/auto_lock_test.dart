import 'package:flutter_test/flutter_test.dart';
import 'package:brainwager/features/game_engine/auto_lock.dart';

void main() {
  const opened = '2026-09-20T12:00:00+00:00';

  bool attempt(AutoLockTracker t, {int pos = 3, String? at = opened}) =>
      t.shouldAttempt(position: pos, openedAt: at);
  void claim(AutoLockTracker t, {int pos = 3, String? at = opened}) =>
      t.markAttempted(position: pos, openedAt: at);

  test('une seule tentative par identité question', () {
    final t = AutoLockTracker();
    expect(attempt(t), isTrue);
    claim(t);
    expect(attempt(t), isFalse);
  });

  test('identités indépendantes (position OU opened_at différents)', () {
    final t = AutoLockTracker();
    claim(t);
    expect(attempt(t, pos: 4), isTrue);
    expect(
      attempt(t, at: '2026-09-20T12:01:00+00:00'),
      isTrue,
    );
  });

  test('reset réautorise tout (nouvelle partie)', () {
    final t = AutoLockTracker();
    claim(t);
    t.reset();
    expect(attempt(t), isTrue);
  });

  group('isFreshnessProbeEligible (zéro réseau avant le seuil)', () {
    final openedDt = DateTime.utc(2026, 9, 20, 12, 0, 0);

    bool eligibleAt(int sec, {String? at = opened}) =>
        isFreshnessProbeEligible(
          localOpenedAt: at,
          durationSec: 30,
          lockGraceSec: 2,
          nowUtc: openedDt.add(Duration(seconds: sec)),
        );

    test('avant le seuil local : pas de probe', () {
      expect(eligibleAt(10), isFalse);
      expect(eligibleAt(27), isFalse);
    });

    test('au seuil et après : probe autorisée', () {
      expect(eligibleAt(28), isTrue);
      expect(eligibleAt(45), isTrue);
    });

    test('opened_at absent/illisible : pas de probe', () {
      expect(eligibleAt(99, at: null), isFalse);
      expect(eligibleAt(99, at: 'pas-une-date'), isFalse);
    });
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
