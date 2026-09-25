# 04 — Config règles + Plan de tâches Phase 1→6 (Phase 0 révisée)

## 1. Fichier de config (créé en Phase 1 : `lib/core/config/game_config.dart`)

```dart
// Toutes les règles modifiables sans toucher au moteur.
enum TeamScoringMode { sum, average }

class FuzzyThresholds {
  final int tiny; final int short; final int long;
  const FuzzyThresholds({this.tiny = 1, this.short = 2, this.long = 3});
}

class GameConfig {
  final int totalQuestions = 11;
  final int finalQuestionIndex = 10;      // 0-based
  final List<int> normalWagers = const [1,2,3,4,5,6,7,8,9,10];
  final List<int> finalWagers = const [0, 10, 20];
  final int defaultDurationSec = 30;
  final int lockGraceSec = 2;             // lock autorisé dès duration − 2 s
  final int hostTimeoutSec = 60;          // transfert réclamable après 60 s
  final int minPlayers = 2;               // 1 admis en test solo
  final int maxPlayers = 50;
  final bool allowNegativeFinal = true;
  final int joinCodeLength = 5;
  final int serverOffsetSamples = 3;
  final int packPreviewCount = 3;         // fiche officielle : 3 exemples
  final TeamScoringMode teamScoring = TeamScoringMode.average; // moyenne par défaut
  final FuzzyThresholds fuzzy = const FuzzyThresholds();
}
```

Tout écart en test passe par `copyWith`, jamais en dur dans l'UI.

Fonction pure de sélection (Phase 1, `question_selector.dart`) :
`selectGameQuestions(pool, {finalCount = 1})` → 10 normales + 1 finale,
sans doublon, finale parmi les plus difficiles (`difficulty` max du pack).
Testée en unitaire (unicité, taille pool insuffisante → erreur explicite,
finale bien de difficulté max).

## 2. Plan de tâches

### Phase 1 — Projet + thème + i18n + moteur pur + tests
Livrables : `flutter create --org com.yakineeddine brainwager` (targetSdk 36,
compileSdk 36, minSdk 24), `go_router`, thème dark, `app_fr/en.arb`,
`features/game_engine/` (validator, scoring + `recomputePlayerStats`,
matcher avec `match_mode`, selector 10+1, team scoring somme/moyenne, FSM),
`test/game_engine/*_test.dart` verts dont cas imposés `Iran/Irak` et
`1984/1985` refusés en exact, logo SVG v1, `analysis_options` strict.
Actions TOI : installer Flutter stable + Android Studio + 1 émulateur API 36.
Aucune clé. Test : `flutter analyze && flutter test`.

### Phase 2 — Supabase temps réel
Livrables : migrations (11 tables dont `entitlements`, `game_questions`),
RLS + RPC (§doc 02) + Edge Function `verify-purchase`, `realtime_service`
(sans tick), create/join/lobby/question/reveal via 2 émulateurs, offset horloge,
lock par tout membre après expiration, `transfer_host` après timeout.
Actions TOI : créer projet EU, coller migrations, activer Anonymous sign-ins,
renseigner `--dart-define SUPABASE_URL/ANON_KEY`, créer la function,
me renvoyer les logs RLS.
Test : checklist §6 doc 02 (réponses et futures questions illisibles,
mises invisibles avant lock, preview = 3, lock/transfer idempotents).

### Phase 3 — Packs + contenu original + éditeur
Livrables : 5 packs × 30 Q FR+EN avec alias et `match_mode` (formulations
originales maison), preview 3 pour officiels, éditeur UGC v1 **sans image** +
CGU + partage `PK-XXXX` + deep link + signalement/blocage.
Actions TOI : relire 10 questions si tu veux un pack perso.
Test : créer pack → share code → import sur 2ᵉ appareil.

### Phase 4 — Équipes, TV, correction manuelle, podium
Livrables : `team_mode` avec scoring somme/moyenne (moyenne défaut),
`/tv` XXL + QR, override hôte via `recompute_player_stats` + recalcul live,
podium + stats fun, polish (confettis, CountdownRing local, sons).
Test : partie à 4 (2 équipes), override → scores/streaks recalculés.

### Phase 5 — Monétisation + crashs
Livrables : AdMob (bannière hors jeu, interstitiel après podium, rewarded 24 h),
UMP RGPD, `in_app_purchase` (`pack_*`, `remove_ads`) validé par Edge Function
+ écran restauration, Sentry optionnel.
Actions TOI : créer IDs AdMob, produits Play, ID UMP.
Test : IDs test en debug, `android.test.purchased` en internal track,
restauration OK, `entitlements` bien alimentée (aucun flag client).

### Phase 6 — Play Store
Livrables : AAB signé (`key.properties` hors git), politique modèle, Data Safety,
descriptions ASO FR/EN, 8 captures, checklist (content rating, **targetSdk 36**,
compileSdk 36, 64-bit, debug off).
Actions TOI : compte dev, fiche, upload AAB, questionnaire.
Test : `flutter build appbundle --release`.

## 3. Ordre + estimations (solo, temps partiel)

P0 plan révisé (aujourd'hui) → P1 ~1 sem → P2 ~2 sem → P3 ~2 sem →
P4 ~1–2 sem → P5 ~1 sem → P6 ~1 sem. Total ~8–10 semaines avant internal track.

## 4. Étape immédiate

Corrections intégrées ci-dessus. Phase 1 démarrée ci-dessous dans ce même message.
