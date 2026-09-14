-- Zusaetzliche Berufs-Synonyme (v1.6.0) - Installation/Heizung/Sanitaer
INSERT INTO search_synonyms (term, canonical_group) VALUES
  ('Heizungsinstallateur', 'instalater'), ('Instalater', 'instalater'),
  ('Instalater grijanja', 'instalater'), ('Grijanje', 'instalater'),
  ('Sanitaerinstallateur', 'instalater'), ('Sanitetski instalater', 'instalater'),
  ('Klimalinstallateur', 'instalater'), ('Ventilationsinstallateur', 'instalater'),
  ('Rohrleitungsbauer', 'instalater'),
  ('Gasinstallateur', 'instalater'), ('Vodoinstalater', 'instalater'),
  ('Elektroinstalater', 'elektrik'), ('Elektricar', 'elektrik'),
  ('Hausmeister', 'haushalt'), ('Limar', 'metal')
ON CONFLICT DO NOTHING;
