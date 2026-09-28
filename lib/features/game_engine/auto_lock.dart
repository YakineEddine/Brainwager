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

/// Décision pure d'auto-lock : le client peut-il tirer son unique tentative
/// lock_question ? Protège contre les snapshots périmés (le RPC ne prend que
/// p_game : un état local en retard verrouillerait la MAUVAISE question).
/// Exige : pas encore tenté + seuil atteint + question fraîche identique
/// (position ET opened_at) + statut frais ouvert.
bool mayAttemptAutoLock({
  required int localPosition,
  required String? localOpenedAt,
  required int freshPosition,
  required String? freshOpenedAt,
  required String freshStatus,
  required bool lockDue,
  required bool notYetAttempted,
}) {
  if (!notYetAttempted || !lockDue) return false;
  if (freshStatus != 'question_open' && freshStatus != 'final_wager') {
    return false;
  }
  if (localPosition != freshPosition) return false;
  if ((localOpenedAt ?? '') != (freshOpenedAt ?? '')) return false;
  return true;
}
