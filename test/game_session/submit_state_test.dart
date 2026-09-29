import 'package:flutter_test/flutter_test.dart';
import 'package:brainwager/features/game_session/game_screen.dart';

const _openedQ3 = '2026-09-20T12:00:00+00:00';
const _openedQ4 = '2026-09-20T12:01:00+00:00';

SubmissionSnapshot _snap({
  int position = 3,
  String? openedAt = _openedQ3,
  String answerText = 'Paris',
  int wager = 7,
  String playerId = 'p1',
}) =>
    SubmissionSnapshot(
      gameId: 'g',
      playerId: playerId,
      position: position,
      openedAt: openedAt,
      answerText: answerText,
      wager: wager,
    );

bool _mark({
  required bool succeeded,
  required SubmissionSnapshot snap,
  int position = 3,
  String? openedAt = _openedQ3,
  String answerText = 'Paris',
  int wager = 7,
  String playerId = 'p1',
}) =>
    shouldMarkSubmitted(
      succeeded: succeeded,
      snapshot: snap,
      gameId: 'g',
      playerId: playerId,
      position: position,
      openedAt: openedAt,
      answerText: answerText,
      wager: wager,
    );

void main() {
  group('shouldMarkSubmitted', () {
    test('A) frappe pendant le vol -> PAS sauvé, texte local gardé', () {
      expect(
        _mark(
          succeeded: true,
          snap: _snap(),
          answerText: 'Paris France',
        ),
        isFalse,
      );
    });

    test('B) même texte + même mise + même question -> sauvé', () {
      expect(_mark(succeeded: true, snap: _snap()), isTrue);
    });

    test('C) mise changée après le départ -> PAS sauvé', () {
      expect(
        _mark(succeeded: true, snap: _snap(), wager: 8),
        isFalse,
      );
    });

    test('D) submit Q3 fini après ouverture Q4 -> Q4 PAS sauvée', () {
      expect(
        _mark(
          succeeded: true,
          snap: _snap(),
          position: 4,
          openedAt: _openedQ4,
          answerText: '',
          wager: 5,
        ),
        isFalse,
      );
    });

    test('D bis) opened_at changé à position égale -> PAS sauvé', () {
      expect(
        _mark(succeeded: true, snap: _snap(), openedAt: _openedQ4),
        isFalse,
      );
    });

    test('joueur différent -> PAS sauvé', () {
      expect(
        _mark(succeeded: true, snap: _snap(), playerId: 'p2'),
        isFalse,
      );
    });

    test('G) échec -> PAS sauvé même si tout correspond', () {
      expect(_mark(succeeded: false, snap: _snap()), isFalse);
    });
  });

  group('isSubmitAllowed', () {
    test('F) second submit pendant un vol -> refusé', () {
      expect(
        isSubmitAllowed(
          status: 'question_open',
          wagersReady: true,
          submitInFlight: true,
        ),
        isFalse,
      );
      expect(
        isSubmitAllowed(
          status: 'question_open',
          wagersReady: true,
          submitInFlight: false,
        ),
        isTrue,
      );
    });

    test('sans mises prêtes ou hors question -> refusé', () {
      expect(
        isSubmitAllowed(
          status: 'question_open',
          wagersReady: false,
          submitInFlight: false,
        ),
        isFalse,
      );
      expect(
        isSubmitAllowed(
          status: 'question_locked',
          wagersReady: true,
          submitInFlight: false,
        ),
        isFalse,
      );
    });
  });

  group('SubmissionState (E : chip après sauvegarde -> dirty)', () {
    test('sélection de mise après état sauvé rend dirty', () {
      final s = SubmissionState()..markSubmitted();
      expect(s.hasSavedAnswer, isTrue);
      // Handler Chip : nouvelle mise + markEdited.
      s.markEdited();
      expect(s.hasSavedAnswer, isFalse);
    });
  });
}
