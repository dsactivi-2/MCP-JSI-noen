-- KORRIGIERTE VERSION (14.09.2026): MySQL-Reste gefixt
--   - status_aktivan: true -> 1 (Spalte ist integer)
--   - note_group/timeline_group/timeline_type: 'kandidat'/'note' -> 1 (Spalten sind integer)

-- ============================================================
-- Testdaten fuer den Neon-Dev-Klon (500 synthetische Kandidaten, KEINE echten Daten)
-- ============================================================

-- ---------- Lookups ----------
INSERT INTO idk_kandidat_status (status_id, status_naziv) VALUES
  (0,'Aktivan'),(1,'U obradi'),(2,'Na poslu'),(3,'Arhiva'),(4,'Rezerva'),
  (5,'Odbijen'),(6,'Intervju'),(7,'Dokumenti'),(8,'Zavrseno')

INSERT INTO idk_kandidat_status_prijave (status_id, status_naziv, status_aktivan, redoslijed_statusa) VALUES
  (0,'Bez prijave',1,1),(1,'Prijavljen',1,2),(2,'U razgovoru',1,3),(3,'Primljen',1,4)

INSERT INTO idk_kandidati_grupe (kg_id, kg_title, kg_date, kg_employeeid) VALUES
  (1,'Standard',now(),1),(2,'Premium',now(),1),(3,'Arhiva',now(),1),(4,'VIP',now(),1)

INSERT INTO idk_struke (id_struke, naziv_struke, naziv_struke_de) VALUES
  (1,'Elektrotehnika','Elektrotechnik'),(2,'Masinstvo','Maschinenbau'),
  (3,'Drvna industrija','Holzindustrie'),(4,'Gastro','Gastronomie'),(5,'Ekonomija','Wirtschaft')

INSERT INTO idk_skole (skola_id, skola_naziv, skola_tip_obrazovanja) VALUES
  (1,'ETS Sarajevo','SSS'),(2,'Masinska skola Tuzla','SSS'),
  (3,'Drvna skola Banja Luka','SSS'),(4,'Gimnazija Zagreb','SSS')

INSERT INTO idk_skole_smjerovi (ss_id, ss_naziv, ss_naziv_de, ss_struka_id, ss_skola_id) VALUES
  (1,'Elektroinstallateur','Elektroinstallateur',1,1),
  (2,'Elektromehanicar','Elektromechaniker',1,1),
  (3,'Elektrotehnicar','Elektrotechniker',1,1),
  (4,'Automehanicar','Automechaniker',2,2),
  (5,'Bravar','Schlosser',2,2),
  (6,'Stolar','Schreiner',3,3),
  (7,'Tesar','Zimmermann',3,3),
  (8,'Kuhar','Koch',4,4),
  (9,'Gastronom','Gastronom',4,4),
  (10,'Ekonomista','Wirtschaftswissenschaftler',5,4)

-- ---------- 500 Kandidaten ----------
INSERT INTO idk_kandidati
  (kandidat_id, kandidat_check, kandidat_ime, kandidat_prezime, kandidat_prijava_na, kandidat_slika,
   kandidat_status, kandidat_datetime, kandidat_spol, kandidat_datumrodjenja, kandidat_group,
   kandidat_porijeklo, kandidat_email, kandidat_mobitel, kandidat_grad,
   kandidat_drzavljanstvo_vrsta, boravak_eu, kandidat_vozacka_dozvola, kandidat_vozacka_kategorija,
   kandidat_status_prijave, kandidat_status_messenger, kandidat_jmbg, kandidat_dipl_id)
SELECT g, '', 'Test'||g, 'Kandidat'||g, '', '',
   CASE WHEN g % 17 = 0 THEN 3 ELSE (ARRAY[0,1,1,1,2,4,5,6,7,8])[g % 10 + 1] END,
   now(),
   CASE WHEN g % 2 = 0 THEN 'M' ELSE 'Z' END,
   (CURRENT_DATE - make_interval(years => 18 + (g % 48))),
   1 + (g % 4),
   CASE WHEN g % 13 = 0 THEN 6 WHEN g % 13 = 1 THEN 7 ELSE 1 + (g % 5) END,
   'k' || g || '@test.dev', '06000000' || (g % 100),
   (ARRAY['Sarajevo','Banja Luka','Tuzla','Zagreb','Beograd','München','Wien'])[g % 7 + 1],
   CASE WHEN g % 6 = 0 THEN NULL WHEN g % 3 = 0 THEN 'NON-EU - Bosnia' ELSE 'EU - Croatia' END,
   CASE WHEN g % 4 = 0 THEN '' ELSE 'DA' END,
   CASE WHEN g % 10 < 7 THEN 'Da' ELSE 'Ne' END,
   (ARRAY['B','B, BE','C1','B','C','CE, C1E',NULL,'B, C1'])[g % 8 + 1],
   CASE WHEN g % 5 = 0 THEN 1 + (g % 3) ELSE NULL END,
   0, NULL, 0
FROM generate_series(1, 500) g

