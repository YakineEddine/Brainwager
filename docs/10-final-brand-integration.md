# 10 — Intégration finale de la marque (ticket final-brand-integration)

Artwork approuvé intégré, repli conservé. Aucune règle, aucune autorité,
aucune config de signature modifiée. `versionCode` NON incrémenté ici
(bump dans le ticket release dédié).

## 1. Assets détectés (`assets/branding/`, déclarés `pubspec.yaml`)

| Fichier | Format vérifié | Usage |
|---|---|---|
| `brainwager_logo.png` | 2000×512 RGBA, bords alpha 0 | `BrainBrand.full`, Home |
| `brainwager_logo_compact.png` | 1024×1024 RGBA, bords alpha 0 | `BrainBrand.compact` |
| `brainwager_mark.png` | 1024×1024 RGBA, bords alpha 0 | `BrainBrand.markOnly` |
| `brainwager_app_icon_source.png` | 1024×1024 RGB opaque | launcher Android |
| `brainwager_splash_mark.png` | 1024×1024 RGBA, bords alpha 0 | splash natif |

Transparence prouvée par script (décodage IDAT) : coins/bords alpha 0
(pas de rectangle noir/blanc), centres opaques. `BoxFit.contain`
partout, aucun étirement, aucune recompression.

## 2. Mappings (`brainBrandAsset()`)

- full → `assets/branding/brainwager_logo.png`
- compact → `assets/branding/brainwager_logo_compact.png`
- markOnly → `assets/branding/brainwager_mark.png`

Repli wordmark + `errorBuilder` intacts (testés via bundle en échec).

## 3. Home

Logo final centré + tagline, sans titre dupliqué ; hiérarchie
Créer/Rejoindre puis Packs/Boutique inchangée ; 320px FR/EN/AR + 1.3x
sans overflow (tests R1–R4 + E).

## 4. Icône launcher Android

Méthode : `flutter_launcher_icons` 0.14.4 (dev), config
`flutter_launcher_icons.yaml`, `dart run flutter_launcher_icons`.
Legacy mipmaps + adaptatif (`mipmap-anydpi-v26/ic_launcher.xml`) générés.
Stratégie adaptive : source unique opaque en foreground (inset 16 %),
fond uni `#1E1B2E` — la séparation avant/arrière-plan sans retouche
artwork est impossible depuis une source opaque unique, donc le fond
reste invisible et l'icône est un plein-bleed sûr aux crops
circulaire/squircle. `applicationId` (`com.yakineeddine.brainwager`),
signing, SDK : intouchés. iOS non généré.

## 5. Splash natif

Méthode : `flutter_native_splash` 2.4.8 (dev), config
`flutter_native_splash.yaml`, `dart run flutter_native_splash:create`.
Fond `#1E1B2E`, sigle centré, plein écran, sans animation/tagline/fausse
progression. Android 12+ : `values-v31` (+ night) avec mêmes couleur et
image (règles splash Android 12 supportées). Bootstrap/auth inchangés,
aucun délai artificiel. iOS/web non générés.

## 6. Dépendances ajoutées (dev uniquement)

- `flutter_launcher_icons: ^0.14.4`
- `flutter_native_splash: ^2.4.8`

Aucune dépendance runtime ajoutée.

## 7. Cohérence

Home = logo final ; compacts là où le texte serait trop grand ;
ancien B-tile invisible en chargement normal ; aucun texte BRAINWAGER
dupliqué autour des assets ; lisible sur fond sombre.

## 8. Reste

Bump `versionCode`, AAB release (après revue), Play Console, 5 packs
de production, validation d'achat réelle.
