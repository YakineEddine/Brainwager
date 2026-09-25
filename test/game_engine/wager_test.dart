import 'package:flutter_test/flutter_test.dart';
import 'package:brainwager/features/game_engine/wager_validator.dart';
import 'package:brainwager/core/config/game_config.dart';

void main() {
  const config = GameConfig();
  const validator = WagerValidator(config);

  test('Q normales acceptent 1..10', () {
    for (var w = 1; w <= 10; w++) {
      expect(validator.validate(questionIndex: 0, wager: w), isNull);
    }
  });

  test('Q normale refuse 0 et 11', () {
    expect(validator.validate(questionIndex: 0, wager: 0), isNotNull);
    expect(validator.validate(questionIndex: 0, wager: 11), isNotNull);
  });

  test('finale accepte uniquement 0/10/20', () {
    expect(
      validator.validate(questionIndex: config.finalQuestionIndex, wager: 0),
      isNull,
    );
    expect(
      validator.validate(questionIndex: config.finalQuestionIndex, wager: 10),
      isNull,
    );
    expect(
      validator.validate(questionIndex: config.finalQuestionIndex, wager: 20),
      isNull,
    );
    expect(
      validator.validate(questionIndex: config.finalQuestionIndex, wager: 15),
      isNotNull,
    );
    expect(
      validator.validate(questionIndex: config.finalQuestionIndex, wager: 5),
      isNotNull,
    );
  });

  test('mise réutilisée refusée (unicité 1..10)', () {
    expect(
      validator.validateUnique(
        questionIndex: 4,
        wager: 7,
        usedWagers: const [7, 3],
      ),
      'wager-already-used',
    );
    expect(
      validator.validateUnique(
        questionIndex: 4,
        wager: 5,
        usedWagers: const [7, 3],
      ),
      isNull,
    );
  });

  test('mises restantes', () {
    expect(
      validator.remainingWagers(const [1, 2, 3]),
      [4, 5, 6, 7, 8, 9, 10],
    );
  });
}
