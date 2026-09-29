import 'package:flutter_test/flutter_test.dart';
import 'package:brainwager/features/game_session/game_screen.dart';

void main() {
  group('restoredAnswerText', () {
    test('A) aucune ligne -> rien à installer', () {
      expect(restoredAnswerText(row: null, currentPosition: 3), isNull);
    });

    test('ligne vide -> rien à installer', () {
      expect(
        restoredAnswerText(
          row: {'answer_text': '', 'question_idx': 3},
          currentPosition: 3,
        ),
        isNull,
      );
    });

    test('B/D) ligne question courante -> texte serveur', () {
      expect(
        restoredAnswerText(
          row: {'answer_text': 'Paris', 'question_idx': 3},
          currentPosition: 3,
        ),
        'Paris',
      );
    });

    test("ligne d'une autre question -> jetée", () {
      expect(
        restoredAnswerText(
          row: {'answer_text': 'Paris', 'question_idx': 5},
          currentPosition: 3,
        ),
        isNull,
      );
    });

    test('G) statut indifférent : la ligne propre reste lisible (lock inclus)',
        () {
      // RLS autorise ses propres lignes quel que soit le statut ; le champ
      // est désactivé par canAnswerIn, jamais vidé au changement de statut.
      expect(
        restoredAnswerText(
          row: {'answer_text': 'Paris', 'question_idx': 3},
          currentPosition: 3,
        ),
        'Paris',
      );
    });
  });

  group('AnswerLoadGuard', () {
    const idA = 'g|p|3|2026-09-20T12:00:00+00:00';
    const idB = 'g|p|4|2026-09-20T12:01:00+00:00';

    test('C) réponse Q3 après ouverture Q4 -> jetée', () {
      final g = AnswerLoadGuard();
      g.beginLoad(idA);
      g.beginLoad(idB);
      expect(g.finishLoad(idA, currentId: idB), isFalse);
      expect(g.finishLoad(idB, currentId: idB), isTrue);
    });

    test('même question -> acceptée', () {
      final g = AnswerLoadGuard();
      g.beginLoad(idA);
      expect(g.finishLoad(idA, currentId: idA), isTrue);
    });

    test('reset nettoie', () {
      final g = AnswerLoadGuard();
      g.beginLoad(idA);
      g.reset();
      expect(g.finishLoad(idA, currentId: idA), isFalse);
    });
  });

  group('SubmissionState', () {
    test('F) nouvelle question -> plus rien de sauvé', () {
      final s = SubmissionState()..markSubmitted();
      s.resetForNewQuestion();
      expect(s.hasSavedAnswer, isFalse);
    });

    test('H) submit réussi -> sauvé ; édition -> modifiable', () {
      final s = SubmissionState();
      expect(s.hasSavedAnswer, isFalse);
      s.markSubmitted();
      expect(s.hasSavedAnswer, isTrue);
      s.markEdited();
      expect(s.hasSavedAnswer, isFalse);
    });
  });
}
