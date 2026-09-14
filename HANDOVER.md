# HANDOVER – CRM-Such-MCP Projekt
## Vollständige Übergabe-Dokumentation | Stand: 14.09.2026, 15:45 Uhr

---

# TEIL 1: PROJEKTÜBERSICHT

## 1.1 Was ist das?
Ein MCP-Server (Model Context Protocol), der dein Legacy-PHP-CRM (Jobstep,
122.004 Kandidaten) per Sprachbefehl durchsuchbar macht. KI-Agenten
(Codex, Kimi CLI, später weitere) können in normaler Sprache (DE/BS/EN)
Kandidaten suchen, Profile anzeigen, exportieren und – nach Freigabe –
Status ändern.

## 1.2 Ausgangslage (Warum dieses Projekt?)
- Altes PHP-CRM (Jobstep) mit MySQL-Datenbank, über 10 Jahre gewachsen
- Grok hatte daraus zuvor ein unbenutzbares Chaos gebaut
- Ziel: Filterlogik des alten CRMs 1:1 übernehmen, aber KI-gestützt und
  zukunftssicher auf Postgres

## 1.3 Was wurde erreicht (14.09., ein Tag)
| Meilenstein | Status |
|---|---|
| Komplette Filterlogik aus PHP extrahiert + verifiziert | ✅ |
| Postgres-Suchfunktion mit 30+ Filtern gebaut | ✅ |
| MCP-Server mit 18 Tools | ✅ |
| 122.004 echte Kandidaten von MySQL → Neon migriert | ✅ |
| Skills für Codex + Kimi CLI | ✅ |
| Synonym-/Gruppen-System (datengetrieben) | ✅ |
| 50 Bugs gefunden und behoben | ✅ |

---

# TEIL 2: ARCHITEKTUR

## 2.1 Die drei Ebenen

```
┌─────────────────────────────────────────────────┐
│  EBENE 3: SKILLS (Anleitung für Agenten)        │
│  SKILL.md + TOOLS.md + AGENTS.md + CHANGELOG.md │
│  Installiert: ~/.agents/skills/crm-kandidatensuche/
│  Codex: ~/.codex/AGENTS.md (Merge-Version)      │
├─────────────────────────────────────────────────┤
│  EBENE 2: MCP-SERVER (Werkzeuge)                │
│  Node.js/TypeScript, 18 Tools                   │
│  stdio-Modus: Clients spawnen lokal (Default)   │
│  HTTP-Modus: MCP_TRANSPORT=http (Remote-Deploy) │
│  Code: Bundle crm-mcp/, läuft aus v1-3-Ordner!  │
├─────────────────────────────────────────────────┤
│  EBENE 1: DATENBANK (Fundament)                 │
│  PRODUKTIONS-DATENBANK: Neon, Branch prod-copy  │
│  179 Tabellen, 122.004 Kandidaten               │
│  Kern: Funktion crm_search_candidates(jsonb,text)│
│  Zusatz: search_synonyms, Profile, Historie,    │
│          pending_changes, Notifications, Trigger│
└─────────────────────────────────────────────────┘
```

## 2.2 Verbindungsdaten (WOHIN ALLES ZEIGT)

| Komponente | Ziel | Wo konfiguriert |
|---|---|---|
| MCP-Server (stdio) | prod-copy (Pooler) | v1-3-Ordner/.env |
| Kimi CLI eigener Server | prod-copy (Pooler) | ~/.kimi-code/mcp.json |
| Verbindungs-String | ~/.neon_prod_copy_url | (Quelle aller Wahrheit) |

**WICHTIG:** Passwort wurde am 14.09. rotiert. Aktueller String steht in
~/.neon_prod_copy_url. Format: postgresql://neondb_owner:npg_...@ep-patient-
salad-b1xsn1ml-pooler.c-5.eu-central-1.aws.neon.tech/neondb?sslmode=require

## 2.3 Bundle-Struktur (~/crm-mcp oder Downloads-Ordner)

