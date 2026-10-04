# 12 — Coquille claire + navigation persistante (ticket light-shell)

Retour tests-appareil : l'UI sombre/violette est remplacée par un système
clair. Aucune règle, aucune autorité, aucun backend modifié.

## 1. Palette claire

Fond `#F5FBFA`, surfaces `#FFFFFF`, primaire cobalt `#3B82F6`
(interactif/sélection), teal `#00A7A0` (succès/positif), corail `#FF6B6B`
(danger/critique), texte `#17324D` / `#6B7C8F`, bordures `#D7E3E1`.
Or réservé aux détails premium/classement (texte en `goldDeep`
`#8A6100` sur fond clair pour le contraste ; teal foncé `#00776F`
pour les badges succès). `ColorScheme.light`, ombres subtiles,
champs teintés `#EAF4F3` dans les cartes blanches, snackbars sombres.

## 2. Composants adaptés

`BrainBackground` (dégradé blanc→cloud, halos teal/cobalt à 0.10–0.12),
`BrainHeroPanel` blanc + ombre, `BrainCard` (or = premium verrouillé
uniquement), badges pleins contrastés, jetons de mise sélectionnés
cobalt/blanc, timer (turquoise/or/corail conservés en phases), rangs
or-foncé, prix boutique or-foncé, Hero Home en dégradé teal→cobalt
(le logo, conçu pour fond sombre, y reste lisible).

## 3. Navigation persistante

`StatefulShellRoute.indexedStack` + `BrainShell` (`NavigationBar`
Material 3, 4 destinations localisées FR/EN/AR, indicateur + icône
pleine, RTL natif, état des onglets préservé) :
Home/Packs/Shop/**Profile** avec navbar ; create/join/game/éditeur/
import/partagé hors shell (testé : aucune navbar). Deep links intacts.

## 4. Profil (fondation visuelle)

`/profile` : sigle, avatar placeholder, état auth RÉEL local
(invité/anonyme + id court, pseudo des métadonnées si présent),
locale, carte "options à venir". Aucun OAuth, aucun faux avatar/solde ;
prêt pour liaison Google/Facebook + avatars.

## 5. Shop : chargement corrigé

La page s'affiche immédiatement : init billing en arrière-plan
(démarrage unique + re-demande seulement si nouveaux SKU, retry
manuel via Refresh). Sections : statut compact, produits (ou attente
localisée), Restore/Refresh. `Buy`/`canBuy` et gate Restore inchangés ;
aucun unlock/prix/SKU factice. Listes premium groupées (`ShopSection`).

## 6. Correctif responsive trouvé par les tests

Actions AppBar Packs (2 TextButtons) débordaient à 320px/1.3x :
regroupées en `PopupMenuButton` (mêmes routes/libellés, tooltip
framework). 320/360px × 1.0/1.3x × EN/FR/AR : zéro overflow.

## 7. Phases suivantes

Auth/avatar, médias packs/questions, révision des réponses,
économie/ads. Classement/podium/jeu : logique inchangée.
