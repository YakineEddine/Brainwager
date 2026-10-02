# 02 — Modèle de données Supabase (Phase 0 révisée, implémentation Phase 2)

Conventions : `uuid` PK `gen_random_uuid()`, `timestamptz` UTC (`now()`),
contenus localisés FR / EN / AR (`*_fr`, `*_en`, `*_ar` selon les tables).
Tout en `public`. RLS activé partout.

## 1. Schéma (13 tables, dont google_play_purchases backend-only, migration 0013)

```text
profiles 1──* packs (owner)          packs 1──* questions 1──1 question_answers_private
packs 1──* questions                 games *──1 packs      games 1──* game_questions
games 1──* teams 1──* players         games 1──* players
players 1──* player_answers           players 1──* wagers
packs 1──* pack_reports               profiles 1──* entitlements
profiles 1──* google_play_purchases (★ SENSITIVE / backend-only, migration 0013)
```

### profiles — 1 ligne par user anon (sans aucun flag premium)
- `id uuid PK → auth.users.id`, `display_name text`, `locale text DEFAULT 'fr'
  CHECK IN ('fr','en','ar')` (arabe ajouté migration 0012),
  `created_at timestamptz`.
- RLS : `SELECT/UPDATE` uniquement `auth.uid() = id`. Aucun listing global.
- Justification : `is_premium` / `no_ads` modifiables par le client sont une faille.
  Les droits sont dans `entitlements`.

### entitlements — droits validés serveur uniquement (correction 1, autorité 0013)
- `id uuid PK`, `user_id uuid → profiles ON DELETE CASCADE`,
  `sku text NOT NULL` (ex. `pack_cinema_xxl`, `remove_ads`),
  `is_active bool DEFAULT true`, `verified_at timestamptz DEFAULT now()`,
  `UNIQUE(user_id, sku)`.
- RLS : `SELECT` own uniquement (`auth.uid() = user_id`). **Aucune policy INSERT/UPDATE/
  DELETE pour `anon`/`authenticated`.** Écriture réservée à `service_role`
  (server-write only), donc à l'Edge Function `verify-purchase` qui valide le purchase token
  auprès de l'API Google Play Developer puis applique via `apply_google_play_purchase`.
  `entitlements` reste SELECT-own only côté client.
- Restauration des achats : même Edge Function en mode `restore` (rejoue la
  validation des tokens connus / `queryPurchases` côté client puis vérif serveur).

### google_play_purchases — ★ SENSITIVE / backend-only (migration 0013)
- `purchase_token text PK` (globalement unique, protection anti-rejeu),
  `user_id uuid → profiles ON DELETE SET NULL` (peut devenir NULL si l'ancien
  profil anonyme disparaît), `sku text NOT NULL`, `order_id text NULL`,
  `obfuscated_account_id text NULL`, `purchase_state text NOT NULL
  CHECK IN ('PURCHASED','PENDING','CANCELLED')`,
  `acknowledgement_state text NOT NULL`, `consumption_state text NOT NULL`,
  `last_verified_at timestamptz DEFAULT now()`, `created_at`, `updated_at`.
- RLS activé avec **zéro policy client** et **zéro privilège `anon`/`authenticated`**
  (`REVOKE ALL ... FROM public, anon, authenticated`). Ledger privé illisible
  et inscriptible uniquement via `service_role`.
- `apply_google_play_purchase(...)` est service-only (`GRANT EXECUTE` à
  `service_role` uniquement, `REVOKE` pour `public`/`anon`/`authenticated`).
  Ce n'est PAS une RPC applicative : Flutter ne doit jamais l'invoquer directement.
  Seule l'Edge Function `verify-purchase` (autorité billing applicative unique)
  l'appelle après validation Google Play.
- Seuls les SKU premium officiels connus ou `remove_ads` sont acceptés
  (`billing-sku-not-allowed` sinon). Produits one-time NON-CONSUMABLE.
  En mode `verify`, un token déjà rattaché à un autre `user_id` est rejeté
  (`purchase-token-already-claimed`) : rejeu inter-profil bloqué.
- Entitlements accordées/révoquées atomiquement avec le ledger dans la même
  fonction. En `restore`, transfert possible du token/entitlement depuis un
  profil anonyme obsolète vers le profil courant ; l'ancien entitlement actif
  est désactivé uniquement si aucun autre token valide ne le soutient.

