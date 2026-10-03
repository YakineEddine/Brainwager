# 08 — Expérience de partie (ticket UI-2)

Refonte visuelle de l'écran de jeu uniquement : aucune règle, aucune RPC,
aucune donnée d'autorité modifiée. Tous les prédicats (`showLockFor`,
`showRevealFor`, `showBoardFor`, `showNextFor`, `showFinishFor`,
`canAnswerIn`, `isSubmitAllowed`, gardes, `BrainClock`) sont inchangés.

## 1. États visuels gameplay

- answering (`question_open`/`final_wager`) : hero question + réponse +
  mises + submit + feedback ; CTA forts.
- verrouillé (`question_locked`) : panneau verrou (icône + libellé de
  statut existant), timer figé/terminé, zone réponse/mises atténuée
  (`Opacity`, déjà désactivée par la logique).
- reveal et au-delà (`reveal`/`final_reveal`/`leaderboard`/`finished`) :
  hero + panneau reveal si réponse présente + contrôles hôte ; la zone de
  réponse n'a plus de sens (le serveur tranche) et est masquée.
- Le titre d'AppBar reste `Jeu · <statut>` (libellés existants).

## 2. Hero question (`BrainQuestionHero`)

Compteur `position + 1 / 11` (toujours LTR, pas de flip bidi en arabe),
prompt dominant (`headlineSmall`), direction du CONTENU de partie
(RTL arabe), timer intégré. Finale : cadre or + rappel
`finalWagerTitle` existant. Catégorie/difficulté absentes du RPC
(`get_current_question` ne les renvoie pas) : non affichées, sans
changement backend. `image_url` renvoyé mais non affiché (ticket futur).

## 3. Timer (`BrainTimer`, `timerPhaseFor`)

Phases : >10 s normal (turquoise), ≤10 s warning (or), ≤5 s critique
(corail, anneau épais + halo + pulsation scale lente 1.0↔1.05, sans
flash). Le calcul `remainingSec` reste serveur (`opened_at` + offset) :
le widget n'affiche que la valeur reçue. `CountdownRing` historique
conservé (fichier + tests intacts).

## 4. Mises (`BrainWagerSelector` / `BrainWagerToken`)

Jetons ronds (56, 68 en finale) : sélectionné = fond or + scale + halo
(évident), déjà-utilisé = visible + barré + cadenas + insensible,
désactivé = atténué. Finale : variante accentuée bordure or. Sémantique
a11y (`selected`/`enabled`/`button`). Haptics `selectionClick` au choix
(appelant). Règles 1–10 / 0–10–20 et mises utilisées inchangées
(`_prevUsedWagers`, `resolveWagerSelection`).

## 5. Réponse / soumission (`BrainAnswerPanel`, `BrainSubmissionStatus`)

Panneau carte : champ (direction contenu, type 18), focus thème, bouton
submit intégré (spinner pendant `submitInFlight`). `SubmissionState`
inchangé ; un flag UI local `_editedAfterSave` (hors modèle) pilote
l'avertissement "modifié, à revalider" (nouvelle clé ARB `answerEdited`
FR/EN/AR). Succès = badge turquoise animé (`AnimatedSwitcher`).
`SubmissionSnapshot`/`shouldMarkSubmitted` intacts.

## 6. Verrouillage

Panels §1 + minuteur figé + atténuation. Aucun nouvel état serveur.

## 7. Reveal (`BrainRevealPanel`)

Lueur or + entrée échelle/fondu (400 ms, une fois), icône célébration,
`RevealedAnswerView` conservé (direction contenu, tests intacts). La
réponse vient uniquement de `reveal_answer` (hôte ou sync) ; jamais
d'inférence locale. Haptics `mediumImpact` unique par révélation.

## 8. Contrôles hôte (`BrainHostControls`)

Carte d'actions : Lock/Reveal primaires, Board/Next secondaires,
Finish corail distinct (destructif/final ≠ progression). Visibilité
100 % prédicats existants. Haptics `lightImpact` au submit réussi.

## 9. Leaderboard / podium / résultat joueur : NON FAITS (données absentes)

Le client ne reçoit ni lignes de classement ni scores ni résultat
individuel par question (seuls `memberCount`/`presenceCount` existent).
Donc : aucun classement, aucun podium, aucun "correct/incorrect"
joueur — l'afficher exigerait SQL/RPC, hors scope et interdit ici.
Les statuts `leaderboard`/`finished` gardent l'état existant (question +
contrôles hôte Next/Finish). Ticket backend/UI ultérieur requis.

## 10. Animations / haptics / a11y

Flutter natif implicite uniquement (`AnimatedScale` jetons,
`AnimatedSwitcher` statuts, `TweenAnimationBuilder` reveal, pulsation
critique) ; cibles ≥48 dp, contrastes élevés, pas de flash rapide,
scroll clavier conservé, RTL vérifié par tests.

## 11. Reste (UI-3+)

Classement/podium (bloqué données), image de question, célébration
reveal enrichie, animations lobby, migration visuelle éditeur UGC et
écrans secondaires.
