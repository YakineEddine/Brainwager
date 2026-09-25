import 'package:flutter_test/flutter_test.dart';
import 'package:brainwager/features/game_engine/question_selector.dart';
import 'package:brainwager/features/game_engine/models.dart';
import 'package:brainwager/core/config/game_config.dart';

List<GameQuestion> pool(int n, {int hardCount = 3}) {
  return List.generate(n, (i) {
    final diff = i >= n - hardCount ? 3 : (i % 2 == 0 ? 1 : 2);
    return GameQuestion(id: 'q${i.toString().padLeft(2, '0')}', difficulty: diff);
  });
}

void main() {
  const config = GameConfig();

  test('11 questions sans doublon, finale la plus difficile', () {
    final selected = selectGameQuestions(pool(30), config: config);
    expect(selected.length, 11);
    expect(selected.map((q) => q.id).toSet().length, 11);
    expect(selected.last.difficulty, 3);
  });

  test('pool trop petite lève une erreur explicite', () {
    expect(
      () => selectGameQuestions(pool(5), config: config),
      throwsA(isA<PoolTooSmallException>()),
    );
  });

  test('finale parmi les difficiles même si peu nombreuses', () {
    final selected = selectGameQuestions(pool(15, hardCount: 1), config: config);
    expect(selected.last.difficulty, 3);
  });
}
