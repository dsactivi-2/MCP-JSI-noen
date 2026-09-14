# CHANGELOG

## 14.09.2026 - Fixes aus Neon-Dev-Klon uebernommen (getestet auf Branch mcp-dev)

- 02_search_function.sql: ARRAY[...]-Fix, ILIKE %L, 0-Treffer liefert JSON,
  Erfahrungsjahre AGE(end,start)
- 04_seed.sql: true->1, 'kandidat'->1 (Integer-Spalten)
- Synonyme: Elektrotehnicar + Elektrotechniker -> elektrik
- Selftest: Erwartung deutsch_a2+ = 225

Verifikation Neon (mcp-dev): alle Checks gruen, Beispiel-Suche 7 Treffer,
Kundenansicht redigiert korrekt.

## 14.09.2026 (2) - MCP-Runtime-Fixes (getestet gegen Neon, alle 5 Tests gruen)

- package.json: "tsx --env-file=.env" - sonst wird die .env nie geladen
  (Server waere mit leerer DATABASE_URL gestartet)
- db.ts: IDs aus Postgres-bigint werden als Number zurueckgegeben
  (proposeChange, listPending, listNotifications) - sonst bricht der
  Freigabe-Workflow mit Zod-Validierungsfehler ab

Testprotokoll (Neon, Branch mcp-dev):
Elektriker-Suche found:7 | Vollprofil komplett | Statuswechsel 20->4 applied
+ Notification geschrieben | Excel-Export 47 Zeilen | Kundensuche redigiert.

## 14.09.2026 (3) - Install-Pipeline-Fixes (Kimi-CLI-Review v1-5)

- KRITISCH: install.sh Zeile "cp -r $SRC $DEST" erzeugte bei Updates eine
  VERSCHACHTELUNG (crm-kandidatensuche/crm-kandidatensuche/) - stiller
  Fehlschlag mit Exit 0. Fix: cp -r "$SKILL_SRC/." "$DEST/"
- TOOLS.md + AGENTS.md liegen jetzt IM Skill-Ordner (keine toten Verweise)
- Verifikation vor "Fertig": alle 4 Dateien + Version muessen stimmen
- Versionsanzeige aus SKILL.md-Frontmatter
- Backup-Rotation: max. 2 Backups
- NEU: rollback.sh (letztes Backup zurueckspielen)
- NEU: ./install.sh --check (installierten Stand pruefen ohne zu kopieren)

## 14.09.2026 (4) - Codex-Review v1-5 verarbeitet

- NEU: CODEX-AGENTS.md = fertige MERGE (Master-Regeln AGENTS.md + Workflow
  SKILL.md) - loest das Ueberschreib-Problem bei ~/.codex/AGENTS.md
- install.sh installiert CODEX-AGENTS.md automatisch nach ~/.codex/AGENTS.md
  (mit Backup + chmod 600), wenn ~/.codex existiert
- SKILL.md: Tabelle repariert (fehlende | bei name_terms/contact_terms)

## 14.09.2026 (5) - EIGENER TIEFEN-AUDIT (Code Zeile fuer Zeile)

KRITISCH:
- getFullProfile: SELECT * auf idk_documents zog document_file (bytea,
  Binaer!) in den Agenten-Context -> jetzt nur Metadaten-Spalten
HOCH:
- Excel-Export: Base64-Ausgabe (bis ~1 MB) sprengte den Context ->
  immer Dateiausgabe (EXPORT_DIR oder os.tmpdir())
- applyChange: SELECT-then-UPDATE = Race Condition, kein Rollback ->
  atomare Transaktion mit UPDATE ... RETURNING, rowCount-Check, ROLLBACK
MITTEL:
- proposeChange prueft Kandidaten-Existenz
- db_schema: ohne Parameter jetzt KOMPAKT (Tabelle + Spaltenzahl + Typen)
  statt ~2000 Zeilen; mit Parameter weiterhin Detail
- index.ts: toter 'filename'-Parameter entfernt
DOCS: Versionen konsolidiert (Server 1.5.0, Skill 1.5.0, 18 Werkzeuge)
VERIFIZIERT GEGEN DUMP (keine Bugs): kri_naziv, document_dataid,
  kri_darum_od-Tippfehler korrekt uebernommen
OFFEN (bewusst): sources-Labels, kein Rate-Limit (lokal ok,
  bei Public-Deploy PFLICHT), idk_nalozi als Phase 2

## 14.09.2026 (6) - KRITISCH: Berufssuche nur 1 Quelle -> 3 Quellen

User-Fund: Heizungsinstallateur-Suche fand 3 statt ~10000.
Ursache: occupation_terms pruefte NUR ke_naziv_kvalifikacije (Ausbildung).
Fix: Match jetzt ueber DREI Quellen ODER-verknuepft:
  1. kandidat_zanimanje (Hauptberuf im Stammsatz)
  2. idk_kandidat_edukacija (ke_naziv_kvalifikacije UND ke_naziv)
  3. idk_kandidat_radno_iskustvo (kri_pozicija UND kri_naziv - Job-Titel)