### Contrat sécurité billing (Flutter vs backend)
- Les purchase tokens Google Play sont backend-sensitive.
- Flutter ne doit JAMAIS : écrire `entitlements`, écrire `google_play_purchases`,
  invoquer `apply_google_play_purchase` directement, décider lui-même qu'un
  achat est valide, débloquer un pack depuis `PurchaseStatus` seul.
- Flutter peut uniquement : recevoir les données d'achat Play, envoyer
  `{sku, purchaseToken, mode}` à `verify-purchase`, puis lire ses propres
  `entitlements` après vérification serveur.
- L'Edge Function + `service_role` reste l'autorité.

### Restauration comptes anonymes (spécifique Brainwager)
- Les users sont actuellement anonymes. Une réinstallation peut produire un
  NOUVEAU UUID Supabase. Ne jamais supposer que l'identité anon survit à
  un uninstall.
- Nouvel achat : le client pose `obfuscatedExternalAccountId =
  SHA-256(UUID Supabase courant)` ; `mode=verify` vérifie l'égalité exacte.
- Restore : propriété/token Google Play re-vérifié côté serveur ; le backend
  peut transférer le token/entitlement de l'ancien profil anon obsolète vers
  le profil courant ; l'ancien entitlement actif est désactivé quand aucun
  autre token valide ne le soutient.

### packs — officiels + UGC (v1 sans image uploadée)
- `id uuid PK`, `owner_id uuid → profiles (NULL si officiel)`,
  `title_fr / title_en / title_ar text NOT NULL`,
  `desc_fr / desc_en / desc_ar text`,
  `is_official bool DEFAULT false`, `is_premium bool DEFAULT false`,
  `price_sku text NULL`, `share_code text UNIQUE`,
  `report_count int DEFAULT 0`, `is_hidden bool DEFAULT false`,
  `ugc_terms_accepted_at timestamptz NULL` (CGU UGC, horodatée serveur),
  `created_at`.
- RLS : lecture liste si `is_official AND NOT is_hidden` OU `owner_id = auth.uid()`.
  Partage par code via RPC `get_pack_by_share_code` (détail §2).
  **Écritures directes interdites** : aucune policy INSERT/UPDATE/DELETE pour
  `authenticated`, aucun droit table (migration 0011). Tout passe par les RPC
  `create_ugc_pack` / `update_ugc_pack` (CGU acceptées obligatoires).
- Invariants UGC (contraintes CHECK, officiels exemptés) : toujours
  non-officiel ET non-premium (`price_sku` NULL) ; code exactement `PK-XXXX`
  (`^PK-[A-Z0-9]{4}$`) ; CGU acceptées (`ugc_terms_accepted_at NOT NULL`).
  Les codes des packs officiels/historiques ne sont pas soumis au format
  `PK-XXXX` (contrainte UGC uniquement).
- UGC v1 : aucun upload d'image (`ugc-image-forbidden` côté serveur).
  Signalement via RPC `report_pack` (raison 3..500, pas d'auto-signalement,
  `report_count` incrémenté au premier signalement uniquement ; doublon =
  mise à jour du motif sans incrément). Aucun seuil automatique de
  masquage `is_hidden` pour l'instant (modération manuelle).

### questions — énoncés (SANS réponses, lecture restreinte anti-triche)
- `id uuid PK`, `pack_id uuid → packs ON DELETE CASCADE`,
  `idx int NOT NULL`, `prompt_fr / prompt_en / prompt_ar text NOT NULL`,
  `image_url text NULL` (officiels uniquement),
  `category text`, `difficulty smallint CHECK 1..3`,
  `match_mode text CHECK IN ('exact','fuzzy') DEFAULT 'fuzzy'`,
  `UNIQUE(pack_id, idx)`.
- RLS : `SELECT` direct restant pour l'éditeur de son propre pack
  (`packs.owner_id = auth.uid()`). **Aucune écriture directe** : INSERT/
  UPDATE/DELETE retirés (policies + droits, migration 0011). L'éditeur écrit
  transactionnellement via `create_ugc_pack` / `update_ugc_pack`
  (remplacement atomique validé : 11..100 questions, prompts 2..500,
  réponses 1..200, catégories ≤ 40, difficulté 1..3, alias ≤ 20 de ≤ 100
  caractères, nombres/années forcés `exact`).
  **Aucune lecture directe des questions d'un pack officiel
  ni des questions d'une partie en cours.** Consultation via :
  - `get_pack_preview(pack_id)` → 3 exemples d'un pack officiel (fiche pack limitée) ;
  - `get_current_question(game_id)` → question courante de la partie (voir §2).
  UGC v1 : `image_url` toujours NULL (rejet `ugc-image-forbidden`).
