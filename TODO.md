# NOTIZBLOCK - CRM-MCP Projekt (Stand: 14.09.2026, ~03:15)

## ✅ ERLEDIGT

- [x] Neon-Dev-Klon (Branch mcp-dev): 18 Tabellen, 500 Test-Kandidaten, 5/5 Tests gruen
- [x] Suchfunktion crm_search_candidates + Trigger, alle Fixes aus Neon-Lauf uebernommen
- [x] MCP-Bundle v1 final (ZIP, inkl. CHANGELOG)
- [x] MCP-Server lokal installiert + per launchd dauerhaft (Start bei Login, Auto-Restart)
- [x] Codex: MCP-Server verbunden (18 Tools), Skill (AGENTS.md) installiert
- [x] Skill-Fix: kandidat_bracnostanje (statt bracno_stanje) in SKILL.md + README + config + Grant
- [x] Alle bekannten Bugs gefixt: --env-file, Number-IDs, ARRAY-Fix, ILIKE %L, AGE(end,start),
0-Treffer-NULL, Synonym Elektrotehnicar, Seed true->1 / 'kandidat'->1
- [x] name_terms + contact_terms Filter nachgebaut (Suchbox aus altem CRM,
filtriert jetzt auch "Max Mustermann" + E-Mail/Telefon/JMBG intern)

## 🔴 OFFEN - Naechste Schritte (Reihenfolge)

- [ ] 1. CODEX-TEST: Frage stellen "Such mir alle Elektriker raus, 20-40 Jahre,
3 Jahre Berufserfahrung, Deutsch A2+" -> erwartet 7 Treffer (NOCH NICHT GEMACHT)
- [x] 2. KIMI CLI: eingerichtet + verifiziert (Agent korrigierte 2 Pfade in
meiner Anleitung: MCP -> ~/.kimi-code/mcp.json (JSON!), Skill ->
~/.agents/skills/crm-kandidatensuche/SKILL.md). 18 Tools, DB-Check ok.
MEINE FEHLER im Bundle-README jetzt gefixt. Achtung: laufende Session sieht
Tools erst nach Neustart von kimi.
- [ ] 3. KIMI APP: Einstellungen -> MCP/Tools-Bereich suchen, Server eintragen
(User schickt Screenshot vom Einstellungsmenue)
- [ ] 4. SICHERHEIT: Neon-Owner-Passwort rotieren (lag im Chat!) - noch offen,
      Kimi-CLI-Review bestaetigt Dringlichkeit

## 🟡 OFFEN - Produktion (Supabase, wenn Dev laeuft)

- [ ] 5. Supabase SQL-Editor: db-setup/01 -> 02 -> 03 ausfuehren
(Passwoerter eintragen; Rolle heisst dort dino_crm_discovery_ro_v1 -
EXAKTEN Namen noch bestaetigen, evtl. per SELECT rolname FROM pg_roles)
- [ ] 6. .env: DATABASE_URL + DATABASE_WRITE_URL auf Supabase umstellen
- [ ] 7. Echte Struka-Labels gegen Supabase-DB pruefen (get_filter_options)
- [ ] 8. Erste echte Suche gegen 200.000 Kandidaten + Performance-Check
- [x] 8a. Trigger durch Statuswechsel: VERIFIZIERT auf Neon (Notification geschrieben)
- [ ] 8b. "Cron-artige" Automatik pruefen: braucht pg_cron oder externen Scheduler,
      NUR wenn das alte CRM Zeitplan-Jobs hatte (abklaeren)
- [x] 9. Neue Suchfunktion (mit name_terms/contact_terms) auf prod-copy
      eingespielt + LIVE GETESTET: Elektriker-Suche found: 3395. ERLEDIGT.

## 🔵 DEPLOY NEON (echte Daten) - LAUFEND, Stand 14.09. ~05:07