```
crm-mcp-bundle-v1.12/
├── VERSION.txt              ← Immer zuerst lesen: Versionsnummer
├── HANDOVER.md              ← DIESES Dokument
├── PLAN.md                  ← Phasenplan 0-5
├── TODO.md                  ← Lebender Aufgabenblock (von beiden gepflegt)
├── FEHLERCHRONIK.md         ← Alle 50 Bugs mit Fix-History
├── CHANGELOG.md             ← Technische Änderungshistorie
├── AGENTS.md                ← Master-Regeln (8 Pflichtregeln)
├── TOOLS.md                 ← Referenz aller 18 Tools
├── DEPLOY.md                ← Remote-Deploy (HTTP + OAuth-Optionen)
├── install.sh               ← Skill-Installer (Backup + Verifikation)
├── rollback.sh              ← Rollback auf letzte Version
├── verify-and-fix.sh        ← Diagnose-Tool (5 kritische Punkte)
├── gruppen_matrix_v1.sql    ← Gruppen-Synonyme (Thomas-Anfrage)
├── kundenanfrage_gig_synonyme.sql
├── db-setup/                ← Für SUPABASE-Produktion (noch nicht eingespielt!)
│   ├── 01_roles_and_tables.sql
│   ├── 02_search_function.sql
│   └── 03_notification_trigger.sql
├── neon-dev/                ← Für Neon prod-copy (EINGESPIELT)
│   ├── 01_extensions.sql
│   ├── 02_search_function.sql   ← AKTUELLE PRODUKTIONSVERSION
│   ├── 03_trigger.sql
│   ├── 04_seed.sql          ← Testdaten (nicht mehr nötig)
│   ├── 05_selftest.sql
│   └── 06_synonyme_v1-6.sql
├── crm-mcp/                 ← Server-Code
│   ├── src/index.ts         ← stdio-Einstieg (default)
│   ├── src/index-http.ts    ← HTTP-Einstieg (Remote)
│   ├── src/tools.ts         ← Zentrale Tool-Registrierung
│   ├── src/db.ts            ← DB-Logik (Pools, Freigabe-Workflow)
│   ├── src/excel.ts         ← Excel-Export
│   ├── src/config.ts        ← Spalten-Whitelist, Option-Queries
│   ├── .env.example
│   └── package.json
└── skills/crm-kandidatensuche/
    ├── SKILL.md             ← Workflow-Anleitung (im Agenten geladen)
    ├── TOOLS.md             ← Tool-Referenz
    ├── AGENTS.md            ← Master-Regeln
    ├── CHANGELOG.md
    └── CODEX-AGENTS.md      ← Merge für ~/.codex/AGENTS.md
```

---

# TEIL 3: DIE 18 TOOLS (vollständig)

## 3.1 Suche & Anzeige
1. **search_candidates** – DAS Hauptwerkzeug. 30+ Filter, Synonyme,
   occupation_source, audience, profile-Merge, Pagination (limit/offset).
2. **get_candidate_profile** – Stammdaten + Gruppe + Statusname.
3. **get_full_profile** – Komplett: Sprachen, Berufserfahrung, Ausbildung,
   Dokumente (nur Metadaten, kein Binaer).

## 3.2 Export & Profile
4. **export_candidates** – Excel-Datei (max 500 Zeilen), IMMER als Datei.
5. **save_search_profile** – Filter unter Namen speichern.
6. **list_search_profiles** – Gespeicherte Profile anzeigen.
7. **delete_search_profile** – Profil deaktivieren.

## 3.3 Schreiben mit Freigabe (Pflicht-Reihenfolge!)
8. **propose_candidate_change** – Änderung vorschlagen (prueft Kandidaten-
   Existenz + Feld-Whitelist). Gibt change_id zurueck.
9. **list_pending_changes** – Offene Freigaben anzeigen.
10. **apply_change** – NACH menschlichem "Ja": confirm=true ausfuehren.
    Atomare Transaktion, Race-Condition-sicher.
11. **reject_change** – Freigabe ablehnen.

## 3.4 Benachrichtigungen
12. **get_notifications** – Statusaenderungen (DB-Trigger schreibt mit).
13. **ack_notification** – Quittieren.
14. **set_notifications_enabled** – Trigger an/aus.

## 3.5 Hilfe
15. **get_filter_options** – Auswahlwerte (groups, statuses, sources...).
16. **get_search_history** – Automatisch mitgeschriebene Suchen.
17. **db_schema** – Kompakte Tabellenuebersicht oder Detail pro Tabelle.
18. **run_query** – Read-only SELECT (max 200 Zeilen, Guarded).

---

# TEIL 4: FILTER-REFERENZ (vollstaendig)

