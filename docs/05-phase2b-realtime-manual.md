# Phase 2B — Plan de test manuel à deux appareils (Realtime/timer)

Device A = hôte · Device B = joueur. Prérequis : migrations 0001–0008
appliquées, pack DEMO01 seedé, Anonymous sign-ins activés.

1. A crée une partie (pack démo), B rejoint avec le code.
2. A et B se voient en Presence (pastille/liste selon UI du moment).
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

Statut : NON EXÉCUTÉ (aucun humain ne l'a encore joué). Ne pas cocher sans
un vrai run à deux appareils.
