import 'package:flutter_test/flutter_test.dart';
import 'package:brainwager/core/config/game_config.dart';

void main() {
  test('I) copyWith préserve tout sauf le champ remplacé', () {
    const base = GameConfig(
      totalQuestions: 7,
      finalQuestionIndex: 6,
      normalWagers: [2, 4],
      finalWagers: [5],
      defaultDurationSec: 45,
      lockGraceSec: 3,
      hostTimeoutSec: 90,
      minPlayers: 3,
      maxPlayers: 12,
      allowNegativeFinal: false,
      joinCodeLength: 6,
      serverOffsetSamples: 5,
      packPreviewCount: 4,
      teamScoring: TeamScoringMode.sum,
      fuzzy: FuzzyThresholds(tiny: 0, short: 1, long: 2),
    );
    final changed = base.copyWith(defaultDurationSec: 30);
    expect(changed.defaultDurationSec, 30);
    expect(changed.totalQuestions, 7);
    expect(changed.finalQuestionIndex, 6);
    expect(changed.normalWagers, [2, 4]);
    expect(changed.finalWagers, [5]);
    expect(changed.lockGraceSec, 3);
    expect(changed.hostTimeoutSec, 90);
    expect(changed.minPlayers, 3);
    expect(changed.maxPlayers, 12);
    expect(changed.allowNegativeFinal, isFalse);
    expect(changed.joinCodeLength, 6);
    expect(changed.serverOffsetSamples, 5);
    expect(changed.packPreviewCount, 4);
    expect(changed.teamScoring, TeamScoringMode.sum);
    expect(changed.fuzzy.tiny, 0);
    expect(changed.fuzzy.short, 1);
    expect(changed.fuzzy.long, 2);
  });

  test('copyWith sans argument conserve tout (défauts inclus)', () {
    const base = GameConfig();
    final same = base.copyWith();
    expect(same.totalQuestions, base.totalQuestions);
    expect(same.lockGraceSec, base.lockGraceSec);
    expect(same.minPlayers, base.minPlayers);
    expect(same.teamScoring, base.teamScoring);
  });
}
