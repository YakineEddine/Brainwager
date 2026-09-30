
-- Brainwager 0011 — Phase 3B UGC server authority.
-- Secure UGC creation/editing, private answers, sharing and reporting.

alter table public.packs
  add column if not exists ugc_terms_accepted_at timestamptz;

alter table public.packs
  drop constraint if exists packs_ugc_terms_required;
alter table public.packs
  add constraint packs_ugc_terms_required
  check (is_official or ugc_terms_accepted_at is not null)
  not valid;
alter table public.packs
  validate constraint packs_ugc_terms_required;

alter table public.packs
  drop constraint if exists packs_ugc_not_premium;
alter table public.packs
  add constraint packs_ugc_not_premium
  check (is_official or (not is_premium and price_sku is null))
  not valid;
alter table public.packs
  validate constraint packs_ugc_not_premium;

alter table public.packs
  drop constraint if exists packs_ugc_share_code_format;
alter table public.packs
  add constraint packs_ugc_share_code_format
  check (is_official or share_code ~ '^PK-[A-Z0-9]{4}$')
  not valid;
alter table public.packs
  validate constraint packs_ugc_share_code_format;

-- All UGC writes now go through validated SECURITY DEFINER RPCs.
drop policy if exists packs_insert_auth on public.packs;
drop policy if exists packs_update_owner on public.packs;
drop policy if exists packs_delete_owner on public.packs;

drop policy if exists questions_insert_owner on public.questions;
drop policy if exists questions_update_owner on public.questions;
drop policy if exists questions_delete_owner on public.questions;

drop policy if exists reports_insert_auth on public.pack_reports;

revoke insert, update, delete on public.packs from authenticated;
revoke insert, update, delete on public.questions from authenticated;
revoke insert on public.pack_reports from authenticated;

-- Internal transactional writer. It owns all validation for UGC question
-- payloads and is never callable by app roles.
create or replace function public._replace_ugc_questions(
  p_pack uuid,
  p_questions jsonb
)
returns void
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_count integer;
  v_item jsonb;
  v_ord bigint;
  v_prompt_fr text;
  v_prompt_en text;
  v_category text;
  v_difficulty integer;
  v_mode text;
  v_answer_fr text;
  v_answer_en text;
  v_aliases_fr text[];
  v_aliases_en text[];
  v_alias_json jsonb;
  v_q uuid;
