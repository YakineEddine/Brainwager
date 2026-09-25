-- Brainwager Phase 2 — 0001 schéma
-- 11 tables (doc 02 révisé). RLS activée ici, policies en 0002, RPC en 0003.
-- Source règles : docs/02-supabase-model.md (relire avant d'appliquer).

create extension if not exists "pgcrypto";
create extension if not exists "unaccent";
create extension if not exists "fuzzystrmatch";

-- Profils (1 ligne par user anon). AUCUN flag premium ici (voir entitlements).
create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text,
  locale text not null default 'fr' check (locale in ('fr', 'en')),
  created_at timestamptz not null default now()
);

-- Droits validés serveur uniquement. Écriture service_role (Edge Function).
create table public.entitlements (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  sku text not null,
  is_active boolean not null default true,
  verified_at timestamptz not null default now(),
  unique (user_id, sku)
);

create table public.packs (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid references public.profiles (id) on delete set null,
  title_fr text not null,
  title_en text not null,
  desc_fr text not null default '',
  desc_en text not null default '',
  is_official boolean not null default false,
  is_premium boolean not null default false,
  price_sku text,
  share_code text unique not null,
  report_count integer not null default 0,
  is_hidden boolean not null default false,
  created_at timestamptz not null default now()
);

create table public.questions (
  id uuid primary key default gen_random_uuid(),
  pack_id uuid not null references public.packs (id) on delete cascade,
  idx integer not null,
  prompt_fr text not null,
  prompt_en text not null,
  image_url text, -- officiels uniquement (UGC v1 : NULL imposé en RPC d'édition)
  category text not null default 'general',
  difficulty smallint not null check (difficulty between 1 and 3),
  match_mode text not null default 'fuzzy' check (match_mode in ('exact', 'fuzzy')),
  unique (pack_id, idx)
);

-- Table sensible : AUCUNE policy SELECT (voir 0002 : aucune policy = refus).
create table public.question_answers_private (
  question_id uuid primary key references public.questions (id) on delete cascade,
  answer_main_fr text not null,
  answer_main_en text not null,
  aliases_fr text[] not null default '{}',
  aliases_en text[] not null default '{}'
);

create table public.games (
  id uuid primary key default gen_random_uuid(),
  join_code text unique not null,
  host_id uuid references public.profiles (id) on delete set null,
  pack_id uuid references public.packs (id) on delete set null,
  language text not null default 'fr' check (language in ('fr', 'en')),
  status text not null default 'lobby'
    check (status in ('lobby', 'question_open', 'question_locked', 'reveal',
                      'leaderboard', 'final_wager', 'final_reveal', 'finished')),
  team_mode boolean not null default false,
  current_question_idx integer not null default 0 check (current_question_idx between 0 and 10),
  question_opened_at timestamptz,
  question_duration_sec integer not null default 30 check (question_duration_sec > 0),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '24 hours')
);

-- Tirage de la partie : 11 lignes posées par create_game. AUCUNE lecture directe.
create table public.game_questions (
  game_id uuid not null references public.games (id) on delete cascade,
  position integer not null check (position between 0 and 10),
  question_id uuid not null references public.questions (id) on delete restrict,
  primary key (game_id, position),
  unique (game_id, question_id)
);

create table public.teams (
  id uuid primary key default gen_random_uuid(),
  game_id uuid not null references public.games (id) on delete cascade,
  name text not null,
  color_idx integer not null default 0,
  unique (game_id, name)
);

create table public.players (
  id uuid primary key default gen_random_uuid(),
  game_id uuid not null references public.games (id) on delete cascade,
  user_id uuid references public.profiles (id) on delete set null,
  nickname text not null check (char_length(nickname) between 2 and 20),
  team_id uuid references public.teams (id) on delete set null,
  score integer not null default 0,
  best_streak integer not null default 0,
  biggest_wager_won integer not null default 0,
  is_host boolean not null default false,
  is_connected boolean not null default true,
  last_seen_at timestamptz not null default now(),
  unique (game_id, nickname),
  unique (game_id, user_id)
);

create table public.player_answers (
  id uuid primary key default gen_random_uuid(),
  game_id uuid not null references public.games (id) on delete cascade,
  player_id uuid not null references public.players (id) on delete cascade,
  question_idx integer not null check (question_idx between 0 and 10),
  answer_text text not null,
  is_correct boolean,
  is_overridden boolean not null default false,
  scored_points integer not null default 0,
  created_at timestamptz not null default now(),
  unique (game_id, player_id, question_idx)
);

create table public.wagers (
  id uuid primary key default gen_random_uuid(),
  game_id uuid not null references public.games (id) on delete cascade,
  player_id uuid not null references public.players (id) on delete cascade,
  question_idx integer not null check (question_idx between 0 and 10),
  amount integer not null,
  unique (game_id, player_id, question_idx),
  check ((question_idx < 10 and amount between 1 and 10)
      or (question_idx = 10 and amount in (0, 10, 20)))
);

-- Unicité des mises 1..10 (règle métier) : la base tranche, même si client piraté.
create unique index wagers_unique_amount_per_player
  on public.wagers (game_id, player_id, amount)
  where question_idx < 10;

create table public.pack_reports (
  id uuid primary key default gen_random_uuid(),
  pack_id uuid not null references public.packs (id) on delete cascade,
  reporter_id uuid references public.profiles (id) on delete set null,
  reason text not null,
  created_at timestamptz not null default now(),
  unique (pack_id, reporter_id)
);

create index players_game_idx on public.players (game_id);
create index answers_game_idx on public.player_answers (game_id, question_idx);
create index wagers_game_idx on public.wagers (game_id, question_idx);
create index game_questions_game_idx on public.game_questions (game_id);

alter table public.profiles enable row level security;
alter table public.entitlements enable row level security;
alter table public.packs enable row level security;
alter table public.questions enable row level security;
alter table public.question_answers_private enable row level security;
alter table public.games enable row level security;
alter table public.game_questions enable row level security;
alter table public.teams enable row level security;
alter table public.players enable row level security;
alter table public.player_answers enable row level security;
alter table public.wagers enable row level security;
alter table public.pack_reports enable row level security;
