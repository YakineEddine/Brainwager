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

-- Durcissement flux Phase 2 (migration 0005) — résultats attendus entre crochets.
-- 11. Question courante en lobby [exception not-started, même pour un membre]
-- select public.get_current_question('<GAME_ID_LOBBY>');
-- 12. Question courante après start [1 ligne JSON sans réponses, membre uniquement]
-- select public.get_current_question('<GAME_ID_STARTED>');
-- 13. Questions futures toujours illisibles [0 ligne ou permission denied]
-- select * from public.game_questions where game_id = '<GAME_ID>';
-- 14. reveal_answer par non-hôte sur question_locked [exception not-host,
--     sans transition d'état]
-- 15. reveal_answer par hôte sur question_locked [réponse retournée,
--     statut → reveal (ou final_reveal si idx 10)]
-- 16. reveal_answer par membre sur statut reveal/final_reveal/finished
--     [réponse retournée, sans transition]
-- 17. show_leaderboard par non-hôte [exception not-host]
-- 18. show_leaderboard hors reveal [exception bad-transition]
-- 19. show_leaderboard sur finale (idx 10) [exception bad-transition]
-- 20. show_leaderboard par hôte sur reveal normal [OK, statut → leaderboard,
--     rejoué → OK sans effet]
-- 21. open_question suivante depuis reveal (sans leaderboard)
--     [exception bad-transition]
-- 22. open_question avec saut d'index [exception invalid-index]
-- 23. finish_game par non-hôte [exception not-host]
-- 24. finish_game hors final_reveal ou idx < 10 [exception bad-transition]
-- 25. finish_game par hôte sur final_reveal idx 10 [OK, statut → finished]
