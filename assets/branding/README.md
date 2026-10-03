# assets/branding — Emplacements du logo Brainwager (artwork final à venir)

Ce dossier accueillera les assets finaux (fournis séparément) :

- `brainwager_logo.png` — logo horizontal complet
- `brainwager_logo_compact.png` — logo compact
- `brainwager_mark.png` — sigle seul
- `brainwager_app_icon_source.png` — source icône (carré, 1024×1024 min)
- `brainwager_splash_mark.png` — sigle pour l'écran de démarrage

Règles :
- ne PAS commiter de faux visuels raster en attendant ;
- `BrainBrand` (`lib/shared/widgets/brand.dart`) affiche automatiquement
  l'asset dès qu'il existe, sinon un wordmark texte de repli ;
- quand les PNG finaux arrivent : les déposer ici, déclarer le dossier
  dans `pubspec.yaml` (`flutter/assets`), et vérifier FR/EN/AR + RTL.

Voir `docs/09-brand-and-polish.md` (splash, icône, direction de marque).
