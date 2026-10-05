
-- Brainwager 0014 — social profile + avatar foundation.
-- Additive profile/onboarding model. OAuth identities stay in Supabase Auth;
-- anonymous -> OAuth linking preserves auth.users.id.
-- App-facing profile writes are RPC-only so locked avatars cannot be selected
-- by a modified client.

create table public.avatar_catalog (
  avatar_key text primary key,
  sort_order smallint not null unique,
  is_free boolean not null default true,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  constraint avatar_catalog_key_format
    check (avatar_key ~ '^[a-z0-9_]{2,32}$'),
  constraint avatar_catalog_sort_order
    check (sort_order between 0 and 999)
);

alter table public.avatar_catalog enable row level security;

insert into public.avatar_catalog (avatar_key, sort_order, is_free, is_active)
values
  ('brain', 10, true, true),
  ('rocket', 20, true, true),
  ('star', 30, true, true),
  ('bolt', 40, true, true),
  ('planet', 50, true, true),
  ('trophy', 60, true, true),
  ('football', 70, true, true),
  ('basketball', 80, true, true);

create table public.user_avatar_unlocks (
  user_id uuid not null references public.profiles(id) on delete cascade,
  avatar_key text not null references public.avatar_catalog(avatar_key) on delete restrict,
  source text not null,
  unlocked_at timestamptz not null default now(),
  primary key (user_id, avatar_key),
  constraint user_avatar_unlocks_source
    check (source in ('starter', 'reward', 'rewarded_ad', 'braincoins', 'purchase', 'admin'))
);

alter table public.user_avatar_unlocks enable row level security;

alter table public.profiles
  add column avatar_key text,
  add column onboarding_completed_at timestamptz,
  add column updated_at timestamptz not null default now();

update public.profiles
set avatar_key = 'brain'
where avatar_key is null;

alter table public.profiles
  alter column avatar_key set default 'brain',
  alter column avatar_key set not null;

alter table public.profiles
  add constraint profiles_avatar_key_fkey
  foreign key (avatar_key)
  references public.avatar_catalog(avatar_key)
  on update cascade
  on delete restrict;

-- Existing app code never directly updates profiles. Future profile writes
-- are server-authoritative through update_my_profile().
drop policy if exists profiles_update_own on public.profiles;
revoke update on public.profiles from authenticated;

-- Catalog / unlock inventory are RPC-only for clients.
revoke all privileges on public.avatar_catalog from public, anon, authenticated;
revoke all privileges on public.user_avatar_unlocks from public, anon, authenticated;

create or replace function public.get_my_profile()
returns jsonb
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_profile public.profiles%rowtype;
begin
  if auth.uid() is null then
    raise exception 'not-authenticated';
  end if;

  perform public._ensure_profile();

  select *
  into v_profile
  from public.profiles p
  where p.id = auth.uid();

  if not found then
    raise exception 'profile-not-found';
  end if;

  return jsonb_build_object(
    'id', v_profile.id,
    'display_name', v_profile.display_name,
    'locale', v_profile.locale,
    'avatar_key', v_profile.avatar_key,
    'onboarding_complete', v_profile.onboarding_completed_at is not null,
    'created_at', v_profile.created_at,
    'updated_at', v_profile.updated_at
  );
end;
$$;

create or replace function public.list_my_avatars()
returns jsonb
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_selected text;
  v_result jsonb;
begin
  if auth.uid() is null then
    raise exception 'not-authenticated';
  end if;

  perform public._ensure_profile();

  select p.avatar_key
  into v_selected
  from public.profiles p
  where p.id = auth.uid();

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'avatar_key', a.avatar_key,
        'sort_order', a.sort_order,
        'is_free', a.is_free,
        'unlocked',
          a.is_free
          or exists (
            select 1
            from public.user_avatar_unlocks u
            where u.user_id = auth.uid()
              and u.avatar_key = a.avatar_key
          ),
        'selected', a.avatar_key = v_selected
      )
      order by a.sort_order, a.avatar_key
    ),
    '[]'::jsonb
  )
  into v_result
  from public.avatar_catalog a
  where a.is_active;

  return v_result;
end;
$$;

create or replace function public.update_my_profile(
  p_display_name text,
  p_avatar_key text,
  p_locale text
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_name text := trim(coalesce(p_display_name, ''));
  v_avatar text := lower(trim(coalesce(p_avatar_key, '')));
  v_locale text := lower(trim(coalesce(p_locale, '')));
  v_profile public.profiles%rowtype;
begin
  if auth.uid() is null then
    raise exception 'not-authenticated';
  end if;

  if not public._nickname_is_clean(v_name) then
    raise exception 'invalid-display-name';
  end if;

  if v_locale not in ('fr', 'en', 'ar') then
    raise exception 'invalid-locale';
  end if;

  if not exists (
    select 1
    from public.avatar_catalog a
    where a.avatar_key = v_avatar
      and a.is_active
      and (
        a.is_free
        or exists (
          select 1
          from public.user_avatar_unlocks u
          where u.user_id = auth.uid()
            and u.avatar_key = a.avatar_key
        )
      )
  ) then
    raise exception 'avatar-locked-or-invalid';
  end if;

  perform public._ensure_profile();

  update public.profiles
  set display_name = v_name,
      avatar_key = v_avatar,
      locale = v_locale,
      onboarding_completed_at = coalesce(onboarding_completed_at, now()),
      updated_at = now()
  where id = auth.uid()
  returning * into v_profile;

  if not found then
    raise exception 'profile-not-found';
  end if;

  return jsonb_build_object(
    'id', v_profile.id,
    'display_name', v_profile.display_name,
    'locale', v_profile.locale,
    'avatar_key', v_profile.avatar_key,
    'onboarding_complete', true,
    'created_at', v_profile.created_at,
    'updated_at', v_profile.updated_at
  );
end;
$$;

revoke all on function public.get_my_profile()
from public, anon, authenticated;
grant execute on function public.get_my_profile()
to authenticated;

revoke all on function public.list_my_avatars()
from public, anon, authenticated;
grant execute on function public.list_my_avatars()
to authenticated;

revoke all on function public.update_my_profile(text, text, text)
from public, anon, authenticated;
grant execute on function public.update_my_profile(text, text, text)
to authenticated;
