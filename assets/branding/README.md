# assets/branding — Emplacements du logo Brainwager (artwork final à venir)

Ce dossier accueillera les assets finaux (fournis séparément) :

- `brainwager_logo.png` — logo horizontal complet
- `brainwager_logo_compact.png` — logo compact
- `brainwager_mark.png` — sigle seul
- `brainwager_app_icon_source.png` — source icône (carré, 1024×1024 min)
- `brainwager_splash_mark.png` — sigle pour l'écran de démarrage

Règles :
- ne PAS commiter de faux visuels raster en attendant ;
- `BrainBrand` (`lib/shared/widgets/brand.dart`) affiche aujourd'hui
  TOUJOURS le wordmark de repli : `_brandAssetFor()` retourne
  volontairement null tant que l'artwork n'est pas approuvé ;
- déposer des PNG ici seuls ne suffit PAS à les activer (aucune magie).

Après approbation de l'artwork final, activer en 4 étapes :
1. déposer les PNG listés ci-dessus dans `assets/branding/` ;
2. déclarer `assets/branding/` dans `pubspec.yaml` (`flutter/assets`) ;
3. mapper chaque `BrainBrandVariant` vers son chemin dans
   `_brandAssetFor()` (`lib/shared/widgets/brand.dart`) ;
4. vérifier le repli (`errorBuilder`) et FR/EN/AR + RTL.

Voir `docs/09-brand-and-polish.md` (splash, icône, direction de marque).
