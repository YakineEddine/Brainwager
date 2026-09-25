# 03 — Écrans, navigation, design Brainwager (Phase 0 révisée)

## 1. Identité visuelle originale (à créer Phase 1/4, rien de copié)

- **Mascotte** : cerveau rond souriant tenant un jeton de casino (vectoriel maison,
  SVG). Déclinaisons : content / stressé (timer) / fête (podium).
- **Motif récurrent** : jetons de mise (1, 5, 10, 20) repris dans `WagerChips`.
- **Palette** (dark-first) :
  - `violet électrique #7C3AED` (primaire), `violet profond #1E1B2E` (fond),
  - `jaune or #FFC93C` (mises, accents), `turquoise #2DD4BF` (succès),
  - `corail #FF6B6B` (erreurs), texte `#FFFFFF / #B8B3CC`.
  - Contraste ≥ 4.5:1, boutons ≥ 56 dp, typo Nunito (OFL) ou système.
- **Sons** : bips synthétisés (compte à rebours, révélation, victoire), toggle global.
- **Logo/icône** : SVG maison, adaptive icon Android (targetSdk 36).

## 2. Liste des écrans (17)

| # | Route | Écran | Acteurs | Contenu / règles UI |
|---|---|---|---|---|
| 1 | `/` | Splash | tous | Logo animé, init Supabase/UMP, redirect home |
| 2 | `/home` | Accueil | tous | Créer / Rejoindre / Packs / Boutique. Bannière AdMob ici OK |
| 3 | `/create` | Créer partie | hôte | Choix pack, individuel/équipes, langue FR/EN de la partie, durée timer, Créer → code 4–6 |
| 4 | `/join` | Rejoindre | joueur | Code + pseudo (filtre gros mots inline), équipe si team_mode |
| 5 | `/lobby/:code` | Lobby | tous | Liste joueurs (Presence : pastille verte), équipe, hôte lance. Partage code/lien |
| 6 | `/game/:id/question` | Question joueur | joueur | Énoncé courant via `get_current_question`, champ réponse libre, `WagerChips` (restantes grisées), anneau timer calculé en local depuis `opened_at + offset` |
| 7 | `/game/:id/host` | Contrôles hôte | hôte | Question suivante, verrouiller, révéler, override Correct/Incorrect, exclure, transfert hôte |
| 8 | `/game/:id/reveal` | Révélation | tous | Bonne réponse, gains/pertes animés. Jamais de pub ici |
| 9 | `/game/:id/board` | Classement inter | tous | Liste animée, streak, gros pari |
| 10 | `/game/:id/final` | Finale Q11 | joueur | Mise 0/10/20, rappel score, confirmation explicite du risque négatif |
| 11 | `/game/:id/podium` | Podium | tous | Top 3 + confettis + stats (série, gros pari, comeback). Rejouer → interstitiel ici OK |
| 12 | `/packs` | Packs | tous | Gratuits / premium (cadenas + prix via `entitlements`), recherche, signaler/bloquer |
| 13 | `/packs/:id` | Détail pack | tous | Pack officiel : **3 exemples uniquement**. Pack UGC : énoncés complets si owner ou code. Acheter / rewarded ad 24 h |
| 14 | `/packs/edit/:id?` | Éditeur | créateur | Titre FR/EN, questions, alias, `match_mode`, difficulté. UGC v1 : **aucun upload d'image**. Case CGU obligatoire, partage via code/lien |
| 15 | `/game/:id/tv` | Mode écran TV | hôte | Question + classement XXL, QR du code, masque les réponses avant reveal |
| 16 | `/shop` | Boutique | tous | Packs premium, `remove_ads`. Lit `entitlements`, propose restauration des achats. Bannière OK |
| 17 | `/settings` | Réglages | tous | Langue FR/EN, son, pseudo, confidentialité, CGU, crédits, version |

Deep links : `brainwager://join/ABC12` et `brainwager://pack/PK-XXXX` (go_router +
`app_links` en Phase 3).

## 3. Navigation (go_router)

```text
/ → /home → /create → /lobby/:code → /game/:id/{question,host,reveal,board,final,podium,tv}
/home → /join → /lobby/:code → …
/home → /packs → /packs/:id → /packs/edit/:id?
/home → /shop, /settings
```

Guards : si `status != lobby`, `/join` redirige vers l'état courant ; retour Android
bloqué pendant `question_open` (dialog abandon) ; hôte qui quitte → `transfer_host()`
avant `pop`. Verrouillage possible par tout membre après expiration (même RPC).

## 4. Composants partagés (`shared/widgets`)

`TokenButton`, `WagerChips` (1–10 + restantes, 0/10/20 en finale),
`CountdownRing` (calcul local `opened_at + duration − now`, rouge + vibration en fin),
`AnswerField` (clavier standard, autocapitalize désactivé),
`ScoreBar`, `PlayerRow` (presence + streak), `EmptyState`,
`AdBannerSlot` (jamais en game).

## 5. Règles AdMob (détail Phase 5)

Bannière : home, packs, shop, settings uniquement. Interstitiel : après podium.
Rewarded : débloquer 1 pack 24 h. UMP avant première pub (UE).
`remove_ads` (via `entitlements`) supprime bannières + interstitiels.