-- ---------- Ausbildung (70 %) ----------
INSERT INTO idk_kandidat_edukacija (ke_kandidat_id, ke_naziv, ke_naziv_kvalifikacije, ke_datumod, ke_datumdo)
SELECT k.kandidat_id,
  'Skola ' || (k.kandidat_id % 20),
  CASE k.kandidat_id % 20
    WHEN 0 THEN 'Elektroinstallateur'
    WHEN 1 THEN 'Elektromehanicar'
    WHEN 2 THEN 'Elektrotehnicar'
    WHEN 3 THEN 'Automehanicar'
    WHEN 4 THEN 'Bravar'
    WHEN 5 THEN 'Stolar'
    WHEN 6 THEN 'Kuhar'
    ELSE (ARRAY['Ekonomista','Gastronom','Tesar'])[k.kandidat_id % 3 + 1]
  END,
  ('2010-09-01'::date + make_interval(years => k.kandidat_id % 10)),
  ('2014-06-01'::date + make_interval(years => k.kandidat_id % 10))
FROM idk_kandidati k WHERE k.kandidat_id % 10 < 7

-- ---------- Sprachen: Deutsch (65 %, davon viele A2/B1), Englisch (15 %) ----------
INSERT INTO idk_kandidat_jezici
  (kj_kandidatid, kj_naziv, kj_slusanje, kj_citanje, kj_govorna_interakcija, kj_govorna_produkcija, kj_pisanje)
SELECT k.kandidat_id, 'Njemacki', l.lvl, l.lvl, l.lvl, l.lvl, l.lvl
FROM idk_kandidati k,
LATERAL (SELECT CASE k.kandidat_id % 10
    WHEN 0 THEN 'A1' WHEN 1 THEN 'A1' WHEN 2 THEN 'A2' WHEN 3 THEN 'A2' WHEN 4 THEN 'A2'
    WHEN 5 THEN 'B1' WHEN 6 THEN 'B1' WHEN 7 THEN 'B2' WHEN 8 THEN 'C1'
    ELSE 'BEZ ZNANJA' END AS lvl) l
WHERE k.kandidat_id % 100 < 65

INSERT INTO idk_kandidat_jezici
  (kj_kandidatid, kj_naziv, kj_slusanje, kj_citanje, kj_govorna_interakcija, kj_govorna_produkcija, kj_pisanje)
SELECT k.kandidat_id, 'Engleski', l.lvl, l.lvl, l.lvl, l.lvl, l.lvl
FROM idk_kandidati k,
LATERAL (SELECT CASE k.kandidat_id % 10
    WHEN 0 THEN 'A1' WHEN 1 THEN 'A2' WHEN 2 THEN 'A2' WHEN 3 THEN 'B1' WHEN 4 THEN 'B1'
    WHEN 5 THEN 'B2' WHEN 6 THEN 'B2' WHEN 7 THEN 'C1' WHEN 8 THEN 'C2'
    ELSE 'BEZ ZNANJA' END AS lvl) l
WHERE k.kandidat_id % 100 >= 65 AND k.kandidat_id % 100 < 80

-- ---------- Berufserfahrung (60 %, Titel passt zur Ausbildung) ----------
INSERT INTO idk_kandidat_radno_iskustvo
  (kri_kandidat_id, kri_darum_od, kri_datum_do, kri_pozicija, kri_naziv)
SELECT k.kandidat_id,
  ('201' || (k.kandidat_id % 9) || '-03-01')::date,
  CASE WHEN k.kandidat_id % 3 = 0 THEN NULL
       ELSE (('201' || (k.kandidat_id % 9) || '-03-01')::date + interval '3 years')::date END,
  COALESCE(ed.q, 'Pomocni radnik'),
  'Firma ' || k.kandidat_id
FROM idk_kandidati k
LEFT JOIN LATERAL (
  SELECT e.ke_naziv_kvalifikacije AS q
  FROM idk_kandidat_edukacija e WHERE e.ke_kandidat_id = k.kandidat_id LIMIT 1
) ed ON true
WHERE k.kandidat_id % 100 < 60

-- ---------- DIPL-Datensaetze (jeder 50.) + Nostrifikation ----------
INSERT INTO idk_nd_kandidata (id_broj_nd_kandidata, status_nd_kandidata)
SELECT kandidat_id, (kandidat_id / 50) % 8 FROM idk_kandidati WHERE kandidat_id % 50 = 0

UPDATE idk_kandidati SET kandidat_dipl_id = kandidat_id WHERE kandidat_id % 50 = 0

INSERT INTO idk_nostrifikovane_diplome (id_cand_dipl, file_nd, full_recognition)
SELECT kandidat_id, 'diploma.pdf', (kandidat_id / 50) % 4 FROM idk_kandidati WHERE kandidat_id % 50 = 0

-- ---------- Notizen / Timeline (Beispiele) ----------
INSERT INTO idk_notes (note_txt, note_datetime, note_group, note_dataid, note_employeeid)
SELECT 'Notiz fuer Kandidat ' || kandidat_id, now(), 1, kandidat_id, 1
FROM idk_kandidati WHERE kandidat_id % 100 = 0

INSERT INTO idk_timeline (timeline_type, timeline_txt, timeline_datetime, timeline_group, timeline_dataid, timeline_employeeid)
SELECT 1, 'Eintrag fuer Kandidat ' || kandidat_id, now(), 1, kandidat_id, 1
FROM idk_kandidati WHERE kandidat_id % 150 = 0

-- ---------- Gruppen + Synonyme aus Prod nachziehen (sind in 01_extensions.sql) ----------;
