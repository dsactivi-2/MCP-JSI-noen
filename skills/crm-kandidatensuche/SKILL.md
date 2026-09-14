---
name: crm-kandidatensuche
version: 1.5.0
description: >
  Kandidaten in der CRM-Datenbank suchen, anzeigen, exportieren und -
  nach Freigabe - aendern. Nutze diesen Skill IMMER wenn der Nutzer nach
  Kandidaten fragt, z.B. "such mir alle Elektriker raus, 20-40 Jahre,
  3 Jahre Berufserfahrung, Deutsch A2+".
---

> Komplett-Referenz aller 18 Tools: siehe TOOLS.md (liegt im SELBEN Ordner wie diese Datei).
> Master-Regeln (Freigabe, Kundenschutz, Archiv): siehe AGENTS.md (ebenfalls im selben Ordner).
> Nach Installation: ~/.agents/skills/crm-kandidatensuche/

# CRM-Kandidatensuche (MCP crm-suche)

## Grundregeln

1. **Suchen NUR ueber `search_candidates`.** Kein eigenes SQL fuer Suchen. `run_query` ist nur fuer Mapping/Analyse.
2. **Kontaktdaten-Schutz:** `audience="customer"` verwenden, sobald der Anfragende ein externer Kunde/Partner ist (E-Mail/Telefon/JMBG/Adresse werden dann automatisch versteckt). Bei internen Nutzern `audience="internal"`. Im Zweifel fragen.
3. **Schreiben NUR mit Freigabe:** niemals direkt aendern. Ablauf: `propose_candidate_change` → dem Nutzer die Aenderung zeigen → erst nach ausdruecklichem "Ja" `apply_change` mit `confirm=true`.
4. **Bestaetigen vor Suche:** Bei mehrdeutigen Anfragen kurz rueckfragen ("Ich suche: Elektriker o.ae., 20-40, Deutsch A2 - stimmt so?"). Eindeutige Anfragen direkt ausfuehren.
5. **0 Ergebnisse:** konkrete Lockerungsvorschlaege machen (z.B. "Alter 20-45 statt 20-40?") und erst nach Zustimmung neu suchen.
8. **Antwortstil:** Deutsch, kurze Saetze, Treffer als kompakte Liste (ID, Name, Alter, Ort, Status). Keine Vermutungen bei fehlenden Feldern - "nicht angegeben" sagen.

## Filter-Referenz (search_candidates -> filters)

| JSON-Schluessel | Typ | Bedeutung (1:1 aus altem PHP-CRM) |
|---|---|---|
| name_terms | text[] | Vor-/Nachname ("Max Mustermann" -> ["max","mustermann"]) |
| contact_terms | text[] | E-Mail/Telefon/JMBG - NUR audience=internal |
| occupation_terms | text[] | Beruf frei; Synonyme automatisch |
| occupation_source | text | any (default: Hauptberuf+Ausbildung+Job-Titel) / experience (nur Job-Titel) / profession (nur Gruppen-Titel) / education (nur Ausbildung) |
| age_from / age_to | int | Alter exakt (PHP zaehlte nur Jahre, hier exakt) |
| has_driving_license | bool | Fuehrerschein vorhanden |
| license_categories | text[] | B,BE,C1,C,C1E,CE - B zieht automatisch C,C1,CE mit |
| has_work_experience | bool | mind. 1 Jobzeile |
| min_experience_years | int | nur Jobs, deren Titel zu occupation_terms passt (sonst alle) |
| german_level / english_level | text | A1..C2 = Stufe ODER besser (Hoeren). BEZ_ZNANJA = explizit ohne. NO_INFO = keine Angabe |
| language_skill | text | kj_slusanje (Default), kj_citanje, kj_govorna_interakcija, kj_govorna_produkcija, kj_pisanje |
| groups | int[] | Kandidatengruppen |
| statuses | int[] | Bearbeitungsstatus 0-8 |
| application_statuses | int[] | 0 schliesst "kein Status" (NULL) mit ein |
| citizenship | text | "EU" oder "NON_EU" |
| residence_eu | text | exakter DB-Wert |
| schools | text[] | Schulname, nur wenn kein Smjer |
| qualifications | text[] | Smjer exakt (ueberschreibt schools und profession_ids) |
| profession_ids | int[] | Struka-IDs, nur wenn kein Smjer |
| sources | int[] | Quelle; 6 nimmt automatisch 7 mit |
| dipl_statuses | int[] | 0 = ohne Diplom einbeziehen |
| nostrification | int[] | 3 = ohne Eintrag einbeziehen |
| include_archive | bool | true = NUR Archiv (Status 3); default ohne Status 3 |
| limit / offset | int | Seiten (max. 50) |

