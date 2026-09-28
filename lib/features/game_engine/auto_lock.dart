// Garde anti-doublon d'auto-lock (pur Dart, testable).
// Un client ne tente lock_question qu'une fois par question : le serveur reste
// l'autorité (idempotent), mais on évite toute boucle de retry locale.
class AutoLockTracker {
  final Set<int> _attempted = {};

  /// Vrai si aucun lock n'a encore été tenté pour cette position.
  bool shouldAttempt(int position) => !_attempted.contains(position);

  /// Marquer AVANT l'appel RPC (même en cas d'échec : pas de retry infini).
  void markAttempted(int position) {
    _attempted.add(position);
  }

  /// Nouvelle partie : tout réautoriser.
  void reset() {
    _attempted.clear();
  }
}