| Filter-Key | Typ | Beschreibung |
|---|---|---|
| occupation_terms | text[] | Beruf; Synonyme automatisch |
| occupation_source | text | any/experience/profession/education |
| name_terms | text[] | Vor-/Nachname |
| contact_terms | text[] | E-Mail/Tel/JMBG (nur internal) |
| age_from / age_to | int | Alter |
| has_driving_license | bool | Fuehrerschein |
| license_categories | text[] | B,BE,C1,C,C1E,CE (B zieht C..CE) |
| has_work_experience | bool | Mind. 1 Job |
| min_experience_years | int | Nur passende Jobs (bei occupation) |
| german_level / english_level | text | A1-C2, BEZ_ZNANJA, NO_INFO |
| language_skill | text | kj_slusanje (Default) + 4 weitere |
| groups / statuses / application_statuses | int[] | IDs |
| citizenship | text | EU / NON_EU |
| residence_eu | text | Exakter DB-Wert |
| schools / qualifications / profession_ids | text[]/int[] | Ausbildungswege |
| sources | int[] | Quelle (6 nimmt 7 mit) |
| dipl_statuses / nostrification | int[] | Diplom (0/3 inkl. NULL) |
| include_archive | bool | true = NUR Archiv |
| limit / offset | int | 1-50, Seiten |

**Archiv-Logik:** Default immer OHNE Status 3. include_archive=true → NUR Status 3.
**Strikte Validierung:** Unbekannte Filter-Keys = sofortiger Fehler (kein
stilles Ignorieren mehr!). limit >50 = Fehler.

---

# TEIL 5: DATEN-MODELL (was wichtig ist)

## 5.1 Kern-Tabellen
- **idk_kandidati** (122.004 Zeilen): Stammdaten. KEIN Berufsfeld!
  Beruf steht in: Gruppe (kandidat_group→kg_title), Ausbildung, Job-Titeln.
- **idk_kandidat_radno_iskustvo** (87.844 Jobzeilen): kri_darum_od
  (Tippfehlung im Original!), kri_datum_do, kri_pozicija, kri_naziv.
  DATUMSFORMAT: volle Daten (2010-09-01), NICHT Jahreszahlen.
- **idk_kandidat_jezici**: 5 Sprachdimensionen (kj_slusanje etc.),
  Werte A1-C2 + BEZ ZNANJA.
- **idk_kandidat_edukacija**: ke_naziv (Schule), ke_naziv_kvalifikacije (Smjer).
- **idk_kandidati_grupe**: kg_id, kg_title – EURE OFFIZIELLE BERUFS-TAXONOMIE
  (z.B. Internetmontažer fasst 20-30 Berufe). Such-Gruppen: grp_<kg_id>.

## 5.2 Zusatz-Tabellen (vom MCP angelegt)
- **search_synonyms** (term, canonical_group): Synonym-Matrix. Gruppen:
  elektrik, mechanik, holz, gastro, instalater, tiefbau, glasfaser,
  rohrleitung, hdd, virt_hdd, virt_rohrleitung, grp_<kg_id> (pro CRM-Gruppe),
  haushalt, metal.
- **search_profiles**: Gespeicherte Suchfilter.
- **search_history**: Automatisch jede Suche (question, filter, found).
- **pending_changes**: Freigabe-Workflow (pending→applying→applied/rejected).
- **status_notifications**: Trigger schreibt bei Statuswechsel.
- **notification_settings**: Schalter.

## 5.3 Wichtige Spalten-Fallstricke (gelernt aus 50 Bugs)
- kandidat_bracnostanje (NICHT bracno_stanje) – beide existieren, varchar ist richtig
- kri_darum_od (NICHT kri_datum_od) – Original-Tippfehler
- kandidat_status 3 = Archiv (immer ausgeblendet bis include_archive)
- kandidat_status_prijave 0 = inkl. NULL
- kandidat_porijeklo 6 = inkl. 7

---

# TEIL 6: ALLE ENTSCHEIDUNGEN (chronologisch)

1. **ADR-001:** LLM schreibt nie SQL → JSON-Filter → validierte RPC-Funktion
2. **Wizard-Entscheidungen (14.09.):**
   - Schreiben MIT Freigabe (propose→apply, nie direkt)
   - Vollprofil: Ja | Profile: Ja | Historie: Ja
   - Excel-Export: Jetzt | Benachrichtigungen: Ja
   - Kundenansicht: Kontakte verstecken | DB: Supabase+Neon
3. **Datenquelle:** Lokalen Dump statt Supabase (Supabase durch Grok
   moeglicherweise veraendert, Dump = verifizierte Wahrheit)
4. **Migration:** Node-Skript statt pgloader (pgloader kann kein SNI/channel_binding)
5. **Berufssuche:** 3 Quellen (Gruppe+Ausbildung+Jobs), occupation_source
6. **Synonyme:** Datengetrieben aus CRM-Gruppen (nicht handgemacht)
7. **Validierung:** Strikt (Fehler statt Schweigen) – teuerste Bugs schwiegen
8. **Performance:** pg_trgm-Indizes + Min-CU (statt sofort Typesense/Redis)
9. **Deploy:** Neon prod-copy als Arbeits-DB, Supabase spaeter
10. **Reviews:** Codex+Kimi pruefen Bundle vor Deploy (16/50 Bugs fanden sie)

