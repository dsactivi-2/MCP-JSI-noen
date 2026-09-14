-- KORRIGIERTE VERSION (14.09.2026): Postgres-Fixes an crm_search_candidates
--   1. text[] || '<literal>' mehrfach zu ARRAY[...] geaendert (Postgres las Literal sonst als Array-Literal)
--   2. Sprach-Filter: ILIKE %s -> ILIKE %L (Wert wurde unquotiert eingefuegt)
--   3. Hauptquery: cnt ist jetzt die tragende Seite (LEFT JOIN t ON true, GROUP BY cnt.n,
--      jsonb_agg mit FILTER) -> bei 0 Treffern kommt jetzt ein Ergebnis-JSON statt NULL
--   4. Erfahrungsjahre: AGE(COALESCE(ende, CURRENT_DATE), start) statt AGE(ende) - EXTRACT(YEAR FROM start)

-- ============================================================
-- crm_search_candidates(filters jsonb, audience text) -> jsonb
-- 1:1 Umsetzung der PHP-Hauptsuche (serversidedata.php, case lista_kandidata),
-- Schema verifiziert gegen Produktions-Dump 26.02.2026.
-- audience = 'internal' (default) | 'customer' -> Kontaktdaten werden NULL
-- LEFT JOINs statt INNER JOINs: Das alte CRM hat Kandidaten ohne Gruppe/
-- Status stillschweigend verworfen - wird hier NICHT kopiert.
--
-- Filter-Schluessel siehe SKILL.md / README
-- ============================================================

CREATE OR REPLACE FUNCTION crm_search_candidates(p_filters jsonb DEFAULT '{}'::jsonb,
                                                 p_audience text DEFAULT 'internal')
RETURNS jsonb
LANGUAGE plpgsql
AS $func$
DECLARE
  c      text[] := ARRAY[]::text[];
  joins  text   := '';
  levels text[];
  cats   text[];
  terms  text[];
  occ_cond text;
  invalid_keys text[];
  ids    text;
  v      text;
  skill  text;
  r_email text; r_mob text; r_jmbg text; r_adr text;
  q      text;
  res    jsonb;
  rec    record;
  lim    int := COALESCE((p_filters->>'limit')::int, 20);
  offs   int := COALESCE((p_filters->>'offset')::int, 0);
