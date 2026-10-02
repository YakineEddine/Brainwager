
-- Brainwager 0013 — Google Play billing authority.
-- Private purchase-token ledger + atomic entitlement application.
-- App clients never read/write google_play_purchases and never execute
-- apply_google_play_purchase directly.

create table public.google_play_purchases (
  purchase_token text primary key,
  user_id uuid references public.profiles (id) on delete set null,
  sku text not null,
  order_id text,
  obfuscated_account_id text,
  purchase_state text not null
    check (purchase_state in ('PURCHASED', 'PENDING', 'CANCELLED')),
  acknowledgement_state text not null
    check (acknowledgement_state in (
      'ACKNOWLEDGEMENT_STATE_UNSPECIFIED',
      'ACKNOWLEDGEMENT_STATE_PENDING',
      'ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED'
    )),
  consumption_state text not null
    check (consumption_state in (
      'CONSUMPTION_STATE_UNSPECIFIED',
      'CONSUMPTION_STATE_YET_TO_BE_CONSUMED',
      'CONSUMPTION_STATE_CONSUMED'
    )),
  last_verified_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index google_play_purchases_user_sku_idx
  on public.google_play_purchases (user_id, sku);

alter table public.google_play_purchases enable row level security;

-- Intentionally no RLS policies: private backend-only ledger.
revoke all on table public.google_play_purchases
from public, anon, authenticated;

create or replace function public.apply_google_play_purchase(
  p_user uuid,
  p_purchase_token text,
  p_sku text,
  p_order_id text,
  p_obfuscated_account_id text,
  p_purchase_state text,
  p_acknowledgement_state text,
  p_consumption_state text,
  p_mode text
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_existing public.google_play_purchases%rowtype;
  v_had_existing boolean := false;
  v_old_user uuid;
  v_effective_user uuid;
  v_transferred boolean := false;
  v_active boolean := false;
begin
  if p_user is null
     or p_purchase_token is null or trim(p_purchase_token) = ''
     or p_sku is null or trim(p_sku) = '' then
    raise exception 'invalid-purchase-input';
  end if;

  if p_mode not in ('verify', 'restore', 'sync') then
    raise exception 'invalid-purchase-mode';
  end if;

  if p_purchase_state not in ('PURCHASED', 'PENDING', 'CANCELLED') then
    raise exception 'invalid-purchase-state';
  end if;

  if p_acknowledgement_state not in (
      'ACKNOWLEDGEMENT_STATE_UNSPECIFIED',
      'ACKNOWLEDGEMENT_STATE_PENDING',
      'ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED'
    ) then
    raise exception 'invalid-acknowledgement-state';
  end if;

  if p_consumption_state not in (
      'CONSUMPTION_STATE_UNSPECIFIED',
      'CONSUMPTION_STATE_YET_TO_BE_CONSUMED',
      'CONSUMPTION_STATE_CONSUMED'
    ) then
    raise exception 'invalid-consumption-state';
  end if;

  -- Only known Brainwager one-time products may grant an entitlement.
  if p_sku <> 'remove_ads'
     and not exists (
       select 1
       from public.packs p
       where p.is_official
         and p.is_premium
         and p.price_sku = p_sku
     ) then
    raise exception 'billing-sku-not-allowed';
  end if;

  if not exists (select 1 from auth.users u where u.id = p_user) then
    raise exception 'billing-user-not-found';
  end if;

  insert into public.profiles (id)
  values (p_user)
  on conflict (id) do nothing;

  select *
  into v_existing
  from public.google_play_purchases
  where purchase_token = p_purchase_token
  for update;

  if found then
    v_had_existing := true;
    v_old_user := v_existing.user_id;

    if v_existing.sku <> p_sku then
      raise exception 'purchase-token-sku-mismatch';
    end if;

    if p_mode = 'verify'
       and v_existing.user_id is not null
       and v_existing.user_id <> p_user then
      raise exception 'purchase-token-already-claimed';
    end if;
  end if;

  -- A verified/restored PURCHASED token belongs to the current caller.
  -- Restore may transfer a token from an obsolete anonymous profile.
  if p_purchase_state = 'PURCHASED' then
    v_effective_user := p_user;
    v_transferred := v_had_existing
      and v_old_user is not null
      and v_old_user <> p_user;
  else
    -- Pending/cancelled state stays attached to its existing owner when known.
    v_effective_user := coalesce(v_old_user, p_user);
  end if;

  insert into public.google_play_purchases (
    purchase_token,
    user_id,
    sku,
    order_id,
    obfuscated_account_id,
    purchase_state,
    acknowledgement_state,
    consumption_state,
    last_verified_at,
    updated_at
  ) values (
    p_purchase_token,
    v_effective_user,
    p_sku,
    nullif(trim(coalesce(p_order_id, '')), ''),
    nullif(trim(coalesce(p_obfuscated_account_id, '')), ''),
    p_purchase_state,
    p_acknowledgement_state,
    p_consumption_state,
    now(),
    now()
  )
  on conflict (purchase_token) do update
  set user_id = excluded.user_id,
      sku = excluded.sku,
      order_id = excluded.order_id,
      obfuscated_account_id = excluded.obfuscated_account_id,
      purchase_state = excluded.purchase_state,
      acknowledgement_state = excluded.acknowledgement_state,
      consumption_state = excluded.consumption_state,
      last_verified_at = now(),
      updated_at = now();

  if p_purchase_state = 'PURCHASED'
     and p_consumption_state <> 'CONSUMPTION_STATE_CONSUMED' then
    insert into public.entitlements (user_id, sku, is_active, verified_at)
    values (v_effective_user, p_sku, true, now())
    on conflict (user_id, sku) do update
    set is_active = true,
        verified_at = now();

    v_active := true;

    -- Restore transfer: remove the old anonymous profile's entitlement only
    -- when it has no other still-purchased token for this SKU.
    if v_transferred then
      update public.entitlements e
      set is_active = false,
          verified_at = now()
      where e.user_id = v_old_user
        and e.sku = p_sku
        and not exists (
          select 1
          from public.google_play_purchases gp
          where gp.user_id = v_old_user
            and gp.sku = p_sku
            and gp.purchase_state = 'PURCHASED'
            and gp.consumption_state <> 'CONSUMPTION_STATE_CONSUMED'
        );
    end if;
  else
    -- Pending/cancelled/consumed: fail closed, but don't revoke if another
    -- valid token still backs the same SKU for the same user.
    update public.entitlements e
    set is_active = false,
        verified_at = now()
    where e.user_id = v_effective_user
      and e.sku = p_sku
      and not exists (
        select 1
        from public.google_play_purchases gp
        where gp.user_id = v_effective_user
          and gp.sku = p_sku
          and gp.purchase_state = 'PURCHASED'
          and gp.consumption_state <> 'CONSUMPTION_STATE_CONSUMED'
      );

    v_active := false;
  end if;

  return jsonb_build_object(
    'active', v_active,
    'transferred', v_transferred,
    'sku', p_sku,
    'purchase_state', p_purchase_state
  );
end;
$$;

revoke all on function public.apply_google_play_purchase(
  uuid, text, text, text, text, text, text, text, text
) from public, anon, authenticated;

grant execute on function public.apply_google_play_purchase(
  uuid, text, text, text, text, text, text, text, text
) to service_role;
