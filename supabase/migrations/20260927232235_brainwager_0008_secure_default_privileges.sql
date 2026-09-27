-- Brainwager 0008 — fail-closed default privileges only.
-- Applies AFTER 0007. Future public-schema objects created by postgres grant
-- nothing to clients by default. Every future migration must explicitly GRANT
-- only what it actually needs (see AGENTS.md).
alter default privileges for role postgres in schema public
  revoke all on tables from anon, authenticated;
alter default privileges for role postgres in schema public
  revoke all on functions from public, anon, authenticated;
