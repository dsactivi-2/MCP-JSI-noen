-- ============================================================
-- GRUPPEN-MATRIX v1.0 (14.09.2026)
-- (1) Alle CRM-Gruppen nach Stellenbeschreibung filterbar machen
-- (2) GIG-Berufe (Thomas-Anfrage) auf Gruppen mappen
-- (3) Neue (virtuelle) Gruppen erstellen: HDD + Rohrleitung
-- Einfach komplett einspielen, dann Kontroll-Query am Ende pruefen.
-- ============================================================

-- ---------- SCHRITT 1: CRM-Gruppen + ihre Berufe als Synonyme ----------
-- Jede Gruppe wird zur Such-Synonym-Gruppe 'grp_<ID>'.
-- Sucht man den Gruppennamen, werden ALLE Berufe der Gruppe mitgesucht.

INSERT INTO search_synonyms (term, canonical_group)
SELECT DISTINCT g.kg_title, 'grp_' || g.kg_id
FROM idk_kandidati_grupe g
WHERE g.kg_title IS NOT NULL AND length(trim(g.kg_title)) >= 4
ON CONFLICT DO NOTHING;

-- Mitglieds-Berufe aus AUSBILDUNG (Smjer) der Gruppenmitglieder
INSERT INTO search_synonyms (term, canonical_group)
SELECT DISTINCT trim(ed.ke_naziv_kvalifikacije), 'grp_' || k.kandidat_group
FROM idk_kandidat_edukacija ed
JOIN idk_kandidati k ON k.kandidat_id = ed.ke_kandidat_id
WHERE ed.ke_naziv_kvalifikacije IS NOT NULL
  AND length(trim(ed.ke_naziv_kvalifikacije)) >= 6
  AND trim(ed.ke_naziv_kvalifikacije) NOT IN ('Ostalo','Nije navedeno')
GROUP BY 1, 2
HAVING count(*) >= 5
ON CONFLICT DO NOTHING;

-- Mitglieds-Berufe aus JOB-TITELN der Gruppenmitglieder
INSERT INTO search_synonyms (term, canonical_group)
SELECT DISTINCT trim(ri.kri_pozicija), 'grp_' || k.kandidat_group
FROM idk_kandidat_radno_iskustvo ri
JOIN idk_kandidati k ON k.kandidat_id = ri.kri_kandidat_id
WHERE ri.kri_pozicija IS NOT NULL
  AND length(trim(ri.kri_pozicija)) >= 6
  AND trim(ri.kri_pozicija) NOT IN ('Radnik','Pomocni radnik','Ostalo','Nije navedeno')
GROUP BY 1, 2
HAVING count(*) >= 5
ON CONFLICT DO NOTHING;

-- ---------- SCHRITT 2: GIG-Berufe auf passende CRM-Gruppen mappen ----------
-- Deutscher Berufsname -> Gruppe wird per Titel-Suche gefunden (keine IDs noetig).
-- Treffer bei MEHREREN Gruppen ist OK (dann wird in allen gesucht).

INSERT INTO search_synonyms (term, canonical_group)
SELECT v.term, 'grp_' || g.kg_id
FROM (VALUES
  ('Tiefbauer'),('Tiefbauarbeiter'),('Bauarbeiter'),('Kanalarbeiter'),('Straßenbauer'),('Strassenbauer'),('Bauhilfsarbeiter'),
  ('Glasfasermonteur'),('Glasfaserinstallateur'),('LWL-Monteur'),('Fiberoptic technician'),('FTTH-Monteur'),('Netzwerktechniker'),('Glasfaser'),
  ('Elektriker'),('Elektroinstallateur'),('Elektromonteur'),('Elektromechaniker'),
  ('Rohrleitungsbauer'),('Rohrschlosser'),('Schweißer'),('Schweisser'),('MAG-Schweißer'),('WIG-Schweißer'),('Welder')
) v(term)
JOIN idk_kandidati_grupe g ON (
     (v.term IN ('Glasfasermonteur','Glasfaserinstallateur','LWL-Monteur','Fiberoptic technician','FTTH-Monteur','Netzwerktechniker','Glasfaser')
        AND (g.kg_title ILIKE '%internet%' OR g.kg_title ILIKE '%opti%' OR g.kg_title ILIKE '%telekom%' OR g.kg_title ILIKE '%mre%'))
  OR (v.term IN ('Tiefbauer','Tiefbauarbeiter','Bauarbeiter','Kanalarbeiter','Straßenbauer','Strassenbauer','Bauhilfsarbeiter')
        AND (g.kg_title ILIKE '%tiefbau%' OR g.kg_title ILIKE '%gradjev%' OR g.kg_title ILIKE '%građev%'
             OR g.kg_title ILIKE '%cest%' OR g.kg_title ILIKE '%zemlj%' OR g.kg_title ILIKE '%bager%'))
  OR (v.term IN ('Elektriker','Elektroinstallateur','Elektromonteur','Elektromechaniker')
        AND g.kg_title ILIKE '%elektr%')
  OR (v.term IN ('Rohrleitungsbauer','Rohrschlosser','Schweißer','Schweisser','MAG-Schweißer','WIG-Schweißer','Welder')
        AND (g.kg_title ILIKE '%zavar%' OR g.kg_title ILIKE '%varil%' OR g.kg_title ILIKE '%metal%'))
)
ON CONFLICT DO NOTHING;

-- ---------- SCHRITT 3: NEUE GRUPPEN erstellen (virtuell) ----------
-- Fuer Berufe ohne CRM-Gruppe: eigene Such-Gruppe.
-- Keine Kandidaten-Umsortierung noetig - sie greifen ueber die Berufs-Titel.

INSERT INTO search_synonyms (term, canonical_group) VALUES
  ('HDD-Bediener','virt_hdd'),('HDD Operator','virt_hdd'),('Horizontalspülbohrgerät','virt_hdd'),
  ('Bedienmannschaft HDD','virt_hdd'),('Operator horizontalnog bušenja','virt_hdd'),
  ('Operator horizontalnog busenja','virt_hdd'),('HDD mašinista','virt_hdd'),
  ('Mašinista bušaće opreme','virt_hdd'),('Bušač','virt_hdd'),('Busac','virt_hdd'),
  ('Horizontalbohrgerät','virt_hdd'),('Spülbohrgerät','virt_hdd'),('HDD','virt_hdd'),
  ('Horizontalbohren','virt_hdd')
ON CONFLICT DO NOTHING;

INSERT INTO search_synonyms (term, canonical_group)
SELECT v.term, 'virt_rohrleitung'
FROM (VALUES
  ('Rohrmonteur'),('Rohrleitungsmonteur'),('Gas-Wasser-Installateur'),
  ('Zavarivač cjevovoda'),('Zavarivac cjevovoda'),('Cjevovodni zavarivač'),('Cjevovodni zavarivac'),
  ('Zavarivač PE cijevi'),('Zavarivac PE cijevi'),('Varilac'),('Varilač'),
  ('Zavarivač'),('Zavarivac'),('Elektroschweißer')
) v(term)
WHERE NOT EXISTS (SELECT 1 FROM search_synonyms s WHERE s.term = v.term)
ON CONFLICT DO NOTHING;

-- ---------- KONTROLLE ----------
SELECT canonical_group, count(*) AS begriffe FROM search_synonyms
GROUP BY 1 ORDER BY 2 DESC;