- Règle matching : `match_mode` par question. Nombres et années
  (regex `^-?\d+([.,]\d+)?$`, années 4 chiffres) imposent `exact` même si
  `match_mode = fuzzy` (vérifié en RPC et en Dart).

### question_answers_private — ★ SENSIBLE
- `question_id uuid PK → questions ON DELETE CASCADE`,
  `answer_main_fr / answer_main_en / answer_main_ar text NOT NULL`,
  `aliases_fr text[] DEFAULT '{}'`, `aliases_en text[] DEFAULT '{}'`,
  `aliases_ar text[] DEFAULT '{}'`.
- RLS : **aucune policy SELECT** pour `anon`/`authenticated`, aucun privilège
  table direct. Accès `service_role` + RPC `security definer` uniquement.
  Le propriétaire éditeur reçoit ses réponses uniquement via
  `get_ugc_pack_for_edit` (jamais en lecture directe).

### games — état synchronisé (+ langue)
- `id uuid PK`, `join_code text UNIQUE NOT NULL` (alphabet sans ambiguïté,
  génération en boucle), `host_id uuid → profiles`, `pack_id uuid → packs`,
  `language text DEFAULT 'fr' CHECK IN ('fr','en','ar')` (arabe : migration
  0012 ; `create_game(p_language = 'ar')` exige un contenu arabe complet du
  pack, sinon échec fermé `pack-language-unavailable`),
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
- RLS : lecture reporter + owner du pack (policies existantes). **Aucune
  écriture directe** : `INSERT` authentifié révoqué (migration 0011).
  Signalements uniquement via `report_pack(...)` : un par couple
  (pack, reporter) ; premier signalement incrémente `report_count`,
  doublon = motif/horodatage mis à jour sans incrément ; auto-signalement
  refusé (`cannot-report-own-pack`). Aucun seuil automatique
  `report_count → is_hidden` : modération manuelle / travail futur.

## 2. RPC `security definer`

