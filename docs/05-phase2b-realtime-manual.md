# Phase 2B — Plan de test manuel à deux appareils (Realtime/timer)

Device A = hôte · Device B = joueur. Prérequis : migrations 0001–0009
appliquées, pack DEMO01 seedé, Anonymous sign-ins activés.

Avant le start, vérifier :
- code de partie visible sur les deux écrans d'attente ;
- deux utilisateurs distincts (pseudos différents) ;
- `Joueurs : 2 / 50`, `En ligne : 2` ;
- seul l'hôte voit `Démarrer la partie`, grisé à 1 joueur, actif à 2.

1. A crée une partie (pack démo), B rejoint avec le code.
2. A et B affichent chacun le code + `Joueurs : 2 / 50` + `En ligne : 2`
   (Presence debug Phase 2 — pas une autorité d'appartenance).
3. A démarre la Q0 : les deux countdowns affichent ~30 s (écart ≤ ~1 s).
4. B passe en arrière-plan 10–20 s puis revient : le restant affiché est
   correct (recalcul depuis `opened_at`, sans rattrapage de ticks).
5. B coupe/rétablit le Wi-Fi : au retour, statut/question/scores à jour
   (recalibrage horloge + reload RPC + réabonnement, sans doublons).
6. Timer à zéro : un/des appareils appellent `lock_question`, l'état reste
   cohérent (une seule transition, serveur autoritaire, idempotent).
7. A révèle : les deux affichent la bonne réponse.
8. A passe au classement : les deux voient `leaderboard`, puis A ouvre Q+1.
9. Hôte vivant + heartbeat actif, attendre > 60 s : l'hôte NE doit PAS être
   transférable (`transfer_host` → `host-active`).
10. Couper le heartbeat/réseau de A assez longtemps (> 60 s sans
    `touch_presence`) : `transfer_host` devient éligible côté serveur.
11. Refresh (navigateur ou kill/relance) de B en lobby : B restaure la MÊME
    identité joueur (même player_id, même pseudo serveur), ne crée PAS un
    nouvel utilisateur anonyme, reste dans la même partie/session.
12. Rejoin avec le même compte déjà membre (même code, pseudo différent
    tapé) : reprise normale de la partie (already_joined), PAS
    `nickname-taken`.
13. Restauration de soumission :
    - Q1 ouverte, B tape une réponse + mise, valide ;
    - B rafraîchit le navigateur avant le lock ;
    - même identité anonyme, même partie/joueur, toujours Q1 ;
    - champ réponse et mise restaurés à l'identique ;
    - B modifie et resoumet pendant que Q1 est ouverte ;
    - une seule ligne answer et une seule mise Q1 existent côté serveur.

Statut : NON EXÉCUTÉ (aucun humain ne l'a encore joué). Ne pas cocher sans
un vrai run à deux appareils.
