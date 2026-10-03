# 06 — Signature release Android / Play (clé d'upload locale)

Package production : `com.yakineeddine.brainwager` (inchangé).
Le build release est signé par la config `release` (`android/app/build.gradle.kts`),
alimentée par le fichier local `android/key.properties` (jamais commité).
Aucun repli vers la clé debug : sans `key.properties` complet, tout
`assembleRelease` / `bundleRelease` échoue avec une erreur Gradle explicite
(fail-closed). Les builds debug/profile restent utilisables sans clé.

## 1. Créer la clé d'upload (humain uniquement, une fois)

Ne pas automatiser : l'humain choisit les mots de passe.

```sh
keytool -genkeypair \
  -v \
  -keystore android/app/upload-keystore.jks \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias upload
```

## 2. Créer android/key.properties (local, jamais commité)

Copier `android/key.properties.example` vers `android/key.properties`
(non suivi par Git) et y mettre les vraies valeurs :

```properties
storePassword=<mot-de-passe-keystore>
keyPassword=<mot-de-passe-clé>
keyAlias=upload
storeFile=upload-keystore.jks
```

## 3. Règles de sécurité

- Ne jamais commiter : `upload-keystore.jks`, `*.jks`, `*.keystore`,
  `android/key.properties`, mots de passe, credentials Play, JSON de
  compte de service Google.
- Sauvegarder hors Git (gestionnaire de mots de passe + copie chiffrée) :
  `android/app/upload-keystore.jks` + les deux mots de passe. Une perte de
  la clé d'upload impose une rotation côté Play Console.
- Play App Signing gère la clé de signature applicative ; cette clé locale
  est uniquement la clé d'upload.

## 4. Vérifier sans builder de release

La clé privée n'est volontairement pas présente dans le dépôt : ne pas
lancer de build release en CI/revue. Vérifications attendues :

- `flutter analyze`, `flutter test`, `git diff --check` verts.
- Aucune occurrence de `signingConfigs.getByName("debug")` pour le release
  dans `android/app/build.gradle.kts`.
- `.gitignore` couvre toujours `android/key.properties`,
  `android/app/*.jks`, `android/app/*.keystore`.
