-- Brainwager Phase 2 — 0004 nettoyage plan gratuit
-- pg_cron : 1×/jour. Si indisponible sur ton projet (plan gratuit),
-- exécute manuellement : select public.cleanup_old_games();
-- Source : docs/02-supabase-model.md §5. À vérifier dans Dashboard > Database > Extensions.

create extension if not exists "pg_cron";

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.schedule(
      'brainwager-cleanup',
      '0 3 * * *',
      'select public.cleanup_old_games()'
    );
  end if;
end
$$;