begin
  if auth.uid() is null then
    raise exception 'not-authenticated';
  end if;

  if not exists (
    select 1
    from public.packs p
    where p.id = p_pack
      and p.owner_id = auth.uid()
      and not p.is_official
  ) then
    raise exception 'pack-not-editable';
  end if;

  if p_questions is null or jsonb_typeof(p_questions) <> 'array' then
    raise exception 'invalid-questions';
  end if;

  v_count := jsonb_array_length(p_questions);
  if v_count < 11 then
    raise exception 'pack-too-small';
  end if;
  if v_count > 100 then
    raise exception 'pack-too-large';
  end if;

  -- Safe only when the public RPC has established that no game references
  -- this pack; any later validation error rolls the whole transaction back.
  delete from public.questions q where q.pack_id = p_pack;

  for v_item, v_ord in
    select e.value, e.ordinality
    from jsonb_array_elements(p_questions) with ordinality as e(value, ordinality)
  loop
    if jsonb_typeof(v_item) <> 'object' then
      raise exception 'invalid-question';
    end if;

    v_prompt_fr := trim(coalesce(v_item->>'prompt_fr', ''));
    v_prompt_en := trim(coalesce(v_item->>'prompt_en', ''));
    v_answer_fr := trim(coalesce(v_item->>'answer_main_fr', ''));
    v_answer_en := trim(coalesce(v_item->>'answer_main_en', ''));
    v_category := trim(coalesce(v_item->>'category', 'general'));
    v_mode := lower(trim(coalesce(v_item->>'match_mode', 'fuzzy')));

    if char_length(v_prompt_fr) < 2 or char_length(v_prompt_fr) > 500
       or char_length(v_prompt_en) < 2 or char_length(v_prompt_en) > 500 then
      raise exception 'invalid-question';
    end if;

    if char_length(v_answer_fr) < 1 or char_length(v_answer_fr) > 200
       or char_length(v_answer_en) < 1 or char_length(v_answer_en) > 200 then
      raise exception 'invalid-answer';
    end if;

    if char_length(v_category) < 1 or char_length(v_category) > 40 then
      raise exception 'invalid-category';
    end if;

    begin
      v_difficulty := (v_item->>'difficulty')::integer;
    exception when invalid_text_representation or null_value_not_allowed then
      raise exception 'invalid-difficulty';
    end;

    if v_difficulty not between 1 and 3 then
      raise exception 'invalid-difficulty';
    end if;

    if v_mode not in ('exact', 'fuzzy') then
      raise exception 'invalid-match-mode';
    end if;

    -- Numeric answers (including years) are always exact, mirroring the
    -- game-engine/server matching contract.
    if v_answer_fr ~ '^-?[0-9]+([.,][0-9]+)?$'
       or v_answer_en ~ '^-?[0-9]+([.,][0-9]+)?$' then
      v_mode := 'exact';
    end if;

    if coalesce(v_item->>'image_url', '') <> '' then
      raise exception 'ugc-image-forbidden';
    end if;

    v_alias_json := case
      when not (v_item ? 'aliases_fr') or v_item->'aliases_fr' = 'null'::jsonb
        then '[]'::jsonb
      else v_item->'aliases_fr'
    end;
    if jsonb_typeof(v_alias_json) <> 'array'
       or exists (
         select 1 from jsonb_array_elements(v_alias_json) a
         where jsonb_typeof(a) <> 'string'
       ) then
      raise exception 'invalid-aliases';
    end if;
    if jsonb_array_length(v_alias_json) > 20 then
      raise exception 'too-many-aliases';
    end if;
    select coalesce(array_agg(trim(x)) filter (where trim(x) <> ''), '{}'::text[])
    into v_aliases_fr
    from jsonb_array_elements_text(v_alias_json) x;
    if exists (
      select 1 from unnest(v_aliases_fr) a where char_length(a) > 100
    ) then
      raise exception 'invalid-aliases';
    end if;

    v_alias_json := case
      when not (v_item ? 'aliases_en') or v_item->'aliases_en' = 'null'::jsonb
        then '[]'::jsonb
      else v_item->'aliases_en'
    end;
    if jsonb_typeof(v_alias_json) <> 'array'
       or exists (
         select 1 from jsonb_array_elements(v_alias_json) a
         where jsonb_typeof(a) <> 'string'
       ) then
      raise exception 'invalid-aliases';
    end if;
    if jsonb_array_length(v_alias_json) > 20 then
      raise exception 'too-many-aliases';
    end if;
    select coalesce(array_agg(trim(x)) filter (where trim(x) <> ''), '{}'::text[])
    into v_aliases_en
    from jsonb_array_elements_text(v_alias_json) x;
    if exists (
      select 1 from unnest(v_aliases_en) a where char_length(a) > 100
    ) then
      raise exception 'invalid-aliases';
    end if;

    insert into public.questions (
      pack_id,
      idx,
      prompt_fr,
      prompt_en,
      image_url,
      category,
      difficulty,
      match_mode
    )
    values (
      p_pack,
      (v_ord - 1)::integer,
      v_prompt_fr,
      v_prompt_en,
      null,
      v_category,
      v_difficulty,
      v_mode
    )
    returning id into v_q;

    insert into public.question_answers_private (
      question_id,
      answer_main_fr,
      answer_main_en,
      aliases_fr,
      aliases_en
    )
    values (
      v_q,
      v_answer_fr,
      v_answer_en,
      v_aliases_fr,
      v_aliases_en
    );
  end loop;
end;
$$;

revoke all on function public._replace_ugc_questions(uuid, jsonb)
from public, anon, authenticated;

