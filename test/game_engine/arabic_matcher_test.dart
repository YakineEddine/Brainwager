import 'package:flutter_test/flutter_test.dart';
import 'package:brainwager/features/game_engine/answer_matcher.dart';
import 'package:brainwager/features/game_engine/models.dart';

void main() {
  group('normalisation arabe (miroir SQL 0012)', () {
    test('W) القَمَر -> قمر (voyelles + article ال retirés)', () {
      expect(normalizeAnswer('القَمَر'), 'قمر');
    });

    test('X) إِسْكَنْدَرِيَّة -> اسكندرية (Alef + harakat)', () {
      expect(normalizeAnswer('إِسْكَنْدَرِيَّة'), 'اسكندرية');
    });

    test('Y) ١٩٦٩ -> 1969 (chiffres arabes)', () {
      expect(normalizeAnswer('١٩٦٩'), '1969');
      expect(normalizeAnswer('۱۹۶۹'), '1969');
    });

    test('tatweel supprimé, Maqsura -> Ya', () {
      expect(normalizeAnswer('كتابـ'), 'كتاب');
      expect(normalizeAnswer('القاهره'), 'قاهره');
    });
  });

  group('matching arabe', () {
    test('alias arabe exact accepté', () {
      expect(
        matchAnswer(
          playerRaw: 'جيتار',
          expectedRaw: 'غيتار',
          aliasesRaw: ['جيتار'],
        ),
        isTrue,
      );
    });

    test('AA) faute de frappe fuzzy acceptée (القاهره vs القاهرة)', () {
      expect(
        matchAnswer(
          playerRaw: 'القاهره',
          expectedRaw: 'القاهرة',
        ),
        isTrue,
      );
    });

    test('AB) ١٩٨٤ vs ١٩٨٥ refusé même en fuzzy', () {
      expect(
        matchAnswer(
          playerRaw: '١٩٨٤',
          expectedRaw: '١٩٨٥',
        ),
        isFalse,
      );
      expect(
        matchAnswer(
          playerRaw: '١٩٨٤',
          expectedRaw: '١٩٨٥',
          mode: MatchMode.exact,
        ),
        isFalse,
      );
    });
  });
}
