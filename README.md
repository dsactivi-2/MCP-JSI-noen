# CRM-Such-MCP v1.0 – finalisiert nach Wizard-Entscheidungen

## Bundle-Inhalt

- `AGENTS.md` - Master-Anleitung (Regeln, Rollen, Antwort-Stil)
- `TOOLS.md` - Referenz aller 18 Tools mit allen Parametern
- `skills/crm-kandidatensuche/SKILL.md` - Arbeitsablaeufe (kommt in den Agenten)
- `db-setup/` (Supabase), `neon-dev/` (Test-Klon), `crm-mcp/` (Server)

## Entscheidungen (aus dem Wizard, Stand 14.09.2026)

| Entscheidung | Umsetzung im Bundle |
|---|---|
| Lesen + Schreiben **mit Freigabe** | `propose_candidate_change` → menschliches OK → `apply_change(confirm=true)`. Writer-Rolle hat nur UPDATE auf 13 freigegebene Spalten von `idk_kandidati` + volle Rechte nur auf Zusatz-Tabellen |
| Vollprofil | `get_full_profile`: Stammdaten + Sprachen + Berufserfahrung + Ausbildung + Dokumente |
| Berufssuchprofile | `save/list/delete_search_profile`, per Namen in `search_candidates(profile=...)` aufrufbar |
| Such-Historie | `search_history`-Tabelle, jede Suche wird automatisch mitschrieben, `get_search_history` |
| Excel-Export jetzt | `export_candidates` (exceljs), max. 500 Zeilen wie das alte CRM |
| Benachrichtigungen | DB-Trigger auf Statusänderung → `status_notifications`, `get/ack/set_notifications_enabled` |
| Kundenansicht | `audience="customer"` in Suche + Profilen: E-Mail, Telefon, JMBG, Adresse werden NULL |
| Supabase + Neon-Dev-Klon | Supabase bleibt Produktion; Anleitung für Neon-Klon + Anonymisierung unten |

## Setup

### 1. SQL ausführen (Supabase SQL Editor, Reihenfolge einhalten)

```bash
db-setup/01_roles_and_tables.sql     # Rollen + Zusatz-Tabellen (Passwörter eintragen!)
db-setup/02_search_function.sql      # Suchfunktion (RLS-Fix: GRANT am Ende)
db-setup/03_notification_trigger.sql # Trigger
```

### 2. MCP-Server installieren

```bash
cd crm-mcp
cp .env.example .env   # DATABASE_URL + DATABASE_WRITE_URL + Passwörter eintragen
npm install
npm start              # Testlauf
```

### 3. In den Client einbinden (Beispiel Claude Desktop)

```json
{
  "mcpServers": {
    "crm-suche": {
      "command": "node",
      "args": ["/ABSOLUTER/PFAD/crm-mcp/node_modules/.bin/tsx", "/ABSOLUTER/PFAD/crm-mcp/src/index.ts"],
      "env": {
        "DATABASE_URL": "postgresql://dino_crm_discovery_ro_v1:PASSWORT@db.xxx.supabase.co:5432/postgres",
        "DATABASE_WRITE_URL": "postgresql://crm_mcp_writer:PASSWORT@db.xxx.supabase.co:5432/postgres",
        "DB_SSL": "true",
        "EXPORT_DIR": "/ABSOLUTER/PFAD/exports"
      }
    }
  }
}
```

Skill installieren (je nach Client):

- **Codex Desktop/CLI:** Inhalt von skills/crm-kandidatensuche/SKILL.md in ~/.codex/AGENTS.md MERGEN (nicht blind ueberschreiben, falls dort schon andere Regeln stehen)
- **Kimi Code CLI:** `mkdir -p ~/.agents/skills && cp -r skills/crm-kandidatensuche ~/.agents/skills/`
  (MCP-Server dort in `~/.kimi-code/mcp.json` eintragen, JSON-Schema `mcpServers`
  mit command/args/env - NICHT TOML, NICHT ~/.kimi/config.toml)