Entschieden: Weg A - pgloader direkt vom lokalen MySQL-Container.
- [x] Branch prod-copy erstellt (Schema-only, Parent production)
- [x] mcp-dev geloescht (Testdaten weg)
- [x] Plan: Launch (100 GB)
- [x] Quelle: jobstep-crm-mysql8 (OrbStack, 127.0.0.1:3307), DB productioncrmdb,
      1718 MB. Dump-Einlesen entfaellt - Container hat die Daten schon.
- [x] NEON-URL in ~/.neon_prod_copy_url gefixt: channel_binding entfernt,
      -pooler Hostname (pgloader: kein channel_binding, kein SNI ->
      Pooler ist der Weg). Host: ep-patient-salad-b1xsn1ml-pooler
- [x] IMPORT FERTIG (Node-Skript, 9m39s): 179 Tabellen, nur 8 Zeilen
      idk_sms_messages hatten MySQL-Zero-Dates -> per sms_clean.mjs repariert
      (TRUNCATE + sauberer Re-Import aller 3512 Zeilen).
- [x] VERIFIZIERT: idk_kandidati = 122.004 echte Kandidaten!
      (Die "200.000" waren ID-Spanne, echte Zahl mit Luecken = 122.004)
- [x] Setup auf prod-copy: 01_extensions + 02_search_function + 03_trigger
      alle erfolgreich eingespielt
- [x] TEST-QUERY ERFOLGREICH: Elektriker-Suche -> found: 3395 echte Treffer!
      Echte Kandidaten (Despotovic, Nukic, Stanojevic), echte Kontaktdaten,
      Gruppen "Precizni tehnicar"/"Automehanicar", Status "Na provjeri".
      Laufzeit 868ms bei 122k Kandidaten. Synonym-Aufloesung funktioniert.
- [ ] DANACH auf prod-copy (SQL Editor): 01_extensions -> 02_search_function
      -> 03_trigger aus neon-dev/
- [ ] Verifizieren: SELECT count(*) FROM idk_kandidati (~200.000 erwartet)
- [x] .env auf prod-copy umstellen (Achtung: Server laeuft aus v1-3-Ordner,
      nicht v1-4!) + launchctl reload -> "CRM-Such-MCP v1.0.0 läuft."
- [ ] DEPLOY v1.7 auf prod-copy: 02_search_function.sql (CREATE OR REPLACE)
      + 06_synonyme_v1-6.sql -> dann Test Heizungsinstallatur/experience
- [ ] VOLLMAPPING: echte Berufsliste aus DB ziehen (DISTINCT kandidat_zanimanje)
      + komplette Synonym-Matrix bauen (User will ~10000 Treffer sehen)
- [ ] ALLERLETZTER SCHRITT: Erste echte Suche in Codex/Kimi CLI testen
- [x] TIEFEN-AUDIT (eigene Code-Analyse): 2 kritische + 2 hohe + 3 mittlere
      Bugs SELBST gefunden und gefixt (siehe CHANGELOG Eintrag 5):
      document_file-Binaer im Kontext, Base64-Export, Race Condition in
      applyChange ohne Transaktion, fehlende Existenzpruefung, db_schema
      Context-Flut, toter Parameter, Versionschaos 15/18
- [x] Codex-Review v1-5: Merge-Problem geloest (CODEX-AGENTS.md = Master +
      Skill zusammen, install.sh installiert es automatisch nach ~/.codex/)
