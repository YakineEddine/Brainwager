# assets/branding — Logo final Brainwager (artwork approuvé, ACTIVÉ)

Contenu (ne pas modifier, ne pas recompresser) :

- `brainwager_logo.png` — logo horizontal (2000×512, RGBA) → `BrainBrand.full`
- `brainwager_logo_compact.png` — logo compact (1024×1024, RGBA) → `compact`
- `brainwager_mark.png` — sigle (1024×1024, RGBA) → `markOnly`
- `brainwager_app_icon_source.png` — source icône (1024×1024, opaque RGB)
- `brainwager_splash_mark.png` — sigle splash (1024×1024, RGBA)

Vérifié : PNG valides, fonds transparents (coins/bords alpha 0, pas de
rectangle noir/blanc), centres opaques, `BoxFit.contain` côté Flutter.

Activation (faite) :
1. PNG déposés ici ;
2. `assets/branding/` déclaré dans `pubspec.yaml` ;
3. variantes mappées dans `brainBrandAsset()`
   (`lib/shared/widgets/brand.dart`) ;
4. repli wordmark + `errorBuilder` conservés si un chargement échoue.

Icône launcher générée (legacy : `brainwager_app_icon_source.png` ;
adaptatif : fond `#1E1B2E` + foreground `brainwager_mark.png`)
(`flutter_launcher_icons`, config `flutter_launcher_icons.yaml`).
Splash généré depuis `brainwager_splash_mark.png`
(`flutter_native_splash`, config `flutter_native_splash.yaml`).

Voir `docs/09-brand-and-polish.md` et `docs/10-final-brand-integration.md`.