NEU: db-setup/04_synonyme_v1-6.sql bzw. neon-dev/06_synonyme_v1-6.sql
(Heizung/Sanitaer/Installation, +14 Begriffe)
DEPLOY auf prod-copy: 02_search_function.sql erneut ausfuehren (CREATE OR
REPLACE) + 06_synonyme_v1-6.sql.

## 14.09.2026 (7) - occupation_source + Synonym-Korrektur

- NEU Filter: occupation_source = any|experience|profession|education.
  "Berufserfahrung als X" sucht jetzt NUR Job-Titel, nicht Ausbildung.
  (User-Fund: Baeckerin/Automechaniker als "Heizungsinstallateur-aehnlich")
- FIX: Bravar/Limar faelschlich in Synonym-Gruppe instalater -> Bravar raus,
  Limar -> metal. Falsche Treffer-Ketten unterbrochen.
- DEPLOY auf prod-copy: 02_search_function.sql (CREATE OR REPLACE)
  + 06_synonyme_v1-6.sql, DANN Test:
  SELECT crm_search_candidates('{"occupation_terms":["Heizungsinstallateur"],
  "occupation_source":"experience","limit":5}'::jsonb, 'internal');

## 14.09.2026 (8) - Trefferliste angereichert (kein Profil-Scanning mehr)

User-Fund: Agent rief get_full_profile fuer JEDEN Treffer auf (50+ Calls).
Ursache: Trefferliste hatte Sprache/Erfahrung/Beruf nicht dabei.
Fix: Suchfunktion liefert pro Treffer jetzt MIT: beruf, deutsch_hoeren,
englisch_hoeren, erfahrung_jahre (korrelierte Subselects, nur auf den
50 Treffer-Zeilen -> billig). SKILL.md Regel 7: kein Nachladen in Listen.
DEPLOY: 02_search_function.sql auf prod-copy erneut (CREATE OR REPLACE).

## 14.09.2026 (9) - STRICTE VALIDIERUNG (Fehler statt Schweigen)

User-Fund: Agent schickte occupation_source an die ALTE Funktion -> still
ignoriert -> Berufsfilter fiel raus -> 31.864 statt gezielter Treffer.
FIX 1: Whitelist aller erlaubten Filter-Schluessel. Unbekannter Schluessel
  = sofortige Fehlermeldung mit Hinweis "Funktion veraltet einspielen".
FIX 2: limit/offset hart validiert (1-50), statt still zu clampen.
WICHTIG: Erst nach DEPLOY der neuen 02_search_function.sql wirksam.

## 14.09.2026 (10) - KRITISCH: kandidat_zanimanje existiert NICHT

Dump-verifiziert: idk_kandidati hat 99 Spalten, KEIN Berufsfeld.
Beruf lebt nur in: Ausbildung (ke_naziv_kvalifikacije), Job-Titeln
(kri_pozicija/kri_naziv) und der GRUPPE (kg_title).
FIX: occupation 'profession'/'any' matchen jetzt auf g.kg_title
(Gruppen-Titel). Anreicherung 'beruf' liefert ebenfalls kg_title.
Gruppen-Matrix baut Mitglieds-Berufe aus Ausbildung + Job-Titeln.
DEPLOY noetig: 02_search_function.sql + gruppen_matrix_v1.sql neu.

## 14.09.2026 (11) - Remote-Deploy vorbereitet

- NEU: Streamable-HTTP-Transport (index-http.ts) - Server als Webserver
- NEU: tools.ts - zentrale Tool-Registrierung fuer stdio + HTTP (1:1 gleich)
- Auth: Bearer MCP_API_KEY, oder hinter OAuth-Proxy (Cloudflare Access)
- DEPLOY.md: Weg A (Cloudflare Tunnel+Access, 1-2h) / Weg B (VPS, 24/7)
- WICHTIG: Vor Deploy eingeschraenkte DB-Rolle anlegen (NICHT Owner!)

## 14.09.2026 (12) - FIX: DECLARE nach BEGIN = Syntaxfehler 42601

STRICTE FILTER-VALIDIERUNG: invalid_keys war INNERHALB des Bodys nach
BEGIN deklariert (PL/pgSQL: DECLARE nur vor BEGIN). -> Variable in den
Haupt-DECLARE-Block verschoben. Datei NEU einspielen noetig.

## 14.09.2026 (13) - FIX: limit-IF ebenfalls im DECLARE gestanden

lim/offs-Validierung war wie invalid_keys im DECLARE-Bereich (42601).
Jetzt: DECLARE nur Variablen, alle IF-Pruefungen nach BEGIN.

## 14.09.2026 (14) - FIX: %Njemacki im format($q$) nicht escaped

LIKE-Literale %%Njemacki%%/%%Engleski%% in der Hauptquery -> format()
parste %N als Specifier (22023). Verdopplung auf %% noetig.
