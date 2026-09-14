-- ============================================================
-- Rollen, Synonyme, Zusatz-Tabellen (Profile, Historie,
-- Pending Changes, Benachrichtigungen, Einstellungen)
-- ROLLENNAMEN ANPASSEN: hier dino_crm_discovery_ro_v1 verwendet
-- (deine bestehende Read-only-Rolle aus der Discovery-Phase)
-- ============================================================

-- ---------- Synonym-Tabelle ----------
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

-- ---------- ROLLE 1: read-only (Suche + alles Lesen) ----------
-- Deine bestehende Rolle; Passwort nur setzen, falls sie LOGIN braucht
ALTER ROLE dino_crm_discovery_ro_v1 WITH LOGIN PASSWORD 'HIER_PASSWORT_EINTRAGEN';
GRANT USAGE ON SCHEMA public TO dino_crm_discovery_ro_v1;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO dino_crm_discovery_ro_v1;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO dino_crm_discovery_ro_v1;
ALTER ROLE dino_crm_discovery_ro_v1 SET statement_timeout = '10s';
ALTER ROLE dino_crm_discovery_ro_v1 SET default_transaction_read_only = on;

-- ---------- ROLLE 2: writer (nur Zusatz-Tabellen + kontrolliertes UPDATE) ----------
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'crm_mcp_writer') THEN
    CREATE ROLE crm_mcp_writer LOGIN PASSWORD 'HIER_STARKES_PASSWORT_EINTRAGEN';
  END IF;
END $$;

GRANT USAGE ON SCHEMA public TO crm_mcp_writer;
-- Zusatz-Tabellen voll
GRANT SELECT, INSERT, UPDATE ON search_profiles, search_history,
  pending_changes, status_notifications, notification_settings TO crm_mcp_writer;
-- Kandidaten: nur lesen + UPDATE auf freigegebene Spalten (Whitelist wird im MCP geprueft)
GRANT SELECT ON idk_kandidati TO crm_mcp_writer;
GRANT UPDATE (kandidat_status, kandidat_group, kandidat_grad, kandidat_drzava,
  kandidat_mobitel, kandidat_email, kandidat_vozacka_dozvola, kandidat_vozacka_kategorija,
  kandidat_iskustvo_u_struci, kandidat_iskustvo_u_struci_trajanje,
  kandidat_status_prijave, boravak_eu, kandidat_bracnostanje)
  ON idk_kandidati TO crm_mcp_writer;
ALTER ROLE crm_mcp_writer SET statement_timeout = '10s';
