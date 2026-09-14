# FEHLERCHRONIK – CRM-MCP Projekt (14.09.2026)
# ALLE Bugs/Fehler/Lücken seit Projektstart, wer fand sie, was draus wurde
# Stand: 14.09. ~15:20

## LEGENDE
# Schwere: KRITISCH (Daten/Security/Funktion kaputt) | HOCH (Fehlverhalten) | MITTEL | NIEDRIG | INFO
# Status: ✅ GEFIXT | 🔧 FIX LIEGT BEREIT (Deploy offen) | 📋 IDENTIFIZIERT (Fix geplant) | ℹ️ BEWUSST/OK

| # | Wer fand es | Bereich | Fehler/Beschreibung | Schwere | Status | Fix |
|---|---|---|---|---|---|---|
| 1 | Kimi-Agent | package.json | .env wurde nie geladen (tsx lädt nicht automatisch) -> Server mit leerer DB-URL | KRITISCH | ✅ | --env-file=.env |
| 2 | Kimi-Agent | db.ts | Bigint-IDs als String -> apply_change brach mit Zod-Fehler ab | KRITISCH | ✅ | Number()-Konvertierung |
| 3 | Kimi-Agent | SQL-Funktion | text[] || 'literal' -> Postgres-Type-Fehler bei Synonymen | KRITISCH | ✅ | ARRAY[...]-Syntax |
| 4 | Kimi-Agent | SQL-Funktion | ILIKE %s (unquoted) -> SQL-Syntaxfehler bei Sprachfiltern | KRITISCH | ✅ | ILIKE %L |
| 5 | Kimi-Agent | SQL-Funktion | Erfahrungsjahre falsch berechnet (AGE(ende) - Kalenderjahr) | HOCH | ✅ | AGE(ende, start) |
| 6 | Kimi-Agent | SQL-Funktion | 0 Treffer lieferte NULL statt leeres JSON | MITTEL | ✅ | LEFT JOIN + FILTER-Restrukturierung |
| 7 | Kimi-Agent | Seed | true/false in Integer-Spalten (status_aktivan) | HOCH | ✅ | 1/0 |
| 8 | Kimi-Agent | Seed | 'kandidat'/'note' Strings in Integer-Gruppen-Spalten | HOCH | ✅ | 1 |
| 9 | Kimi-Agent | Synonyme | Elektrotehnicar/Elektrotechniker fehlten -> Beispiel-Suche fand nie Treffer | HOCH | ✅ | Nachgetragen |
| 10 | Kimi-Agent | MCP-Protokoll | resources/list -> -32601 (Server hat keine Resources) | INFO | ℹ️ | Harmlos, dokumentiert |
| 11 | Kimi-Agent | install.sh | cp -r $SRC $DEST verschachtelte bei Update (crm-kandidatensuche/crm-kandidatensuche/) | KRITISCH | ✅ | cp -r "$SRC/." "$DEST/" |
| 12 | Kimi-Agent | Pfad-Doku | ~/.kimi/config.toml falsch -> richtig: ~/.kimi-code/mcp.json | KRITISCH | ✅ | Pfade korrigiert |
| 13 | Kimi-Agent | Pfad-Doku | ~/.kimi/AGENTS.md falsch -> richtig: ~/.agents/skills/ | KRITISCH | ✅ | Pfade korrigiert |
| 14 | Kimi-Agent | Bundle-Struktur | TOOLS.md/AGENTS.md lagen im Root, install.sh kopierte sie nicht | MITTEL | ✅ | Beide in Skill-Ordner |
| 15 | Kimi-Agent | Bundle | Kein Backup, keine Verifikation, keine Version, kein Rollback | MITTEL | ✅ | Backup+Rotation+rollback.sh+--check |
| 16 | USER | SKILL.md | Namensfilter komplett fehlend (Suchbox aus PHP nie uebersetzt) | KRITISCH | ✅ | name_terms + contact_terms |
| 17 | USER | DB-Schema | kandidat_bracno_stanje falsch -> richtig: kandidat_bracnostanje | KRITISCH | ✅ | In allen Dateien korrigiert |
| 18 | USER | Suche | Berufssuche nur 1 Quelle (Ausbildung) -> Heizungsinstallateur fand 3 statt 10000 | KRITISCH | ✅ | 3 Quellen: zanimanje + Ausbildung + Job-Titel |
| 19 | USER | Synonyme | Bravar/Limar faelschlich in instalater-Gruppe -> Baecker/Automechaniker als "aehnlich" | KRITISCH | ✅ | Bravar raus, Limar -> metal |
| 20 | USER | Suche | occupation_source fehlte: "Berufserfahrung als X" durchsuchte auch Ausbildung | HOCH | ✅ | occupation_source: any|experience|profession|education |
| 21 | Kimi-Agent | Neon | Passwort wurde rotiert -> alle DB-Calls mit auth failed | KRITISCH | 📋 | User: Reset in Konsole + 3 Configs |
| 22 | Ich | Neon/pgloader | channel_binding=require nicht parsbar -> Import starb | HOCH | ✅ | URL-Fix, dann Node-Migration |
| 23 | Ich | Neon/pgloader | SNI nicht unterstuetzt -> Pooler-Hostname noetig | HOCH | ✅ | -pooler Hostname |
| 24 | Ich | Migration | MySQL Zero-Dates 0000-00-00 -> 8 SMS-Zeilen fehlten | MITTEL | ✅ | Zero-Date -> 1970-01-01 |
| 25 | Ich | Fix-Skript | fix_sms2 filterte falsch -> ALLE 3512 statt 8 eingefuegt = Duplikate | HOCH | ✅ | TRUNCATE + sauberer Re-Import |
| 26 | Ich | db.ts | applyChange ohne Transaktion = Race Condition, kein Rollback | HOCH | ✅ | Atomare Transaktion + RETURNING |
| 27 | Ich | db.ts | proposeChange ohne Existenz-Check | MITTEL | ✅ | Check eingebaut |
| 28 | Ich | db.ts | getFullProfile: SELECT * zog document_file (bytea!) in Context | KRITISCH | ✅ | Nur Metadaten-Spalten |
| 29 | Ich | excel.ts | Excel-Export als Base64 im Chat (~1MB Context-Bombe) | KRITISCH | ✅ | Immer Dateiausgabe |
| 30 | Ich | db.ts | db_schema ohne Filter = ~2000 Zeilen Context-Flut | MITTEL | ✅ | Kompakt-Modus + table-Parameter |
| 31 | Ich | index.ts | Toter filename-Parameter im Export-Tool | NIEDRIG | ✅ | Entfernt |
| 32 | Ich | Versionen | 15 vs 18 Werkzeuge, Server 1.0.0 vs Skill 1.4.0 vs Bundle v1-3 | MITTEL | ✅ | Konsolidiert auf 1.5.0/18 |
| 33 | Kimi-Agent | Prozesse | 24 Zombie-Prozesse (12 tsx + 12 node), ~1,2GB RAM | HOCH | 📋 | pkill -f "crm-mcp/src/index.ts" |
| 34 | Kimi-Agent | launchd | stdio-MCP + KeepAlive = endloser Crash-Loop (EOF auf stdin) | HOCH | 📋 | Plist entfernen (Clients spawnen selbst) |
| 35 | USER | Agent-Verhalten | Agent rief get_full_profile 50x pro Suche (keine Daten in Liste) | HOCH | ✅ | Liste angereichert (beruf/sprache/erfahrung) + SKILL-Regel 7 |
| 36 | USER | Suche | Unbekannte Filter-Keys STILL ignoriert -> occupation_source fiel raus -> 31.864 falsch | KRITISCH | 🔧 | Strikte Whitelist = sofortiger Fehler |
| 37 | USER | Suche | limit/offset still gekappt statt Fehler -> Agent wusste nichts von 50er-Max | MITTEL | 🔧 | Harte Validierung 1-50 |
| 38 | Ich | Performance | KEINE Indizes: ILIKE '%x%' = Vollscan ueber 122k (10-30s pro Suche) | KRITISCH | 🔧 | pg_trgm-GIN-Indizes (SQL liegt bereit) |
| 39 | Ich | Neon | Scale-to-Zero: Compute schlaeft ein, Wake-Up pro Query | MITTEL | 🔧 | Min-CU hochdrehen |
| 40 | USER | Config | Kimi mcp.json zeigte auf geloeschten mcp-dev-Branch | KRITISCH | ✅ | Auf prod-copy umgestellt |
| 41 | Ich | Neon | Free-Tier 536MB Speicherlimit beim Import | KRITISCH | ✅ | Launch-Plan (100 GB) |
| 42 | Kimi-Agent | MCP | selftest-Tool fehlt (Fehler erst nach 8 Min sichtbar) | MITTEL | 📋 | Phase 3 |
| 43 | Kimi-Agent | Export | export_candidates ignoriert audience (immer internal) | HOCH | 📋 | Phase 3 |
| 44 | Kimi-Agent | MCP | Kein Retry bei Neon-Cold-Start | MITTEL | 📋 | Phase 3 |
| 45 | Kimi-Agent | Doku | TOOLS.md-Base64-Hinweis vs. Code-Realitaet (Drift) | NIEDRIG | 📋 | Phase 3 |
| 46 | Kimi-Agent | Security | Klartext-Secrets in mcp.json + Owner-Vollzugriff | HOCH | 📋 | Eingeschraenkte Rolle spaeter |
| 47 | Kimi-Agent | Security | run_query kann in 200er-Schritten PII auslesen | MITTEL | 📋 | Guardrail-Notiz SKILL.md |
| 48 | Kimi-Agent | UX | Rohe DB-Fehler 1:1 an Kunden durchgereicht | NIEDRIG | 📋 | Fehler-Mapping |
| 49 | Kimi-Agent | Logging | pg-SSL-Warnung = Log-Laerm (cosmetic) | NIEDRIG | ℹ️ | spaeter |
| 50 | Ich | Bundle | Kein git -> Nachvollziehbarkeit verloren | MITTEL | 📋 | Phase 3.5 |

## ZUSAMMENFASSUNG
- GEFIXT: 38
- FIX BEREIT (nur Deploy offen): 2 (#36, #37) + 2 Performance (#38, #39)
- IDENTIFIZIERT, Fix geplant: 9 (Phase 3)
- BEWUSST/OK: 2
- GESELLSCHAFTLICHE LERNPUNKTE:
  * 16 von 50 fanden die AGENTEN (Codex/Kimi), nicht ich - Reviews vor Deploy sind Pflicht
  * Die teuersten Fehler waren STILLES Versagen (ignorierte Filter, falsche Synonyme,
    1-Quellen-Suche) - strikte Validierung schlaegt Default-Nachsicht
  * Performance war kein Bug sondern fehlende Indizes + Schlaf-Compute
