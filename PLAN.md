# OPTIMIERTER PLAN v2.0 – CRM-Such-MCP (Stand 14.09. ~14:15)

## TEIL 1: WAS DIE ANALYSE ERGEBEN HAT

### 1.1 Datenbank (verifiziert gegen Dump + Live-DB)
- 179 Tabellen, davon 17 im Such-Kern. Kandidaten: 122.004 echte Datensätze
  (ID-Spanne bis ~200k mit Lückchen durch Löschungen)
- Beruf eines Kandidaten steht in DREI Quellen: kandidat_zanimanje (Hauptberuf),
  idk_kandidat_edukacija (Ausbildung), idk_kandidat_radno_iskustvo.kri_pozicija
  (Job-Titel). Sprachen in 5 Dimensionen (PHP nutzte nur kj_slusanje/Hören).
- Technische Schätze: kandidat_jmbg, -email, -mobitel, -adresa vorhanden
  (Kunden-Redaction greift auf alle 4).

### 1.2 PHP-UI-Filter (vollständig, aus kandidati.php + serversidedata.php)
17 Filterfelder + Suchbox + Archiv-Cookie. Zweite Abfrage lista_kandidata_dn
ist nur ein Subset (keine neuen Filter). Alle 17 sind in der MCP-Suche
abgebildet. Besonderheiten (alle abgebildet): Führerschein-Leiter B->CE,
Quelle 6 nimmt 7 mit, Bewerbungsstatus 0 inkl. NULL, Nostrifikation 3 inkl.
NULL, Archiv-Standard ausgeblendet.

### 1.3 MCP-Bewertung (ehrlich)
Richtig: Parametrisierung (kein Injection), Whitelist beim Schreiben,
Freigabe-Workflow, Kunden-Redaction, Read-only-Guard.
Falsch war: Berufssuche nur 1 Quelle; handgefertigte Mini-Synonymtabelle
(Bravar/Limar-Fehler); KEINE Indizes für ILIKE -> Vollscan pro Suche;
Doku/Code-Drift; Versionschaos; stdio-Server unter launchd (falsch).

## TEIL 2: DAS ZEITPROBLEM (Warum 8+ Minuten)
1. ILIKE '%x%' ohne trigram-GIN-Index = Volltextscan über 122k Zeilen,
   mehrfach pro Suche (3 Berufs-Quellen + Sprachen-EXISTS + ...)
   -> 10-30 Sekunden PRO Suchauftrag
2. Neon Compute: Scale-to-Zero nach 5 Min -> jede Suche nach Pause
   beginnt mit Wake-Up
3. Beides zusammen x 10 Aufträge x 2 Agenten = die 8 Minuten
Fix: Indizes (unten) + Min-CPU hoch. Erwartung: <1s pro Suche.

## TEIL 3: DER PLAN (in Reihenfolge, jeder Schritt abhakbar)

### PHASE 0 – Blocker beseitigen (10 Min, alles manuell)
- [ ] 0.1 Neon-Passwort: Dashboard -> prod-copy -> Connect -> Reset password
      -> neuen String sicher speichern (read -s nach ~/.neon_prod_copy_url,
      dann sed channel_binding raus + -pooler rein)
- [ ] 0.2 jq-Update ~/.kimi-code/mcp.json (Befehl im Chat 06:50)
- [ ] 0.3 printf-Update v1-3/.env + launchctl reload (Befehl im Chat 06:50)
- [ ] 0.4 Zombie-Prozesse: pkill -f "crm-mcp/src/index.ts"
- [ ] 0.5 launchd-Plist ENTFERNEN (stdio-MCP gehoert ans Client-Spawning):
      launchctl unload ~/Library/LaunchAgents/com.crm-mcp.plist
      rm ~/Library/LaunchAgents/com.crm-mcp.plist
- [ ] 0.6 Smoke-Test: "Wie viele Kandidaten?" -> 122.004