| Fonction | Rôle | Vérifications serveur |
|---|---|---|
| `server_time()` | `now()` pour offset | aucune |
| `create_game(p_pack_id, p_team_mode, p_language)` | game + code + tirage `game_questions` + player hôte | pack visible / entitlement premium OK, pseudo validé serveur, code alloué sans course, finale tirée au hasard parmi les plus difficiles, 10 normales au hasard parmi le reste |
| `join_game(p_code, p_nickname, p_team_id?)` | ajoute player (reprise idempotente si déjà membre) | statut `lobby` pour les nouveaux, pseudo unique + filtre **serveur** (pas client-only), team existe, plafond 50 |
| `start_game()` / `open_question(p_idx)` | statut + `question_opened_at = now()` | hôte uniquement |
| `get_current_question(p_game)` | retourne position, prompt dans `games.language`, image, `match_mode`, `duration`, `opened_at` — sans réponses | membre uniquement ; question courante seulement |
| `get_pack_preview(p_pack)` | aperçu pack sans réponses | officiel → max 3 énoncés ; UGC du propriétaire → tous les énoncés + métadonnées ; champs arabes inclus partout ; jamais réponses/alias ; pack masqué refusé ; UGC non possédé refusé |
| `submit_answer(p_game, p_idx, p_text, p_wager)` | upsert answer + wager | statut open, timer OK, wager valide ; `wager-already-used` émis uniquement pour l'index unique normal (montants 1..10) |
| `lock_question(p_game)` | `open → locked` + correction auto, idempotente | hôte **ou tout membre si `now() >= opened_at + duration − 2 s`** ; rejouée sans effet |
| `reveal_answer(p_game)` | retourne réponse + transition `locked → reveal/final_reveal` | transition réservée à l'hôte ; lecture ensuite ouverte aux membres ; sinon exception |
| `show_leaderboard(p_game)` | `reveal → leaderboard` (questions normales), idempotente | hôte uniquement ; `position < 10` |
| `finish_game(p_game)` | `final_reveal → finished` (finale idx 10) | hôte uniquement |
| `override_answer(p_answer_id, p_correct)` | correction hôte puis `recompute_player_stats(player)` depuis tout l'historique | hôte, partie non `finished` ; recalcule `score`, `best_streak`, `biggest_wager_won` |
| `transfer_host(p_game, p_new_player?)` | change hôte, idempotent | hôte actuel **ou tout membre si hôte inactif (`last_seen_at < now() − 60 s`)** |
| `get_pack_by_share_code(code)` | lecture pack partagé + aperçu par code | officiel → max 3 exemples ; UGC partagé → tous les énoncés + métadonnées (champs arabes inclus), jamais réponses/alias ; respecte `is_hidden` ; `is_owned` + `question_count` inclus |
| `create_ugc_pack(...)` | crée pack UGC + questions + réponses privées, atomique | CGU obligatoires (`terms-required`), titres/desc bornés, code `PK-XXXX` sans course, 11..100 questions validées, retour `{id, share_code}` ; surcharge trilingue (migration 0012) : `p_title_ar`, `p_desc_ar`, questions avec `prompt_ar` / `answer_main_ar` / `aliases_ar`, contenu arabe valide exigé (anciennes surcharges FR/EN conservées pour compatibilité) |
| `update_ugc_pack(...)` | réécrit un pack UGC (titres + remplacement atomique) | owner non-officiel uniquement ; `pack-in-use` tant qu'UNE partie référence le pack ; surcharge trilingue : métadonnées arabes ; un vieux client ne peut pas effacer l'arabe d'un pack arabisé (`arabic-content-required`) ; paire `prompt_ar`/`answer_main_ar` incohérente → `invalid-arabic-content` |
| `get_ugc_pack_for_edit(...)` | pack UGC complet pour l'éditeur (seule voie vers ses réponses) | owner uniquement ; inclut réponses + alias, champs arabes inclus |
| `report_pack(...)` | signale un pack | raison 3..500, pas d'auto-signalement, `report_count` incrémenté au premier signalement seulement (doublon = motif mis à jour) ; aucun masquage automatique |
| `cleanup_old_games()` | delete `expires_at < now() − 7 j` | pg_cron 1×/jour |

Toutes : `SECURITY DEFINER`, `SET search_path = public`, `REVOKE` public + `GRANT`
ciblé, contrôle `auth.uid()` interne.

Edge Function `verify-purchase` (Deno, service_role, slug `verify-purchase`,
version 1, ACTIVE, `verify_jwt: true`) : seule autorité billing app-facing.
Utilisateurs authentifiés uniquement. Package Google Play :
`com.yakineeddine.brainwager`. Validation via
`purchases.productsv2.getproductpurchasev2`, tentative d'acknowledgement
serveur, fail-closed si credentials Google absents (secret
`GOOGLE_SERVICE_ACCOUNT_JSON` attendu, jamais commité).
Modes `verify` / `restore` / `sync` : `verify` exige que le SHA-256 du user id
Supabase égale `obfuscatedExternalAccountId` ; `restore` permet le transfert
de profil anonyme (token/entitlement déplacé, ancien entitlement désactivé
sans autre token valide) ; `sync` revalide les tokens stockés. `apply_google_play_purchase`
n'est PAS une RPC app : service-only, jamais invoquée par Flutter.

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
Arabe (serveur, migration 0012) : lettres arabes préservées, harakat retirés,
tatweel supprimé, variantes d'Alef normalisées, comportement final
Alef Maqsura/Ya selon SQL, chiffres arabo-indiens/persans vers ASCII,
séparateurs décimaux/milliers arabes normalisés, article défini ال normalisé ;
comportement FR/EN inchangé.
Si valeur numérique/année → `exact` forcé. Si `match_mode = exact` → égalité
normalisée (ou alias) uniquement, **aucune** tolérance Levenshtein.
Si `fuzzy` → égalité OU `levenshtein ≤ seuil` (1 si len ≤ 5, 2 si len ≤ 8, sinon 3).
Cas imposés refusés en exact : `Iran` vs `Irak`, `1984` vs `1985`
(tests Dart + SQL Phase 2, jeu de 50 paires FR/EN).

Pack démo DEMO01 : titre/description arabes + 11 énoncés arabes + 11 réponses
privées/alias arabes (migration 0012, backfill).

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
