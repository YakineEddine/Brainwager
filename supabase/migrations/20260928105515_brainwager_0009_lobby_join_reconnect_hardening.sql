-- Brainwager 0009 — lobby join/reconnect hardening (mirror deployed).
-- Applies AFTER 0008. Redefines create_game / join_game / touch_presence /
-- start_game with identical signatures. No other objects touched.
-- All: SECURITY DEFINER, search_path = public, extensions.

-- A) create_game : même signature, capture et retourne le player_id hôte.
create or replace function public.create_game(
  p_pack_id uuid, p_nickname text,
  p_team_mode boolean default false,
  p_language text default 'fr',
  p_duration integer default 30,
  p_share_code text default null
)
returns jsonb language plpgsql security definer set search_path = public, extensions as $$
declare
  v_pack record;
  v_code text;
  v_game uuid;
  v_player uuid;
  v_finale uuid;
  v_normals uuid[];
  v_n text := trim(p_nickname);
begin
  if auth.uid() is null then raise exception 'not-authenticated'; end if;
  if char_length(v_n) < 2 or char_length(v_n) > 20 then
    raise exception 'invalid-nickname';
  end if;
  if p_language not in ('fr', 'en') then raise exception 'invalid-language'; end if;
  if p_duration is null or p_duration <= 0 then p_duration := 30; end if;

  select * into v_pack from public.packs where id = p_pack_id;
  if not found then raise exception 'pack-not-found'; end if;
  if v_pack.is_hidden then raise exception 'pack-hidden'; end if;
  if (v_pack.owner_id is distinct from auth.uid())
     and not (v_pack.is_official) then
    if p_share_code is null
       or upper(trim(p_share_code)) <> upper(trim(v_pack.share_code)) then
      raise exception 'pack-not-visible';
    end if;
  end if;
  if v_pack.is_premium then
    if not exists (select 1 from public.entitlements e
                   where e.user_id = auth.uid()
                     and e.sku = v_pack.price_sku and e.is_active) then
      raise exception 'pack-premium-locked';
    end if;
  end if;
  if (select count(*) from public.questions q where q.pack_id = p_pack_id) < 11 then
    raise exception 'pack-too-small';
  end if;

  perform public._ensure_profile();

  loop
    v_code := public._gen_code(5);
    exit when not exists (select 1 from public.games g where g.join_code = v_code);
  end loop;

  insert into public.games (join_code, host_id, pack_id, language, team_mode,
                            question_duration_sec)
  values (v_code, auth.uid(), p_pack_id, p_language, coalesce(p_team_mode, false),
          p_duration)
  returning id into v_game;

  insert into public.players (game_id, user_id, nickname, is_host)
  values (v_game, auth.uid(), v_n, true)
  returning id into v_player;

  select q.id into v_finale
  from public.questions q
  where q.pack_id = p_pack_id
  order by q.difficulty desc, q.idx asc
  limit 1;

  select array_agg(q.id order by q.idx asc) into v_normals
  from public.questions q
  where q.pack_id = p_pack_id and q.id <> v_finale;

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
    'game_id', v_game, 'player_id', v_player, 'join_code', v_code
  );
end;
$$;

-- B) join_game : ré-entrée idempotente (même partie démarrée, avec
--    refresh de présence), sinon join normal plafonné à 50. Doublon réel
--    de pseudo → nickname-taken. Seul l'INSERT est protégé par EXCEPTION ;
--    le diagnostic de contrainte tranche user_id vs nickname (jamais de
--    mapping aveugle vers nickname-taken).
create or replace function public.join_game(
  p_code text, p_nickname text, p_team_id uuid default null
)
returns jsonb language plpgsql security definer set search_path = public, extensions as $$
declare
  v_game record;
  v_me record;
  v_player uuid;
  v_n text := trim(p_nickname);
  v_constraint text;