BEGIN
  -- limit/offset hart validieren (statt still clampen)
  IF lim < 1 OR lim > 50 THEN
    RAISE EXCEPTION 'limit muss 1-50 sein, war: % (max. 50 pro Seite - weitere Seiten per offset)', lim;
  END IF;
  IF offs < 0 THEN
    RAISE EXCEPTION 'offset darf nicht negativ sein, war: %', offs;
  END IF;

  -- ---------- STRICTE FILTER-VALIDIERUNG ----------
  -- Unbekannte Schluessel = sofortiger Fehler (NIEMALS still ignorieren!)
  invalid_keys := ARRAY(
    SELECT je.key FROM jsonb_object_keys(p_filters) je(key)
    WHERE je.key NOT IN ('age_from','age_to','occupation_terms','occupation_source',
      'name_terms','contact_terms','has_driving_license','license_categories',
      'has_work_experience','min_experience_years','german_level','english_level',
      'language_skill','groups','statuses','application_statuses','citizenship',
      'residence_eu','schools','qualifications','profession_ids','sources',
      'dipl_statuses','nostrification','include_archive','limit','offset'));
  IF array_length(invalid_keys, 1) > 0 THEN
    RAISE EXCEPTION 'Unbekannte Filter-Schluessel: % - SUCHFUNKTION IST VERALTET (neue Version einspielen) oder Tippfehler im Filter', array_to_string(invalid_keys, ', ');
  END IF;

  IF p_audience NOT IN ('internal','customer') THEN
    RAISE EXCEPTION 'Ungueltige audience: %', p_audience;
  END IF;

  -- Redaktion fuer Kundenansicht
  IF p_audience = 'customer' THEN
    r_email := 'NULL'; r_mob := 'NULL'; r_jmbg := 'NULL'; r_adr := 'NULL';
  ELSE
    r_email := 'k.kandidat_email'; r_mob := 'k.kandidat_mobitel';
    r_jmbg := 'k.kandidat_jmbg'; r_adr := 'k.kandidat_adresa';
  END IF;

  -- ---------- ARCHIV ----------
  IF COALESCE((p_filters->>'include_archive')::boolean, false) THEN
    c := c || ARRAY['k.kandidat_status = 3'];
  ELSE
    c := c || ARRAY['k.kandidat_status IS DISTINCT FROM 3'];
  END IF;

  -- ---------- ALTER ----------
  IF (p_filters->>'age_from') ~ '^\d+$' AND (p_filters->>'age_to') ~ '^\d+$' THEN
    c := c || format('EXTRACT(YEAR FROM AGE(k.kandidat_datumrodjenja)) BETWEEN %s AND %s',
                     (p_filters->>'age_from')::int, (p_filters->>'age_to')::int);
  END IF;

  -- ---------- NAMEN (Suchbox aus altem CRM) ----------
  IF jsonb_typeof(p_filters->'name_terms') = 'array' THEN
    SELECT string_agg(format('(k.kandidat_ime ILIKE %L OR k.kandidat_prezime ILIKE %L)',
             '%' || je.value || '%', '%' || je.value || '%'), ' OR ')
      INTO ids FROM jsonb_array_elements_text(p_filters->'name_terms') je(value);
    IF ids IS NOT NULL THEN c := c || '(' || ids || ')'; END IF;
  END IF;

  -- ---------- KONTAKT-SEARCH (NUR intern: E-Mail/Telefon/JMBG) ----------
  IF jsonb_typeof(p_filters->'contact_terms') = 'array' AND p_audience = 'internal' THEN
    SELECT string_agg(format('(k.kandidat_email ILIKE %L OR k.kandidat_mobitel ILIKE %L OR k.kandidat_jmbg ILIKE %L)',
             '%' || je.value || '%', '%' || je.value || '%', '%' || je.value || '%'), ' OR ')
      INTO ids FROM jsonb_array_elements_text(p_filters->'contact_terms') je(value);
    IF ids IS NOT NULL THEN c := c || '(' || ids || ')'; END IF;
  END IF;

  -- ---------- BERUFTERMS + SYNONYME ----------
  IF jsonb_typeof(p_filters->'occupation_terms') = 'array' THEN
    terms := ARRAY(SELECT je.value FROM jsonb_array_elements_text(p_filters->'occupation_terms') je(value));
    SELECT ARRAY(
      SELECT DISTINCT s2.term FROM search_synonyms s1
      JOIN search_synonyms s2 ON s2.canonical_group = s1.canonical_group
      WHERE s1.term ILIKE ANY(terms)
    ) || terms INTO terms;
  END IF;

  -- BERUF: Quelle waehlbar (occupation_source, default 'any')
  v := COALESCE(p_filters->>'occupation_source', 'any');
  IF v NOT IN ('any','experience','profession','education') THEN
    RAISE EXCEPTION 'Ungueltige occupation_source: % (any|experience|profession|education)', v;
  END IF;
  IF terms IS NOT NULL AND array_length(terms, 1) > 0 THEN
    SELECT string_agg(format($y$
      (g.kg_title ILIKE %1$L
       OR EXISTS (SELECT 1 FROM idk_kandidat_edukacija ed
                  WHERE ed.ke_kandidat_id = k.kandidat_id
                    AND (ed.ke_naziv_kvalifikacije ILIKE %1$L OR ed.ke_naziv ILIKE %1$L))
       OR EXISTS (SELECT 1 FROM idk_kandidat_radno_iskustvo ri
                  WHERE ri.kri_kandidat_id = k.kandidat_id
                    AND (ri.kri_pozicija ILIKE %1$L OR ri.kri_naziv ILIKE %1$L)))$y$,
      '%' || t || '%'), ' OR ')
    INTO occ_cond FROM unnest(terms) t;

    IF v = 'experience' THEN
      SELECT string_agg(format(
        'EXISTS (SELECT 1 FROM idk_kandidat_radno_iskustvo ri WHERE ri.kri_kandidat_id = k.kandidat_id AND (ri.kri_pozicija ILIKE %L OR ri.kri_naziv ILIKE %L))',
        '%' || t || '%', '%' || t || '%'), ' OR ')
      INTO occ_cond FROM unnest(terms) t;
    ELSIF v = 'profession' THEN
      SELECT string_agg(format('g.kg_title ILIKE %L', '%' || t || '%'), ' OR ')
      INTO occ_cond FROM unnest(terms) t;
    ELSIF v = 'education' THEN
      SELECT string_agg(format(
        'EXISTS (SELECT 1 FROM idk_kandidat_edukacija ed WHERE ed.ke_kandidat_id = k.kandidat_id AND ed.ke_naziv_kvalifikacije ILIKE %L)',
        '%' || t || '%'), ' OR ')
      INTO occ_cond FROM unnest(terms) t;
    END IF;
    c := c || ARRAY['(' || occ_cond || ')'];
  END IF;

  -- ---------- FUEHRERSCHEIN ----------
  IF (p_filters->>'has_driving_license')::boolean IS true THEN
    c := c || format('k.kandidat_vozacka_dozvola ILIKE %L', '%Da%');
  END IF;

  -- ---------- FUEHRERSCHEINKATEGORIEN ----------
  IF jsonb_typeof(p_filters->'license_categories') = 'array' THEN
    cats := ARRAY(SELECT je.value FROM jsonb_array_elements_text(p_filters->'license_categories') je(value));
    v := CASE
      WHEN 'B'   = ANY(cats) THEN 'CE|C1E|C|C1|B'
      WHEN 'C1'  = ANY(cats) THEN 'CE|C1E|C|C1'
      WHEN 'C'   = ANY(cats) THEN 'CE|C1E|C'
      WHEN 'C1E' = ANY(cats) THEN 'CE|C1E'
      WHEN 'CE'  = ANY(cats) THEN 'CE'
      ELSE NULL END;
    IF v IS NOT NULL THEN
      c := c || format('k.kandidat_vozacka_kategorija ~* %L',
                       '(^|[^A-Z0-9])(' || v || ')([^A-Z0-9]|$)');
    END IF;
    IF 'BE' = ANY(cats) THEN
      c := c || format('k.kandidat_vozacka_kategorija ~* %L', '(^|[^A-Z0-9])BE([^A-Z0-9]|$)');
    END IF;
  END IF;

  -- ---------- BERUFSERFAHRUNG ----------
  IF (p_filters->>'has_work_experience')::boolean IS true THEN
    c := c || ARRAY['EXISTS (SELECT 1 FROM idk_kandidat_radno_iskustvo ri WHERE ri.kri_kandidat_id = k.kandidat_id)'];
  END IF;

  IF (p_filters->>'min_experience_years') ~ '^\d+$' THEN
    IF terms IS NOT NULL AND array_length(terms, 1) > 0 THEN
      c := c || format($x$EXISTS (SELECT 1 FROM idk_kandidat_radno_iskustvo ri
          WHERE ri.kri_kandidat_id = k.kandidat_id
            AND (%s)
            AND EXTRACT(YEAR FROM AGE(COALESCE(ri.kri_datum_do::date, CURRENT_DATE), ri.kri_darum_od::date)) >= %s)$x$,
        (SELECT string_agg(format('(ri.kri_pozicija ILIKE %L OR ri.kri_naziv ILIKE %L)',
                 '%' || t || '%', '%' || t || '%'), ' OR ') FROM unnest(terms) t),
        (p_filters->>'min_experience_years')::int);
    ELSE
      c := c || format($x$EXISTS (SELECT 1 FROM idk_kandidat_radno_iskustvo ri
          WHERE ri.kri_kandidat_id = k.kandidat_id
          AND EXTRACT(YEAR FROM AGE(COALESCE(ri.kri_datum_do::date, CURRENT_DATE), ri.kri_darum_od::date)) >= %s)$x$,
        (p_filters->>'min_experience_years')::int);
    END IF;
  END IF;

  -- ---------- SPRACHEN ----------
  skill := COALESCE(p_filters->>'language_skill', 'kj_slusanje');
  IF skill NOT IN ('kj_slusanje','kj_citanje','kj_govorna_interakcija','kj_govorna_produkcija','kj_pisanje') THEN
    RAISE EXCEPTION 'Ungueltige language_skill: %', skill;
  END IF;

  FOR rec IN
    SELECT key, lang FROM (VALUES
      ('german_level',  'Njemacki'),
      ('english_level', 'Engleski')) AS t(key, lang)
  LOOP
    v := p_filters->>rec.key;
    IF v IS NOT NULL THEN
      IF v = 'NO_INFO' THEN
        c := c || format($x$NOT EXISTS (SELECT 1 FROM idk_kandidat_jezici kj
            WHERE kj.kj_kandidatid = k.kandidat_id
              AND kj.kj_naziv ILIKE %L
              AND kj.%s = ANY (ARRAY['A1','A2','B1','B2','C1','C2','BEZ ZNANJA']))$x$,
            '%' || rec.lang || '%', skill);
      ELSE
        levels := CASE v
          WHEN 'A1' THEN ARRAY['A1','A2','B1','B2','C1','C2']
          WHEN 'A2' THEN ARRAY['A2','B1','B2','C1','C2']
          WHEN 'B1' THEN ARRAY['B1','B2','C1','C2']
          WHEN 'B2' THEN ARRAY['B2','C1','C2']
          WHEN 'C1' THEN ARRAY['C1','C2']
          WHEN 'C2' THEN ARRAY['C2']
          WHEN 'BEZ_ZNANJA' THEN ARRAY['BEZ ZNANJA']
          ELSE NULL END;
        IF levels IS NULL THEN RAISE EXCEPTION 'Ungueltiger %: %', rec.key, v; END IF;
        c := c || format($x$EXISTS (SELECT 1 FROM idk_kandidat_jezici kj
            WHERE kj.kj_kandidatid = k.kandidat_id
              AND kj.kj_naziv ILIKE %L
              AND kj.%s = ANY (%L::text[]))$x$,
            '%' || rec.lang || '%', skill, levels);
      END IF;
    END IF;
  END LOOP;

  -- ---------- GRUPPEN / STATUS / BEWERBUNGSSTATUS ----------
  IF jsonb_typeof(p_filters->'groups') = 'array' THEN
    SELECT string_agg(je.value, ',') INTO ids
      FROM jsonb_array_elements_text(p_filters->'groups') je(value)
     WHERE je.value ~ '^\d+$';
    IF ids IS NOT NULL THEN c := c || format('k.kandidat_group IN (%s)', ids); END IF;
  END IF;

  IF jsonb_typeof(p_filters->'statuses') = 'array' THEN
    SELECT string_agg(je.value, ',') INTO ids
      FROM jsonb_array_elements_text(p_filters->'statuses') je(value)
     WHERE je.value ~ '^\d+$';
    IF ids IS NOT NULL THEN c := c || format('k.kandidat_status IN (%s)', ids); END IF;
  END IF;

  IF jsonb_typeof(p_filters->'application_statuses') = 'array' THEN
    SELECT string_agg(je.value, ',') INTO ids
      FROM jsonb_array_elements_text(p_filters->'application_statuses') je(value)
     WHERE je.value ~ '^\d+$';
    IF ids IS NOT NULL THEN
      IF EXISTS (SELECT 1 FROM jsonb_array_elements_text(p_filters->'application_statuses') je
                 WHERE je.value = '0') THEN
        c := c || format('(k.kandidat_status_prijave IN (%s) OR k.kandidat_status_prijave IS NULL)', ids);
      ELSE
        c := c || format('k.kandidat_status_prijave IN (%s)', ids);
      END IF;
    END IF;
  END IF;

  -- ---------- STAATSANGEHOERIGKEIT / AUFENTHALT ----------
  v := p_filters->>'citizenship';
  IF v = 'EU' THEN
    c := c || format('k.kandidat_drzavljanstvo_vrsta LIKE %L', 'EU%');
  ELSIF v = 'NON_EU' THEN
    c := c || format('(k.kandidat_drzavljanstvo_vrsta NOT LIKE %L OR k.kandidat_drzavljanstvo_vrsta IS NULL)', 'EU%');
  END IF;

  v := p_filters->>'residence_eu';
  IF v IS NOT NULL AND v <> '' THEN
    c := c || format('k.boravak_eu = %L', v);
  END IF;

  -- ---------- SCHULEN / SMJER / STRUKA ----------
  IF jsonb_typeof(p_filters->'schools') = 'array'
     AND jsonb_typeof(p_filters->'qualifications') IS DISTINCT FROM 'array' THEN
    c := c || ARRAY[$x$EXISTS (SELECT 1 FROM idk_kandidat_edukacija ed
        WHERE ed.ke_kandidat_id = k.kandidat_id AND ($x$ ||
      (SELECT string_agg(format('ed.ke_naziv ILIKE %L', '%' || je.value || '%'), ' OR ')
         FROM jsonb_array_elements_text(p_filters->'schools') je(value)) || '))'];
  END IF;

  IF jsonb_typeof(p_filters->'qualifications') = 'array' THEN
    c := c || ARRAY[$x$EXISTS (SELECT 1 FROM idk_kandidat_edukacija ed
        WHERE ed.ke_kandidat_id = k.kandidat_id AND ($x$ ||
      (SELECT string_agg(format('ed.ke_naziv_kvalifikacije = %L', je.value), ' OR ')
         FROM jsonb_array_elements_text(p_filters->'qualifications') je(value)) || '))'];
  END IF;

  IF jsonb_typeof(p_filters->'profession_ids') = 'array'
     AND jsonb_typeof(p_filters->'qualifications') IS DISTINCT FROM 'array' THEN
    SELECT string_agg(je.value, ',') INTO ids
      FROM jsonb_array_elements_text(p_filters->'profession_ids') je(value)
     WHERE je.value ~ '^\d+$';
    IF ids IS NOT NULL THEN
      c := c || format($x$EXISTS (SELECT 1 FROM idk_kandidat_edukacija ed
          WHERE ed.ke_kandidat_id = k.kandidat_id
            AND ed.ke_naziv_kvalifikacije IN
                (SELECT ss.ss_naziv FROM idk_skole_smjerovi ss WHERE ss.ss_struka_id IN (%s)))$x$, ids);
    END IF;
  END IF;

  -- ---------- HERKUNFT (6 nimmt 7 mit) ----------
  IF jsonb_typeof(p_filters->'sources') = 'array' THEN
    SELECT string_agg(je.value, ',') INTO ids
      FROM jsonb_array_elements_text(p_filters->'sources') je(value)
     WHERE je.value ~ '^\d+$';
    IF ids IS NOT NULL THEN
      IF EXISTS (SELECT 1 FROM jsonb_array_elements_text(p_filters->'sources') je WHERE je.value = '6')
         AND NOT EXISTS (SELECT 1 FROM jsonb_array_elements_text(p_filters->'sources') je WHERE je.value = '7') THEN
        ids := ids || ',7';
      END IF;
      c := c || format('k.kandidat_porijeklo IN (%s)', ids);
    END IF;
  END IF;

  -- ---------- DIPL-STATUS / NOSTRIFIKATION ----------
  IF jsonb_typeof(p_filters->'dipl_statuses') = 'array' THEN
    SELECT string_agg(je.value, ',') INTO ids
      FROM jsonb_array_elements_text(p_filters->'dipl_statuses') je(value)
     WHERE je.value ~ '^\d+$';
    IF ids IS NOT NULL THEN
      joins := joins || ' LEFT JOIN idk_nd_kandidata ndk ON k.kandidat_dipl_id = ndk.id_broj_nd_kandidata';
      IF EXISTS (SELECT 1 FROM jsonb_array_elements_text(p_filters->'dipl_statuses') je WHERE je.value = '0') THEN
        c := c || format('(k.kandidat_dipl_id = 0 OR ndk.status_nd_kandidata IN (%s))', ids);
      ELSE
        c := c || format('ndk.status_nd_kandidata IN (%s)', ids);
      END IF;
    END IF;
  END IF;

  IF jsonb_typeof(p_filters->'nostrification') = 'array' THEN
    SELECT string_agg(je.value, ',') INTO ids
      FROM jsonb_array_elements_text(p_filters->'nostrification') je(value)
     WHERE je.value ~ '^\d+$';
    IF ids IS NOT NULL THEN
      joins := joins || ' LEFT JOIN idk_nostrifikovane_diplome nodi ON k.kandidat_dipl_id = nodi.id_cand_dipl';
      IF EXISTS (SELECT 1 FROM jsonb_array_elements_text(p_filters->'nostrification') je WHERE je.value = '3') THEN
        c := c || format('(nodi.full_recognition IS NULL OR nodi.full_recognition IN (%s))', ids);
      ELSE
        c := c || format('nodi.full_recognition IN (%s)', ids);
      END IF;
    END IF;
  END IF;

  -- ---------- HAUPTABFRAGE ----------
  q := format($q$
    SELECT jsonb_build_object(
      'audience',         %L,
      'filters_received', %L::jsonb,
      'found',            cnt.n,
      'returned',         LEAST(%s, GREATEST(cnt.n - %s, 0)),
      'candidates',       COALESCE(jsonb_agg(row_to_json(t) ORDER BY t.kandidat_id DESC) FILTER (WHERE t.kandidat_id IS NOT NULL), '[]'::jsonb))
    FROM (
      SELECT count(*) AS n FROM idk_kandidati k
      LEFT JOIN idk_kandidati_grupe g ON k.kandidat_group = g.kg_id
      %s WHERE %s
    ) cnt
    LEFT JOIN (
      SELECT k.kandidat_id, k.kandidat_ime, k.kandidat_prezime, k.kandidat_datumrodjenja,
             k.kandidat_spol, %s AS kandidat_jmbg, k.kandidat_status, k.kandidat_status_messenger,
             %s AS kandidat_email, %s AS kandidat_mobitel, %s AS kandidat_adresa,
             k.kandidat_grad, k.kandidat_group, k.kandidat_porijeklo, g.kg_title, s.status_naziv,
             g.kg_title AS beruf,
             (SELECT kj.kj_slusanje FROM idk_kandidat_jezici kj
               WHERE kj.kj_kandidatid = k.kandidat_id AND kj.kj_naziv ILIKE '%%Njemacki%%'
               ORDER BY array_position(ARRAY['A1','A2','B1','B2','C1','C2']::text[], kj.kj_slusanje) DESC NULLS LAST
               LIMIT 1) AS deutsch_hoeren,
             (SELECT kj.kj_slusanje FROM idk_kandidat_jezici kj
               WHERE kj.kj_kandidatid = k.kandidat_id AND kj.kj_naziv ILIKE '%%Engleski%%'
               ORDER BY array_position(ARRAY['A1','A2','B1','B2','C1','C2']::text[], kj.kj_slusanje) DESC NULLS LAST
               LIMIT 1) AS englisch_hoeren,
             (SELECT COALESCE(SUM(GREATEST(
                 EXTRACT(YEAR FROM AGE(COALESCE(ri.kri_datum_do::date, CURRENT_DATE), ri.kri_darum_od::date))::int, 0)), 0)
               FROM idk_kandidat_radno_iskustvo ri WHERE ri.kri_kandidat_id = k.kandidat_id) AS erfahrung_jahre
      FROM idk_kandidati k
      LEFT JOIN idk_kandidati_grupe g ON k.kandidat_group = g.kg_id
      LEFT JOIN idk_kandidat_status  s ON k.kandidat_status = s.status_id
      %s
      WHERE %s
      ORDER BY k.kandidat_id DESC
      LIMIT %s OFFSET %s
    ) t ON true
    GROUP BY cnt.n
  $q$,
    p_audience, p_filters, lim, offs,
    joins, array_to_string(c, ' AND '),
    r_jmbg, r_email, r_mob, r_adr,
    joins, array_to_string(c, ' AND '),
    lim, offs);

  EXECUTE q INTO res;
  RETURN res;
END;
$func$
