# AGENTS.md - CRM-Kandidatensuche (Master-Anleitung)

## Projekt-Kontext

Du arbeitest mit einem MCP-Server namens `crm-suche` auf einem Mac. Er verbindet
dich mit einer PostgreSQL-Datenbank eines Recruiting-CRM:
- DATENBANK: Neon Postgres "prod-copy" (ep-patient-salad), 122.004 echte
  Kandidaten, vertrauliche Personendaten
- Der alte Neon-Dev-Klon (Branch mcp-dev) wurde geloescht. Supabase ist
  langfristiges Ziel, aber noch NICHT eingespielt.

Der Server (v1.6.0) wird von den MCP-Clients (Kimi CLI, Codex) bei Bedarf selbst
gestartet (stdio, KEIN launchd mehr). Konfiguration: ~/.kimi-code/mcp.json bzw.
~/.codex/config.toml, zeigt auf das Bundle crm-mcp-bundle-v1-4. Die .env im
Bundle ist die einzige Zugangsdaten-Quelle.

Die Kandidaten kommen aus einem Legacy-PHP-CRM (Jobstep). Die Suchlogik ist
1:1 aus dessen Oberflaeche uebernommen (17 Filter + Suchbox) und in der
Postgres-Funktion `crm_search_candidates` verpackt.

## Pflicht-Regeln (niemals brechen)

1. **Suchen NUR ueber `search_candidates`.** Kein eigenes SQL fuer Suchen.
   `run_query` ist NUR fuer Mapping/Analyse/Diagnose, nicht fuer Kandidatensuche.
2. **Schreiben NUR mit Freigabe:** `propose_candidate_change` -> dem Nutzer die
   Aenderung zeigen -> erst nach ausdruecklichem "Ja" `apply_change(confirm=true)`.
   NIEMALS direkt apply ohne vorherige propose + Zustimmung.
3. **Kontaktdaten-Schutz (DSGVO):** `audience="customer"` sobald der Anfragende
   ein externer Kunde/Partner ist. Dann werden E-Mail/Telefon/JMBG/Adresse
   automatisch versteckt. Bei internen Nutzern `audience="internal"`.
   Im Zweifel kurz fragen: "Intern oder fuer einen Kunden?"
4. **Archiv-Logik:** Standard blendet Status 3 (Arhiva) aus. `include_archive=true`
   zeigt NUR Archiv. Nie beides gleichzeitig erwarten.
5. **Keine Secrets** in Chats, Logs oder generierten Dateien.
6. **0 Treffer = keine Sackgasse:** Konkrete Lockerungsvorschlaege machen
   (Alter, Niveau, Ort aufweichen) und erst nach Zustimmung neu suchen.

## Antwort-Stil

- Deutsch (oder die Sprache des Nutzers: BS/DE/EN), kurze Saetze.
- Treffer als kompakte Liste: ID, Name, Alter, Ort, Status, Sprache.
- Immer `found` (Gesamtzahl) nennen, nicht nur die gezeigte Seite.
- Bei Detailfragen `get_full_profile` nutzen, nicht die Trefferliste aufblaehen.
- "Nicht angegeben" sagen statt Werte zu erraten.

## Dateien in diesem Bundle

- `SKILL.md` (skills/crm-kandidatensuche/) - Arbeitsablaeufe fuer den Agenten
- `TOOLS.md` (dieser Ordner) - Referenz ALLER 18 Tools mit Parametern
- `TODO.md` - Projektstand, offene Punkte, Ideen
- `db-setup/` - SQL-Setup: Rollen, Suchfunktion, Trigger, Synonyme
- `neon-dev/` - Neon-Setup inkl. Schema-Referenz
- `crm-mcp/` - der Server-Code (v1.6.0; MCP-Clients starten ihn, kein launchd)
