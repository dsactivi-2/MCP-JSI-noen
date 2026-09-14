// ============================================================
// KONFIGURATION - nach DB-Mapping hier pflegen
// Spaltennamen verifiziert gegen Produktions-Dump 26.02.2026
// ============================================================

export const EDITABLE_COLUMNS = [
  "kandidat_status", "kandidat_group", "kandidat_grad", "kandidat_drzava",
  "kandidat_mobitel", "kandidat_email", "kandidat_vozacka_dozvola",
  "kandidat_vozacka_kategorija", "kandidat_iskustvo_u_struci",
  "kandidat_iskustvo_u_struci_trajanje", "kandidat_status_prijave",
  "boravak_eu", "kandidat_bracnostanje",
] as const;

export const CUSTOMER_HIDDEN_FIELDS = [
  "kandidat_email", "kandidat_mobitel", "kandidat_jmbg",
  "kandidat_adresa", "kandidat_broj_pasosa",
];

// Optionen fuer get_filter_options (Domains)
export const OPTION_QUERIES: Record<string, string | null> = {
  groups: "SELECT kg_id AS id, kg_title AS label FROM idk_kandidati_grupe ORDER BY kg_title",
  statuses: "SELECT status_id AS id, status_naziv AS label FROM idk_kandidat_status ORDER BY status_id",
  application_statuses: "SELECT status_id AS id, status_naziv AS label, status_aktivan AS aktiv FROM idk_kandidat_status_prijave ORDER BY redoslijed_statusa",
  sources: "SELECT kandidat_porijeklo AS id, count(*) AS anzahl FROM idk_kandidati GROUP BY 1 ORDER BY 1",
  // Labels aus Spaltenkommentar: 0=old way, 1=dipl, 2=dak, 3=partner, 4=svezavize, 5=jobstep web
  citizenship_values: "SELECT DISTINCT kandidat_drzavljanstvo_vrsta AS wert FROM idk_kandidati WHERE kandidat_drzavljanstvo_vrsta IS NOT NULL ORDER BY 1",
  residence_values: "SELECT DISTINCT boravak_eu AS wert FROM idk_kandidati WHERE boravak_eu IS NOT NULL AND boravak_eu <> '' ORDER BY 1",
  schools: "SELECT DISTINCT ke_naziv AS wert FROM idk_kandidat_edukacija WHERE ke_naziv IS NOT NULL ORDER BY 1 LIMIT 300",
  qualifications: "SELECT DISTINCT ke_naziv_kvalifikacije AS wert, count(*) AS anzahl FROM idk_kandidat_edukacija WHERE ke_naziv_kvalifikacije IS NOT NULL GROUP BY 1 ORDER BY 2 DESC LIMIT 500",
  profession_ids: "SELECT s.id_struke AS id, s.naziv_struke AS label, s.naziv_struke_de AS label_de, (SELECT count(*) FROM idk_skole_smjerovi ss WHERE ss.ss_struka_id = s.id_struke) AS smjer_anzahl FROM idk_struke s ORDER BY s.naziv_struke",
  schools_catalog: "SELECT skola_id AS id, skola_naziv AS label, skola_naziv_de AS label_de FROM idk_skole ORDER BY skola_naziv",
  license_categories: null, // statisch, siehe unten
  dipl_statuses: "SELECT DISTINCT status_nd_kandidata AS id, count(*) AS anzahl FROM idk_nd_kandidata GROUP BY 1 ORDER BY 1",
  nostrification: "SELECT DISTINCT full_recognition AS id, count(*) AS anzahl FROM idk_nostrifikovane_diplome GROUP BY 1 ORDER BY 1",
};

export const STATIC_OPTIONS: Record<string, unknown> = {
  license_categories: ["B", "BE", "C1", "C", "C1E", "CE"],
  language_levels: ["A1", "A2", "B1", "B2", "C1", "C2", "BEZ_ZNANJA", "NO_INFO"],
  language_skills: {
    kj_slusanje: "Hoeren",
    kj_citanje: "Lesen",
    kj_govorna_interakcija: "Sprechen (Interaktion)",
    kj_govorna_produkcija: "Sprechen (frei)",
    kj_pisanje: "Schreiben",
  },
};

export const EXPORT_MAX_ROWS = 500; // wie im alten CRM
