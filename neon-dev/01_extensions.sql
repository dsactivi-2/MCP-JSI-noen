-- Synonyme + Zusatz-Tabellen (Neon-Version, ohne Rollen)

CREATE TABLE IF NOT EXISTS search_synonyms (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  term text NOT NULL,
  canonical_group text NOT NULL,
  UNIQUE (term, canonical_group)
);

INSERT INTO search_synonyms (term, canonical_group) VALUES
  ('Elektriker', 'elektrik'), ('Elektroinstallateur', 'elektrik'),
  ('Elektromonteur', 'elektrik'), ('Elektromechaniker', 'elektrik'),
  ('Elektrotehnicar', 'elektrik'), ('Elektrotechniker', 'elektrik'),
  ('Mechaniker', 'mechanik'), ('Kfz-Mechaniker', 'mechanik'),
  ('Automechaniker', 'mechanik'), ('Schlosser', 'mechanik'),
  ('Varilac', 'mechanik'), ('Bravar', 'mechanik'), ('Zavarivac', 'mechanik'),
  ('Tesar', 'holz'), ('Stolar', 'holz'), ('Schreiner', 'holz'), ('Tischler', 'holz'),
  ('Kuhar', 'gastro'), ('Koch', 'gastro'), ('Nastavnik', 'gastro')
ON CONFLICT DO NOTHING;

-- ---------- Zusatz-Tabellen ----------
CREATE TABLE IF NOT EXISTS search_profiles (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name text NOT NULL UNIQUE,
  filter jsonb NOT NULL,
  active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS search_history (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  question_text text,
  filter jsonb NOT NULL,
  found int,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS pending_changes (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  candidate_id int NOT NULL,
  changes jsonb NOT NULL,
  reason text,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','applied','rejected')),
  created_at timestamptz NOT NULL DEFAULT now(),
  decided_at timestamptz
);

CREATE TABLE IF NOT EXISTS status_notifications (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  candidate_id int NOT NULL,
  old_status int,
  new_status int,
  acked boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS notification_settings (
  key text PRIMARY KEY,
  enabled boolean NOT NULL DEFAULT true
);
INSERT INTO notification_settings (key, enabled) VALUES ('status_change', true)
ON CONFLICT (key) DO NOTHING;
