-- Brainwager 0007 — Realtime publication as a true allowlist.
-- Applies AFTER 0006. Publication `supabase_realtime` must contain EXACTLY
-- the five durable game-state tables. Any other public table found in the
-- publication is removed (never packs/questions/profiles/entitlements/
-- pack_reports, and never question_answers_private/game_questions).
-- Idempotent; guarded on publication existence. Broadcast/Presence RLS
-- is a separate upcoming Realtime ticket (not configured here).
do $$
declare
  t text;
begin
  if not exists (select 1 from pg_publication
                 where pubname = 'supabase_realtime') then
    return;
  end if;
  -- 1. Add any missing allowed table.
  for t in select unnest(array['games', 'players', 'player_answers',
                               'wagers', 'teams']) loop
    if not exists (select 1 from pg_publication_tables
                   where pubname = 'supabase_realtime'
                     and schemaname = 'public' and tablename = t) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
  -- 2-3. Remove every public table NOT in the five-table allowlist.
  for t in select pgt.tablename from pg_publication_tables pgt
           where pgt.pubname = 'supabase_realtime'
             and pgt.schemaname = 'public'
             and pgt.tablename <> all (array['games', 'players',
                                            'player_answers', 'wagers', 'teams']) loop
    execute format('alter publication supabase_realtime drop table public.%I', t);
  end loop;
end
$$;
