// Messages d'erreur conviviaux FR pour les conditions de jeu attendues.
// L'UI n'affiche que ceci ; le détail brut reste dans l'exception (debug).
String friendlyGameError(Object error) {
  final s = '$error';
  if (s.contains('game-not-found')) {
    return 'Partie introuvable. Vérifie le code.';
  }
  if (s.contains('game-already-started')) {
    return 'La partie a déjà commencé.';
  }
  if (s.contains('nickname-taken')) {
    return 'Ce pseudo est déjà pris dans cette partie.';
  }
  if (s.contains('game-full')) {
    return 'Partie complète (50 joueurs max).';
  }
  if (s.contains('not-enough-players')) {
    return 'Il faut au moins 2 joueurs pour démarrer.';
  }
  if (s.contains('not-member')) {
    return 'Tu n’es pas membre de cette partie.';
  }
  if (s.contains('not-open')) {
    return 'Question fermée : attends la suivante.';
  }
  if (s.contains('wager-already-used')) {
    return 'Mise déjà utilisée : choisis-en une autre.';
  }
  if (s.contains('session-absente')) {
    return 'Session perdue : rejoins la partie à nouveau.';
  }
  return 'Erreur réseau ou serveur. Réessaie.';
}