begin
  -- A) Utilisateur authentifié + pseudo bien formé.
  if auth.uid() is null then raise exception 'not-authenticated'; end if;
  if char_length(v_n) < 2 or char_length(v_n) > 20 then
    raise exception 'invalid-nickname';
  end if;
  -- B) Partie par code normalisé.
  select * into v_game from public.games
  where join_code = upper(trim(p_code));
  if not found then raise exception 'game-not-found'; end if;

  -- C) Déjà membre : refresh présence + reprise idempotente,
  --    même partie démarrée. Le pseudo retourné est celui du serveur.
  select * into v_me from public.players p
  where p.game_id = v_game.id and p.user_id = auth.uid();
  if found then
    update public.players
    set last_seen_at = now(), is_connected = true
    where id = v_me.id;
    return jsonb_build_object(
      'game_id', v_game.id,
      'player_id', v_me.id,
      'join_code', v_game.join_code,
      'nickname', v_me.nickname,
      'is_host', v_me.is_host,
      'already_joined', true
    );
  end if;

  -- D) Nouveau joueur : lobby only, plafond 50, équipe, doublon explicite.
  if v_game.status <> 'lobby' then raise exception 'game-already-started'; end if;
  if (select count(*) from public.players p
      where p.game_id = v_game.id) >= 50 then
    raise exception 'game-full';
  end if;
  if p_team_id is not null
     and not exists (select 1 from public.teams t
                     where t.id = p_team_id and t.game_id = v_game.id) then
    raise exception 'team-not-found';
  end if;
  if exists (select 1 from public.players p
             where p.game_id = v_game.id and p.nickname = v_n) then
    raise exception 'nickname-taken';
  end if;

  perform public._ensure_profile();

  -- E) Seul l'INSERT est protégé ; le diagnostic tranche la contrainte.
  begin
    insert into public.players (game_id, user_id, nickname, team_id)
    values (v_game.id, auth.uid(), v_n, p_team_id)
    returning id into v_player;
  exception when unique_violation then
    get stacked diagnostics v_constraint = constraint_name;
    if v_constraint = 'players_game_id_user_id_key' then
      -- Devenu membre entre-temps (course) : reprise idempotente.
      select * into v_me from public.players p
      where p.game_id = v_game.id and p.user_id = auth.uid();
      if not found then raise exception 'nickname-taken'; end if;
      update public.players
      set last_seen_at = now(), is_connected = true
      where id = v_me.id;
      return jsonb_build_object(
        'game_id', v_game.id,
        'player_id', v_me.id,
        'join_code', v_game.join_code,
        'nickname', v_me.nickname,
        'is_host', v_me.is_host,
        'already_joined', true
      );
    elsif v_constraint = 'players_game_id_nickname_key' then
      raise exception 'nickname-taken';
    else
      -- Violation inattendue : jamais déguisée en nickname-taken.
      -- Revérifier l'adhésion (course), sinon erreur explicite.
      select * into v_me from public.players p
      where p.game_id = v_game.id and p.user_id = auth.uid();
      if found then
        update public.players
        set last_seen_at = now(), is_connected = true
        where id = v_me.id;
        return jsonb_build_object(
          'game_id', v_game.id,
          'player_id', v_me.id,
          'join_code', v_game.join_code,
          'nickname', v_me.nickname,
          'is_host', v_me.is_host,
          'already_joined', true
        );
      end if;
      raise exception 'unexpected-unique-violation';
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

-- C) touch_presence : heartbeat du joueur courant, not-member si inconnu.
create or replace function public.touch_presence(p_game uuid)
returns void language plpgsql security definer set search_path = public, extensions as $$
declare
  v_n integer;
begin
  update public.players
  set last_seen_at = now(), is_connected = true
  where game_id = p_game and user_id = auth.uid();
  get diagnostics v_n = row_count;
  if v_n = 0 then raise exception 'not-member'; end if;
end;
$$;

-- D) start_game : hôte uniquement, minimum 2 joueurs, puis open 0.
create or replace function public.start_game(p_game uuid)
returns void language plpgsql security definer set search_path = public, extensions as $$
begin
  if not public.is_game_host(p_game) then raise exception 'not-host'; end if;
  if (select count(*) from public.players p
      where p.game_id = p_game) < 2 then
    raise exception 'not-enough-players';
  end if;
  perform public.open_question(p_game, 0);
end;
$$;

-- EXECUTE : révoqué de public/anon/authenticated, accordé à authenticated.
revoke all on function public.create_game(uuid, text, boolean, text, integer, text) from public, anon, authenticated;
grant execute on function public.create_game(uuid, text, boolean, text, integer, text) to authenticated;
revoke all on function public.join_game(text, text, uuid) from public, anon, authenticated;
grant execute on function public.join_game(text, text, uuid) to authenticated;
revoke all on function public.touch_presence(uuid) from public, anon, authenticated;
grant execute on function public.touch_presence(uuid) to authenticated;
revoke all on function public.start_game(uuid) from public, anon, authenticated;
grant execute on function public.start_game(uuid) to authenticated;
