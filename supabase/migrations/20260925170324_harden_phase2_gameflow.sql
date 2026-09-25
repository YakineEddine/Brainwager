-- Brainwager Phase 2 hardening — game flow + reveal authority
-- À appliquer APRÈS 0001–0004. Ne modifie jamais 0001–0004 (déjà déployables).
-- Source règles : docs/02-supabase-model.md §2, lib/features/game_engine/game_fsm.dart
-- (miroir strict). Toutes les fonctions : SECURITY DEFINER, search_path verrouillé.

-- 1. Anti-triche pré-démarrage : aucun énoncé tant que la partie est en lobby.
--    current_question_idx vaut 0 par défaut et game_questions est rempli dès
--    create_game : sans ce garde, un membre lirait la question 0 avant le start.
create or replace function public.get_current_question(p_game uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v_game record;
  v_prompt text;
  v_image text;
  v_mode text;
begin
  if not public.is_game_member(p_game) then raise exception 'not-member'; end if;
  select * into v_game from public.games where id = p_game;
  if not found then raise exception 'game-not-found'; end if;
  if v_game.status = 'lobby' then raise exception 'not-started'; end if;
  select case when v_game.language = 'fr' then q.prompt_fr else q.prompt_en end,
         q.image_url, q.match_mode
    into v_prompt, v_image, v_mode
  from public.game_questions gq
  join public.questions q on q.id = gq.question_id
  where gq.game_id = p_game and gq.position = v_game.current_question_idx;
  if not found then raise exception 'question-not-found'; end if;
  return jsonb_build_object(
    'position', v_game.current_question_idx,
    'prompt', v_prompt,
    'image_url', v_image,
    'match_mode', v_mode,
    'duration_sec', v_game.question_duration_sec,
    'opened_at', v_game.question_opened_at,
    'status', v_game.status,
    'language', v_game.language
  );
end;
$$;

-- 2. Autorité de révélation : la transition question_locked → reveal/final_reveal
--    est réservée à l'hôte. Une fois révélé, tout membre peut relire la réponse.
--    Avant le lock : personne. Idempotent (rejoué sans effet ni erreur).
create or replace function public.reveal_answer(p_game uuid)
returns text language plpgsql security definer set search_path = public as $$
declare
  v_game record;
  v_qid uuid;
  v_ans text;
begin
  if not public.is_game_member(p_game) then raise exception 'not-member'; end if;
  select * into v_game from public.games where id = p_game;
  if not found then raise exception 'game-not-found'; end if;
  if v_game.status not in ('question_locked', 'reveal', 'leaderboard',
                           'final_reveal', 'finished') then
    raise exception 'not-locked';
  end if;
  if v_game.status = 'question_locked'
     and not public.is_game_host(p_game) then
    raise exception 'not-host';
  end if;
  select gq.question_id into v_qid from public.game_questions gq
  where gq.game_id = p_game and gq.position = v_game.current_question_idx;
  if v_game.language = 'fr' then
    select ap.answer_main_fr into v_ans from public.question_answers_private ap
    where ap.question_id = v_qid;
  else
    select ap.answer_main_en into v_ans from public.question_answers_private ap
    where ap.question_id = v_qid;
  end if;
  if v_game.status = 'question_locked' then
    update public.games
    set status = case when v_game.current_question_idx = 10
                      then 'final_reveal' else 'reveal' end
    where id = p_game;
  end if;
  return v_ans;
end;
$$;

-- 3a. Classement intermédiaire : reveal → leaderboard (questions normales).
--     Hôte uniquement. Idempotent (rejoué sur leaderboard : sans effet).
create or replace function public.show_leaderboard(p_game uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_game record;
begin
  if not public.is_game_host(p_game) then raise exception 'not-host'; end if;
  select * into v_game from public.games where id = p_game;
  if not found then raise exception 'game-not-found'; end if;
  if v_game.status = 'leaderboard' then
    return; -- idempotent : même état, aucun effet
  end if;
  if v_game.status <> 'reveal' then raise exception 'bad-transition'; end if;
  if v_game.current_question_idx >= 10 then raise exception 'bad-transition'; end if;
  update public.games set status = 'leaderboard' where id = p_game;
end;
$$;

-- 3b. Fin de partie : final_reveal → finished (finale idx 10 uniquement).
--     Hôte uniquement. Stricte (pas d'idempotence : un seul passage).
create or replace function public.finish_game(p_game uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_game record;
begin
  if not public.is_game_host(p_game) then raise exception 'not-host'; end if;
  select * into v_game from public.games where id = p_game;
  if not found then raise exception 'game-not-found'; end if;
  if v_game.status <> 'final_reveal' then raise exception 'bad-transition'; end if;
  if v_game.current_question_idx <> 10 then raise exception 'bad-transition'; end if;
  update public.games set status = 'finished' where id = p_game;
end;
$$;

-- 3c. Durcissement open_question : après la Q0, la manche normale précédente
--     doit être allée jusqu'au classement (reveal → show_leaderboard →
--     leaderboard). Ouverture depuis reveal refusée : pas de contournement
--     du classement, pas de reset timer sauvage. Séquentiel strict maintenu.
create or replace function public.open_question(p_game uuid, p_idx integer)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_game record;
  v_status text;
begin
  if not public.is_game_host(p_game) then raise exception 'not-host'; end if;
  if p_idx < 0 or p_idx > 10 then raise exception 'invalid-index'; end if;
  select * into v_game from public.games where id = p_game;
  if not found then raise exception 'game-not-found'; end if;
  v_status := case when p_idx = 10 then 'final_wager' else 'question_open' end;
  -- Garde-fou FSM serveur (miroir docs/02 §2 + game_fsm.dart) :
  -- démarrage depuis lobby uniquement, suite strictement séquentielle
  -- depuis leaderboard (pas de saut, pas de rejeu, pas de reset timer).
  if p_idx = 0 then
    if v_game.status <> 'lobby' then raise exception 'bad-transition'; end if;
  else
    if v_game.status <> 'leaderboard' then
      raise exception 'bad-transition';
    end if;
    if p_idx <> v_game.current_question_idx + 1 then
      raise exception 'invalid-index';
    end if;
  end if;
  update public.games
  set current_question_idx = p_idx, status = v_status,
      question_opened_at = now(), expires_at = now() + interval '24 hours'
  where id = p_game;
end;
$$;

-- Droits d'exécution : authenticated uniquement (modèle 0003 inchangé).
-- get_current_question / reveal_answer / open_question gardent leurs grants.
revoke all on function public.show_leaderboard(uuid) from public;
grant execute on function public.show_leaderboard(uuid) to authenticated;
revoke all on function public.finish_game(uuid) from public;
grant execute on function public.finish_game(uuid) to authenticated;
