-- Brainwager Phase 2 — 0003 RPC security definer
-- Seule écriture autorisée du jeu. Miroir des règles Dart (doc 02 §4).
-- Toutes : SECURITY DEFINER, search_path verrouillé, contrôle auth.uid() interne.

-- Horloge serveur (mesure offset client).
create or replace function public.server_time()
returns timestamptz
language sql stable security definer set search_path = public as $$
  select now();
$$;

-- Générateur de code sans caractères ambigus (0/O, 1/I/L exclus).
create or replace function public._gen_code(p_len integer)
returns text language plpgsql security definer set search_path = public as $$
declare
  v_alphabet constant text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  v_out text := '';
  i integer;
begin
  for i in 1..p_len loop
    v_out := v_out || substr(v_alphabet, 1 + floor(random() * char_length(v_alphabet))::integer, 1);
  end loop;
  return v_out;
end;
$$;

create or replace function public.is_game_host(p_game uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.games g
    where g.id = p_game and g.host_id = auth.uid()
  );
$$;

-- Normalisation miroir du Dart : minuscules, accents, ponctuation, articles, trim.
create or replace function public.normalize_answer(p_raw text)
returns text language plpgsql immutable security definer
  set search_path = public, extensions as $$
declare
  v text;
begin
  if p_raw is null then return ''; end if;
  v := lower(trim(p_raw));
  begin
    v := unaccent(v);
  exception when undefined_function then
    -- repli sans unaccent : remplace les voyelles accentuées FR courantes
    v := translate(v, 'àâäéèêëîïôöùûüÿçñ', 'aaaeeeeiioouuuycn');
  end;
  v := regexp_replace(v, '[’‘''ʼ`]', '''', 'g');
  v := regexp_replace(v, '[^a-z0-9\s\-]', ' ', 'g');
  v := regexp_replace(v, '\s+', ' ', 'g');
  v := trim(v);
  v := regexp_replace(v, '^(le|la|les|un|une|des|the|a|an|l|d)\s+', '', 'i');
  v := replace(v, ',', '.');
  return v;
end;
$$;

create or replace function public.is_numeric_like(p_norm text)
returns boolean language sql immutable security definer set search_path = public as $$
  select p_norm ~ '^-?[0-9]+(\.[0-9]+)?$'
      or p_norm ~ '^(17|18|19|20)[0-9]{2}$'
      or regexp_replace(p_norm, '[\s\.]', '', 'g') ~ '^[0-9]+$';
$$;

-- Match miroir Dart : égalité / alias, puis Levenshtein si fuzzy non numérique.
create or replace function public.match_answer(
  p_player text, p_expected text, p_aliases text[], p_mode text
)
returns boolean language plpgsql immutable security definer
  set search_path = public, extensions as $$
declare
  v_p text := public.normalize_answer(p_player);
  v_e text := public.normalize_answer(p_expected);
  v_a text;
  v_c text;
  v_d integer;
  v_thresh integer;
begin
  if v_p = '' or v_e = '' then return false; end if;
  if v_p = v_e then return true; end if;
  if p_aliases is not null then
    foreach v_a in array p_aliases loop
      if v_p = public.normalize_answer(v_a) then return true; end if;
    end loop;
  end if;
  -- Nombres / années : exact strict.
  if public.is_numeric_like(v_p) or public.is_numeric_like(v_e) then
    return false;
  end if;
  if p_mode = 'exact' then return false; end if;
  if public.levenshtein(v_p, v_e) <=
     case when char_length(v_e) <= 5 then 1
          when char_length(v_e) <= 8 then 2
          else 3 end then
    return true;
  end if;
  if p_aliases is not null then
    foreach v_a in array p_aliases loop
      v_c := public.normalize_answer(v_a);
      v_d := public.levenshtein(v_p, v_c);
      v_thresh := case when char_length(v_c) <= 5 then 1
                       when char_length(v_c) <= 8 then 2
                       else 3 end;
      if v_d <= v_thresh then return true; end if;
    end loop;
  end if;
  return false;
end;
$$;

-- Recalcule score / best_streak / biggest_wager_won depuis tout l'historique.
create or replace function public.recompute_player_stats(p_player uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  r record;
  v_score integer := 0;
  v_streak integer := 0;
  v_best integer := 0;
  v_biggest integer := 0;
  v_pts integer;
begin
  for r in
    select a.question_idx, a.is_correct, coalesce(w.amount, 0) as amount
    from public.player_answers a
    left join public.wagers w
      on w.game_id = a.game_id and w.player_id = a.player_id
     and w.question_idx = a.question_idx
    where a.player_id = p_player
    order by a.question_idx
  loop
    if r.question_idx = 10 then
      if coalesce(r.is_correct, false) then v_pts := r.amount;
      else v_pts := -r.amount; end if;
    else
      if coalesce(r.is_correct, false) then v_pts := r.amount;
      else v_pts := 0; end if;
    end if;
    v_score := v_score + v_pts;
    if coalesce(r.is_correct, false) then
      v_streak := v_streak + 1;
      if v_streak > v_best then v_best := v_streak; end if;
      if v_pts > v_biggest then v_biggest := v_pts; end if;
    else
      v_streak := 0;
    end if;
  end loop;
  update public.players
  set score = v_score, best_streak = v_best, biggest_wager_won = v_biggest
  where id = p_player;
end;
$$;

-- Assure la ligne profiles pour l'appelant (auth anonyme).
create or replace function public._ensure_profile()
returns void language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id)
  values (auth.uid())
  on conflict (id) do nothing;
end;
$$;

-- Création de partie : game + hôte + tirage 10+1 (finale la plus difficile).
create or replace function public.create_game(
  p_pack_id uuid, p_nickname text,
  p_team_mode boolean default false,
  p_language text default 'fr',
  p_duration integer default 30
)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_pack record;
  v_code text;
  v_game uuid;
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
  if v_pack.owner_id is distinct from auth.uid()
     and not (v_pack.is_official) then
    raise exception 'pack-not-visible';
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
  values (v_game, auth.uid(), v_n, true);

  -- Finale : difficulté max, idx asc en départage.
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

  return jsonb_build_object('game_id', v_game, 'join_code', v_code);
end;
$$;

create or replace function public.join_game(
  p_code text, p_nickname text, p_team_id uuid default null
)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_game record;
  v_player uuid;
  v_n text := trim(p_nickname);
begin
  if auth.uid() is null then raise exception 'not-authenticated'; end if;
  if char_length(v_n) < 2 or char_length(v_n) > 20 then
    raise exception 'invalid-nickname';
  end if;
  select * into v_game from public.games
  where join_code = upper(trim(p_code));
  if not found then raise exception 'game-not-found'; end if;
  if v_game.status <> 'lobby' then raise exception 'game-already-started'; end if;
  if p_team_id is not null
     and not exists (select 1 from public.teams t
                     where t.id = p_team_id and t.game_id = v_game.id) then
    raise exception 'team-not-found';
  end if;

  perform public._ensure_profile();

  insert into public.players (game_id, user_id, nickname, team_id)
  values (v_game.id, auth.uid(), v_n, p_team_id)
  returning id into v_player;

  return jsonb_build_object('game_id', v_game.id, 'player_id', v_player);
exception when unique_violation then
  raise exception 'nickname-taken';
end;
$$;

-- Heartbeat léger (pas d'UPDATE direct autorisé en RLS).
create or replace function public.touch_presence(p_game uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  update public.players
  set last_seen_at = now(), is_connected = true
  where game_id = p_game and user_id = auth.uid();
end;
$$;

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
  -- depuis reveal/leaderboard (pas de saut, pas de rejeu, pas de reset timer).
  if p_idx = 0 then
    if v_game.status <> 'lobby' then raise exception 'bad-transition'; end if;
  else
    if v_game.status not in ('reveal', 'leaderboard') then
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

create or replace function public.start_game(p_game uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform public.open_question(p_game, 0);
end;
$$;

-- Question courante servie aux membres (SANS réponses).
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

-- Fiche officielle : 3 exemples uniquement. UGC owner : liste complète.
create or replace function public.get_pack_preview(p_pack uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v_pack record;
begin
  select * into v_pack from public.packs where id = p_pack;
  if not found then raise exception 'pack-not-found'; end if;
  if v_pack.is_hidden then raise exception 'pack-hidden'; end if;
  if v_pack.is_official then
    return (select coalesce(jsonb_agg(t order by t.idx), '[]'::jsonb)
            from (select q.idx, q.prompt_fr, q.prompt_en, q.category, q.difficulty
                  from public.questions q
                  where q.pack_id = p_pack order by q.idx asc limit 3) t);
  end if;
  if v_pack.owner_id is distinct from auth.uid() then
    raise exception 'pack-not-visible';
  end if;
  return (select coalesce(jsonb_agg(t order by t.idx), '[]'::jsonb)
          from (select q.idx, q.prompt_fr, q.prompt_en, q.category,
                       q.difficulty, q.match_mode
                from public.questions q
                where q.pack_id = p_pack order by q.idx asc) t);
end;
$$;

create or replace function public.get_pack_by_share_code(p_code text)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v_pack record;
begin
  select * into v_pack from public.packs
  where share_code = upper(trim(p_code)) and not is_hidden;
  if not found then raise exception 'pack-not-found'; end if;
  return jsonb_build_object('id', v_pack.id, 'title_fr', v_pack.title_fr,
                            'title_en', v_pack.title_en, 'is_premium', v_pack.is_premium);
end;
$$;

-- Soumission réponse + mise (upsert atomique). Verrou serveur faisant foi.
create or replace function public.submit_answer(
  p_game uuid, p_idx integer, p_text text, p_wager integer
)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_game record;
  v_player uuid;
begin
  if auth.uid() is null then raise exception 'not-authenticated'; end if;
  select * into v_game from public.games where id = p_game;
  if not found then raise exception 'game-not-found'; end if;
  select p.id into v_player from public.players p
  where p.game_id = p_game and p.user_id = auth.uid();
  if not found then raise exception 'not-member'; end if;
  if p_idx <> v_game.current_question_idx then raise exception 'wrong-index'; end if;
  if p_idx < 10 and v_game.status <> 'question_open' then
    raise exception 'not-open';
  end if;
  if p_idx = 10 and v_game.status <> 'final_wager' then
    raise exception 'not-open';
  end if;
  if v_game.question_opened_at is null then raise exception 'not-open'; end if;
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

  insert into public.player_answers
    (game_id, player_id, question_idx, answer_text, is_correct, is_overridden, scored_points)
  values (p_game, v_player, p_idx, trim(p_text), null, false, 0)
  on conflict (game_id, player_id, question_idx)
  do update set answer_text = excluded.answer_text,
                is_correct = null, is_overridden = false, scored_points = 0;

  insert into public.wagers (game_id, player_id, question_idx, amount)
  values (p_game, v_player, p_idx, p_wager)
  on conflict (game_id, player_id, question_idx)
  do update set amount = excluded.amount;
exception when unique_violation then
  raise exception 'wager-already-used';
end;
$$;

-- Verrouillage : hôte OU tout membre après expiration − 2 s. Idempotent.
create or replace function public.lock_question(p_game uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_game record;
  v_is_host boolean;
  v_deadline timestamptz;
  r record;
  v_qid uuid;
  v_exp text;
  v_alias text[];
  v_mode text;
  v_ok boolean;
  v_amount integer;
begin
  select * into v_game from public.games where id = p_game;
  if not found then raise exception 'game-not-found'; end if;
  if not public.is_game_member(p_game) then raise exception 'not-member'; end if;
  if v_game.status in ('question_locked', 'reveal', 'leaderboard',
                       'final_reveal', 'finished') then
    return; -- idempotent
  end if;
  if v_game.status not in ('question_open', 'final_wager') then
    raise exception 'not-open';
  end if;
  v_is_host := public.is_game_host(p_game);
  v_deadline := v_game.question_opened_at
                + make_interval(secs => v_game.question_duration_sec)
                - make_interval(secs => 2);
  if not v_is_host and now() < v_deadline then
    raise exception 'not-allowed-yet';
  end if;

  update public.games set status = 'question_locked' where id = p_game;

  select gq.question_id into v_qid from public.game_questions gq
  where gq.game_id = p_game and gq.position = v_game.current_question_idx;

  -- Correction auto des copies non encore corrigées.
  for r in
    select a.id as aid, a.player_id, a.answer_text
    from public.player_answers a
    where a.game_id = p_game and a.question_idx = v_game.current_question_idx
      and a.is_correct is null
  loop
    if v_game.language = 'fr' then
      select ap.answer_main_fr, ap.aliases_fr, q.match_mode
        into v_exp, v_alias, v_mode
      from public.question_answers_private ap
      join public.questions q on q.id = ap.question_id
      where ap.question_id = v_qid;
    else
      select ap.answer_main_en, ap.aliases_en, q.match_mode
        into v_exp, v_alias, v_mode
      from public.question_answers_private ap
      join public.questions q on q.id = ap.question_id
      where ap.question_id = v_qid;
    end if;
    v_ok := public.match_answer(r.answer_text, v_exp, v_alias, v_mode);
    select w.amount into v_amount from public.wagers w
    where w.game_id = p_game and w.player_id = r.player_id
      and w.question_idx = v_game.current_question_idx;
    update public.player_answers
    set is_correct = v_ok,
        scored_points = case
          when v_game.current_question_idx = 10 and v_ok then coalesce(v_amount, 0)
          when v_game.current_question_idx = 10 and not v_ok then -coalesce(v_amount, 0)
          when v_ok then coalesce(v_amount, 0)
          else 0 end
    where id = r.aid;
    perform public.recompute_player_stats(r.player_id);
  end loop;
end;
$$;

-- Révélation : réponse seulement si verrouillé (ou après). Idempotent.
create or replace function public.reveal_answer(p_game uuid)
returns text language plpgsql security definer set search_path = public as $$
declare
  v_game record;
  v_qid uuid;
  v_ans text;
begin
  if not public.is_game_member(p_game) then raise exception 'not-member'; end if;
  select * into v_game from public.games where id = p_game;
  if v_game.status not in ('question_locked', 'reveal', 'leaderboard',
                           'final_reveal', 'finished') then
    raise exception 'not-locked';
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

-- Correction manuelle hôte + recalcul complet (correction 7).
create or replace function public.override_answer(p_answer_id uuid, p_correct boolean)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_ans record;
  v_game record;
  v_amount integer;
begin
  select * into v_ans from public.player_answers where id = p_answer_id;
  if not found then raise exception 'answer-not-found'; end if;
  select * into v_game from public.games where id = v_ans.game_id;
  if v_game.status = 'finished' then raise exception 'game-finished'; end if;
  if not public.is_game_host(v_ans.game_id) then raise exception 'not-host'; end if;
  select w.amount into v_amount from public.wagers w
  where w.game_id = v_ans.game_id and w.player_id = v_ans.player_id
    and w.question_idx = v_ans.question_idx;
  update public.player_answers
  set is_correct = p_correct, is_overridden = true,
      scored_points = case
        when v_ans.question_idx = 10 and p_correct then coalesce(v_amount, 0)
        when v_ans.question_idx = 10 and not p_correct then -coalesce(v_amount, 0)
        when p_correct then coalesce(v_amount, 0)
        else 0 end
  where id = p_answer_id;
  perform public.recompute_player_stats(v_ans.player_id);
end;
$$;

-- Transfert hôte : hôte actuel OU membre si hôte inactif depuis 60 s. Idempotent.
create or replace function public.transfer_host(p_game uuid, p_new_player uuid default null)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_game record;
  v_caller uuid;
  v_host_player record;
  v_target uuid;
begin
  select * into v_game from public.games where id = p_game;
  if not found then raise exception 'game-not-found'; end if;
  select p.id into v_caller from public.players p
  where p.game_id = p_game and p.user_id = auth.uid();
  if not found then raise exception 'not-member'; end if;

  if public.is_game_host(p_game) then
    if p_new_player is null then raise exception 'missing-target'; end if;
    select * into v_host_player from public.players
    where id = p_new_player and game_id = p_game;
    if not found then raise exception 'target-not-found'; end if;
    v_target := p_new_player;
  else
    select p.* into v_host_player from public.players p
    join public.games g on g.host_id = p.user_id and g.id = p.game_id
    where p.game_id = p_game limit 1;
    if v_host_player.last_seen_at > now() - make_interval(secs => 60) then
      raise exception 'host-active';
    end if;
    if p_new_player is null then v_target := v_caller;
    else
      if not exists (select 1 from public.players p
                     where p.id = p_new_player and p.game_id = p_game) then
        raise exception 'target-not-found';
      end if;
      v_target := p_new_player;
    end if;
  end if;

  update public.players set is_host = (id = v_target) where game_id = p_game;
  update public.games g
  set host_id = (select p.user_id from public.players p where p.id = v_target)
  where g.id = p_game;
end;
$$;

create or replace function public.cleanup_old_games()
returns integer language plpgsql security definer set search_path = public as $$
declare
  v_n integer;
begin
  delete from public.games where expires_at < now() - interval '7 days';
  get diagnostics v_n = row_count;
  return v_n;
end;
$$;

-- Droits d'exécution : authenticated uniquement (anon Supabase non signé = rien).
revoke all on function public.server_time() from public;
grant execute on function public.server_time() to authenticated;
revoke all on function public.create_game(uuid, text, boolean, text, integer) from public;
grant execute on function public.create_game(uuid, text, boolean, text, integer) to authenticated;
revoke all on function public.join_game(text, text, uuid) from public;
grant execute on function public.join_game(text, text, uuid) to authenticated;
revoke all on function public.touch_presence(uuid) from public;
grant execute on function public.touch_presence(uuid) to authenticated;
revoke all on function public.open_question(uuid, integer) from public;
grant execute on function public.open_question(uuid, integer) to authenticated;
revoke all on function public.start_game(uuid) from public;
grant execute on function public.start_game(uuid) to authenticated;
revoke all on function public.get_current_question(uuid) from public;
grant execute on function public.get_current_question(uuid) to authenticated;
revoke all on function public.get_pack_preview(uuid) from public;
grant execute on function public.get_pack_preview(uuid) to authenticated;
revoke all on function public.get_pack_by_share_code(text) from public;
grant execute on function public.get_pack_by_share_code(text) to authenticated;
revoke all on function public.submit_answer(uuid, integer, text, integer) from public;
grant execute on function public.submit_answer(uuid, integer, text, integer) to authenticated;
revoke all on function public.lock_question(uuid) from public;
grant execute on function public.lock_question(uuid) to authenticated;
revoke all on function public.reveal_answer(uuid) from public;
grant execute on function public.reveal_answer(uuid) to authenticated;
revoke all on function public.override_answer(uuid, boolean) from public;
grant execute on function public.override_answer(uuid, boolean) to authenticated;
revoke all on function public.transfer_host(uuid, uuid) from public;
grant execute on function public.transfer_host(uuid, uuid) to authenticated;

-- Interne uniquement : jamais appelable par le client (SECURITY DEFINER + écriture
-- scores). Invoquée uniquement par lock_question / override_answer en interne.
revoke all on function public.recompute_player_stats(uuid) from public, anon, authenticated;
