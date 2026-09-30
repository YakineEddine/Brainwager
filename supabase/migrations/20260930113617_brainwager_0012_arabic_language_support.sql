
-- Brainwager 0012 — Arabic language support.
-- Adds Arabic content, Arabic-aware answer matching and trilingual UGC RPCs.

alter table public.packs
  add column if not exists title_ar text not null default '',
  add column if not exists desc_ar text not null default '';

alter table public.questions
  add column if not exists prompt_ar text not null default '';

alter table public.question_answers_private
  add column if not exists answer_main_ar text not null default '',
  add column if not exists aliases_ar text[] not null default '{}';

alter table public.profiles drop constraint if exists profiles_locale_check;
alter table public.profiles
  add constraint profiles_locale_check check (locale in ('fr', 'en', 'ar'));

alter table public.games drop constraint if exists games_language_check;
alter table public.games
  add constraint games_language_check check (language in ('fr', 'en', 'ar'));

update public.packs
set title_ar = 'سهرة تجريبية',
    desc_ar = 'حزمة اختبار للمرحلة 2'
where share_code = 'DEMO01';

update public.questions q
set prompt_ar = v.prompt_ar
from (
  values
    (0, 'ماذا يُسمّى المثلث الذي تتساوى أضلاعه الثلاثة؟'),
    (1, 'ما الآلة الموسيقية ذات الأوتار الستة التي تُستخدم كثيرًا في السهرات؟'),
    (2, 'ما اللون الناتج عن مزج الأزرق والأصفر؟'),
    (3, 'ما عاصمة البرتغال؟'),
    (4, 'كم عدد لاعبي فريق كرة القدم على أرض الملعب؟'),
    (5, 'ما الجرم السماوي الذي يضيء ليالينا بعكس ضوء الشمس؟'),
    (6, 'في أي مدينة يوجد البرج المائل الشهير؟'),
    (7, 'ما المعدن النفيس الذي رمزه الكيميائي Au؟'),
    (8, 'في أي عام مشى الإنسان على القمر لأول مرة؟'),
    (9, 'ما المحيط الذي يحد الساحل الغربي لفرنسا؟'),
    (10, 'ما النهر الذي يمر عبر مدينة القاهرة قبل أن يصب في البحر؟')
) as v(idx, prompt_ar),
public.packs p
where p.id = q.pack_id
  and p.share_code = 'DEMO01'
  and q.idx = v.idx;

update public.question_answers_private a
set answer_main_ar = v.answer_ar,
    aliases_ar = v.aliases_ar
from (
  values
    (0, 'متساوي الأضلاع', array['مثلث متساوي الأضلاع']::text[]),
    (1, 'غيتار', array['جيتار','قيثارة']::text[]),
    (2, 'أخضر', array['اللون الأخضر']::text[]),
    (3, 'لشبونة', array['ليشبونة','لسبونة']::text[]),
    (4, '11', array['١١','أحد عشر']::text[]),
    (5, 'القمر', array['قمر']::text[]),
    (6, 'بيزا', array['بيزا الإيطالية']::text[]),
    (7, 'الذهب', array['ذهب']::text[]),
    (8, '1969', array['١٩٦٩']::text[]),
    (9, 'المحيط الأطلسي', array['الأطلسي','المحيط الأطلنطي','الأطلنطي']::text[]),
    (10, 'النيل', array['نيل']::text[])
) as v(idx, answer_ar, aliases_ar),
public.questions q,
public.packs p
where q.id = a.question_id
  and p.id = q.pack_id
  and p.share_code = 'DEMO01'
  and q.idx = v.idx;

create or replace function public.normalize_answer(p_raw text)
returns text
language plpgsql
immutable
security definer
set search_path = public, extensions
as $$
declare
  v text;
