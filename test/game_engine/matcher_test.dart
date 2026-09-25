import 'package:flutter_test/flutter_test.dart';
import 'package:brainwager/features/game_engine/answer_matcher.dart';
import 'package:brainwager/features/game_engine/models.dart';

void main() {
  test('normalisation accents/casse/articles', () {
    expect(
      matchAnswer(playerRaw: 'La Tour Eiffel', expectedRaw: 'tour eiffel'),
      isTrue,
    );
    expect(matchAnswer(playerRaw: 'Éléphant', expectedRaw: 'elephant'), isTrue);
    expect(matchAnswer(playerRaw: "l'Avion", expectedRaw: 'avion'), isTrue);
  });

  test('alias acceptés', () {
    expect(
      matchAnswer(
        playerRaw: 'NYC',
        expectedRaw: 'New York',
        aliasesRaw: const ['nyc', 'new-york city'],
      ),
      isTrue,
    );
  });

  test('fuzzy tolère petite faute', () {
    expect(
      matchAnswer(playerRaw: 'Napoleon', expectedRaw: 'Napoléon'),
      isTrue,
    );
  });

  test('Iran vs Irak refusés en exact', () {
    expect(
      matchAnswer(
        playerRaw: 'Irak',
        expectedRaw: 'Iran',
        mode: MatchMode.exact,
      ),
      isFalse,
    );
  });

  test('1984 vs 1985 refusés (années toujours exact)', () {
    expect(
      matchAnswer(playerRaw: '1985', expectedRaw: '1984'),
      isFalse,
    );
    expect(
      matchAnswer(
        playerRaw: '1985',
        expectedRaw: '1984',
        mode: MatchMode.fuzzy,
      ),
      isFalse,
      reason: 'années forcées en exact même en fuzzy',
    );
  });

  test('nombres forcés en exact', () {
    expect(matchAnswer(playerRaw: '42', expectedRaw: '43'), isFalse);
    expect(matchAnswer(playerRaw: '42', expectedRaw: '42'), isTrue);
  });
}
