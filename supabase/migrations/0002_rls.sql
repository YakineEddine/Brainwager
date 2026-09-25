-- Brainwager Phase 2 — 0002 RLS
-- Principe : tout ce qui est sensible n'a AUCUNE policy SELECT (refus par défaut).
-- Les écritures jeu passent par les RPC security definer (0003) qui bypassent la RLS.
-- À appliquer APRÈS 0001.

-- Helpers (lecture seule, appelés dans les policies).
create or replace function public.is_game_member(p_game uuid)
returns boolean language sql stable as $$
  select exists (
    select 1 from public.players p
    where p.game_id = p_game and p.user_id = auth.uid()
  );
$$;

-- profiles : soi-même uniquement.
create policy profiles_select_own on public.profiles
  for select using (auth.uid() = id);
create policy profiles_update_own on public.profiles
  for update using (auth.uid() = id);

-- entitlements : lecture de ses propres droits. AUCUNE écriture authenticated.
create policy entitlements_select_own on public.entitlements
  for select using (auth.uid() = user_id);

-- packs : officiels visibles non masqués, ou owner. Partage par code via RPC.
create policy packs_select_visible on public.packs
  for select using (
    (is_official and not is_hidden) or (owner_id = auth.uid())
  );
create policy packs_insert_auth on public.packs
  for insert with check (auth.uid() is not null and owner_id = auth.uid());
create policy packs_update_owner on public.packs
  for update using (owner_id = auth.uid());
create policy packs_delete_owner on public.packs
  for delete using (owner_id = auth.uid());

-- questions : lecture directe UNIQUEMENT pour l'éditeur de son propre pack.
-- Packs officiels et questions de partie : via get_pack_preview / get_current_question.
create policy questions_select_owner on public.questions
  for select using (
    exists (select 1 from public.packs pk
            where pk.id = questions.pack_id and pk.owner_id = auth.uid())
  );
create policy questions_insert_owner on public.questions
  for insert with check (
    exists (select 1 from public.packs pk
            where pk.id = pack_id and pk.owner_id = auth.uid())
  );
create policy questions_update_owner on public.questions
  for update using (
    exists (select 1 from public.packs pk
            where pk.id = questions.pack_id and pk.owner_id = auth.uid())
  );
create policy questions_delete_owner on public.questions
  for delete using (
    exists (select 1 from public.packs pk
            where pk.id = questions.pack_id and pk.owner_id = auth.uid())
  );

-- question_answers_private + game_questions : AUCUNE policy (refus total).
-- Ne rien créer ici volontairement.

-- games : lecture si membre. Écriture via RPC uniquement (pas d'update direct).
create policy games_select_member on public.games
  for select using (public.is_game_member(id));
create policy games_insert_auth on public.games
  for insert with check (auth.uid() is not null and host_id = auth.uid());

-- teams : lecture si membre. Écriture via RPC hôte.
create policy teams_select_member on public.teams
  for select using (public.is_game_member(game_id));

-- players : lecture si même partie. Écriture via join_game / RPC.
create policy players_select_same_game on public.players
  for select using (public.is_game_member(game_id));

-- player_answers : ses propres lignes + toutes après verrouillage (anti-copie).
create policy answers_select_locked on public.player_answers
  for select using (
    exists (select 1 from public.players me
            where me.game_id = player_answers.game_id
              and me.user_id = auth.uid()
              and me.id = player_answers.player_id)
    or
    (public.is_game_member(player_answers.game_id)
     and exists (select 1 from public.games g
                 where g.id = player_answers.game_id
                   and g.status in ('reveal', 'leaderboard', 'final_reveal', 'finished')))
  );

-- wagers : ses propres mises + toutes après verrouillage (correction 3).
create policy wagers_select_locked on public.wagers
  for select using (
    exists (select 1 from public.players me
            where me.game_id = wagers.game_id
              and me.user_id = auth.uid()
              and me.id = wagers.player_id)
    or
    (public.is_game_member(wagers.game_id)
     and exists (select 1 from public.games g
                 where g.id = wagers.game_id
                   and g.status in ('question_locked', 'reveal', 'leaderboard',
                                    'final_reveal', 'finished')))
  );

-- pack_reports : signalement authentifié, lecture reporter ou owner du pack.
create policy reports_insert_auth on public.pack_reports
  for insert with check (auth.uid() is not null and reporter_id = auth.uid());
create policy reports_select_mine on public.pack_reports
  for select using (
    reporter_id = auth.uid()
    or exists (select 1 from public.packs pk
               where pk.id = pack_reports.pack_id and pk.owner_id = auth.uid())
  );
