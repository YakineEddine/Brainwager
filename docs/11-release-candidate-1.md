# 11 — Release Candidate 1 (ticket chore/release-candidate-1)

Base : `main` @ `4f2045a` (final branding). AUCUNE action Play Console.
Version bump revue dans un ticket release séparé : pas de bump ici.

## 1. Version

`pubspec.yaml` : `version: 0.1.0+2` (modifié, seul changement de version).
`versionName = 0.1.0`, `versionCode = 2` (dérivés Flutter du `+2`,
build release réussi donc versionCode numérique valide).
`applicationId` : `com.yakineeddine.brainwager` (inchangé).

## 2. Preflight Android

- `namespace` : `com.yakineeddine.brainwager`.
- `minSdk 24`, `targetSdk 36`, `compileSdk 36`.
- Release signing : `signingConfigs.release` via `android/key.properties`
  local, `signingConfig = signingConfigs.getByName("release")`,
  échec fermé (`GradleException` explicite) si clé absente/incomplète,
  aucun repli debug. Mots de passe ni lus ni imprimés ici.

## 3. Branding

5 assets finaux intégrés et testés (mappings `brainBrandAsset`,
launcher legacy + adaptatif mark transparent sur `#1E1B2E`,
splash `#1E1B2E` + sigle, Android 12+ inclus). Voir `docs/10`.

## 4. Backend inchangé

- Migration 0013 : `933cde159d985efba5f6e49745df9534a12a1785`.
- `verify-purchase` v3 : `f93cb487fee38e7b70c8cd672cce7bd896c409bf`.
- Aucune migration, RPC, RLS, Edge, secret, ni action distante.

## 5. Qualité

- `flutter analyze` : aucun problème.
- `flutter test` : 372 passed, 0 failed.
- `git diff --check` : propre (bruit formateur/generated reverti).

## 6. AAB signé

- Commande : `flutter build appbundle --release` avec
  `SUPABASE_URL=https://nqveyhdzyurqrqgrrfbn.supabase.co` et la publishable
  key de production (dart-define, non commitées).
- Résultat : build réussi, signature release locale (fail-closed aurait
  échoué sinon ; aucun fallback debug n'existe).
- Fichier : `build/app/outputs/bundle/release/app-release.aab`
  (62 925 897 octets, construit le 2026-10-04 12:48:07, ignoré par Git).
- `versionCode=2`, `versionName=0.1.0` (config `0.1.0+2`).
- NON uploadé (aucune action Play Console dans ce ticket).

## 7. Bloqueurs externes restants (avant test d'achat réel)

- Upload Play Console non effectué.
- Secret `GOOGLE_SERVICE_ACCOUNT_JSON` toujours externe/manuel.
- Produits Play non configurés ; validation d'achat réelle en attente.
- 5 packs de production requis.