### PHASE 1 – Performance (10 Min, SQL Editor)
- [ ] 1.1 Indizes einspielen (SQL aus Chat 13:05, pg_trgm + 7 GIN + 5 B-Tree)
- [ ] 1.2 Pruefung: SELECT crm_search_candidates('{"occupation_terms":
      ["Elektriker"],"limit":5}'::jsonb,'internal') -> muss < 1s sein
- [ ] 1.3 Neon -> Computes -> Min CU auf 0.5-1 (Scale-to-Zero aus oder hoch)

### PHASE 2 – Berufs-Mapping komplett (30-60 Min, der eigentliche Fix)
Handgemachte 35 Synonyme reichen nie. Datengetrieben vorgehen:
- [ ] 2.1 Echte Bezeichnungen ziehen (SQL Editor, Ergebnis als CSV/JSON):
      SELECT kandidat_zanimanje AS beruf, count(*) FROM idk_kandidati
      WHERE kandidat_zanimanje IS NOT NULL AND kandidat_zanimanje <> ''
      GROUP BY 1 ORDER BY 2 DESC;            -- Hauptberufe
      SELECT ke_naziv_kvalifikacije, count(*) FROM idk_kandidat_edukacija
      WHERE ke_naziv_kvalifikacije IS NOT NULL GROUP BY 1 ORDER BY 2 DESC; -- Ausbildungen
      SELECT kri_pozicija, count(*) FROM idk_kandidat_radno_iskustvo
      WHERE kri_pozicija IS NOT NULL GROUP BY 1 ORDER BY 2 DESC LIMIT 500; -- Job-Titel
- [ ] 2.2 Liste mir geben -> ich baue die komplette Synonym-Matrix
      (BS/DE/EN-Gruppen, alle Schreibweisen, KEIN Raten)
- [ ] 2.3 Matrix als SQL liefern -> einspielen -> Test Heizungsinstallateur
      muss ~10.000-Treffer-Niveau erreichen

### PHASE 3 – Code-Haertung (Kimi-Agent, 1-2h, kein Neon noetig)
- [ ] 3.1 selftest-Tool (DB-Ping, Writer?, Export-Dir, Notification-State)
- [ ] 3.2 export_candidates: audience-Parameter + search_history-Eintrag
- [ ] 3.3 Neon-Cold-Start-Retry beim ersten Connect
- [ ] 3.4 Doc-Drift: TOOLS.md (Base64-Hinweis raus), AGENTS.md-Pfade,
      package.json -> 1.5.0
- [ ] 3.5 Bundle unter git (~/crm-mcp-repo statt Downloads)
- [ ] 3.6 run_query PII-Guardrail-Notiz in SKILL.md

### PHASE 4 – Verifikation (30 Min)
- [ ] 4.1 Benchmarks A (Codex) + B (Kimi) neu laufen lassen
- [ ] 4.2 Ziel: beide < 3 Min, Protokolle vergleichen, Abweichungen analysieren
- [ ] 4.3 Trefferqualitaet stichprobenartig von Hand gegen alte PHP-UI pruefen
      (2-3 Suchauftraege parallel in altem CRM laufen lassen, Mengen vergleichen)

### PHASE 5 – Danach (bewusst spaeter, nicht heute)
- [ ] 5.1 Supabase-Produktion: db-setup einspielen + .env-Umschaltung
- [ ] 5.2 Public-Deploy-Entscheidung (API-Key 1/2 Tag / OAuth 1-2 Tage)
- [ ] 5.3 Stufe-2 (Redis/Typesense) NUR wenn Benchmarks p95 > 2s zeigen

## TEIL 4: REGELN DAMIT ES LAUFT
1. Ein Aenderungs-Stream: ich baue -> du spielst ein -> Agent testet -> Ergebnis zu mir
2. Jede DB-Aenderung per SQL-Datei im Bundle (kein Hand-SQL im Editor)
3. Vor jedem Benchmark: Passwort + Indizes + Synonyme pruefen (Checkliste)
4. Kein Feature-Bau ohne Testauftrag im Benchmark-Stil
