import 'package:flutter_test/flutter_test.dart';
import 'package:brainwager/features/game_session/game_screen.dart';

List<({int idx, int amount})> rows(List<List<int>> pairs) =>
    [for (final p in pairs) (idx: p[0], amount: p[1])];

void main() {
  group('resolveWagerSelection', () {
    test('courante restaurée, précédentes exclues du set', () {
      // Q antérieures : 1 et 5 ; Q3 courante sauvée à 7, sélection périmée 5.
      final r = resolveWagerSelection(
        position: 3,
        current: 5,
        rows: rows([
          [0, 1],
          [1, 5],
          [3, 7],
        ]),
      );
      expect(r.previousUsed, {1, 5});
      expect(r.previousUsed.contains(7), isFalse);
      expect(r.saved, 7);
      expect(r.wager, 7);
    });

    test('mise courante libre conservée (remplace la sauvée)', () {
      final r = resolveWagerSelection(
        position: 3,
        current: 4,
        rows: rows([
          [0, 1],
          [3, 7],
        ]),
      );
      expect(r.wager, 4);
      expect(r.saved, 7);
    });

    test('sans sauvegarde : première valeur libre', () {
      final r = resolveWagerSelection(
        position: 2,
        current: 5,
        rows: rows([
          [0, 5],
          [1, 1],
        ]),
      );
      expect(r.saved, isNull);
      expect(r.wager, 2);
    });

    test('finale : jamais 5, défaut 0, sauvegarde restaurée', () {
      final dflt = resolveWagerSelection(position: 10, current: 5, rows: []);
      expect(dflt.wager, 0);
      expect(dflt.saved, isNull);
      final kept = resolveWagerSelection(
        position: 10,
        current: 5,
        rows: rows([
          [10, 20],
        ]),
      );
      expect(kept.saved, 20);
      expect(kept.wager, 20);
      final valid = resolveWagerSelection(position: 10, current: 10, rows: []);
      expect(valid.wager, 10);
    });
  });

  group('canSubmitAnswer', () {
    test('question ouverte + mises prêtes', () {
      expect(
        canSubmitAnswer(status: 'question_open', wagersReady: true),
        isTrue,
      );
      expect(
        canSubmitAnswer(status: 'final_wager', wagersReady: true),
        isTrue,
      );
    });

    test('bloqué sans mises prêtes (état initial/reconnect)', () {
      expect(
        canSubmitAnswer(status: 'question_open', wagersReady: false),
        isFalse,
      );
    });

    test('bloqué hors question ouverte', () {
      for (final s in ['lobby', 'question_locked', 'reveal', 'finished']) {
        expect(
          canSubmitAnswer(status: s, wagersReady: true),
          isFalse,
          reason: s,
        );
      }
    });
  });

  group('showLockFor', () {
    test('hôte : verrou manuel sur question ouverte', () {
      expect(
        showLockFor(
          status: 'question_open',
          isHost: true,
          lockDue: false,
        ),
        isTrue,
      );
      expect(
        showLockFor(status: 'final_wager', isHost: true, lockDue: false),
        isTrue,
      );
    });

    test('non-hôte : seulement après le seuil local', () {
      expect(
        showLockFor(status: 'question_open', isHost: false, lockDue: false),
        isFalse,
      );
      expect(
        showLockFor(status: 'question_open', isHost: false, lockDue: true),
        isTrue,
      );
    });

    test('aucun Lock hors question ouverte', () {
      for (final s in [
        'lobby',
        'question_locked',
        'reveal',
        'leaderboard',
        'final_reveal',
        'finished',
      ]) {
        expect(
          showLockFor(status: s, isHost: true, lockDue: true),
          isFalse,
          reason: s,
        );
        expect(
          showLockFor(status: s, isHost: false, lockDue: true),
          isFalse,
          reason: s,
        );
      }
    });
  });
}
