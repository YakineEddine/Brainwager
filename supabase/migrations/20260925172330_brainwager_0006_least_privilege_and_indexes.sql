-- Brainwager 0006 — least privilege + full RLS alignment.
-- Applies AFTER 0005. Table grants least-privilege, every application policy
-- explicit `TO authenticated` with `(select auth.uid())` in row predicates,
-- UPDATE ownership policies carry WITH CHECK. No policies and no table
-- privileges for question_answers_private / game_questions (fail-closed).

-- is_numeric_like is INTERNAL (pure helper): no client EXECUTE at all.
revoke all on function public.is_numeric_like(text) from public, anon, authenticated;

-- RPC EXECUTE: no Brainwager SECURITY DEFINER function callable by anon.
-- Public app RPCs: revoked from public/anon/authenticated, then granted
-- to authenticated only. Internal helpers stay client-inaccessible (0003).
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

-- is_game_member: RLS policies run it as the calling user, so authenticated
-- needs EXECUTE; anon/PUBLIC must not have it.
revoke all on function public.is_game_member(uuid) from public, anon, authenticated;
grant execute on function public.is_game_member(uuid) to authenticated;

-- Table privileges least-privilege: remove everything from clients first,
-- then re-grant only what the architecture needs. Game writes go through
-- SECURITY DEFINER RPCs. NOTHING (not even SELECT) on the two sensitive tables.
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

-- RLS: full alignment. Every policy below targets authenticated explicitly.

drop policy if exists profiles_select_own on public.profiles;
create policy profiles_select_own on public.profiles
  for select to authenticated using ((select auth.uid()) = id);
drop policy if exists profiles_update_own on public.profiles;
create policy profiles_update_own on public.profiles
  for update to authenticated
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);

drop policy if exists entitlements_select_own on public.entitlements;
create policy entitlements_select_own on public.entitlements
  for select to authenticated using ((select auth.uid()) = user_id);

drop policy if exists packs_select_visible on public.packs;
create policy packs_select_visible on public.packs
  for select to authenticated using (
    (is_official and not is_hidden) or (owner_id = (select auth.uid()))
  );
drop policy if exists packs_insert_auth on public.packs;
create policy packs_insert_auth on public.packs
  for insert to authenticated
  with check ((select auth.uid()) is not null
              and owner_id = (select auth.uid()));
drop policy if exists packs_update_owner on public.packs;
create policy packs_update_owner on public.packs
  for update to authenticated
  using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()));
drop policy if exists packs_delete_owner on public.packs;
create policy packs_delete_owner on public.packs
  for delete to authenticated using (owner_id = (select auth.uid()));

drop policy if exists questions_select_owner on public.questions;
create policy questions_select_owner on public.questions
  for select to authenticated using (
    exists (select 1 from public.packs pk
            where pk.id = questions.pack_id
              and pk.owner_id = (select auth.uid()))
  );
drop policy if exists questions_insert_owner on public.questions;
create policy questions_insert_owner on public.questions
  for insert to authenticated
  with check (
    exists (select 1 from public.packs pk
            where pk.id = questions.pack_id
              and pk.owner_id = (select auth.uid()))
  );
drop policy if exists questions_update_owner on public.questions;
create policy questions_update_owner on public.questions
  for update to authenticated
  using (
    exists (select 1 from public.packs pk
            where pk.id = questions.pack_id
              and pk.owner_id = (select auth.uid()))
  )
  with check (
    exists (select 1 from public.packs pk
            where pk.id = questions.pack_id
              and pk.owner_id = (select auth.uid()))
  );
drop policy if exists questions_delete_owner on public.questions;
create policy questions_delete_owner on public.questions
  for delete to authenticated using (
    exists (select 1 from public.packs pk
            where pk.id = questions.pack_id
              and pk.owner_id = (select auth.uid()))
  );

-- question_answers_private + game_questions: intentionally NO policy (fail-closed).

drop policy if exists games_select_member on public.games;
create policy games_select_member on public.games
  for select to authenticated using (public.is_game_member(id));
drop policy if exists games_insert_auth on public.games;
create policy games_insert_auth on public.games
  for insert to authenticated
  with check ((select auth.uid()) is not null
              and host_id = (select auth.uid()));

drop policy if exists teams_select_member on public.teams;
create policy teams_select_member on public.teams
  for select to authenticated using (public.is_game_member(game_id));

drop policy if exists players_select_same_game on public.players;
create policy players_select_same_game on public.players
  for select to authenticated using (public.is_game_member(game_id));

drop policy if exists answers_select_locked on public.player_answers;
create policy answers_select_locked on public.player_answers
  for select to authenticated using (
    exists (select 1 from public.players me
            where me.game_id = player_answers.game_id
              and me.user_id = (select auth.uid())
              and me.id = player_answers.player_id)
    or
    (public.is_game_member(player_answers.game_id)
     and exists (select 1 from public.games g
                 where g.id = player_answers.game_id
                   and g.status in ('reveal', 'leaderboard', 'final_reveal', 'finished')))
  );

drop policy if exists wagers_select_locked on public.wagers;
create policy wagers_select_locked on public.wagers
  for select to authenticated using (
    exists (select 1 from public.players me
            where me.game_id = wagers.game_id
              and me.user_id = (select auth.uid())
              and me.id = wagers.player_id)
    or
    (public.is_game_member(wagers.game_id)
     and exists (select 1 from public.games g
                 where g.id = wagers.game_id
                   and g.status in ('question_locked', 'reveal', 'leaderboard',
                                    'final_reveal', 'finished')))
  );

drop policy if exists reports_insert_auth on public.pack_reports;
create policy reports_insert_auth on public.pack_reports
  for insert to authenticated
  with check ((select auth.uid()) is not null
              and reporter_id = (select auth.uid()));
drop policy if exists reports_select_mine on public.pack_reports;
create policy reports_select_mine on public.pack_reports
  for select to authenticated using (
    reporter_id = (select auth.uid())
    or exists (select 1 from public.packs pk
               where pk.id = pack_reports.pack_id
                 and pk.owner_id = (select auth.uid()))
  );

-- FK indexes (IF NOT EXISTS; existing game_id indexes untouched).
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
