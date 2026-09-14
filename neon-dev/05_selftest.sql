-- ============================================================
-- SELF-TEST: Nach 00-04 ausfuehren. Erwartete Werte in Klammern.
-- ============================================================
SELECT 'kandidaten_gesamt' AS check, count(*) AS wert FROM idk_kandidati                        -- (500)
UNION ALL SELECT 'archiv_status3', count(*) FROM idk_kandidati WHERE kandidat_status = 3          -- (~29)
UNION ALL SELECT 'deutsch_a2_oder_besser', count(*) FROM idk_kandidati k WHERE EXISTS
  (SELECT 1 FROM idk_kandidat_jezici kj WHERE kj.kj_kandidatid = k.kandidat_id
   AND kj.kj_naziv ILIKE '%Njemacki%' AND kj.kj_slusanje = ANY (ARRAY['A2','B1','B2','C1','C2']))  -- (~225, deterministisch)
UNION ALL SELECT 'elektro_ausbildung', count(*) FROM idk_kandidat_edukacija
  WHERE ke_naziv_kvalifikacije ILIKE '%Elektro%'                                                  -- (~75)
UNION ALL SELECT 'mit_berufserfahrung', count(*) FROM idk_kandidat_radno_iskustvo;                -- (~300)

-- Beispiel-Suche des Nutzers (intern): muss Treffer > 0 liefern
SELECT crm_search_candidates('{"occupation_terms":["Elektriker"],"age_from":20,"age_to":40,"min_experience_years":3,"german_level":"A2","limit":5}'::jsonb, 'internal');

-- Kundenansicht: gleiche Suche, aber kandidat_email/mobitel/jmbg/adresa muessen NULL sein
SELECT crm_search_candidates('{"occupation_terms":["Elektriker"],"limit":3}'::jsonb, 'customer');
