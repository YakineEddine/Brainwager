// Garde anti-doublon d'auto-lock (pur Dart, testable).
// Un client ne tente lock_question qu'une fois par question : le serveur reste
// l'autorité (idempotent), mais on évite toute boucle de retry locale.
// Les tentatives sont identifiées par (position + opened_at) : un snapshot
// périmé ne peut jamais consommer la tentative de la vraie question.
import 'timing.dart';

class AutoLockTracker {
  final Set<String> _attempted = {};

  static String identity({
    required int position,
    required String? openedAt,
  }) =>
      '$position|${openedAt ?? ''}';

  /// Vrai si aucune tentative n'a encore été réclamée pour cette question.
  bool shouldAttempt({required int position, required String? openedAt}) =>
      !_attempted.contains(identity(position: position, openedAt: openedAt));

  /// Réclamer AVANT tout appel réseau (même en cas d'échec : pas de retry
  /// infini, et un snapshot périmé ne rejoue jamais chaque seconde).
  void markAttempted({required int position, required String? openedAt}) {
    _attempted.add(identity(position: position, openedAt: openedAt));
  }

  /// Nouvelle partie : tout réautoriser.
  void reset() {
    _attempted.clear();
  }
}

/// Porte d'entrée réseau de l'auto-lock (pure, testable) : le client ne doit
/// faire AUCUN appel (même pas get_current_question) tant que l'horloge
/// locale corrigée n'a pas atteint opened_at + duration − lockGraceSec.
/// Le ticker 1 s reste donc 100 % local hors seuil.
bool isFreshnessProbeEligible({
  required String? localOpenedAt,
  required int durationSec,
  required int lockGraceSec,
  required DateTime nowUtc,
}) {
  final opened =
      localOpenedAt == null ? null : DateTime.tryParse(localOpenedAt)?.toUtc();
  if (opened == null) return false;
  return isLockDue(
    openedAtUtc: opened,
    durationSec: durationSec,
    lockGraceSec: lockGraceSec,
    nowUtc: nowUtc,
  );
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
