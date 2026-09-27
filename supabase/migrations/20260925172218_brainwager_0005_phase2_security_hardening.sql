-- Brainwager 0005 — Phase 2 game-flow + reveal authority (final).
-- Aligned with deployed backend. Applies AFTER 0004.
-- Source: docs/02-supabase-model.md §2, lib/features/game_engine/game_fsm.dart.
-- All functions: SECURITY DEFINER, search_path locked to public, extensions.

-- get_current_question: member check, game existence,
-- reject lobby OR never-opened question with `not-started`.
create or replace function public.get_current_question(p_game uuid)
returns jsonb language plpgsql stable security definer
  set search_path = public, extensions as $$
declare
  v_game record;
  v_prompt text;
  v_image text;
  v_mode text;
begin
  if not public.is_game_member(p_game) then raise exception 'not-member'; end if;
  select * into v_game from public.games where id = p_game;
  if not found then raise exception 'game-not-found'; end if;
  if v_game.status = 'lobby' or v_game.question_opened_at is null then
    raise exception 'not-started';
  end if;
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

-- reveal_answer: only the host transitions question_locked → reveal/final_reveal.
-- Members may read once already revealed. Before lock: nobody. Idempotent.
create or replace function public.reveal_answer(p_game uuid)
returns text language plpgsql security definer
  set search_path = public, extensions as $$
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

-- open_question: Q0 only from lobby; later questions only from leaderboard
-- (previous normal round must have reached the board); strict next index.
create or replace function public.open_question(p_game uuid, p_idx integer)
returns void language plpgsql security definer
  set search_path = public, extensions as $$
declare
  v_game record;
  v_status text;
begin
  if not public.is_game_host(p_game) then raise exception 'not-host'; end if;
  if p_idx < 0 or p_idx > 10 then raise exception 'invalid-index'; end if;
  select * into v_game from public.games where id = p_game;
  if not found then raise exception 'game-not-found'; end if;
  v_status := case when p_idx = 10 then 'final_wager' else 'question_open' end;
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

-- show_leaderboard: host only. ORDER: reject final question first
-- (`final-question`), then leaderboard replay returns successfully,
-- otherwise require reveal.
create or replace function public.show_leaderboard(p_game uuid)
returns void language plpgsql security definer
  set search_path = public, extensions as $$
declare
  v_game record;
begin
  if not public.is_game_host(p_game) then raise exception 'not-host'; end if;
  select * into v_game from public.games where id = p_game;
  if not found then raise exception 'game-not-found'; end if;
  if v_game.current_question_idx >= 10 then raise exception 'final-question'; end if;
  if v_game.status = 'leaderboard' then
    return; -- replay: already on board, no effect
  end if;
  if v_game.status <> 'reveal' then raise exception 'bad-transition'; end if;
  update public.games set status = 'leaderboard' where id = p_game;
end;
$$;

-- finish_game: host only. Already finished → success (idempotent).
-- Otherwise require final_reveal AND index 10.
create or replace function public.finish_game(p_game uuid)
returns void language plpgsql security definer
  set search_path = public, extensions as $$
declare
  v_game record;
begin
  if not public.is_game_host(p_game) then raise exception 'not-host'; end if;
  select * into v_game from public.games where id = p_game;
  if not found then raise exception 'game-not-found'; end if;
  if v_game.status = 'finished' then
    return; -- idempotent: terminal state already reached
  end if;
  if v_game.status <> 'final_reveal' then raise exception 'bad-transition'; end if;
  if v_game.current_question_idx <> 10 then raise exception 'bad-transition'; end if;
  update public.games set status = 'finished' where id = p_game;
end;
$$;

-- Execution rights: authenticated callers (hardened to anon-exclusion in 0006).
revoke all on function public.show_leaderboard(uuid) from public;
grant execute on function public.show_leaderboard(uuid) to authenticated;
revoke all on function public.finish_game(uuid) from public;
grant execute on function public.finish_game(uuid) to authenticated;
