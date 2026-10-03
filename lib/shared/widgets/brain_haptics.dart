// Haptique Brainwager (app uniquement, jamais en tests widget) :
// impulsions sobres aux moments clés, jamais à chaque rebuild/tick.
import 'package:flutter/services.dart';

class BrainHaptics {
  /// Sélection de mise : clic discret.
  static Future<void> select() => HapticFeedback.selectionClick();

  /// Soumission réussie : impact léger.
  static Future<void> success() => HapticFeedback.lightImpact();

  /// Révélation : impact moyen, une seule fois par réponse révélée.
  static Future<void> reveal() => HapticFeedback.mediumImpact();
}
