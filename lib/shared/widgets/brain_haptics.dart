// Haptique Brainwager (best-effort multi-plateforme) : web/desktop/test
// sans implémentation haptique ne doivent jamais faire échouer le gameplay.
// Chaque opération est donc protégée : un support manquant est ignoré.
// Impulsions sobres aux moments clés, jamais à chaque rebuild/tick.
import 'package:flutter/services.dart';

class BrainHaptics {
  /// Sélection de mise : clic discret.
  static Future<void> select() async {
    try {
      await HapticFeedback.selectionClick();
    } catch (_) {}
  }

  /// Soumission réussie : impact léger.
  static Future<void> success() async {
    try {
      await HapticFeedback.lightImpact();
    } catch (_) {}
  }

  /// Révélation : impact moyen, une seule fois par réponse révélée
  /// (l'appelant déduplique via _installRevealedAnswer).
  static Future<void> reveal() async {
    try {
      await HapticFeedback.mediumImpact();
    } catch (_) {}
  }
}
