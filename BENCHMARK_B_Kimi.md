# BENCHMARK B – 10 Suchaufträge (an Kimi CLI)
# Ausführen mit dem crm-suche MCP auf der prod-copy Datenbank.
# Pro Auftrag: search_candidates ausführen, gefundene Zahl notieren.
# Am Ende: Tabelle mit Auftragsnr + Trefferzahl + Auffälligkeiten.

---

## Auftrag 1 – Schweißer/Welders mit Synonymen
„Such mir alle Schweißer und ähnliche Berufe (Varilac, Zavarivac), 22–45 Jahre, Deutsch A2+"
Wichtig: Synonym-Gruppe greift automatisch. Erwartung: Treffer über alle Schreibweisen.

## Auftrag 2 – Holzberufe
„Alle Tischler, Schreiner, Stolare und Zimmermann (Tesar), 20–50 Jahre"
Wichtig: Mehrere Begriffe direkt in occupation_terms oder Synonym-Gruppe holz. Erwartung: gemischte Trefferliste.

## Auftrag 3 – Kontaktsuche (nur intern!)
„Finde den Kandidaten mit der E-Mail-Adresse die 'meier' enthält"
Wichtig: contact_terms NUR mit audience=internal! Erwartung: 1–5 Treffer.

## Auftrag 4 – Aufenthaltsstatus
„Alle Kandidaten mit Aufenthalt in der EU (boravak_eu), Deutsch B1+, Alter 20–40"
Wichtig: residence_eu erst per get_filter_options Werte ansehen! Erwartung: korrekt gefiltert.

## Auftrag 5 – Quelle/Partner
„Alle Kandidaten aus Quelle 'dipl' (sources=1), jünger als 35"
Wichtig: sources=1 (laut Spaltenkommentar: dipl). Erwartung: gefilterte Liste.

## Auftrag 6 – Nostrifikation
„Alle Kandidaten mit DIPL-Status 'nostrifiziert' – Nostrifikations-Typ egal"
Wichtig: dipl_statuses per get_filter_options ermitteln. Erwartung: Liste mit Diplom-Daten.

## Auftrag 7 – Archiv-Zugriff
„Zeig mir 5 archivierte Kandidaten (nur Archiv, Status 3)"
Wichtig: include_archive=true! Erwartung: genau Status-3-Kandidaten.

## Auftrag 8 – English speakers
„Alle Kandidaten mit Englisch B2 oder besser, ohne Altersgrenze, ohne Archiv"
Wichtig: english_level = "B2" → zieht C1/C2 mit. Erwartung: Trefferliste.

## Auftrag 9 – Ausbildungsweg
„Alle Kandidaten mit Ausbildung 'Elektroinstallateur' (genau dieser Smjer), 18–35 Jahre"
Wichtig: occupation_source = "education" UND occupation_terms = ["Elektroinstallateur"]. Erwartung: nur Kandidaten mit DIESEM Ausbildungs-Smjer.

## Auftrag 10 – Kombination + Export-Vorbereitung
„Alle Kandidaten: Alter 20–30, Deutsch A2+, Führerschein ja, ausser Archiv – und speicher diesen Filter unter dem Namen 'Junge-Fahrer-A2'"
Wichtig: save_search_profile mit dem exakten Filter-JSON. Danach: list_search_profiles aufrufen und bestätigen, dass das Profil existiert. Erwartung: Profil gespeichert.

---

# ABSCHLUSS – Ergebnisprotokoll
Erstelle eine Tabelle:
| Nr | Auftrag (Kurz) | Trefferzahl | Korrekt? (j/n) | Auffälligkeit |

Dann als Datei speichern unter ~/Documents/benchmark-kimi.md und den Inhalt auch hier im Chat ausgeben.
