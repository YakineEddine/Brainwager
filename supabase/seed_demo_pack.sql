-- Brainwager Phase 2 — seed démo (pack de test, 100 % original)
-- Usage : à coller APRÈS les migrations pour tester à 2 émulateurs sans attendre
-- la Phase 3 (contenu définitif). 11 questions FR/EN + réponses + alias.
-- Pack officiel gratuit, share_code DEMO01.

do $$
declare
  v_pack uuid;
  v_q uuid;
begin
  insert into public.packs
    (title_fr, title_en, desc_fr, desc_en, is_official, is_premium, share_code)
  values
    ('Démo Soirée', 'Demo Party', 'Pack de test Phase 2', 'Phase 2 test pack',
     true, false, 'DEMO01')
  returning id into v_pack;

  -- Q0..Q9 normales (difficultés 1-2), Q10 finale (difficulté 3).
  -- Formulation maison, réponses courtes pour tester le fuzzy.
  create temp table tmp_q (i int, fr text, en text, afr text, aen text,
                           alfr text[], alen text[], cat text, dif int, mode text)
  on commit drop;
  insert into tmp_q values
    (0, 'Comment appelle-t-on un triangle aux trois côtés égaux ?', 'What do you call a triangle with three equal sides ?', 'équilatéral', 'equilateral', '{equilateral}', '{equilateral}', 'science', 1, 'fuzzy'),
    (1, 'Quel instrument à six cordes accompagne souvent les veillées ?', 'Which six-string instrument is common at evening gatherings ?', 'guitare', 'guitar', '{gratte}', '{guitar}', 'musique', 1, 'fuzzy'),
    (2, 'Quelle couleur obtient-on en mélangeant du bleu et du jaune ?', 'Which color do you get mixing blue and yellow ?', 'vert', 'green', '{}', '{}', 'science', 1, 'fuzzy'),
    (3, 'Comment se nomme la capitale du Portugal ?', 'What is the capital of Portugal ?', 'Lisbonne', 'Lisbon', '{lisboa}', '{lisboa,lisbon}', 'geo', 1, 'fuzzy'),
    (4, 'Quel nombre de joueurs compte une équipe de football sur le terrain ?', 'How many players does a football team field ?', '11', '11', '{onze}', '{eleven}', 'sport', 1, 'exact'),
    (5, 'Quel objet céleste éclaire nos nuits en reflétant le soleil ?', 'Which night object shines by reflecting the sun ?', 'lune', 'moon', '{la lune}', '{the moon}', 'science', 2, 'fuzzy'),
    (6, 'Dans quelle ville se trouve la tour penchée célèbre ?', 'In which city is the famous leaning tower ?', 'Pise', 'Pisa', '{}', '{}', 'geo', 2, 'fuzzy'),
    (7, 'Quel métal précieux a pour symbole chimique Au ?', 'Which precious metal has chemical symbol Au ?', 'or', 'gold', '{}', '{}', 'science', 2, 'fuzzy'),
    (8, 'En quelle année l''homme a-t-il marché sur la Lune pour la première fois ?', 'In which year did humans first walk on the Moon ?', '1969', '1969', '{}', '{}', 'histoire', 2, 'exact'),
    (9, 'Quel océan borde la côte ouest de la France ?', 'Which ocean borders the west coast of France ?', 'Atlantique', 'Atlantic', '{atlantique}', '{atlantic}', 'geo', 2, 'fuzzy'),
    (10, 'Quel fleuve traverse la ville du Caire avant de rejoindre la mer ?', 'Which river flows through Cairo to the sea ?', 'Nil', 'Nile', '{le nil}', '{the nile}', 'geo', 3, 'fuzzy');

  -- Insertion questions + réponses privées via boucle (évite 11 blocs).
  declare
    r record;
  begin
    for r in select * from tmp_q order by i loop
      insert into public.questions
        (pack_id, idx, prompt_fr, prompt_en, category, difficulty, match_mode)
      values (v_pack, r.i, r.fr, r.en, r.cat, r.dif, r.mode)
      returning id into v_q;
      insert into public.question_answers_private
        (question_id, answer_main_fr, answer_main_en, aliases_fr, aliases_en)
      values (v_q, r.afr, r.aen, r.alfr, r.alen);
    end loop;
  end;
end
$$;