begin
  if p_raw is null then return ''; end if;
  v := lower(trim(p_raw));

  begin
    v := unaccent(v);
  exception when undefined_function then
    v := translate(v, 'àâäéèêëîïôöùûüÿçñ', 'aaaeeeeiioouuuycn');
  end;

  v := translate(v, '٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹', '01234567890123456789');
  v := translate(v, 'أإآٱى', 'ااااي');
  v := replace(v, 'ـ', '');
  v := regexp_replace(v, '[ؐ-ًؚ-ٰٟۖ-ۭ]', '', 'g');
  v := replace(v, '٫', '.');
  v := replace(v, '٬', '');

  v := regexp_replace(v, '[’‘''ʼ`]', '''', 'g');
  v := regexp_replace(v, '[^a-z0-9ء-ي\s\-]', ' ', 'g');
  v := regexp_replace(v, '\s+', ' ', 'g');
  v := trim(v);
  v := regexp_replace(v, '^(le|la|les|un|une|des|the|a|an|l|d)\s+', '', 'i');

  if v ~ '^ال[ء-ي]' then
    v := substr(v, 3);
  end if;

  v := replace(v, ',', '.');
  return v;
end;
$$;

revoke all on function public.normalize_answer(text)
from public, anon, authenticated;


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
  v_prompt_ar text;
  v_category text;
  v_difficulty integer;
  v_mode text;
  v_answer_fr text;
  v_answer_en text;
  v_answer_ar text;
  v_aliases_fr text[];
  v_aliases_en text[];
  v_aliases_ar text[];
  v_alias_json jsonb;
  v_q uuid;
  v_has_existing_ar boolean;
begin
  if auth.uid() is null then raise exception 'not-authenticated'; end if;

  if not exists (
    select 1 from public.packs p
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
  if v_count < 11 then raise exception 'pack-too-small'; end if;
  if v_count > 100 then raise exception 'pack-too-large'; end if;

  select exists (
    select 1
    from public.questions q
    join public.question_answers_private a on a.question_id = q.id
    where q.pack_id = p_pack
      and (trim(q.prompt_ar) <> '' or trim(a.answer_main_ar) <> '')
  ) into v_has_existing_ar;

  if v_has_existing_ar and exists (
    select 1
    from jsonb_array_elements(p_questions) e(value)
    where not (e.value ? 'prompt_ar')
       or not (e.value ? 'answer_main_ar')
  ) then
    raise exception 'arabic-content-required';
  end if;

  delete from public.questions q where q.pack_id = p_pack;

  for v_item, v_ord in
    select e.value, e.ordinality
    from jsonb_array_elements(p_questions) with ordinality as e(value, ordinality)
  loop
    if jsonb_typeof(v_item) <> 'object' then raise exception 'invalid-question'; end if;

    v_prompt_fr := trim(coalesce(v_item->>'prompt_fr', ''));
    v_prompt_en := trim(coalesce(v_item->>'prompt_en', ''));
    v_prompt_ar := trim(coalesce(v_item->>'prompt_ar', ''));
    v_answer_fr := trim(coalesce(v_item->>'answer_main_fr', ''));
    v_answer_en := trim(coalesce(v_item->>'answer_main_en', ''));
    v_answer_ar := trim(coalesce(v_item->>'answer_main_ar', ''));
    v_category := trim(coalesce(v_item->>'category', 'general'));
    v_mode := lower(trim(coalesce(v_item->>'match_mode', 'fuzzy')));

    if char_length(v_prompt_fr) < 2 or char_length(v_prompt_fr) > 500
       or char_length(v_prompt_en) < 2 or char_length(v_prompt_en) > 500 then
      raise exception 'invalid-question';
    end if;

    if v_prompt_ar <> ''
       and (char_length(v_prompt_ar) < 2 or char_length(v_prompt_ar) > 500) then
      raise exception 'invalid-question';
    end if;

    if char_length(v_answer_fr) < 1 or char_length(v_answer_fr) > 200
       or char_length(v_answer_en) < 1 or char_length(v_answer_en) > 200 then
      raise exception 'invalid-answer';
    end if;

    if v_answer_ar <> ''
       and (char_length(v_answer_ar) < 1 or char_length(v_answer_ar) > 200) then
      raise exception 'invalid-answer';
    end if;

    if (v_prompt_ar = '') <> (v_answer_ar = '') then
      raise exception 'invalid-arabic-content';
    end if;

    if char_length(v_category) < 1 or char_length(v_category) > 40 then
      raise exception 'invalid-category';
    end if;

    begin
      v_difficulty := (v_item->>'difficulty')::integer;
    exception when invalid_text_representation or null_value_not_allowed then
      raise exception 'invalid-difficulty';
    end;

    if v_difficulty not between 1 and 3 then raise exception 'invalid-difficulty'; end if;
    if v_mode not in ('exact', 'fuzzy') then raise exception 'invalid-match-mode'; end if;

    if public.is_numeric_like(public.normalize_answer(v_answer_fr))
       or public.is_numeric_like(public.normalize_answer(v_answer_en))
       or (v_answer_ar <> ''
           and public.is_numeric_like(public.normalize_answer(v_answer_ar))) then
      v_mode := 'exact';
    end if;

    if coalesce(v_item->>'image_url', '') <> '' then raise exception 'ugc-image-forbidden'; end if;

    v_alias_json := case
      when not (v_item ? 'aliases_fr') or v_item->'aliases_fr' = 'null'::jsonb
        then '[]'::jsonb else v_item->'aliases_fr' end;
    if jsonb_typeof(v_alias_json) <> 'array'
       or exists (select 1 from jsonb_array_elements(v_alias_json) a
                  where jsonb_typeof(a) <> 'string') then
      raise exception 'invalid-aliases';
    end if;
    if jsonb_array_length(v_alias_json) > 20 then raise exception 'too-many-aliases'; end if;
    select coalesce(array_agg(trim(x)) filter (where trim(x) <> ''), '{}'::text[])
    into v_aliases_fr from jsonb_array_elements_text(v_alias_json) x;
    if exists (select 1 from unnest(v_aliases_fr) a where char_length(a) > 100) then
      raise exception 'invalid-aliases';
    end if;

    v_alias_json := case
      when not (v_item ? 'aliases_en') or v_item->'aliases_en' = 'null'::jsonb
        then '[]'::jsonb else v_item->'aliases_en' end;
    if jsonb_typeof(v_alias_json) <> 'array'
       or exists (select 1 from jsonb_array_elements(v_alias_json) a
                  where jsonb_typeof(a) <> 'string') then
      raise exception 'invalid-aliases';
    end if;
    if jsonb_array_length(v_alias_json) > 20 then raise exception 'too-many-aliases'; end if;
    select coalesce(array_agg(trim(x)) filter (where trim(x) <> ''), '{}'::text[])
    into v_aliases_en from jsonb_array_elements_text(v_alias_json) x;
    if exists (select 1 from unnest(v_aliases_en) a where char_length(a) > 100) then
      raise exception 'invalid-aliases';
    end if;

    v_alias_json := case
      when not (v_item ? 'aliases_ar') or v_item->'aliases_ar' = 'null'::jsonb
        then '[]'::jsonb else v_item->'aliases_ar' end;
    if jsonb_typeof(v_alias_json) <> 'array'
       or exists (select 1 from jsonb_array_elements(v_alias_json) a
                  where jsonb_typeof(a) <> 'string') then
      raise exception 'invalid-aliases';
    end if;
    if jsonb_array_length(v_alias_json) > 20 then raise exception 'too-many-aliases'; end if;
    select coalesce(array_agg(trim(x)) filter (where trim(x) <> ''), '{}'::text[])
    into v_aliases_ar from jsonb_array_elements_text(v_alias_json) x;
    if exists (select 1 from unnest(v_aliases_ar) a where char_length(a) > 100) then
      raise exception 'invalid-aliases';
    end if;

    insert into public.questions (
      pack_id, idx, prompt_fr, prompt_en, prompt_ar, image_url,
      category, difficulty, match_mode
    ) values (
      p_pack, (v_ord - 1)::integer, v_prompt_fr, v_prompt_en, v_prompt_ar,
      null, v_category, v_difficulty, v_mode
    ) returning id into v_q;

    insert into public.question_answers_private (
      question_id, answer_main_fr, answer_main_en, answer_main_ar,
      aliases_fr, aliases_en, aliases_ar
    ) values (
      v_q, v_answer_fr, v_answer_en, v_answer_ar,
      v_aliases_fr, v_aliases_en, v_aliases_ar
    );
  end loop;
end;
$$;

revoke all on function public._replace_ugc_questions(uuid, jsonb)
from public, anon, authenticated;


create or replace function public.create_ugc_pack(
  p_title_fr text,
  p_title_en text,
  p_title_ar text,
  p_desc_fr text,
  p_desc_en text,
  p_desc_ar text,
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
  v_title_ar text := trim(coalesce(p_title_ar, ''));
  v_desc_fr text := trim(coalesce(p_desc_fr, ''));
  v_desc_en text := trim(coalesce(p_desc_en, ''));
  v_desc_ar text := trim(coalesce(p_desc_ar, ''));
  v_code text;
  v_pack uuid;
  v_constraint text;
begin
  if auth.uid() is null then raise exception 'not-authenticated'; end if;
  if p_accept_terms is distinct from true then raise exception 'terms-required'; end if;

  if char_length(v_title_fr) < 2 or char_length(v_title_fr) > 80
     or char_length(v_title_en) < 2 or char_length(v_title_en) > 80
     or char_length(v_title_ar) < 2 or char_length(v_title_ar) > 80 then
    raise exception 'invalid-title';
  end if;

  if char_length(v_desc_fr) > 500
     or char_length(v_desc_en) > 500
     or char_length(v_desc_ar) > 500 then
    raise exception 'invalid-description';
  end if;

  perform public._ensure_profile();

  loop
    v_code := 'PK-' || public._gen_code(4);
    begin
      insert into public.packs (
        owner_id, title_fr, title_en, title_ar, desc_fr, desc_en, desc_ar,
        is_official, is_premium, price_sku, share_code, report_count,
        is_hidden, ugc_terms_accepted_at
      ) values (
        auth.uid(), v_title_fr, v_title_en, v_title_ar,
        v_desc_fr, v_desc_en, v_desc_ar,
        false, false, null, v_code, 0, false, now()
      ) returning id into v_pack;
      exit;
    exception when unique_violation then
      get stacked diagnostics v_constraint = constraint_name;
      if v_constraint = 'packs_share_code_key' then continue; end if;
      raise;
    end;
  end loop;

  perform public._replace_ugc_questions(v_pack, p_questions);

  if exists (
    select 1
    from public.questions q
    join public.question_answers_private a on a.question_id = q.id
    where q.pack_id = v_pack
      and (trim(q.prompt_ar) = '' or trim(a.answer_main_ar) = '')
  ) then
    raise exception 'invalid-arabic-content';
  end if;

  return jsonb_build_object('id', v_pack, 'share_code', v_code);
end;
$$;

create or replace function public.update_ugc_pack(
  p_pack uuid,
  p_title_fr text,
  p_title_en text,
  p_title_ar text,
  p_desc_fr text,
  p_desc_en text,
  p_desc_ar text,
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
  v_title_ar text := trim(coalesce(p_title_ar, ''));
  v_desc_fr text := trim(coalesce(p_desc_fr, ''));
  v_desc_en text := trim(coalesce(p_desc_en, ''));
  v_desc_ar text := trim(coalesce(p_desc_ar, ''));
begin
  if auth.uid() is null then raise exception 'not-authenticated'; end if;
  select * into v_pack from public.packs p where p.id = p_pack;
  if not found then raise exception 'pack-not-found'; end if;

  if v_pack.is_official or v_pack.owner_id is distinct from auth.uid() then
    raise exception 'pack-not-editable';
  end if;

  if exists (select 1 from public.games g where g.pack_id = p_pack) then
    raise exception 'pack-in-use';
  end if;

  if char_length(v_title_fr) < 2 or char_length(v_title_fr) > 80
     or char_length(v_title_en) < 2 or char_length(v_title_en) > 80
     or char_length(v_title_ar) < 2 or char_length(v_title_ar) > 80 then
    raise exception 'invalid-title';
  end if;

  if char_length(v_desc_fr) > 500
     or char_length(v_desc_en) > 500
     or char_length(v_desc_ar) > 500 then
    raise exception 'invalid-description';
  end if;

  update public.packs
  set title_fr = v_title_fr,
      title_en = v_title_en,
      title_ar = v_title_ar,
      desc_fr = v_desc_fr,
      desc_en = v_desc_en,
      desc_ar = v_desc_ar
  where id = p_pack;

  perform public._replace_ugc_questions(p_pack, p_questions);

  if exists (
    select 1
    from public.questions q
    join public.question_answers_private a on a.question_id = q.id
    where q.pack_id = p_pack
      and (trim(q.prompt_ar) = '' or trim(a.answer_main_ar) = '')
  ) then
    raise exception 'invalid-arabic-content';
  end if;

  return jsonb_build_object('id', p_pack, 'share_code', v_pack.share_code);
end;
$$;

revoke all on function public.create_ugc_pack(
  text, text, text, text, text, text, jsonb, boolean
) from public, anon, authenticated;
grant execute on function public.create_ugc_pack(
  text, text, text, text, text, text, jsonb, boolean
) to authenticated;

revoke all on function public.update_ugc_pack(
  uuid, text, text, text, text, text, text, jsonb
) from public, anon, authenticated;
grant execute on function public.update_ugc_pack(
  uuid, text, text, text, text, text, text, jsonb
) to authenticated;

create or replace function public.get_ugc_pack_for_edit(p_pack uuid)
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
  if auth.uid() is null then raise exception 'not-authenticated'; end if;
  select * into v_pack from public.packs p where p.id = p_pack;
  if not found then raise exception 'pack-not-found'; end if;

  if v_pack.is_official or v_pack.owner_id is distinct from auth.uid() then
    raise exception 'pack-not-editable';
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'idx', q.idx,
        'prompt_fr', q.prompt_fr,
        'prompt_en', q.prompt_en,
        'prompt_ar', q.prompt_ar,
        'category', q.category,
        'difficulty', q.difficulty,
        'match_mode', q.match_mode,
        'answer_main_fr', a.answer_main_fr,
        'answer_main_en', a.answer_main_en,
        'answer_main_ar', a.answer_main_ar,
        'aliases_fr', a.aliases_fr,
        'aliases_en', a.aliases_en,
        'aliases_ar', a.aliases_ar
      ) order by q.idx
    ), '[]'::jsonb
  ) into v_questions
  from public.questions q
  join public.question_answers_private a on a.question_id = q.id
  where q.pack_id = p_pack;

  return jsonb_build_object(
    'id', v_pack.id,
    'title_fr', v_pack.title_fr,
    'title_en', v_pack.title_en,
    'title_ar', v_pack.title_ar,
    'desc_fr', v_pack.desc_fr,
    'desc_en', v_pack.desc_en,
    'desc_ar', v_pack.desc_ar,
    'share_code', v_pack.share_code,
    'is_hidden', v_pack.is_hidden,
    'terms_accepted_at', v_pack.ugc_terms_accepted_at,
    'questions', v_questions
  );
end;
$$;


create or replace function public.get_pack_preview(p_pack uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_pack record;
begin
  select * into v_pack from public.packs where id = p_pack;
  if not found then raise exception 'pack-not-found'; end if;
  if v_pack.is_hidden then raise exception 'pack-hidden'; end if;

  if v_pack.is_official then
    return (
      select coalesce(jsonb_agg(t order by t.idx), '[]'::jsonb)
      from (
        select q.idx, q.prompt_fr, q.prompt_en, q.prompt_ar,
               q.category, q.difficulty
        from public.questions q
        where q.pack_id = p_pack
        order by q.idx asc
        limit 3
      ) t
    );
  end if;

  if v_pack.owner_id is distinct from auth.uid() then
    raise exception 'pack-not-visible';
  end if;

  return (
    select coalesce(jsonb_agg(t order by t.idx), '[]'::jsonb)
    from (
      select q.idx, q.prompt_fr, q.prompt_en, q.prompt_ar,
             q.category, q.difficulty, q.match_mode
      from public.questions q
      where q.pack_id = p_pack
      order by q.idx asc
    ) t
  );
end;
$$;

create or replace function public.get_pack_by_share_code(p_code text)
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
  if auth.uid() is null then raise exception 'not-authenticated'; end if;

  select * into v_pack
  from public.packs p
  where p.share_code = upper(trim(p_code)) and not p.is_hidden;
  if not found then raise exception 'pack-not-found'; end if;

  if v_pack.is_official then
    select coalesce(jsonb_agg(t order by t.idx), '[]'::jsonb)
    into v_questions
    from (
      select q.idx, q.prompt_fr, q.prompt_en, q.prompt_ar,
             q.category, q.difficulty
      from public.questions q
      where q.pack_id = v_pack.id
      order by q.idx
      limit 3
    ) t;
  else
    select coalesce(jsonb_agg(t order by t.idx), '[]'::jsonb)
    into v_questions
    from (
      select q.idx, q.prompt_fr, q.prompt_en, q.prompt_ar,
             q.category, q.difficulty, q.match_mode
      from public.questions q
      where q.pack_id = v_pack.id
      order by q.idx
    ) t;
  end if;

  return jsonb_build_object(
    'id', v_pack.id,
    'title_fr', v_pack.title_fr,
    'title_en', v_pack.title_en,
    'title_ar', v_pack.title_ar,
    'desc_fr', v_pack.desc_fr,
    'desc_en', v_pack.desc_en,
    'desc_ar', v_pack.desc_ar,
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

create or replace function public.create_game(
  p_pack_id uuid,
  p_nickname text,
  p_team_mode boolean default false,
  p_language text default 'fr',
  p_duration integer default 30,
  p_share_code text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_pack record;
  v_code text;
  v_game uuid;
  v_player uuid;
  v_finale uuid;
  v_normals uuid[];
  v_n text := trim(p_nickname);
  v_constraint text;
begin
  if auth.uid() is null then raise exception 'not-authenticated'; end if;
  if not public._nickname_is_clean(v_n) then raise exception 'invalid-nickname'; end if;
  if p_language not in ('fr', 'en', 'ar') then raise exception 'invalid-language'; end if;
  if p_duration is null or p_duration <= 0 then p_duration := 30; end if;

  select * into v_pack from public.packs where id = p_pack_id;
  if not found then raise exception 'pack-not-found'; end if;
  if v_pack.is_hidden then raise exception 'pack-hidden'; end if;

  if (v_pack.owner_id is distinct from auth.uid()) and not v_pack.is_official then
    if p_share_code is null
       or upper(trim(p_share_code)) <> upper(trim(v_pack.share_code)) then
      raise exception 'pack-not-visible';
    end if;
  end if;

  if v_pack.is_premium and not exists (
    select 1 from public.entitlements e
    where e.user_id = auth.uid()
      and e.sku = v_pack.price_sku
      and e.is_active
  ) then
    raise exception 'pack-premium-locked';
  end if;

  if (select count(*) from public.questions q where q.pack_id = p_pack_id) < 11 then
    raise exception 'pack-too-small';
  end if;

  if p_language = 'ar' and exists (
    select 1
    from public.questions q
    left join public.question_answers_private a on a.question_id = q.id
    where q.pack_id = p_pack_id
      and (trim(q.prompt_ar) = '' or a.question_id is null or trim(a.answer_main_ar) = '')
  ) then
    raise exception 'pack-language-unavailable';
  end if;

  perform public._ensure_profile();

  loop
    v_code := public._gen_code(5);
    begin
      insert into public.games (
        join_code, host_id, pack_id, language, team_mode, question_duration_sec
      ) values (
        v_code, auth.uid(), p_pack_id, p_language,
        coalesce(p_team_mode, false), p_duration
      ) returning id into v_game;
      exit;
    exception when unique_violation then
      get stacked diagnostics v_constraint = constraint_name;
      if v_constraint = 'games_join_code_key' then continue; end if;
      raise;
    end;
  end loop;

  insert into public.players (game_id, user_id, nickname, is_host)
  values (v_game, auth.uid(), v_n, true)
  returning id into v_player;

  select q.id into v_finale
  from public.questions q
  where q.pack_id = p_pack_id
  order by q.difficulty desc nulls last, random()
  limit 1;
  if v_finale is null then raise exception 'pack-too-small'; end if;

  select array_agg(s.id order by s.rnd) into v_normals
  from (
    select q.id, random() as rnd
    from public.questions q
    where q.pack_id = p_pack_id and q.id <> v_finale
    order by rnd
    limit 10
  ) s;

  if coalesce(array_length(v_normals, 1), 0) < 10 then
    raise exception 'pack-too-small';
  end if;

  for i in 0..9 loop
    insert into public.game_questions (game_id, position, question_id)
    values (v_game, i, v_normals[i + 1]);
  end loop;

  insert into public.game_questions (game_id, position, question_id)
  values (v_game, 10, v_finale);

  return jsonb_build_object(
    'game_id', v_game,
    'player_id', v_player,
    'join_code', v_code
  );
end;
$$;

create or replace function public.get_current_question(p_game uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
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

  select case v_game.language
           when 'fr' then q.prompt_fr
           when 'en' then q.prompt_en
           when 'ar' then q.prompt_ar
           else null
         end,
         q.image_url,
         q.match_mode
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


create or replace function public.lock_question(p_game uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_game record;
  v_is_host boolean;
  v_deadline timestamptz;
  r record;
  v_qid uuid;
  v_exp text;
  v_alias text[];
  v_mode text;
  v_ok boolean;
  v_amount integer;
begin
  select * into v_game from public.games where id = p_game;
  if not found then raise exception 'game-not-found'; end if;
  if not public.is_game_member(p_game) then raise exception 'not-member'; end if;

  if v_game.status in ('question_locked', 'reveal', 'leaderboard',
                       'final_reveal', 'finished') then return; end if;
  if v_game.status not in ('question_open', 'final_wager') then
    raise exception 'not-open';
  end if;

  v_is_host := public.is_game_host(p_game);
  v_deadline := v_game.question_opened_at
                + make_interval(secs => v_game.question_duration_sec)
                - make_interval(secs => 2);
  if not v_is_host and now() < v_deadline then raise exception 'not-allowed-yet'; end if;

  update public.games set status = 'question_locked' where id = p_game;

  select gq.question_id into v_qid
  from public.game_questions gq
  where gq.game_id = p_game and gq.position = v_game.current_question_idx;

  for r in
    select a.id as aid, a.player_id, a.answer_text
    from public.player_answers a
    where a.game_id = p_game
      and a.question_idx = v_game.current_question_idx
      and a.is_correct is null
  loop
    if v_game.language = 'fr' then
      select ap.answer_main_fr, ap.aliases_fr, q.match_mode
      into v_exp, v_alias, v_mode
      from public.question_answers_private ap
      join public.questions q on q.id = ap.question_id
      where ap.question_id = v_qid;
    elsif v_game.language = 'en' then
      select ap.answer_main_en, ap.aliases_en, q.match_mode
      into v_exp, v_alias, v_mode
      from public.question_answers_private ap
      join public.questions q on q.id = ap.question_id
      where ap.question_id = v_qid;
    else
      select ap.answer_main_ar, ap.aliases_ar, q.match_mode
      into v_exp, v_alias, v_mode
      from public.question_answers_private ap
      join public.questions q on q.id = ap.question_id
      where ap.question_id = v_qid;
    end if;

    v_ok := public.match_answer(r.answer_text, v_exp, v_alias, v_mode);

    select w.amount into v_amount
    from public.wagers w
    where w.game_id = p_game
      and w.player_id = r.player_id
      and w.question_idx = v_game.current_question_idx;

    update public.player_answers
    set is_correct = v_ok,
        scored_points = case
          when v_game.current_question_idx = 10 and v_ok then coalesce(v_amount, 0)
          when v_game.current_question_idx = 10 and not v_ok then -coalesce(v_amount, 0)
          when v_ok then coalesce(v_amount, 0)
          else 0
        end
    where id = r.aid;

    perform public.recompute_player_stats(r.player_id);
  end loop;
end;
$$;

create or replace function public.reveal_answer(p_game uuid)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_game record;
  v_qid uuid;
  v_ans text;
begin
  if not public.is_game_member(p_game) then raise exception 'not-member'; end if;
  select * into v_game from public.games where id = p_game;
  if not found then raise exception 'game-not-found'; end if;

  if v_game.status = 'question_locked' then
    if not public.is_game_host(p_game) then raise exception 'not-host'; end if;
    update public.games
    set status = case
      when v_game.current_question_idx = 10 then 'final_reveal'
      else 'reveal'
    end
    where id = p_game;
    v_game.status := case
      when v_game.current_question_idx = 10 then 'final_reveal'
      else 'reveal'
    end;
  elsif v_game.status not in ('reveal','leaderboard','final_reveal','finished') then
    raise exception 'not-locked';
  end if;

  select gq.question_id into v_qid
  from public.game_questions gq
  where gq.game_id = p_game and gq.position = v_game.current_question_idx;

  if v_game.language = 'fr' then
    select ap.answer_main_fr into v_ans
    from public.question_answers_private ap where ap.question_id = v_qid;
  elsif v_game.language = 'en' then
    select ap.answer_main_en into v_ans
    from public.question_answers_private ap where ap.question_id = v_qid;
  else
    select ap.answer_main_ar into v_ans
    from public.question_answers_private ap where ap.question_id = v_qid;
  end if;

  return v_ans;
end;
$$;

revoke all on function public.create_game(uuid, text, boolean, text, integer, text)
from public, anon, authenticated;
grant execute on function public.create_game(uuid, text, boolean, text, integer, text)
to authenticated;

revoke all on function public.get_current_question(uuid)
from public, anon, authenticated;
grant execute on function public.get_current_question(uuid) to authenticated;

revoke all on function public.get_pack_preview(uuid)
from public, anon, authenticated;
grant execute on function public.get_pack_preview(uuid) to authenticated;

revoke all on function public.get_pack_by_share_code(text)
from public, anon, authenticated;
grant execute on function public.get_pack_by_share_code(text) to authenticated;

revoke all on function public.get_ugc_pack_for_edit(uuid)
from public, anon, authenticated;
grant execute on function public.get_ugc_pack_for_edit(uuid) to authenticated;

revoke all on function public.lock_question(uuid)
from public, anon, authenticated;
grant execute on function public.lock_question(uuid) to authenticated;

revoke all on function public.reveal_answer(uuid)
from public, anon, authenticated;
grant execute on function public.reveal_answer(uuid) to authenticated;
