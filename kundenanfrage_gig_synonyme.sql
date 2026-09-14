-- ============================================================
-- KUNDENANFRAGE GIG mbH (Thomas): Sourcing-Sammlung
-- Tiefbauer | Glasfasermonteure | Elektriker | Rohrleitungsbauer | HDD
-- Schritt 1: Rohrleitungsbauer aus instalater-Gruppe in Schweißer-Gruppe
--    verschieben (dort gehoert er hin - Kunde will SCHWEISSEN)
-- Schritt 2: Neue Gruppen einfuegen
-- ============================================================

-- Schritt 1
DELETE FROM search_synonyms WHERE term = 'Rohrleitungsbauer' AND canonical_group = 'instalater';

-- Schritt 2
INSERT INTO search_synonyms (term, canonical_group) VALUES
  -- TIEFBAU (Erd-/Strassen-/Tiefbauarbeiten)
  ('Tiefbauer', 'tiefbau'), ('Tiefbauarbeiter', 'tiefbau'),
  ('Bauarbeiter', 'tiefbau'), ('Bauhilfsarbeiter', 'tiefbau'),
  ('Građevinski radnik', 'tiefbau'), ('Gradjevinski radnik', 'tiefbau'),
  ('Zemljani radovi', 'tiefbau'), ('Zemljaniradnik', 'tiefbau'),
  ('Radnik na zemljanim radovima', 'tiefbau'),
  ('Cestarski radnik', 'tiefbau'), ('Cestar', 'tiefbau'),
  ('Asfalter', 'tiefbau'), ('Asfaltirac', 'tiefbau'),
  ('Bagerista', 'tiefbau'), ('Maschinist bagera', 'tiefbau'),
  ('Kanalarbeiter', 'tiefbau'), ('Rovokopač', 'tiefbau'),
  ('Rovokopac', 'tiefbau'), ('Strassenbauer', 'tiefbau'),

  -- GLASFASER (LWL/FTTH/Netztechnik)
  ('Glasfasermonteur', 'glasfaser'), ('Glasfaserinstallateur', 'glasfaser'),
  ('LWL-Monteur', 'glasfaser'), ('LWL Installateur', 'glasfaser'),
  ('Fiberoptic technician', 'glasfaser'), ('Fiber optic', 'glasfaser'),
  ('Optički montažer', 'glasfaser'), ('Opticki montazer', 'glasfaser'),
  ('Montažer optičkih kablova', 'glasfaser'),
  ('Montazer optickih kablova', 'glasfaser'),
  ('Telekomunikacijski monter', 'glasfaser'),
  ('Telekom montazer', 'glasfaser'),
  ('Tehničar za optičke mreže', 'glasfaser'),
  ('Tehnicar za opticke mreze', 'glasfaser'),
  ('Netzwerktechniker', 'glasfaser'), ('FTTH-Monteur', 'glasfaser'),

  -- ELEKTRIK (bereits teilweise vorhanden, ergaenzt)
  ('Elektriker', 'elektrik'), ('Elektroinstallateur', 'elektrik'),
  ('Elektroinstalater', 'elektrik'), ('Elektrotehnicar', 'elektrik'),
  ('Elektrotechniker', 'elektrik'), ('Elektromonteur', 'elektrik'),
  ('Elektromehanicar', 'elektrik'), ('Elektromechaniker', 'elektrik'),
  ('Elektricar', 'elektrik'), ('Električar', 'elektrik'),
  ('Elektrotehnik', 'elektrik'), ('Elektro radnik', 'elektrik'),

  -- ROHRLEITUNG / SCHWEISSEN (Gas-, Wasser-, Fernwärme in Stahl + PE)
  ('Rohrleitungsbauer', 'rohrleitung'), ('Rohrschlosser', 'rohrleitung'),
  ('Rohrmonteur', 'rohrleitung'), ('Rohrleitungsmonteur', 'rohrleitung'),
  ('Gas-Wasser-Installateur', 'rohrleitung'),
  ('Zavarivač cjevovoda', 'rohrleitung'), ('Zavarivac cjevovoda', 'rohrleitung'),
  ('Cjevovodni zavarivač', 'rohrleitung'), ('Cjevovodni zavarivac', 'rohrleitung'),
  ('Zavarivač PE cijevi', 'rohrleitung'), ('Zavarivac PE cijevi', 'rohrleitung'),
  ('Schweißer', 'rohrleitung'), ('Schweisser', 'rohrleitung'),
  ('Varilac', 'rohrleitung'), ('Varilač', 'rohrleitung'),
  ('Zavarivač', 'rohrleitung'), ('Zavarivac', 'rohrleitung'),
  ('Welder', 'rohrleitung'), ('MAG-Schweißer', 'rohrleitung'),
  ('WIG-Schweißer', 'rohrleitung'), ('Elektroschweißer', 'rohrleitung'),

  -- HDD (Horizontalspülbohr-/Directional-Drilling-Bediener)
  ('HDD-Bediener', 'hdd'), ('HDD Operator', 'hdd'),
  ('Horizontalspülbohrgerät', 'hdd'),
  ('Bedienmannschaft HDD', 'hdd'),
  ('Operator horizontalnog bušenja', 'hdd'),
  ('Operator horizontalnog busenja', 'hdd'),
  ('HDD mašinista', 'hdd'), ('HDD masinista', 'hdd'),
  ('Mašinista bušaće opreme', 'hdd'),
  ('Masinista busace opreme', 'hdd'),
  ('Bušač', 'hdd'), ('Busac', 'hdd'),
  ('Horizontalbohrgerät', 'hdd'), ('Spülbohrgerät', 'hdd')

ON CONFLICT DO NOTHING;

-- Kontrolle: Gruppen und Staerke anzeigen
SELECT canonical_group, count(*) FROM search_synonyms GROUP BY 1 ORDER BY 2 DESC;
