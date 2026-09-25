// Validation des mises : Q normales 1..10 usage unique, finale 0/10/20.
import '../../core/config/game_config.dart';

class WagerValidator {
  final GameConfig config;
  const WagerValidator([this.config = const GameConfig()]);

  /// Retourne null si valide, sinon un code d'erreur lisible en test.
  String? validate({required int questionIndex, required int wager}) {
    final isFinal = questionIndex == config.finalQuestionIndex;
    if (isFinal) {
      if (!config.finalWagers.contains(wager)) return 'invalid-final-wager';
      return null;
    }
    if (!config.normalWagers.contains(wager)) return 'invalid-wager';
    return null;
  }

  /// Vérifie l'unicité 1..10 sur l'historique (la base impose aussi l'UNIQUE partiel).
  String? validateUnique({
    required int questionIndex,
    required int wager,
    required List<int> usedWagers,
  }) {
    final err = validate(questionIndex: questionIndex, wager: wager);
    if (err != null) return err;
    if (questionIndex != config.finalQuestionIndex &&
        usedWagers.contains(wager)) {
      return 'wager-already-used';
    }
    return null;
  }

  List<int> remainingWagers(List<int> usedWagers) {
    return config.normalWagers.where((w) => !usedWagers.contains(w)).toList();
  }
}
