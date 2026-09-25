# 02 — Modèle de données Supabase (Phase 0 révisée, implémentation Phase 2)

Conventions : `uuid` PK `gen_random_uuid()`, `timestamptz` UTC (`now()`),
textes FR/EN dupliqués (`*_fr`, `*_en`). Tout en `public`. RLS activé partout.

## 1. Schéma (11 tables)

```text
profiles 1──* packs (owner)          packs 1──* questions 1──1 question_answers_private
packs 1──* questions                 games *──1 packs      games 1──* game_questions
games 1──* teams 1──* players         games 1──* players
players 1──* player_answers           players 1──* wagers
packs 1──* pack_reports               profiles 1──* entitlements
```

### profiles — 1 ligne par user anon (sans aucun flag premium)
- `id uuid PK → auth.users.id`, `display_name text`, `locale text(2) DEFAULT 'fr'`,
  `created_at timestamptz`.
- RLS : `SELECT/UPDATE` uniquement `auth.uid() = id`. Aucun listing global.
- Justification : `is_premium` / `no_ads` modifiables par le client sont une faille.
  Les droits sont dans `entitlements`.

### entitlements — droits validés serveur uniquement (correction 1)
- `id uuid PK`, `user_id uuid → profiles ON DELETE CASCADE`,
  `sku text NOT NULL` (ex. `pack_cinema_xxl`, `remove_ads`),
  `is_active bool DEFAULT true`, `verified_at timestamptz DEFAULT now()`,
  `UNIQUE(user_id, sku)`.
- RLS : `SELECT` uniquement `auth.uid() = user_id`. **Aucune policy INSERT/UPDATE/
  DELETE pour `anon`/`authenticated`.** Écriture réservée à `service_role`,
  donc à l'Edge Function `verify-purchase` qui valide le purchase token
  auprès de l'API Google Play Developer puis upsert.
- Restauration des achats : même Edge Function en mode `restore` (rejoue la
  validation des tokens connus / `queryPurchases` côté client puis vérif serveur).

### packs — officiels + UGC (v1 sans image uploadée)
- `id uuid PK`, `owner_id uuid → profiles (NULL si officiel)`,
  `title_fr / title_en text NOT NULL`, `desc_fr / desc_en text`,
  `is_official bool DEFAULT false`, `is_premium bool DEFAULT false`,
  `price_sku text NULL`, `share_code text UNIQUE (6 chars)`,
  `report_count int DEFAULT 0`, `is_hidden bool DEFAULT false`,
  `created_at`.
- RLS : lecture liste si `is_official AND NOT is_hidden` OU `owner_id = auth.uid()`.
  Partage par code uniquement via RPC `get_pack_by_share_code`.
  `INSERT` authentifié, `UPDATE/DELETE` owner. CGU acceptées obligatoires à la création.
