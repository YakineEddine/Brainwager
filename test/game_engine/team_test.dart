import 'package:flutter_test/flutter_test.dart';
import 'package:brainwager/features/game_engine/team_scoring.dart';
import 'package:brainwager/core/config/game_config.dart';

void main() {
  test('moyenne par défaut', () {
    const config = GameConfig(); // average
    expect(teamScore(const [10, 20, 30], config), 20.0);
  });

  test('somme en option', () {
    const config = GameConfig(teamScoring: TeamScoringMode.sum);
    expect(teamScore(const [10, 20, 30], config), 60.0);
  });

  test('équipe vide vaut 0', () {
    const config = GameConfig();
    expect(teamScore(const [], config), 0);
  });
}