- Claude Desktop: siehe JSON-Beispiel oben

Nach Installation: Client neu starten (Skills/Tools werden nur in neuen Sessions registriert).

### 4. Neon-Dev-Klon (optional, empfohlen für Tests)

1. Projekt bei Neon anlegen, **Branch** `dev` erstellen
2. Schema importieren: nur `db-setup/*.sql` + Tabellenstruktur (keine Personendaten!)
   Oder: Supabase-Schema-Dump ohne Daten: `pg_dump --schema-only ...`
3. Kleinen, anonymisierten Datensatz erzeugen:

```sql
-- 5000 zufaellige Kandidaten kopieren + anonymisieren
CREATE TABLE dev_sample AS SELECT * FROM idk_kandidati ORDER BY random() LIMIT 5000;
UPDATE dev_sample SET
  kandidat_ime = 'Test', kandidat_prezime = 'Kandidat ' || kandidat_id,
  kandidat_email = 'k' || kandidat_id || '@test.dev',
  kandidat_mobitel = '000000000', kandidat_jmbg = NULL, kandidat_adresa = NULL;
```

4. Im `.env` des MCP für Entwicklung `DATABASE_URL` auf Neon zeigen lassen.

## Verifikation der Filterlogik

Alle 17 Filter sind 1:1 aus `serversidedata.php` (case `lista_kandidata`) übernommen und gegen
den Produktions-Dump vom 26.02.2026 geprüft. Bewusste Abweichungen:
- **LEFT JOINs** statt INNER JOINs (altes CRM verlor Kandidaten ohne Gruppe/Status)
- **Exaktes Alter** statt PHP-Jahresdifferenz
- **Kundenansicht** redigiert Kontaktdaten (gab es im alten CRM nicht)

## Sicherheit

- Read-only-Rolle: `statement_timeout 10s`, `default_transaction_read_only`, nur SELECT
- Writer-Rolle: kein DELETE/DDL, UPDATE nur auf 13 Whitelist-Spalten, Server prüft zusätzlich
- Freigabe-Pflicht: `apply_change` verlangt `confirm=true` = explizites menschliches Zustimmen
- Kein Secret im Code, alles über `.env`


## Status Schema-Verifikation

Verifiziert gegen Produktions-Dump (26.02.2026, Teile aa/ab/ac_aa) UND PHP-Quelltext:
alle von der Suche genutzten Spalten inkl. `idk_kandidati`, `idk_kandidat_jezici`,
`idk_kandidat_radno_iskustvo` (Achtung: Spalte heißt im Original `kri_darum_od`),
`idk_kandidat_edukacija`, `idk_kandidat_status`, `idk_kandidat_status_prijave`,
`idk_kandidati_grupe`, `idk_nd_kandidata`.
Alle Such-Tabellen sind gegen Dump UND PHP verifiziert. `profession_ids` liefert
jetzt lesbare Namen aus `idk_struke` (BS + DE). Für später: `idk_notes`,
`idk_timeline`, `idk_tasks` (Phase-2-Kandidaten).

## Update-Prozedur (v1-x -> v1-y)

Ein Befehl erledigt alles (Backup + Kopieren + Verifikation):
`bash install.sh`   (Rollback: `bash rollback.sh`)

Manuell nur noetig, wenn das Skript nicht laeuft:
1. Backup: `cp -r ~/.agents/skills/crm-kandidatensuche ~/.agents/skills/crm-kandidatensuche.bak.$(date +%Y%m%d)`
2. Kopieren: `cp -r skills/crm-kandidatensuche/. ~/.agents/skills/crm-kandidatensuche/`
   (ALLE 4 Dateien: SKILL.md, TOOLS.md, AGENTS.md, CHANGELOG.md liegen jetzt
   zusammen im Skill-Ordner)
3. Codex: Inhalt von AGENTS.md nach ~/.codex/AGENTS.md mergen
4. CHANGELOG.md lesen - dort steht, ob die DB-Seite (02_search_function.sql)
   erneut eingespielt werden muss
