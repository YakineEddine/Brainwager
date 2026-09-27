-- Brainwager — sync hardening avec le backend déployé.
-- À appliquer APRÈS 20260925170324_harden_phase2_gameflow.sql.
-- Contenu : alignement gameflow (9A/9B), durcissement EXECUTE (aucun RPC
-- appelable par anon), privilèges tables least-privilege, policies UPDATE
-- sûres (USING + WITH CHECK), index FK, publication Realtime exacte,
-- default privileges fail-closed. Idempotent et rejouable là où possible.

-- 9A. get_current_question : membre d'abord, game-not-found, puis
--     not-started si lobby OU question jamais ouverte (opened_at NULL).
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

-- 9B. finish_game : hôte uniquement ; déjà finished → succès sans effet
--     (idempotent) ; sinon exige final_reveal + idx 10.
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
    return; -- idempotent : état terminal déjà atteint
  end if;
  if v_game.status <> 'final_reveal' then raise exception 'bad-transition'; end if;
  if v_game.current_question_idx <> 10 then raise exception 'bad-transition'; end if;
  update public.games set status = 'finished' where id = p_game;
end;
$$;

-- 2. EXECUTE : aucun RPC Brainwager appelable par anon. Les RPC publiques sont
--    révoquées de public/anon/authenticated puis accordées à authenticated seul.
--    Les helpers internes restent sans aucun accès client (voir 0003).
revoke all on function public.server_time() from public, anon, authenticated;
grant execute on function public.server_time() to authenticated;
revoke all on function public.create_game(uuid, text, boolean, text, integer, text) from public, anon, authenticated;
grant execute on function public.create_game(uuid, text, boolean, text, integer, text) to authenticated;
revoke all on function public.join_game(text, text, uuid) from public, anon, authenticated;
grant execute on function public.join_game(text, text, uuid) to authenticated;
revoke all on function public.touch_presence(uuid) from public, anon, authenticated;
grant execute on function public.touch_presence(uuid) to authenticated;
revoke all on function public.open_question(uuid, integer) from public, anon, authenticated;
grant execute on function public.open_question(uuid, integer) to authenticated;
revoke all on function public.start_game(uuid) from public, anon, authenticated;
grant execute on function public.start_game(uuid) to authenticated;
revoke all on function public.get_current_question(uuid) from public, anon, authenticated;
grant execute on function public.get_current_question(uuid) to authenticated;
revoke all on function public.get_pack_preview(uuid) from public, anon, authenticated;
grant execute on function public.get_pack_preview(uuid) to authenticated;
revoke all on function public.get_pack_by_share_code(text) from public, anon, authenticated;
grant execute on function public.get_pack_by_share_code(text) to authenticated;
revoke all on function public.submit_answer(uuid, integer, text, integer) from public, anon, authenticated;
grant execute on function public.submit_answer(uuid, integer, text, integer) to authenticated;
revoke all on function public.lock_question(uuid) from public, anon, authenticated;
grant execute on function public.lock_question(uuid) to authenticated;
revoke all on function public.reveal_answer(uuid) from public, anon, authenticated;
grant execute on function public.reveal_answer(uuid) to authenticated;
revoke all on function public.override_answer(uuid, boolean) from public, anon, authenticated;
grant execute on function public.override_answer(uuid, boolean) to authenticated;
revoke all on function public.transfer_host(uuid, uuid) from public, anon, authenticated;
grant execute on function public.transfer_host(uuid, uuid) to authenticated;
revoke all on function public.show_leaderboard(uuid) from public, anon, authenticated;
grant execute on function public.show_leaderboard(uuid) to authenticated;
revoke all on function public.finish_game(uuid) from public, anon, authenticated;
grant execute on function public.finish_game(uuid) to authenticated;

-- is_game_member : appelée par les policies RLS en tant qu'utilisateur courant,
-- donc exécutable par authenticated, mais jamais par anon/PUBLIC.
revoke all on function public.is_game_member(uuid) from public, anon, authenticated;
grant execute on function public.is_game_member(uuid) to authenticated;

-- 3. Tables least-privilege : on retire tout aux clients, puis on ne redonne
--    que le strict nécessaire. Écritures jeu via RPC security definer.
--    AUCUN droit (même SELECT) sur question_answers_private et game_questions.
revoke all privileges on all tables in schema public from anon, authenticated;

grant select, update on public.profiles to authenticated;
grant select on public.entitlements to authenticated;
grant select, insert, update, delete on public.packs to authenticated;
grant select, insert, update, delete on public.questions to authenticated;
grant select on public.games to authenticated;
grant select on public.teams to authenticated;
grant select on public.players to authenticated;
grant select on public.player_answers to authenticated;
grant select on public.wagers to authenticated;
grant select, insert on public.pack_reports to authenticated;

-- 4. Policies UPDATE sûres : USING + WITH CHECK (pas de changement de
--    propriété pendant l'UPDATE) et (select auth.uid()) anti-per-row.
drop policy if exists profiles_update_own on public.profiles;
create policy profiles_update_own on public.profiles
  for update using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);

drop policy if exists packs_update_owner on public.packs;
create policy packs_update_owner on public.packs
  for update using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()));

drop policy if exists questions_update_owner on public.questions;
create policy questions_update_owner on public.questions
  for update using (
    exists (select 1 from public.packs pk
            where pk.id = questions.pack_id
              and pk.owner_id = (select auth.uid()))
  )
  with check (
    exists (select 1 from public.packs pk
            where pk.id = questions.pack_id
              and pk.owner_id = (select auth.uid()))
  );

-- 6. Index des clés étrangères (IF NOT EXISTS ; on garde les index game_id).
create index if not exists game_questions_question_idx
  on public.game_questions (question_id);
create index if not exists games_host_idx on public.games (host_id);
create index if not exists games_pack_idx on public.games (pack_id);
create index if not exists pack_reports_reporter_idx
  on public.pack_reports (reporter_id);
create index if not exists packs_owner_idx on public.packs (owner_id);
create index if not exists answers_player_idx
  on public.player_answers (player_id);
create index if not exists players_team_idx on public.players (team_id);
create index if not exists players_user_idx on public.players (user_id);
create index if not exists wagers_player_idx on public.wagers (player_id);

-- 7. Publication Realtime : EXACTEMENT les 5 tables d'état durable.
--    Idempotent (vérifie pg_publication_tables avant ADD/DROP).
do $$
declare
  t text;
begin
  if not exists (select 1 from pg_publication
                 where pubname = 'supabase_realtime') then
    return;
  end if;
  for t in select unnest(array['games', 'players', 'player_answers',
                               'wagers', 'teams']) loop
    if not exists (select 1 from pg_publication_tables
                   where pubname = 'supabase_realtime'
                     and schemaname = 'public' and tablename = t) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
  for t in select unnest(array['question_answers_private',
                               'game_questions']) loop
    if exists (select 1 from pg_publication_tables
               where pubname = 'supabase_realtime'
                 and schemaname = 'public' and tablename = t) then
      execute format('alter publication supabase_realtime drop table public.%I', t);
    end if;
  end loop;
end
$$;

-- 8. Default privileges fail-closed : les futurs objets du schéma public
--    créés par postgres n'accordent rien à anon/authenticated/PUBLIC.
--    Chaque future migration accorde explicitement ce dont elle a besoin.
alter default privileges for role postgres in schema public
  revoke all on tables from anon, authenticated;
alter default privileges for role postgres in schema public
  revoke all on functions from public, anon, authenticated;
