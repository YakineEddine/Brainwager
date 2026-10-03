# 09 — Marque et polish secondaire (ticket brand-polish)

Identité premium + cohérence des écrans secondaires. Aucune règle,
aucune RPC, aucune autorité modifiée. Logo final NON créé en code
(artwork séparé) : structure + points d'intégration prêts.

## 1. Direction de marque

Trivia social premium : intelligent, compétitif, énergique, mémorable.
Langage établi : fond profond, violet électrique, or, turquoise, corail,
motif jetons/mises. Aucun emprunt tiers (logo, layout, assets).

## 2. Slots d'assets (`assets/branding/`)

Emplacements documentés (`assets/branding/README.md`, sans faux raster) :
`brainwager_logo.png`, `brainwager_logo_compact.png`, `brainwager_mark.png`,
`brainwager_app_icon_source.png`, `brainwager_splash_mark.png`.
`BrainBrand` (`lib/shared/widgets/brand.dart`, variantes
full/compact/markOnly, taille configurable, RTL-safe) affiche l'asset
dès qu'il existe, sinon wordmark texte (B doré + BRAINWAGER).

## 3. Home

Hero `BrainBrand` centré + tagline ; Créer/Rejoindre en cartes primaires
pleine largeur ; Packs/Boutique en duo compact secondaire ; entrées
échelonnées. Routes et libellés inchangés.

## 4. Lobby

Code en panneau hero (inchangé) ; présence avec icône + transition
(`AnimatedSwitcher` sur le compteur). Aucun faux joueur, Presence intacte.

## 5. Packs / détail

Cartes catalogue avec entrée échelonnée ; premium verrouillé = bordure
or + titre or + cadenas (désirable) ; UGC = badge turquoise (inchangé).
Détail : hero + badges + aperçu groupé en carte (lignes denses,
diviseurs). Buy/report/edit et `get_pack_preview` inchangés.

## 6. Shop

Cartes produit (prix Play réel en or fort, badge Owned), Buy/Restore/
Refresh et readiness gating STRICTEMENT intacts. Aucun dark pattern :
ni fausse remise, ni fausse urgence, ni prix barré.

## 7. UGC

Coquille `BrainScaffold` + états partagés ; titres en carte ; questions
en `BrainCard` (`ExpansionTile` conservé) ; ajout secondaire pleine
largeur ; partage/conditions/erreurs en cartes ; save primaire + indicateur
enregistré. Minimum 11 questions, RPC, validation, CGU, exact numérique :
intacts.

## 8. Import / partagé / report

`BrainScaffold` + cartes + états partagés + badges ; RPC (`lookup` via
`get_pack_by_share_code`, `report_pack`) et routage inchangés. Dialogue
de signalement conservé (thème automatique).

## 9. États / motion

`BrainLoading`/`BrainEmpty`/`BrainError` partout ; `BrainEntrance`
(fondu + glissement, délais ≤400 ms, respecte `disableAnimations`) sur
Home et catalogue ; ripple natif ; pas de nouvelle dépendance.

## 10. Splash / icône (préparation, pas d'implémentation)

- Splash futur : fond profond + `brainwager_splash_mark` centré, sans
  longue animation, lancement rapide ; bootstrap actuel intact ;
  `flutter_native_splash` NON ajouté.
- Icône finale : source carrée 1024×1024 min, marque centrale sûre, sans
  micro-texte, compatible crop adaptatif ; génération APRÈS approbation.

## 11. Reste en attente d'artwork

Logo/icones/splash PNG finaux, illustrations, célébrations enrichies,
migration visuelle des écrans restants (game over/tv/settings le cas
échéant).
