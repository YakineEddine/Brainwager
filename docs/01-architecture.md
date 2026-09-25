# 01 — Architecture Brainwager (Phase 0 révisée)

## 1. Objectifs architecturaux

1. **Moteur de jeu 100 % testable sans réseau** : règles, mises, scoring, fuzzy matching,
   sélection des 11 questions, score équipe, recalcul stats en pur Dart
   (`features/game_engine/`), couvert par tests unitaires.
2. **Temps réel fiable à dizaines de joueurs** sur Supabase plan gratuit :
   Postgres Changes pour l'état durable, Broadcast pour les événements ponctuels,
   Presence pour la connexion. Pas de logique d'autorité côté client.
3. **Anti-triche par construction** : bonnes réponses ET questions à venir jamais
   lisibles par les joueurs (RLS). Seules des RPC `security definer`
   (`get_current_question`, `reveal_answer`) exposent le nécessaire au bon moment.
4. **i18n FR/EN dès le départ**, mode sombre, gros boutons, 60 fps sur entrée de gamme.
5. **Monétisation non intrusive et sécurisée** : jamais de pub pendant une question ;
   droits premium jamais modifiables par le client (table `entitlements` + Edge Function).
6. **Compte à rebours sans broadcast périodique** : calculé côté client depuis
   `question_opened_at + offset serveur`. Aucun `tick`.

## 2. Stack figée (vérifiée Phase 1)

| Couche | Choix | Pourquoi |
|---|---|---|
| Flutter | stable 3.47.3 constaté / Dart associé, `minSdk 24`, `targetSdk 36`, `compileSdk 36`, Java 17 | Exigence Play : nouvelles apps = API 36 (Android 16) depuis 31/08/2026. AAB requis |
| État | `flutter_riverpod` 2.x (`Notifier`/`AsyncNotifier`, sans code-gen en Phase 1) | Simple, testable |
| Navigation | `go_router` | Deep links `brainwager://join/ABC12` pour partage parties/packs |
| i18n | `flutter_localizations` + `gen-l10n` (ARB `app_fr.arb` / `app_en.arb`) | Officiel, sans dépendance tierce |
| Backend | `supabase_flutter` 2.x | Auth anonyme + Postgres + Realtime |
| Ads | `google_mobile_ads` + `user_messaging_platform` (UMP RGPD) | AdMob + consentement UE |
| Billing | `in_app_purchase` + Edge Function `verify-purchase` + table `entitlements` | Validation serveur du purchase token Play, restauration incluse |
| Crashs | `sentry_flutter` (désactivable) ou Play Console seule | Aucun Firebase |
| Anim | `confetti`, `flutter_animate` | Podium, classements, compte à rebours |
| Son | `audioplayers` (sons synthétisés maison, toggle) | Zéro asset copié |
| Tests | `flutter_test`, `mocktail` | Moteur pur mocké facilement |

Décision senior : **pas de code-gen Riverpod / Freezed en Phase 1**. Ajout en
Phase 4 seulement si les modèles deviennent lourds.

Sécurité achats (correction 1) : `profiles` ne contient AUCUN flag premium.
`entitlements(user_id, sku, is_active, verified_at)` n'a aucune policy
INSERT/UPDATE pour `authenticated`. Seule l'Edge Function (service_role) écrit
après validation du purchase token auprès de l'API Google Play Developer.
Restauration = même fonction en mode `restore`.

## 3. Structure dossiers (feature-first)

```text
brainwager/
  android/                      # applicationId com.yakineeddine.brainwager, targetSdk 36
  lib/
    main.dart
    app/
      router.dart
      theme.dart
      l10n/                     # app_fr.arb, app_en.arb
    core/
      config/
        game_config.dart        # voir doc 04 (team scoring, lock grace, match_mode…)
      network/
        supabase_client.dart
        realtime_service.dart   # Changes + Broadcast ponctuels + Presence (sans tick)
      utils/
        clock.dart
        profanity_filter.dart
        logger.dart
    features/
      game_engine/              # ★ PUR DART, zéro import Flutter/Supabase
        models.dart             # Question(match_mode), Wager, PlayerScore, GameState
        wager_validator.dart
        scoring.dart            # scoring + recompute_player_stats (source de vérité)
        answer_matcher.dart     # normalisation + Levenshtein + match_mode exact/fuzzy
        question_selector.dart  # 10 normales + 1 finale, sans doublon, finale difficile
        team_scoring.dart       # somme | moyenne (moyenne par défaut)
        game_fsm.dart
      lobby/
      game_session/
      teams/
      host_screen/
      packs/                    # UGC v1 : sans upload d'image
      shop/                     # lit entitlements, jamais de flag local
      settings/
    shared/
      widgets/                  # WagerChips, CountdownRing (client-side), ScoreBar…
  test/
    game_engine/
  supabase/
    migrations/
    functions/verify-purchase/  # Edge Function validation Play
    tests/
  docs/
```

Règles d'import : `features/*` ne s'importent jamais entre elles sauf via `core` ou
`app/router`. `game_engine` n'importe rien de `core/network`.

## 4. Flux temps réel (détail doc 02)

- **Durable** (Postgres Changes) : `games`, `players`, `player_answers`, `wagers`,
  `teams`, `game_questions` (lecture directe refusée, voir doc 02).
- **Éphémère** (Broadcast canal `game:{id}`, ponctuel uniquement) : `opened`,
  `locked`, `revealed`, `scores`. Aucun événement périodique.
- **Presence** (`presence:game:{id}`) : qui est en ligne, hôte, déconnexion.
- **Timer** : `games.question_opened_at = now()` serveur. Client :
  `restant = opened_at + duration − (now_local + offset)`. Offset via RPC
  `server_time()` (moyenne de 3 appels). Verrouillage faisant foi =
  RPC `lock_question()` idempotente (tout membre après expiration + grâce 2 s).

## 5. Stratégie de tests

- Phase 1 (pur Dart) : mises, scoring finale négative, `recompute_player_stats`
  depuis historique (pas d'incrémental), normalisation FR, Levenshtein,
  `match_mode` exact vs fuzzy avec cas imposés `Iran/Irak` et `1984/1985` refusés
  en exact, sélecteur 10+1 sans doublon avec finale difficile, team somme/moyenne,
  FSM transitions illégales rejetées.
- Phase 2 (SQL) : `SELECT` réponses privées refusé, `get_current_question` seule
  voie, mises des autres invisibles avant lock, double mise rejetée, lock par
  non-hôte après expiration OK / avant refusé, `transfer_host` par membre après
  timeout hôte OK.
- Phase 4+ : widget tests `WagerChips`, `CountdownRing`.
- Aucun test Firebase.

## 6. Risques plan gratuit + parades

| Risque | Parade |
|---|---|
| Quota Realtime | 1 canal Broadcast + 1 Changes par partie, zéro tick, nettoyage `expires_at` + pg_cron |
| Horloges divergentes | Offset mesuré, autorité serveur, client indicatif uniquement |
| Triche | Aucune lecture directe réponses ni questions futures ; RPC seules ; preview officielle limitée à 3 |
| Pseudos / UGC toxiques | Filtre embarqué, signalement + blocage + CGU, exclusion par hôte, pas d'image UGC en v1 |
| Taille AAB | SVG + sons synthétisés, targetSdk 36 testé sur émulateur API 36 |

## 7. Livraison Phase 1

Projet Flutter + thème + router + i18n FR/EN + `game_engine` pur + tests verts.
Aucun appel Supabase en Phase 1. Cela verrouille les règles avant le réseau.
