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
  if (s.contains('not-locked')) {
    return 'La question n’est pas encore verrouillée.';
  }
  if (s.contains('not-allowed-yet')) {
    return 'Verrouillage trop tôt : attends la fin du timer.';
  }
  if (s.contains('locked')) return 'Temps écoulé : question verrouillée.';
  if (s.contains('empty-answer')) {
    return 'Écris une réponse avant de valider.';
  }
  if (s.contains('invalid-final-wager')) {
    return 'Mise finale : 0, 10 ou 20 uniquement.';
  }
  if (s.contains('invalid-wager')) {
    return 'Mise invalide pour cette question.';
  }
  if (s.contains('wrong-index')) {
    return 'Question périmée : recharge l’état.';
  }
  if (s.contains('bad-transition')) {
    return 'Action impossible dans l’état actuel.';
  }
  if (s.contains('wager-already-used')) {
    return 'Mise déjà utilisée : choisis-en une autre.';
  }
  if (s.contains('session-absente')) {
    return 'Session perdue : rejoins la partie à nouveau.';
  }
  return 'Erreur réseau ou serveur. Réessaie.';
}

/// Messages UGC FR/EN (Phase 3C) : validation cliente (mêmes codes que le
/// serveur 0011) + erreurs RPC. Jamais de texte PostgREST brut en UI.
/// Les codes indexés (`invalid-question:3`) sont réduits à leur base.
String friendlyUgcError(Object error, String languageCode) {
  final en = languageCode == 'en';
  // Codes serveur type `invalid-question` (éventuellement `invalid-question:3`
  // côté validation cliente) : premier token à tirets du texte brut.
  final code =
      RegExp(r'[a-z]+(?:-[a-z]+)+').firstMatch('$error')?.group(0) ?? '';
  switch (code) {
    case 'terms-required':
      return en
          ? 'You must accept the content terms to create a pack.'
          : 'Tu dois accepter les CGU de création de contenu.';
    case 'invalid-title':
      return en
          ? 'Title must be 2–80 characters (FR and EN).'
          : 'Le titre doit faire 2 à 80 caractères (FR et EN).';
    case 'invalid-description':
      return en
          ? 'Description must be 500 characters max.'
          : 'La description doit faire 500 caractères max.';
    case 'invalid-questions':
      return en ? 'Invalid question list.' : 'Liste de questions invalide.';
    case 'pack-too-small':
      return en
          ? 'A pack needs at least 11 questions.'
          : 'Un pack nécessite au moins 11 questions.';
    case 'pack-too-large':
      return en
          ? 'A pack holds 100 questions max.'
          : 'Un pack contient 100 questions max.';
    case 'invalid-question':
      return en
          ? 'A question must be 2–500 characters (FR and EN).'
          : 'Chaque question doit faire 2 à 500 caractères (FR et EN).';
    case 'invalid-answer':
      return en
          ? 'Each answer must be 1–200 characters (FR and EN).'
          : 'Chaque réponse doit faire 1 à 200 caractères (FR et EN).';
    case 'invalid-category':
      return en
          ? 'Category must be 1–40 characters.'
          : 'La catégorie doit faire 1 à 40 caractères.';
    case 'invalid-difficulty':
      return en
          ? 'Difficulty must be 1, 2 or 3.'
          : 'La difficulté doit être 1, 2 ou 3.';
    case 'invalid-match-mode':
      return en
          ? 'Match mode must be exact or fuzzy.'
          : 'Le mode doit être exact ou fuzzy.';
    case 'invalid-aliases':
      return en
          ? 'Aliases must be text, 100 characters max each.'
          : 'Les alias doivent être du texte, 100 caractères max chacun.';
    case 'too-many-aliases':
      return en
          ? '20 aliases max per language.'
          : '20 alias max par langue.';
    case 'ugc-image-forbidden':
      return en
          ? 'Images are not allowed in community packs.'
          : 'Les images sont interdites dans les packs communautaires.';
    case 'pack-not-found':
      return en ? 'Pack not found.' : 'Pack introuvable.';
    case 'pack-not-editable':
      return en
          ? 'Only the owner can edit this pack.'
          : 'Seul le propriétaire peut modifier ce pack.';
    case 'pack-in-use':
      return en
          ? 'This pack is used by an existing game and cannot be edited yet.'
          : 'Ce pack est utilisé par une partie existante et ne peut pas encore être modifié.';
    default:
      return en
          ? 'Network or server error. Try again.'
          : 'Erreur réseau ou serveur. Réessaie.';
  }
}