AND zwischen allen Kategorien, OR innerhalb von Listen.

## WICHTIG: "Berufserfahrung als X" != "Ausbildung X"

Nutzer sagt "3 Jahre Erfahrung als Heizungsinstallateur":
-> occupation_terms: ["Heizungsinstallateur"], occupation_source: "experience",
   min_experience_years: 3
(NUR Jobs zaehlen, deren Titel zum Beruf passt - NICHT die Ausbildung)
Nutzer sagt nur "Heizungsinstallateur" (egal wo erfasst):
-> occupation_terms ohne occupation_source (default any)

## Beispiel Namenssuche

Nutzer: "such den Kandidaten Mustermann"
-> search_candidates(filters={"name_terms": ["mustermann"]}, audience="internal")
(contact_terms nur, wenn nach E-Mail/Telefon-Fragmenten gesucht wird - sonst Fehler
wg. Datenschutz-Regel vermeiden)

## Ablaeufe

**Suche:** search_candidates(filters, audience, question_text=Originalfrage) -> Ergebnis hat `found` + `candidates`. Weitere Seiten mit offset. `profile="Name"` laedt ein gespeichertes Berufssuchprofil und mergt es.

**Profil ansehen:** `get_candidate_profile` (Stammdaten) oder `get_full_profile` (komplett: Sprachen, Berufserfahrung, Ausbildung, Dokumente).

**Export:** `export_candidates` (max. 500 Zeilen, .xlsx). Datei dem Nutzer bereitstellen.

**Aendern (mit Freigabe):**
1. `propose_candidate_change(candidate_id, changes, reason)` - erlaubte Felder: kandidat_status, kandidat_group, kandidat_grad, kandidat_drzava, kandidat_mobitel, kandidat_email, kandidat_vozacka_dozvola, kandidat_vozacka_kategorija, kandidat_iskustvo_u_struci, kandidat_iskustvo_u_struci_trajanje, kandidat_status_prijave, boravak_eu, kandidat_bracnostanje
2. Nutzer die Aenderung zeigen ("Soll ich Kandidat #12345 auf Status 4 setzen?")
3. Nur nach "Ja": `apply_change(change_id, confirm=true)`

**Berufssuchprofile:** `save_search_profile` (AI schlaegt vor, Mensch bestaetigt), `list_search_profiles`, `delete_search_profile`.

**Benachrichtigungen:** `get_notifications` (Statusaenderungen), `ack_notification`, `set_notifications_enabled`.

**Optionen nachschlagen:** `get_filter_options(domain)` - Werte fuer groups, statuses, sources, schools, qualifications usw.

## Beispiele

Nutzer: "such mir alle Elektriker raus oder aehnliche Berufe mit alter 20-40 mit 3 jahren berufserfahrung und deutsch a2+"
-> search_candidates(filters={
     "occupation_terms": ["Elektriker"],
     "age_from": 20, "age_to": 40,
     "min_experience_years": 3,
     "german_level": "A2"
   }, audience="internal", question_text="...")
-> Antwort: "Gefunden: X. Erste 20: ..." + Angebot fuer mehr/Export/Detail
