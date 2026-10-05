# 13 — Compte social + avatar + onboarding (ticket social-auth-avatar)

Backend 0014 LIVE et immuable : aucune migration, aucune RLS/RPC modifiée.
Flutter seul + manifest Android. Zéro secret, zéro SDK natif.

## 1. Bootstrap anonyme préservé

Le démarrage restaure/crée toujours une session Supabase anonyme
(`initSupabase` inchangé). Les UUID existants (historique parties/packs)
ne sont jamais remplacés silencieusement.

## 2. Link vs sign-in (deux intents distincts)

- Sécuriser l'invité courant (UUID préservé) : `linkIdentity`
  - Google : `supa().auth.linkIdentity(OAuthProvider.google, redirectTo: brainwagerAuthCallback)`
  - Facebook : `supa().auth.linkIdentity(OAuthProvider.facebook, redirectTo: brainwagerAuthCallback)`
- Déjà un compte (autre appareil) : `signInWithOAuth`
  - Google/Facebook avec le même `redirectTo`.
  - Avertissement UI : ouvre le compte existant au lieu de l'invité.

Jamais de choix silencieux : le bouton "sécuriser" ne fait que du link,
la section "déjà un compte" ne fait que du sign-in. Les tests verrouillent
les compteurs d'appels (A–E).

Le retour booléen = navigateur ouvert, PAS authentifié. Le succès réel
vient de `auth.onAuthStateChange` → recharge autoritative profil/avatars/
identités. Un seul abonnement, dispose sûr, aucun poll.

## 3. Callback auth

Constante unique : `brainwagerAuthCallback = 'brainwager://auth-callback'`.

Android : troisième intent-filter isolé (`scheme=brainwager`,
`host=auth-callback`), sans toucher pack/join, sans `autoVerify="true"`.
`DeepLinkService`/`parseBrainwagerLink` ignorent cet hôte (null, jamais
routé jeu/pack). Supabase Auth traite la session.

## 4. Autorité serveur (RPC 0014 uniquement)

- `loadProfile()` → `rpc get_my_profile`
- `loadAvatars()` → `rpc list_my_avatars`
- `saveProfile()` → `rpc update_my_profile` (params exacts
  `p_display_name` / `p_avatar_key` / `p_locale`)

Aucun UPDATE direct, aucun SELECT sur `avatar_catalog` /
`user_avatar_unlocks`. Échec save = pas de profil optimiste, gate fermée.

## 5. Avatars : les 8 clés live

`brain, rocket, star, bolt, planet, trophy, football, basketball`
(seed 0014). La disponibilité vient du serveur (`unlocked`) ; l'art est
un mapping local Material (`psychology, rocket_launch, star, bolt,
public, emoji_events, sports_soccer, sports_basketball`).
`BrainAvatarView` (anneau + check) et `BrainAvatarChooser`
(seuls les unlocked sélectionnables) réutilisables profil/lobby/futur
classement. Serveur = autorité finale (`avatar-locked-or-invalid`).

## 6. Gate onboarding (niveau app)

`MaterialApp.router builder → OnboardingGate` : chargement compact,
`onboarding_complete=false` → `OnboardingScreen` plein écran SANS navbar,
`true` → enfant router intact. La localisation go_router sous-jacente est
préservée (même widget enfant réaffiché après succès).

## 7. Écrans

- Onboarding : branding, welcome, explication, pseudo (2–20 + filtre
  existant, serveur tranche), chooser, "Continuer en invité" (save RPC),
  "Continuer avec Google/Facebook" (link), "Déjà un compte ?" (sign-in).
  Pré-remplissage unique depuis `display_name/full_name/name` si valide,
  jamais après frappe.
- Profil : avatar + pseudo + locale + état (invité/connecté via
  `getUserIdentities`, sans tokens). Anonyme → "Sécuriser" (link).
  Édition pseudo + avatars débloqués via `update_my_profile`.
- Create/Join : pré-remplissage unique du pseudo depuis le profil serveur
  si champ vide, jamais d'écrasement (le joueur peut changer).

## 8. OAuth indisponible / erreurs

Providers non configurés (normal avant manip console) : pas de crash, pas
de texte brut, erreur localisée (`oauthUnavailable`), session invité
intacte, UI réutilisable. État pending affiché pendant le navigateur.

## 9. Non inclus (volontaire)

Pas de suppression de compte, pas de `unlinkIdentity`, pas de sign-out.
Aucun secret OAuth dans Flutter, aucun `google_sign_in` /
`flutter_facebook_auth` / Firebase.

## 10. Configuration externe restante

- Activer Google + Facebook dans Supabase Auth (dashboard).
- Autoriser `brainwager://auth-callback` dans les redirect URLs.
- Activer le liaising manuel d'identités (linking) côté Supabase.
- Tester sur appareil avec providers configurés (pas de faux succès).

## 11. Durcissement revue (même ticket, second commit)

- Sélection avatar immédiate : `BrainAvatarChooser(selectedKey)` local
  prime sur le flag serveur (aucune mutation des modèles, aucun RPC pour
  le déplacement visuel) ; affichage profil résolu par
  `profile.avatarKey` d'abord (`resolveVisibleAvatar`).
- Recharges sérialisées par génération : un vol à la fois, event =>
  invalidation + un seul suivi, résultats périmés jetés (UID capturé au
  départ, installation seulement si génération courante et même user).
  Changement de compte => fail-closed immédiat (profil/avatars/providers/
  erreurs effacés, gate fermée). Link (UUID identique) => simple refresh.
- Events typés (`AuthEventKind`) : reload pour signedIn/userUpdated/
  signedOut/other ; `tokenRefreshed`/`initialSession` ignorés.
- Gate fail-closed : `profile == null && error == null` => compact,
  jamais l'enfant au premier frame (pas de flash Home/navbar).
- Account-aware : `ProfileUiState.isAnonymous` (gateway, jamais supa()
  direct en build) ; lié => CTA "Save profile", contrôles guest-only
  masqués, statut connecté affiché.
- Sémantique avatar localisée (`avatarBrain…avatarBasketball` FR/EN/AR,
  repli générique, jamais la clé brute).
- Erreurs séparées : `profile-load-error` → `profileLoadError`,
  `profile-save-error` → `profileSaveError` (inconnus classés par chemin).
