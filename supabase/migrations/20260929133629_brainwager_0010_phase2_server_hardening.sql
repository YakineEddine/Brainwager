
-- Brainwager 0010 — final Phase 2 server hardening.
-- No table/data changes. Keeps public RPC signatures stable.

-- Server-side nickname policy mirrors the current Flutter filter so direct
-- RPC callers cannot bypass client validation.
create or replace function public._nickname_is_clean(p_nickname text)
returns boolean
language sql
immutable
set search_path = pg_catalog
as $$
  select
    p_nickname is not null
    and char_length(trim(p_nickname)) between 2 and 20
    and not exists (
      select 1
      from unnest(array[
        'merde','con','connard','salope','pute','encule','bite','couille',
        'fuck','shit','bitch','asshole','dick','nazi','hitler'
      ]::text[]) as banned(root)
      where strpos(lower(trim(p_nickname)), banned.root) > 0
    );
$$;

revoke all on function public._nickname_is_clean(text)
from public, anon, authenticated;

-- create_game:
-- - server-side nickname filter
-- - atomic/race-safe join-code allocation
-- - randomized finale among the hardest questions
-- - randomized ten normal questions from the remainder
create or replace function public.create_game(
  p_pack_id uuid,
  p_nickname text,
  p_team_mode boolean default false,
  p_language text default 'fr',
  p_duration integer default 30,
  p_share_code text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_pack record;
  v_code text;
  v_game uuid;
  v_player uuid;
  v_finale uuid;
  v_normals uuid[];
  v_n text := trim(p_nickname);
  v_constraint text;
begin
  if auth.uid() is null then
    raise exception 'not-authenticated';
  end if;

  if not public._nickname_is_clean(v_n) then
    raise exception 'invalid-nickname';
  end if;

  if p_language not in ('fr', 'en') then
    raise exception 'invalid-language';
  end if;

  if p_duration is null or p_duration <= 0 then
    p_duration := 30;
  end if;

  select *
  into v_pack
  from public.packs
  where id = p_pack_id;

  if not found then
    raise exception 'pack-not-found';
  end if;

  if v_pack.is_hidden then
    raise exception 'pack-hidden';
  end if;

  if (v_pack.owner_id is distinct from auth.uid())
     and not v_pack.is_official then
    if p_share_code is null
       or upper(trim(p_share_code)) <> upper(trim(v_pack.share_code)) then
      raise exception 'pack-not-visible';
    end if;
  end if;

  if v_pack.is_premium then
    if not exists (
      select 1
      from public.entitlements e
      where e.user_id = auth.uid()
        and e.sku = v_pack.price_sku
        and e.is_active
    ) then
      raise exception 'pack-premium-locked';
    end if;
  end if;

  if (select count(*) from public.questions q where q.pack_id = p_pack_id) < 11 then
    raise exception 'pack-too-small';
  end if;

  perform public._ensure_profile();

  -- Allocate the code by attempting the insert itself. A concurrent creator
  -- can no longer win between a pre-check and the INSERT.

  loop
    v_code := public._gen_code(5);

    begin
      insert into public.games (
        join_code,
        host_id,
        pack_id,
        language,
        team_mode,
        question_duration_sec
      )
      values (
        v_code,
        auth.uid(),
        p_pack_id,
        p_language,
        coalesce(p_team_mode, false),
        p_duration
      )
      returning id into v_game;

      exit;
    exception when unique_violation then
      get stacked diagnostics v_constraint = constraint_name;

      if v_constraint = 'games_join_code_key' then
        continue;
      end if;

      raise;
    end;
  end loop;

  insert into public.players (game_id, user_id, nickname, is_host)
  values (v_game, auth.uid(), v_n, true)
  returning id into v_player;

  -- Highest difficulty wins; random() only breaks ties at that difficulty.
  -- NULL difficulty is last, so a malformed pool still cannot outrank a
  -- properly classified question.

  select q.id
  into v_finale
  from public.questions q
  where q.pack_id = p_pack_id
  order by q.difficulty desc nulls last, random()
  limit 1;

  if v_finale is null then
    raise exception 'pack-too-small';
  end if;

  -- Pick and order ten distinct normal questions randomly from the remainder.

  select array_agg(s.id order by s.rnd)
  into v_normals
  from (
    select q.id, random() as rnd
    from public.questions q
    where q.pack_id = p_pack_id
      and q.id <> v_finale
    order by rnd
    limit 10
  ) s;

  if coalesce(array_length(v_normals, 1), 0) < 10 then
    raise exception 'pack-too-small';
  end if;

  for i in 0..9 loop
    insert into public.game_questions (game_id, position, question_id)
    values (v_game, i, v_normals[i + 1]);
  end loop;

  insert into public.game_questions (game_id, position, question_id)
  values (v_game, 10, v_finale);

  return jsonb_build_object(
    'game_id', v_game,
    'player_id', v_player,
    'join_code', v_code
  );
end;
$$;

-- join_game keeps 0009 idempotent reconnect semantics but enforces nickname
-- policy on the server as well and refreshes presence on the rare user-id race.

create or replace function public.join_game(
  p_code text,
  p_nickname text,
  p_team_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_game record;
  v_player uuid;
  v_existing record;
  v_n text := trim(p_nickname);
  v_constraint text;
begin
  if auth.uid() is null then
    raise exception 'not-authenticated';
  end if;

  if not public._nickname_is_clean(v_n) then
    raise exception 'invalid-nickname';
  end if;

  select *
  into v_game
  from public.games
  where join_code = upper(trim(p_code));

  if not found then
    raise exception 'game-not-found';
  end if;

  select p.id, p.nickname, p.is_host
  into v_existing
  from public.players p
  where p.game_id = v_game.id
    and p.user_id = auth.uid()
  limit 1;

  if found then
    update public.players
    set last_seen_at = now(),
        is_connected = true
    where id = v_existing.id;

    return jsonb_build_object(
      'game_id', v_game.id,
      'player_id', v_existing.id,
      'join_code', v_game.join_code,
      'nickname', v_existing.nickname,
      'is_host', v_existing.is_host,
      'already_joined', true
    );
  end if;

  if v_game.status <> 'lobby' then
    raise exception 'game-already-started';
  end if;

  if (select count(*) from public.players p where p.game_id = v_game.id) >= 50 then
    raise exception 'game-full';
  end if;

  if p_team_id is not null
     and not exists (
       select 1
       from public.teams t
       where t.id = p_team_id
         and t.game_id = v_game.id
     ) then
    raise exception 'team-not-found';
  end if;

  if exists (
    select 1
    from public.players p
    where p.game_id = v_game.id
      and p.nickname = v_n
  ) then
    raise exception 'nickname-taken';
  end if;

  perform public._ensure_profile();

  begin
    insert into public.players (game_id, user_id, nickname, team_id)
    values (v_game.id, auth.uid(), v_n, p_team_id)
    returning id into v_player;
  exception when unique_violation then
    get stacked diagnostics v_constraint = constraint_name;

    if v_constraint = 'players_game_id_user_id_key' then
      select p.id, p.nickname, p.is_host
      into v_existing
      from public.players p
      where p.game_id = v_game.id
        and p.user_id = auth.uid()
      limit 1;

      if found then
        update public.players
        set last_seen_at = now(),
            is_connected = true
        where id = v_existing.id;

        return jsonb_build_object(
          'game_id', v_game.id,
          'player_id', v_existing.id,
          'join_code', v_game.join_code,
          'nickname', v_existing.nickname,
          'is_host', v_existing.is_host,
          'already_joined', true
        );
      end if;

      raise;
    elsif v_constraint = 'players_game_id_nickname_key' then
      raise exception 'nickname-taken';
    else
      raise;
    end if;
  end;

  return jsonb_build_object(
    'game_id', v_game.id,
    'player_id', v_player,
    'join_code', v_game.join_code,
    'nickname', v_n,
    'is_host', false,
    'already_joined', false
  );
end;
$$;

-- submit_answer maps only the intentional partial unique wager index to the
-- friendly wager-already-used error. Any unrelated integrity failure is kept.

create or replace function public.submit_answer(
  p_game uuid,
  p_idx integer,
  p_text text,
  p_wager integer
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_game record;
  v_player uuid;
  v_constraint text;
begin
  if auth.uid() is null then
    raise exception 'not-authenticated';
  end if;

  select *
  into v_game
  from public.games
  where id = p_game;

  if not found then
    raise exception 'game-not-found';
  end if;

  select p.id
  into v_player
  from public.players p
  where p.game_id = p_game
    and p.user_id = auth.uid();

  if not found then
    raise exception 'not-member';
  end if;

  if p_idx <> v_game.current_question_idx then
    raise exception 'wrong-index';
  end if;

  if p_idx < 10 and v_game.status <> 'question_open' then
    raise exception 'not-open';
  end if;

  if p_idx = 10 and v_game.status <> 'final_wager' then
    raise exception 'not-open';
  end if;

  if v_game.question_opened_at is null then
    raise exception 'not-open';
  end if;

  if now() >= v_game.question_opened_at
              + make_interval(secs => v_game.question_duration_sec) then
    raise exception 'locked';
  end if;

  if p_idx < 10 and (p_wager < 1 or p_wager > 10) then
    raise exception 'invalid-wager';
  end if;

  if p_idx = 10 and p_wager not in (0, 10, 20) then
    raise exception 'invalid-final-wager';
  end if;

  if p_text is null or char_length(trim(p_text)) = 0 then
    raise exception 'empty-answer';
  end if;

  insert into public.player_answers (
    game_id,
    player_id,
    question_idx,
    answer_text,
    is_correct,
    is_overridden,
    scored_points
  )
  values (
    p_game,
    v_player,
    p_idx,
    trim(p_text),
    null,
    false,
    0
  )
  on conflict (game_id, player_id, question_idx)
  do update
  set answer_text = excluded.answer_text,
      is_correct = null,
      is_overridden = false,
      scored_points = 0;

  begin
    insert into public.wagers (game_id, player_id, question_idx, amount)
    values (p_game, v_player, p_idx, p_wager)
    on conflict (game_id, player_id, question_idx)
    do update
    set amount = excluded.amount;
  exception when unique_violation then
    get stacked diagnostics v_constraint = constraint_name;

    if v_constraint = 'wagers_unique_amount_per_player' then
      raise exception 'wager-already-used';
    end if;

    raise;
  end;
end;
$$;

-- Fail closed: only signed-in Supabase Auth users (including anonymous-auth
-- users, which use the authenticated Postgres role) can call app RPCs.

revoke all on function public.create_game(uuid, text, boolean, text, integer, text)
from public, anon, authenticated;
grant execute on function public.create_game(uuid, text, boolean, text, integer, text)
to authenticated;

revoke all on function public.join_game(text, text, uuid)
from public, anon, authenticated;
grant execute on function public.join_game(text, text, uuid)
to authenticated;

revoke all on function public.submit_answer(uuid, integer, text, integer)
from public, anon, authenticated;
grant execute on function public.submit_answer(uuid, integer, text, integer)
to authenticated;