---

# TEIL 7: BETRIEBSANLEITUNG

## 7.1 Server starten/stoppen (lokal, stdio)
Clients (Codex/Kimi) spawnen den Server SELBST – kein launchd noetig!
(Fruher gab es eine launchd-Plist → Crash-Loop, wurde entfernt.)
Manuell testen: cd <bundle>/crm-mcp && npm start

## 7.2 Skills aktualisieren (bei neuem Bundle)
bash <bundle>/install.sh
→ Backup + Kopieren + Verifikation + Codex-AGENTS.md
Dann: Codex + Kimi NEU STARTEN (nur neue Sessions laden Skills).

## 7.3 Suchfunktion aktualisieren (bei DB-Aenderung)
1. neon-dev/02_search_function.sql im TextEditor oeffnen
2. Cmd+A, Cmd+C
3. Neon SQL Editor → alles loeschen → einfuegen → Run
4. Test: SELECT crm_search_candidates('{"limit":1}'::jsonb,'internal');
TRICK bei kleinen Fixes: SELECT replace(pg_get_functiondef('crm_search_
candidates(jsonb,text)'::regprocedure), 'alt', 'neu') → Ergebnis ausfuehren.

## 7.4 Neues Passwort (wenn rotiert)
1. Neon Dashboard → prod-copy → Connect → Reset password
2. String kopieren → Terminal: read -s nach ~/.neon_prod_copy_url
3. sed: channel_binding raus, -pooler rein
4. jq → ~/.kimi-code/mcp.json | printf → v1-3/.env
5. Verifizieren: node -e pg-Test (Skript in FEHLERCHRONIK #21)

## 7.5 Kundenanfrage bearbeiten (Beispiel GIG/Thomas)
1. Gruppen pruefen: SELECT kg_id,kg_title FROM idk_kandidati_grupe...
2. Synonym-Gruppe nutzen: occupation_terms:["Tiefbauer","Glasfasermonteur",
   "Elektriker","Rohrleitungsbauer","HDD-Bediener"]
3. Fuer Kunden: audience='customer' (Kontakte versteckt)
4. Export: export_candidates → Excel-Datei

---

# TEIL 8: OFFENE PUNKTE (Stand 14.09. 15:45)

## 8.1 Heute noch (Blocker vor Benchmarks)
- [ ] Suchfunktion FINAL einspielen (letzte Version mit kri_darum_od + %%-
      Escape + DECLARE-Fix) → Elektriker-Test muss found:3395 mit beruf/
      deutsch_hoeren/erfahrung_jahre liefern
- [ ] Gruppen-Matrix (gruppen_matrix_v1.sql, korrigierte Fassung) einspielen
- [ ] trigram-Indizes einspielen (SQL aus Chat 13:05)
- [ ] Neon Min-CU auf 0.5-1 (Compute-Einstellung)

## 8.2 Diese Woche
- [ ] Benchmarks A (Codex) + B (Kimi) → Ziel <3 Min, Trefferzahlen vergleichen
- [ ] Vollmapping: DISTINCT-Listen (zanimanje-Ersatz: Ausbildung+Jobtitel)
      → komplette Synonym-Matrix aus echten Daten
- [ ] Antwort-Mail an Thomas (scheuse@gigmbh.net): Zahlen je Beruf + Profile
- [ ] Neon-Owner-Passwort: eingeschraenkte Rolle crm_mcp_remote anlegen

## 8.3 Phase 3 (Code-Haertung, an Kimi-Agent delegierbar)
- [ ] selftest-Tool (DB-Ping, Writer?, Export-Dir, Notification-State)
- [ ] export_candidates: audience-Parameter + Historie
- [ ] Neon-Cold-Start-Retry
- [ ] Doc-Drift (TOOLS.md/AGENTS.md aktualisieren)
- [ ] package.json → 1.6.0 | Bundle unter git
- [ ] run_query PII-Guardrail-Hinweis

## 8.4 Strategisch (bewusst spaeter)
- [ ] Supabase-Produktion: db-setup einspielen + .env-Umschaltung
- [ ] Remote-Deploy (DEPLOY.md Weg A Cloudflare 1-2h / Weg B VPS)
- [ ] Stufe-2 Performance (Redis/Typesense) NUR wenn p95>2s
- [ ] idk_nalozi als Phase-2-Tools | Dashboard | Rollenmodell

---

# TEIL 9: KONTAKTE & EXTERNE BEZÜGE

- **Thomas (GIG mbH)**: scheuse@gigmbh.net – Sourcing-Anfrage:
  Tiefbauer, Glasfasermonteure, Elektriker, Rohrleitungsbauer
  (Schweissen Gas/Wasser/Fernwärme Stahl+PE), HDD-Bediener.
  → Synonyme in kundenanfrage_gig_synonyme.sql + gruppen_matrix_v1.sql
- **Neon**: Projekt „CRM", Branch prod-copy (ep-patient-salad-b1xsn1ml-pooler),
  Plan: Launch (100 GB)
- **Alte DB**: jobstep-crm-mysql8 (OrbStack, 127.0.0.1:3307, DB productioncrmdb)
  – LAEUFT NOCH, nicht stoppen bis Umzug komplett abgenommen

---

# TEIL 10: LESSONS LEARNED (das Wichtigste aus 50 Bugs)

1. **Stille Fehler sind die teuersten.** Unbekannte Filter ignoriert,
   falsche Synonyme, 1-Quellen-Suche – nichts meldete sich. Deshalb:
   strikte Validierung, harte Fehler, Whitelists.
2. **Agenten-Reviews vor Deploy.** 16 von 50 Bugs fanden Codex/Kimi, nicht
   der Autor. Reviews sind Pflicht, kein Bonus.
3. **Verifizieren gegen echte Daten, nicht Erinnerung.** kandidat_zanimanje
   existierte nie – aus einem alten Planungsdokument übernommen. Dump
   schlägt Doku.
4. **Performance ist kein Bug, sondern fehlende Indizes.** pg_trgm + 12
   Indizes + Min-CU lösen, was sonst Stufe-2-Infrastruktur gebraucht hätte.
5. **Jede Änderung als Datei im Bundle, nie Hand-SQL.** Nachvollziehbarkeit
   (und git folgt noch).
6. **pg_get_functiondef-Trick** repariert Live-Funktionen ohne 400-Zeilen-
   Copy-Paste (kleine Fixes).
7. **stdio-MCP gehört ans Client-Spawning, nicht an launchd.** EOF-Loop.
8. **Neon-Spezifika:** kein channel_binding in pgloader/pg, Pooler-Host
   noetig bei alten libpq, pg_proc-Updates gesperrt.

---

# ANHANG A: VERIFIKATIONSCHECKS (Copy-Paste)

-- Server-Test lokal
cd <bundle>/crm-mcp && node -e "const pg=require('pg'),fs=require('fs');
const c=new pg.Client(fs.readFileSync(process.env.HOME+'/.neon_prod_copy_url','utf8').trim());
c.connect().then(()=>c.query('SELECT count(*) FROM idk_kandidati'))
 .then(r=>{console.log('OK:',r.rows[0].count);process.exit(0)})
 .catch(e=>{console.log('FEHLER:',e.message);process.exit(1)});"
-- Erwartet: OK: 122004

-- Funktions-Version pruefen
SELECT position('%%Njemacki%%' in prosrc)>0 FROM pg_proc
WHERE proname='crm_search_candidates';  -- Erwartet: t

-- Suche komplett
SELECT crm_search_candidates('{"occupation_terms":["Elektriker"],"age_from":20,
"age_to":40,"german_level":"A2","limit":3}'::jsonb,'internal');

# ANHANG B: DATEI-REGISTER (was liegt wo)

| Datei | Zweck | Aktualisieren |
|---|---|---|
| ~/.neon_prod_copy_url | DB-Verbindung (Quelle) | Bei Passwort-Rotation |
| ~/.kimi-code/mcp.json | Kimi CLI Server-Config | jq-Befehl 7.4 |
| v1-3/crm-mcp/.env | Server-Config (lauft!) | printf-Befehl 7.4 |
| ~/.agents/skills/crm-kandidatensuche/ | Kimi Skills | install.sh |
| ~/.codex/AGENTS.md | Codex Master-Regeln | install.sh (mergt) |
| Neon prod-copy | PRODUKTIONS-DATEN | SQL Editor |

# ANHANG C: NÄCHSTER MAKLERSCHNITT (wenn du in 3 Monaten weiter machst)
1. VERSION.txt lesen → TODO.md lesen → FEHLERCHRONIK lesen
2. Verify: Anhang A ausfuehren → alles gruen?
3. Dann: oberster offener Punkt in TODO.md