create or replace function public.create_ugc_pack(
  p_title_fr text,
  p_title_en text,
  p_desc_fr text,
  p_desc_en text,
  p_questions jsonb,
  p_accept_terms boolean
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_title_fr text := trim(coalesce(p_title_fr, ''));
  v_title_en text := trim(coalesce(p_title_en, ''));
  v_desc_fr text := trim(coalesce(p_desc_fr, ''));
  v_desc_en text := trim(coalesce(p_desc_en, ''));
  v_code text;
  v_pack uuid;
  v_constraint text;
begin
  if auth.uid() is null then
    raise exception 'not-authenticated';
  end if;

  if p_accept_terms is distinct from true then
    raise exception 'terms-required';
  end if;

  if char_length(v_title_fr) < 2 or char_length(v_title_fr) > 80
     or char_length(v_title_en) < 2 or char_length(v_title_en) > 80 then
    raise exception 'invalid-title';
  end if;

  if char_length(v_desc_fr) > 500 or char_length(v_desc_en) > 500 then
    raise exception 'invalid-description';
  end if;

  perform public._ensure_profile();

  loop
    v_code := 'PK-' || public._gen_code(4);

    begin
      insert into public.packs (
        owner_id,
        title_fr,
        title_en,
        desc_fr,
        desc_en,
        is_official,
        is_premium,
        price_sku,
        share_code,
        report_count,
        is_hidden,
        ugc_terms_accepted_at
      )
      values (
        auth.uid(),
        v_title_fr,
        v_title_en,
        v_desc_fr,
        v_desc_en,
        false,
        false,
        null,
        v_code,
        0,
        false,
        now()
      )
      returning id into v_pack;

      exit;
    exception when unique_violation then
      get stacked diagnostics v_constraint = constraint_name;
      if v_constraint = 'packs_share_code_key' then
        continue;
      end if;
      raise;
    end;
  end loop;

  perform public._replace_ugc_questions(v_pack, p_questions);

  return jsonb_build_object(
    'id', v_pack,
    'share_code', v_code
  );
end;
$$;

create or replace function public.update_ugc_pack(
  p_pack uuid,
  p_title_fr text,
  p_title_en text,
  p_desc_fr text,
  p_desc_en text,
  p_questions jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_pack record;
  v_title_fr text := trim(coalesce(p_title_fr, ''));
  v_title_en text := trim(coalesce(p_title_en, ''));
  v_desc_fr text := trim(coalesce(p_desc_fr, ''));
  v_desc_en text := trim(coalesce(p_desc_en, ''));
begin
  if auth.uid() is null then
    raise exception 'not-authenticated';
  end if;

  select *
  into v_pack
  from public.packs p
  where p.id = p_pack;

  if not found then
    raise exception 'pack-not-found';
  end if;

  if v_pack.is_official or v_pack.owner_id is distinct from auth.uid() then
    raise exception 'pack-not-editable';
  end if;

  -- game_questions points to live question rows. Refuse content mutation while
  -- any game still references the pack so an editor cannot alter a live or
  -- retained game snapshot. Cleanup later releases the pack for editing.
  if exists (
    select 1 from public.games g where g.pack_id = p_pack
  ) then
    raise exception 'pack-in-use';
  end if;

  if char_length(v_title_fr) < 2 or char_length(v_title_fr) > 80
     or char_length(v_title_en) < 2 or char_length(v_title_en) > 80 then
    raise exception 'invalid-title';
  end if;

  if char_length(v_desc_fr) > 500 or char_length(v_desc_en) > 500 then
    raise exception 'invalid-description';
  end if;

  update public.packs
  set title_fr = v_title_fr,
      title_en = v_title_en,
      desc_fr = v_desc_fr,
      desc_en = v_desc_en
  where id = p_pack;

  perform public._replace_ugc_questions(p_pack, p_questions);

  return jsonb_build_object(
    'id', p_pack,
    'share_code', v_pack.share_code
  );
end;
$$;

create or replace function public.get_ugc_pack_for_edit(
  p_pack uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_catalog
as $$
declare
  v_pack record;
  v_questions jsonb;
begin
  if auth.uid() is null then
    raise exception 'not-authenticated';
  end if;

  select *
  into v_pack
  from public.packs p
  where p.id = p_pack;

  if not found then
    raise exception 'pack-not-found';
  end if;

  if v_pack.is_official or v_pack.owner_id is distinct from auth.uid() then
    raise exception 'pack-not-editable';
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'idx', q.idx,
        'prompt_fr', q.prompt_fr,
        'prompt_en', q.prompt_en,
        'category', q.category,
        'difficulty', q.difficulty,
        'match_mode', q.match_mode,
        'answer_main_fr', a.answer_main_fr,
        'answer_main_en', a.answer_main_en,
        'aliases_fr', a.aliases_fr,
        'aliases_en', a.aliases_en
      )
      order by q.idx
    ),
    '[]'::jsonb
  )
  into v_questions
  from public.questions q
  join public.question_answers_private a on a.question_id = q.id
  where q.pack_id = p_pack;

  return jsonb_build_object(
    'id', v_pack.id,
    'title_fr', v_pack.title_fr,
    'title_en', v_pack.title_en,
    'desc_fr', v_pack.desc_fr,
    'desc_en', v_pack.desc_en,
    'share_code', v_pack.share_code,
    'is_hidden', v_pack.is_hidden,
    'terms_accepted_at', v_pack.ugc_terms_accepted_at,
    'questions', v_questions
  );
