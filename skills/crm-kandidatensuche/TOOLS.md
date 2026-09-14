# TOOLS.md - Referenz: Alle 18 Tools des crm-suche MCP

Der Tool-Praefix haengt vom Client ab (Server-Name kann abweichen):
- Kimi Code CLI:  mcp__crm-suche__*
- Codex:          mcp__crm_suche_2__* (Server heisst dort "crm-suche-2")
- Claude Desktop: mcp__crm_suche__*
Im Zweifel im Client nach dem registrierten Servernamen schauen.

## 1. Suche

### search_candidates  (DAS Haupt-Werkzeug)
Filter in der alten CRM-Hauptsuche - alle UND-verknuepft, OR innerhalb von Listen.
- filters (object): Filter-JSON, siehe Tabelle unten
- audience (internal|customer, default internal)
- question_text (string, optional): Originalfrage -> landet in Such-Historie
- profile (string, optional): Name eines gespeicherten Profils; dessen Filter
  werden gemergt, explizite Filter ueberschreiben das Profil
- Returns: { audience, filters_received, found, returned, candidates[50] }

**Filter-Schluessel:**
| Schluessel | Typ | Bedeutung |
|---|---|---|
| name_terms | text[] | Vor-/Nachname ("Max Mustermann" -> ["max","mustermann"]) |
| contact_terms | text[] | E-Mail/Telefon/JMBG - NUR audience=internal |
| occupation_terms | text[] | Beruf frei; Synonyme automatisch; Erfahrung zaehlt dann nur passende Jobs |
| age_from / age_to | int | Alter exakt |
| has_driving_license | bool | Fuehrerschein vorhanden |
| license_categories | text[] | B,BE,C1,C,C1E,CE - B zieht C..CE mit |
| has_work_experience | bool | mind. 1 Jobzeile |
| min_experience_years | int | nur Jobs, deren Titel zu occupation_terms passt |
| german_level / english_level | text | A1..C2 = Stufe ODER besser; BEZ_ZNANJA; NO_INFO |
| language_skill | text | kj_slusanje (Default), kj_citanje, kj_govorna_interakcija, kj_govorna_produkcija, kj_pisanje |
| groups | int[] | Kandidatengruppen |
| statuses | int[] | Bearbeitungsstatus 0-8 |
| application_statuses | int[] | 0 schliesst NULL mit ein |
| citizenship | text | "EU" oder "NON_EU" |
| residence_eu | text | exakter DB-Wert |
| schools | text[] | Schulname, nur wenn kein Smjer |
| qualifications | text[] | Smjer exakt (ueberschreibt schools + profession_ids) |
| profession_ids | int[] | Struka-IDs, nur wenn kein Smjer |
| sources | int[] | Quelle; 6 nimmt automatisch 7 mit |
| dipl_statuses | int[] | 0 = ohne Diplom einbeziehen |
| nostrification | int[] | 3 = ohne Eintrag einbeziehen |
| include_archive | bool | true = NUR Archiv (Status 3); default ohne 3 |
| limit / offset | int | Seiten (max. 50) |

Beispiel:
{"occupation_terms":["Elektriker"],"age_from":20,"age_to":40,
 "min_experience_years":3,"german_level":"A2"}

## 2. Anzeige

### get_candidate_profile
{id, audience} -> Stammdaten + Gruppenname + Statusname. audience=customer
versteckt kandidat_email/mobitel/jmbg/adresa.

### get_full_profile
{id, audience} -> komplett: Stammdaten + sprachen + berufserfahrung +
ausbildung + dokumente (fehlertolerant, wenn Tabelle fehlt).

## 3. Export

### export_candidates
{filters} -> .xlsx, max. 500 Zeilen (wie altes CRM). EXPORT_DIR gesetzt ->
Dateipfad; sonst Base64 + Hinweis als .xlsx speichern.

## 4. Schreiben mit Freigabe (REIHENFOLGE EINHALTEN!)

1. propose_candidate_change {candidate_id, changes, reason}
   -> Nur erlaubte Felder: kandidat_status, kandidat_group, kandidat_grad,
   kandidat_drzava, kandidat_mobitel, kandidat_email, kandidat_vozacka_dozvola,
   kandidat_vozacka_kategorija, kandidat_iskustvo_u_struci,
   kandidat_iskustvo_u_struci_trajanje, kandidat_status_prijave, boravak_eu,
   kandidat_bracnostanje
2. Dem Nutzer zeigen: "Soll ich Kandidat #12345: {changes} setzen?"
3. NUR nach "Ja": apply_change {change_id, confirm: true}
4. Alternativen: list_pending_changes {status}, reject_change {change_id}

## 5. Benachrichtigungen

- get_notifications {unacked_only, limit} -> Statusaenderungen (Trigger)
- ack_notification {id}
- set_notifications_enabled {enabled} -> Trigger an/aus

## 6. Hilfs-Tools

- get_filter_options {domain} -> Auswahlwerte. Domains: groups, statuses,
  application_statuses, sources, citizenship_values, residence_values, schools,
  qualifications, profession_ids, license_categories, dipl_statuses,
  nostrification, language_levels, language_skills
- get_search_history {limit} -> letzte Suchen (automatisch mitschrieben)
- db_schema {} -> Tabellen+Spalten (fuer Mapping-Pruefung)
- run_query {sql, params} -> NUR read-only SELECT, LIMIT 200 erzwungen.
  Fuer Mapping/Analyse, NIEMALS fuer Kandidatensuche.

## Fehler-Behandlung

- "Ungueltige audience" -> nur internal/customer
- "Nicht erlaubte Felder" -> changes-Whitelist pruefen (Kap. 4)
- "Schreibzugriff nicht konfiguriert" -> DATABASE_WRITE_URL fehlt in .env
- 0 Treffer -> siehe AGENTS.md Regel 6 (Lockerungsvorschlaege)