- [x] Kimi-CLI-Review v1-5 verarbeitet: install.sh cp-Bug (Verschachtelung!)
      gefixt, TOOLS/AGENTS in Skill-Ordner verschoben, Verifikation +
      Version + Backup-Rotation + rollback.sh + --check eingebaut
      ("Such mir alle Elektriker raus, 20-40 Jahre, 3 Jahre Berufserfahrung,
      Deutsch A2+") -> dann ist der Umzug KOMPLETT
- [ ] Später altes System: MySQL-Container jobstep-crm-mysql8 NUR stoppen,
      wenn CRM komplett umgezogen ist (erst nach Absprache!)

## 🟢 IDEEN - Spaeter (nicht blockierend)

- [ ] Berufssuchprofile mit echten Synonymen fuellen (aus Produktionsdaten lernen)
- [ ] idk_notes / idk_timeline in get_full_profile anbinden
- [ ] idk_nalozi (Auftraege/Nalog) als zweite MCP-Tool-Gruppe
- [ ] Such-Historie im UI nutzen (wiederkehrende Suchen erkennen)
- [ ] Neon-Read-Replica evaluieren (erst wenn Produktions-Last da ist)
- [ ] Online-Deploy (Cloudflare o.ae.) fuer Zugriff von aussen
- [ ] MCP-Integration: Grok, Cursor, Hermes, ChatGPT, Codex CLI
- [ ] Rollen/Rechte-Modell: Bewerber / Kunde / User / Entwickler / ProjektManager
- [ ] Dashboard fuer Kunde + User + Projektmanager
- [ ] PERFORMANCE (Punkt 8 Vorbereitung): pg_trgm-Extension + 2 GIN-Indizes auf
      kandidat_ime/prezime auf SUPABASE anlegen (namenssuche 10x schneller,
      loest das echte Problem - ILIKE '%x%' kann keine normalen Indizes nutzen)
- [ ] STUFE-2 - USER-IDEE (Redis sess.ids + Typesense), GENAU SO umsetzen wenn
      Trigger eintritt. TRIGGER (klar definiert): Wenn Punkt 8 (Performance-Check
      gegen echte 200k) zeigt: p95-Suche > 2 Sekunden ODER taeglich > 10.000
      Suchanfragen -> dann Redis-Layer bauen:
        WENN redis.sess.ids existiert UND Filter enger als sess.basis
          -> RPC nur noch mit diesen IDs filtern (WHERE id = ANY(ids))
        SONST
          -> Typesense-Vollsuche -> IDs + Basisfilter 60 min nach Redis
      TYPESENSE erst, wenn Filter + pg_trgm + Indizes nicht mehr reichen.
      Bis dahin gilt: Postgres + pg_trgm ist der Such-Stack.

## 🐛 BEKANNTE UNGELOESTE PROBLEME

- (keine aktuell)

## 📓 NOTIZEN / KLAERUNGEN

- Trigger durch Statuswechsel: ✅ VERIFIZIERT auf Neon (Kandidat 20 -> Status 4,
  Notification in status_notifications geschrieben). Manueller Wechsel per MCP
  funktioniert.
- "Cron-job-artige" automatische Trigger: NICHT implementiert. Unser Trigger feuert
  nur bei UPDATE durch MCP. Falls das alte CRM Zeitplan-Aufgaben hatte (taegliche
  Erinnerungen, Auto-Archiv nach X Tagen), braucht es pg_cron (Supabase: Database->
  Extensions) oder einen externen Scheduler. Erst pruefen, OB das alte CRM sowas hatte.
- DEPLOY: Der 1,53-GB-MySQL-Dump muss NICHT neu importiert werden - die Daten
  liegen BEREITS auf Supabase (User hatte sie dort schon hochgeladen).
  "Deploy" heisst hier nur: db-setup/01-03 auf Supabase ausfuehren + .env umstellen.
  (Dump-Import zu Neon nur noetig, falls Supabase-Daten veraltet sind - dann
  pgloader lokal, NICHT ueber Chat-Upload.)

## MASTERPLAN v2.0
Siehe PLAN.md im Bundle - Phasen 0-5, abarbeiten in Reihenfolge.
Kern: Passwort(0) -> Indizes(1) -> echte Synonym-Matrix(2) -> Haertung(3)
-> Benchmarks(4) -> Supabase/Public spaeter (5).

- [ ] KRITISCH FIX EINPSPIELEN: kandidat_zanimanje existiert NICHT (99 Spalten
      verifiziert). Neue 02_search_function.sql (kg_title statt zanimanje) +
      gruppen_matrix_v1.sql (Mitglieder aus Ausbildung+Job-Titeln) auf
      prod-copy einspielen. DANN erst Tests/Benchmarks.
