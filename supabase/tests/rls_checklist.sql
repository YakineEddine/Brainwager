-- Brainwager Phase 2 — checklist RLS/RPC (tests manuels, 2 comptes anon)
-- Exécuter connecté en tant que joueur A (après signInAnonymously).
-- Résultats attendus entre crochets.

-- 1. Réponses privées illisibles [0 ligne ou permission denied]
select * from public.question_answers_private limit 1;

-- 2. Tirage illisible en direct [0 ligne ou permission denied]
select * from public.game_questions limit 1;

-- 3. Question courante via RPC uniquement [1 ligne JSON sans réponses]
-- select public.get_current_question('<GAME_ID>');

-- 4. Mises des autres invisibles avant lock [que mes lignes]
-- select * from public.wagers where game_id = '<GAME_ID>';

-- 5. reveal avant lock [exception not-locked]
-- select public.reveal_answer('<GAME_ID>');

-- 6. Double mise 7 (Q différentes) [exception wager-already-used]
-- 7. Mise finale 15 [exception invalid-final-wager]
-- 8. lock par non-hôte avant expiration [exception not-allowed-yet],
--    après expiration − 2 s [OK, idempotent si rejoué]
-- 9. open_question par non-hôte [exception not-host]
-- 10. Preview officielle [exactement 3 éléments]
-- select public.get_pack_preview('<PACK_ID>');
