# NEON-DEV-KLON - Anleitung fuer die Agentin mit Neon-Plugin

## Antworten auf deine Fragen

1. **Branch?** -> JA: Bitte einen Branch `mcp-dev` im bestehenden Projekt "CRM" erstellen
   (erstellt am 13.09., EU-Central, Postgres 18). Produktions-Daten gibt es auf Neon
   NICHT - das ist bewusst so.
2. **MySQL-Dump importieren?** -> NEIN, nicht importieren. Das Bundle enthaelt
   `neon-dev/00_schema.sql`: die 17 Kern-Tabellen bereits als sauberes Postgres-DDL
   (aus dem Dump vom 26.02.2026 konvertiert + verifiziert).

## Ausfuehrung (Reihenfolge, je eine Datei per run_sql)

1. `neon-dev/00_schema.sql`     - Tabellen (idempotent, IF NOT EXISTS)
2. `neon-dev/01_extensions.sql` - Synonyme + Zusatz-Tabellen (Profile, Historie,
                                  pending_changes, Notifications, Settings)
3. `neon-dev/02_search_function.sql` - crm_search_candidates(jsonb, text)
4. `neon-dev/03_trigger.sql`    - Benachrichtigungs-Trigger
5. `neon-dev/04_seed.sql`       - 500 synthetische Test-Kandidaten + Lookups
6. `neon-dev/05_selftest.sql`   - Pruef-Abfragen: muessen die erwarteten Werte liefern
   (Kommentare in der Datei). WICHTIG: Die Beispiel-Suche am Ende muss Treffer > 0
   liefern und bei audience='customer' muessen kandidat_email/mobitel/jmbg/adresa
   NULL sein.

## Danach

- Connection String des Branches generieren (nur im Chat androppen, wenn der Nutzer
  ihn fuer die .env braucht - nicht in diesem Dokument speichern)
- Dem Nutzer melden: Klon bereit, MCP-.env fuer Dev auf Neon zeigen lassen,
  SUPABASE bleibt unangetastet.

## Regeln

- KEINE Rollen anlegen (Neon-Default-Rolle reicht fuer den Dev-Klon)
- KEINE echten Personendaten - Seed ist komplett synthetisch
- Keine Aenderungen an den idk_*-Tabellen ausser ueber diese Dateien
