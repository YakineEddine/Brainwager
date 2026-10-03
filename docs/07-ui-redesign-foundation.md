# 07 — Refonte UI : fondation premium (ticket UI-1)

Direction : passer du prototype fonctionnel à un party quiz premium
(sombre, énergique, lisible), sans toucher backend, règles, billing,
l10n ni RTL. Pas de logo final dans ce ticket (wordmark temporaire).

## 1. Audit : faiblesses identifiées

- Thème minimal : couleurs déclarées mais à peine appliquées (seuls les
  boutons elevated étaient stylés) ; surfaces Material par défaut ;
  aucune échelle typographique, aucun système d'espacement/rayons ;
  AppBar/champs/chips/diviseurs non thémés.
- Écrans en colonnes brutes : `Scaffold` + `Column` + `ListTile` par défaut,
  hiérarchie faible, look "CRUD"/placeholder, aucun rythme visuel.
- États bricolés écran par écran (loading/erreur/vide dupliqués, styles
  incohérents) ; badges = `Text()` bruts sans emphase.
- Home : 3–4 boutons empilés, aucune identité produit.
- Aucune bibliothèque de composants partagés (seul `CountdownRing`).
- Packs/shop : lignes plates, premium peu désirable, prix peu visibles.

## 2. Décisions de design

- Palette de marque INCHANGÉE (violet électrique `#7C3AED`, fond profond
  `#1E1B2E`, or `#FFC93C`, turquoise, corail) + rôles sémantiques
  (fond/surfaces/bordures) et variantes (violet profond, or profond).
- Atmosphère sombre premium : dégradé de fond + halos violets, cartes en
  couches (surface + bordure violette + ombre douce), panneau hero à
  bordure or pour codes/prix/questions.
- CTA forts : boutons 56 dp, rayon 16, libellés gras ; primaire violet,
  secondaire contour, discret texte.
- Typographie : display 34/800 (wordmark, codes, questions), titres
  24/20/16, corps 16/14/12 ; or réservé à l'énergie (prix, succès).
- Design tokens purs Dart (`lib/app/design_tokens.dart`) : espacements
  4/8/16/24/32/48, rayons 8/16/24/pill, hauteur tactile 56/48.
- RTL-safe : aucune position gauche/droite dure (`Positioned.directional`,
  `Wrap`, alignements logiques) ; contenus arabes inchangés.

## 3. Composants réutilisables introduits

- `lib/app/design_tokens.dart` : `BrainSpacing`, `BrainRadius`,
  `BrainTouch`, `BrainRoles` (pur Dart).
- `lib/app/theme.dart` (étendu) : `ColorScheme.dark` complet + nouveaux
  hexes, `textTheme`, `appBarTheme` transparente, thèmes
  elevated/outlined/text buttons, `cardTheme`, `chipTheme`,
  `inputDecorationTheme`, `dividerTheme`, `snackBarTheme`, indicateur or.
- `lib/shared/widgets/brain_scaffold.dart` : `BrainBackground`
  (dégradé + halos) + `BrainScaffold` (fond + AppBar).
- `lib/shared/widgets/brain_buttons.dart` : `BrainPrimaryButton`,
  `BrainSecondaryButton`, `BrainGhostButton` (wrappers Material, mêmes
  classes sous-jacentes), `BrainMenuCard` (carte menu icône + titre).
- `lib/shared/widgets/brain_card.dart` : `BrainCard`, `BrainHeroPanel`.
- `lib/shared/widgets/section_header.dart` : `SectionHeader`.
- `lib/shared/widgets/state_views.dart` : `BrainLoading`, `BrainEmpty`,
  `BrainError` (message + retry).
- `lib/shared/widgets/badges.dart` : `BrainBadge` (premium/or,
  verrouillé/corail, officiel/violet, perso+possédé/turquoise),
  `BrainBadgeRow`.

## 4. Écrans retouchés (comportement et textes identiques)

- Home : hero wordmark + tagline, 4 cartes menu (Créer/Rejoindre/Packs/
  Boutique) avec icônes colorées ; mêmes routes, mêmes libellés.
- Create : sections pseudo + langue en cartes, CTA via `BrainPrimaryButton`.
- Join : carte formulaire + CTA principal ; pré-remplissage deep link intact.
- Lobby waiting (`LobbyWaitingView`) : code en panneau hero, stats
  membres/présence en carte, CTA hôte ; tous textes/callbacks conservés.
- Game shell : `BrainScaffold` (3 sites), question + timer en panneau hero ;
  logique, statuts, mises, soumission inchangés.
- Packs : cartes riches (titre, description 2 lignes, badges chips),
  états via composants partagés ; détail : panneau hero + badges + aperçu.
- Shop : `BrainScaffold`, lignes produit en cartes (prix réel Play,
  badge Owned), boutons Buy/Restore/Refresh et gating inchangés.

## 5. Reste pour les phases suivantes

- Logo/mascotte final, illustrations, sons, animations (confettis, transitions).
- Detail pack enrichi (galerie, stats), éditeur UGC (thème champs, préview),
  écrans import/partagé/report, onboarding, settings, mode TV, podium.
- Gate premium, billing, deep links, UGC, arabe/RTL : intacts et à préserver.