- UGC v1 : aucun upload d'image. `questions.image_url` reste `NULL` pour tout pack
  non officiel (contrainte en RPC d'édition). Signalement via `pack_reports` +
  blocage (`is_hidden` après seuil) + CGU.

### questions — énoncés (SANS réponses, lecture restreinte anti-triche)
- `id uuid PK`, `pack_id uuid → packs ON DELETE CASCADE`,
  `idx int NOT NULL`, `prompt_fr / prompt_en text NOT NULL`,
  `image_url text NULL` (officiels uniquement),
  `category text`, `difficulty smallint CHECK 1..3`,
  `match_mode text CHECK IN ('exact','fuzzy') DEFAULT 'fuzzy'`,
  `UNIQUE(pack_id, idx)`.
- RLS : `SELECT` direct uniquement si `packs.owner_id = auth.uid()` (édition de
  son propre pack). **Aucune lecture directe des questions d'un pack officiel
  ni des questions d'une partie en cours.** Consultation via :
  - `get_pack_preview(pack_id)` → 3 exemples d'un pack officiel (fiche pack limitée) ;
  - `get_current_question(game_id)` → question courante de la partie (voir §2).
- Règle matching : `match_mode` par question. Nombres et années
  (regex `^-?\d+([.,]\d+)?$`, années 4 chiffres) imposent `exact` même si
  `match_mode = fuzzy` (vérifié en RPC et en Dart).

### question_answers_private — ★ SENSIBLE
- `question_id uuid PK → questions ON DELETE CASCADE`,
  `answer_main_fr / answer_main_en text NOT NULL`,
  `aliases_fr text[] DEFAULT '{}'`, `aliases_en text[] DEFAULT '{}'`.
- RLS : **aucune policy SELECT** pour `anon`/`authenticated`. Accès `service_role`
  + RPC `security definer` uniquement.

### games — état synchronisé (+ langue)
- `id uuid PK`, `join_code text UNIQUE NOT NULL` (alphabet sans ambiguïté,
  génération en boucle), `host_id uuid → profiles`, `pack_id uuid → packs`,
  `language text(2) DEFAULT 'fr' CHECK IN ('fr','en')`,
  `status text CHECK IN ('lobby','question_open','question_locked','reveal',
  'leaderboard','final_wager','final_reveal','finished') DEFAULT 'lobby'`,
  `team_mode bool DEFAULT false`, `current_question_idx int DEFAULT 0`,
  `question_opened_at timestamptz NULL`, `question_duration_sec int DEFAULT 30`,
  `created_at`, `expires_at timestamptz DEFAULT now() + interval '24 hours'`.
- RLS : `SELECT` si membre (`EXISTS players`). `INSERT` authentifié.
  `UPDATE` direct refusé (`USING (false)`) ; mutations via RPC.

### game_questions — tirage de la partie (correction 2)
- `game_id uuid → games ON DELETE CASCADE`, `position int CHECK 0..10`,
  `question_id uuid → questions`, `UNIQUE(game_id, position)`,
  `UNIQUE(game_id, question_id)`, PK `(game_id, position)`.
- RLS : **aucune policy SELECT** pour `anon`/`authenticated` (questions à venir
  illisibles). Lecture via `get_current_question` uniquement.
- Remplissage à `create_game` par sélection serveur (miroir de la fonction pure
  Dart `selectGameQuestions`) : 10 questions normales + 1 finale, sans doublon,
  finale choisie parmi les plus difficiles (`difficulty = max`, `match_mode`
  conservé).

### teams
- `id uuid PK`, `game_id uuid → games ON DELETE CASCADE`, `name text`,
  `color_idx int`, `UNIQUE(game_id, name)`.
- RLS : lecture si membre ; écriture via RPC hôte.

### players
- `id uuid PK`, `game_id uuid → games ON DELETE CASCADE`,
  `user_id uuid → profiles`, `nickname text NOT NULL`,
  `team_id uuid NULL → teams`, `score int DEFAULT 0`,
  `best_streak int DEFAULT 0`, `biggest_wager_won int DEFAULT 0`,
  `is_host bool DEFAULT false`, `is_connected bool DEFAULT true`,
  `last_seen_at timestamptz DEFAULT now()`,
  `UNIQUE(game_id, nickname)`, `UNIQUE(game_id, user_id)`.
- RLS : lecture si même partie ; `INSERT` via `join_game` ; `UPDATE` soi-même
  (`team_id`, `is_connected`) ou hôte via RPC.

### player_answers
- `id uuid PK`, `game_id uuid`, `player_id uuid → players ON DELETE CASCADE`,
  `question_idx int`, `answer_text text NOT NULL`,
  `is_correct bool NULL`, `is_overridden bool DEFAULT false`,
  `scored_points int DEFAULT 0`, `created_at`,
  `UNIQUE(game_id, player_id, question_idx)`.
- RLS : lecture de ses propres lignes + toutes après verrouillage
  (`games.status IN ('reveal','leaderboard','final_reveal','finished')`).
  Écriture via `submit_answer` uniquement.

### wagers — RLS verrouillée jusqu'au lock (correction 3)
- `id uuid PK`, `game_id uuid`, `player_id uuid → players ON DELETE CASCADE`,
  `question_idx int`, `amount int NOT NULL`,
  `UNIQUE(game_id, player_id, question_idx)`,
  `CHECK ((question_idx < 10 AND amount BETWEEN 1 AND 10) OR
          (question_idx = 10 AND amount IN (0,10,20)))`,
  `UNIQUE(game_id, player_id, amount)` partielle `WHERE question_idx < 10`.
- RLS : `SELECT` de ses propres mises + toutes les mises **seulement après
  verrouillage** (même condition que `player_answers`). Mises des autres
  invisibles pendant `question_open` / `final_wager`. Écriture via `submit_answer`.

### pack_reports
- `id uuid PK`, `pack_id uuid → packs`, `reporter_id uuid`, `reason text`,
  `created_at`, `UNIQUE(pack_id, reporter_id)`.
- RLS : `INSERT` authentifié, lecture owner + service. Seuil → `is_hidden = true`.

## 2. RPC `security definer`

| Fonction | Rôle | Vérifications serveur |
|---|---|---|
| `server_time()` | `now()` pour offset | aucune |
| `create_game(p_pack_id, p_team_mode, p_language)` | game + code + tirage `game_questions` + player hôte | pack visible / entitlement premium OK, remplit 11 lignes sans doublon |
| `join_game(p_code, p_nickname, p_team_id?)` | ajoute player | statut `lobby`, pseudo unique + filtre, team existe |
| `start_game()` / `open_question(p_idx)` | statut + `question_opened_at = now()` | hôte uniquement |
| `get_current_question(p_game)` | retourne position, prompt dans `games.language`, image, `match_mode`, `duration`, `opened_at` — sans réponses | membre uniquement ; question courante seulement |
| `get_pack_preview(p_pack)` | 3 exemples d'un pack officiel | respecte `is_hidden` ; jamais la liste complète |
| `submit_answer(p_game, p_idx, p_text, p_wager)` | upsert answer + wager | statut open, timer OK, wager valide (contraintes tranchent) |
| `lock_question(p_game)` | `open → locked` + correction auto, idempotente | hôte **ou tout membre si `now() >= opened_at + duration − 2 s`** ; rejouée sans effet |
| `reveal_answer(p_game)` | retourne réponse + transition `locked → reveal/final_reveal` | transition réservée à l'hôte ; lecture ensuite ouverte aux membres ; sinon exception |
| `show_leaderboard(p_game)` | `reveal → leaderboard` (questions normales), idempotente | hôte uniquement ; `position < 10` |
| `finish_game(p_game)` | `final_reveal → finished` (finale idx 10) | hôte uniquement |
| `override_answer(p_answer_id, p_correct)` | correction hôte puis `recompute_player_stats(player)` depuis tout l'historique | hôte, partie non `finished` ; recalcule `score`, `best_streak`, `biggest_wager_won` |
| `transfer_host(p_game, p_new_player?)` | change hôte, idempotent | hôte actuel **ou tout membre si hôte inactif (`last_seen_at < now() − 60 s`)** |
| `get_pack_by_share_code(code)` | lecture pack partagé | respecte `is_hidden` |
| `cleanup_old_games()` | delete `expires_at < now() − 7 j` | pg_cron 1×/jour |

Toutes : `SECURITY DEFINER`, `SET search_path = public`, `REVOKE` public + `GRANT`
ciblé, contrôle `auth.uid()` interne.

Edge Function `verify-purchase` (Deno, service_role) : reçoit `{sku, purchaseToken}`,
valide auprès de Google Play Developer API, upsert `entitlements`, retourne droits.
Mode `restore` : revalide et réactive.

## 3. Realtime (sans tick)

- **Postgres Changes** : `games:id=eq.{id}`, `players`, `player_answers`, `wagers`,
  `teams` filtrés `game_id=eq.{id}`.
- **Broadcast** `game:{id}` ponctuel : `opened {idx, server_ts, duration}`,
  `locked`, `revealed {answer}`, `scores {deltas}`. Aucun périodique.
- **Presence** `presence:game:{id}` : `{player_id, nickname, is_host, online_at}`,
  heartbeat 15 s. Pas d'UPDATE par seconde (quota).
- **Compte à rebours** : 100 % client depuis `question_opened_at + offset`.

## 4. Correction auto (miroir Dart ↔ SQL, avec match_mode)

Normalisation : minuscules, accents, ponctuation, articles initiaux, espaces, trim.
Si valeur numérique/année → `exact` forcé. Si `match_mode = exact` → égalité
normalisée (ou alias) uniquement, **aucune** tolérance Levenshtein.
Si `fuzzy` → égalité OU `levenshtein ≤ seuil` (1 si len ≤ 5, 2 si len ≤ 8, sinon 3).
Cas imposés refusés en exact : `Iran` vs `Irak`, `1984` vs `1985`
(tests Dart + SQL Phase 2, jeu de 50 paires FR/EN).

## 5. Nettoyage plan gratuit

`pg_cron` quotidien `cleanup_old_games()`. `expires_at` 24 h, prolongé à chaque
`open_question`. Profils anon conservés.

## 6. Tests RLS/RPC Phase 2 (checklist)

1. `SELECT question_answers_private` / `game_questions` direct → refusé.
2. `get_current_question` OK membre, refusé non-membre ; ne renvoie jamais les réponses.
3. `reveal_answer` avant lock → exception ; après → réponse.
4. `wagers` des autres invisibles en `question_open`, visibles en `reveal`.
5. Double mise `7` → violation unique partielle ; finale `15` → CHECK.
6. `lock_question` par non-hôte avant expiration → refusé ; après expiration − 2 s → OK,
   rejouée → sans effet.
7. `open_question` non-hôte → exception ; `transfer_host` par membre après 60 s
   d'inactivité hôte → OK.
8. Preview officielle → exactement 3 exemples.
9. Reconnect : Presence + rattrapage `SELECT` état.