end;
$$;

-- Share lookup: official packs expose only the same 3-question preview;
-- shared UGC exposes all prompts/matching metadata but never answers/aliases.
create or replace function public.get_pack_by_share_code(
  p_code text
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_catalog
as $$
declare
  v_pack record;
  v_questions jsonb;
begin
  if auth.uid() is null then
    raise exception 'not-authenticated';
  end if;

  select *
  into v_pack
  from public.packs p
  where p.share_code = upper(trim(p_code))
    and not p.is_hidden;

  if not found then
    raise exception 'pack-not-found';
  end if;

  if v_pack.is_official then
    select coalesce(jsonb_agg(t order by t.idx), '[]'::jsonb)
    into v_questions
    from (
      select q.idx, q.prompt_fr, q.prompt_en, q.category, q.difficulty
      from public.questions q
      where q.pack_id = v_pack.id
      order by q.idx
      limit 3
    ) t;
  else
    select coalesce(jsonb_agg(t order by t.idx), '[]'::jsonb)
    into v_questions
    from (
      select q.idx, q.prompt_fr, q.prompt_en, q.category, q.difficulty, q.match_mode
      from public.questions q
      where q.pack_id = v_pack.id
      order by q.idx
    ) t;
  end if;

  return jsonb_build_object(
    'id', v_pack.id,
    'title_fr', v_pack.title_fr,
    'title_en', v_pack.title_en,
    'desc_fr', v_pack.desc_fr,
    'desc_en', v_pack.desc_en,
    'is_official', v_pack.is_official,
    'is_premium', v_pack.is_premium,
    'price_sku', v_pack.price_sku,
    'share_code', v_pack.share_code,
    'is_owned', v_pack.owner_id = auth.uid(),
    'question_count', (
      select count(*) from public.questions q where q.pack_id = v_pack.id
    ),
    'questions', v_questions
  );
end;
$$;

create or replace function public.report_pack(
  p_pack uuid,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_pack record;
  v_reason text := trim(coalesce(p_reason, ''));
  v_report uuid;
  v_already boolean := false;
begin
  if auth.uid() is null then
    raise exception 'not-authenticated';
  end if;

  if char_length(v_reason) < 3 or char_length(v_reason) > 500 then
    raise exception 'invalid-report-reason';
  end if;

  select *
  into v_pack
  from public.packs p
  where p.id = p_pack
    and not p.is_hidden;

  if not found then
    raise exception 'pack-not-found';
  end if;

  if v_pack.owner_id = auth.uid() then
    raise exception 'cannot-report-own-pack';
  end if;

  perform public._ensure_profile();

  insert into public.pack_reports (pack_id, reporter_id, reason)
  values (p_pack, auth.uid(), v_reason)
  on conflict (pack_id, reporter_id) do nothing
  returning id into v_report;

  if v_report is null then
    v_already := true;
    update public.pack_reports
    set reason = v_reason,
        created_at = now()
    where pack_id = p_pack
      and reporter_id = auth.uid();
  else
    update public.packs
    set report_count = report_count + 1
    where id = p_pack;
  end if;

  return jsonb_build_object(
    'reported', true,
    'already_reported', v_already
  );
end;
$$;

-- App-facing RPC grants: authenticated Supabase Auth users only.
revoke all on function public.create_ugc_pack(text, text, text, text, jsonb, boolean)
from public, anon, authenticated;
grant execute on function public.create_ugc_pack(text, text, text, text, jsonb, boolean)
to authenticated;

revoke all on function public.update_ugc_pack(uuid, text, text, text, text, jsonb)
from public, anon, authenticated;
grant execute on function public.update_ugc_pack(uuid, text, text, text, text, jsonb)
to authenticated;

revoke all on function public.get_ugc_pack_for_edit(uuid)
from public, anon, authenticated;
grant execute on function public.get_ugc_pack_for_edit(uuid)
to authenticated;

revoke all on function public.get_pack_by_share_code(text)
from public, anon, authenticated;
grant execute on function public.get_pack_by_share_code(text)
to authenticated;

revoke all on function public.report_pack(uuid, text)
from public, anon, authenticated;
grant execute on function public.report_pack(uuid, text)
to authenticated;
