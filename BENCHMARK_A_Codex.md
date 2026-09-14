# BENCHMARK A – 10 Suchaufträge (an Codex)
# Ausführen mit dem crm-suche MCP auf der prod-copy Datenbank.
# Pro Auftrag: search_candidates ausführen, gefundene Zahl notieren.
# Am Ende: Tabelle mit Auftragsnr + Trefferzahl + Auffälligkeiten.

---

## Auftrag 1 – Der Klassiker (Elektriker)
„Such mir alle Elektriker raus oder ähnliche Berufe, 20–40 Jahre, 3 Jahre Berufserfahrung, Deutsch A2+"
Erwartung: mehrere hundert bis tausende Treffer, Synonyme greifen (Elektroinstallateur etc.)

## Auftrag 2 – Berufserfahrung NUR aus Job-Titeln (occupation_source!)
„Finde Kandidaten mit mind. 2 Jahren Berufserfahrung als Koch – zählt nur, wer als Koch GEARBEITET hat, Ausbildung zählt nicht"
Wichtig: occupation_source = "experience" verwenden! Erwartung: deutlich weniger als ohne Quellen-Filter.

## Auftrag 3 – Namenssuche
„Sucht alle Kandidaten mit Nachnamen 'Hodzic'"
Wichtig: name_terms verwenden. Erwartung: Trefferliste mit echten Namen.

## Auftrag 4 – Führerschein-Leiter
„Alle Kandidaten mit Führerschein Klasse B (inkl. höherer Klassen C, C1, CE), Alter 25–50"
Wichtig: license_categories = ["B"] → zieht automatisch C/C1/CE mit. Erwartung: große Trefferzahl.

## Auftrag 5 – Sprache + Staatsangehörigkeit
„Alle Kandidaten mit Deutsch B1 oder besser UND EU-Staatsangehörigkeit, ohne Archiv"
Erwartung: gefilterte Liste; Archiv (Status 3) darf NICHT auftauchen.

## Auftrag 6 – 0-Treffer-Test (wichtig!)
„Such mir Zahnärzte, 25–35 Jahre, 5 Jahre Erfahrung, Russisch C1"
Erwartung: WENN 0 → Agent schlägt Lockerungen vor (Regel!), nicht einfach „keine Treffer".
Notiere: Macht der Agent Vorschläge?

## Auftrag 7 – Kundenansicht (Datenschutz!)
„Zeig mir die ersten 5 Elektriker – als wärst du ein externer Kunde (audience=customer)"
Wichtig: In der Ausgabe dürfen kandidat_email, kandidat_mobitel, kandidat_jmbg, kandidat_adresa NICHT auftauchen. Notiere: Sind alle 4 Felder versteckt?

## Auftrag 8 – Gruppen + Status
„Alle Kandidaten aus Gruppe 'Automehanicar' mit Status 'U obradi' oder 'Na poslu'"
Wichtig: Gruppen-ID und Status-ID erst per get_filter_options nachschlagen! Erwartung: sauber gefilterte Liste.

## Auftrag 9 – Vollprofil
„Zeig mir das komplette Profil von Kandidat 8699"
Erwartung: Stammdaten + Sprachen + Berufserfahrung + Ausbildung + Dokumente (nur Metadaten, keine Binaerdaten).

## Auftrag 10 – Komplex-Kombo
„Alle Mechaniker (inkl. ähnlicher Berufe), 30–45 Jahre, mindestens 5 Jahre Erfahrung im Beruf, Deutsch B2+, Führerschein B, EU-Bürger, ausser Archiv, max. 20 Treffer anzeigen"
Erwartung: Kombination aus 6+ Filtern läuft fehlerfrei.

---

# ABSCHLUSS – Ergebnisprotokoll
Erstelle eine Tabelle:
| Nr | Auftrag (Kurz) | Trefferzahl | Korrekt? (j/n) | Auffälligkeit |

Dann als Datei speichern unter ~/Documents/benchmark-codex.md und den Inhalt auch hier im Chat ausgeben.
