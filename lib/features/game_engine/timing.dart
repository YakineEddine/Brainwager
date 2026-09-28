// Helpers de timing purs (aucun import Flutter/Supabase).
// Compte à rebours et seuil de verrouillage projetés depuis les timestamps
// serveur absolus (opened_at + duration). Le serveur reste l'autorité ;
// ces fonctions ne font que projeter l'état pour l'affichage et le lock tardif.

/// Temps restant en secondes. Jamais négatif.
int remainingSeconds({
  required DateTime openedAtUtc,
  required int durationSec,
  required DateTime nowUtc,
}) {
  final end = openedAtUtc.add(Duration(seconds: durationSec));
  final diff = end.difference(nowUtc).inSeconds;
  return diff < 0 ? 0 : diff;
}

/// Instant absolu à partir duquel le lock tardif est accepté côté serveur :
/// opened_at + duration − lockGraceSec (miroir de lock_question).
DateTime lockEligibleAt({
  required DateTime openedAtUtc,
  required int durationSec,
  required int lockGraceSec,
}) {
  return openedAtUtc.add(Duration(seconds: durationSec - lockGraceSec));
}

/// Vrai quand le temps corrigé a atteint le point de lock éligible.
bool isLockDue({
  required DateTime openedAtUtc,
  required int durationSec,
  required int lockGraceSec,
  required DateTime nowUtc,
}) {
  return !nowUtc.isBefore(
    lockEligibleAt(
      openedAtUtc: openedAtUtc,
      durationSec: durationSec,
      lockGraceSec: lockGraceSec,
    ),
  );
}
