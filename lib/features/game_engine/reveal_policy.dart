// Politique de lecture de la réponse révélée (pur Dart).
// Miroir de reveal_answer côté serveur : la transition
// question_locked → reveal/final_reveal est réservée à l'hôte ;
// une fois révélé, tout membre peut relire la réponse.
// Jamais de lecture pendant question_open/final_wager.
const _readableStatuses = {
  'reveal',
  'leaderboard',
  'final_reveal',
  'finished',
};

/// Vrai si le client peut appeler reveal_answer en LECTURE (réponse déjà
/// révélée). Faux en question_locked même pour l'hôte : l'hôte passe par
/// la transition (voir [mayTransitionReveal]).
bool maySyncReadRevealed(String status) => _readableStatuses.contains(status);

/// Vrai si l'hôte peut déclencher la transition de révélation.
bool mayTransitionReveal({required String status, required bool isHost}) =>
    status == 'question_locked' && isHost;
