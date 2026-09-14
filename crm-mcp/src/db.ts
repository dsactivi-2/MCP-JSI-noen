import pg from "pg";
import { CUSTOMER_HIDDEN_FIELDS, EDITABLE_COLUMNS, OPTION_QUERIES, STATIC_OPTIONS } from "./config.js";

const ssl = process.env.DB_SSL === "true" ? { rejectUnauthorized: true } : undefined;

export const pool = new pg.Pool({
  connectionString: process.env.DATABASE_URL,
  ssl,
  max: 5,
  statement_timeout: 10000,
  query_timeout: 10000,
});

// Schreib-Pool nur wenn konfiguriert
export const writePool = process.env.DATABASE_WRITE_URL
  ? new pg.Pool({ connectionString: process.env.DATABASE_WRITE_URL, ssl, max: 2, statement_timeout: 10000 })
  : null;

export function requireWriter() {
  if (!writePool) throw new Error("Schreibzugriff nicht konfiguriert (DATABASE_WRITE_URL fehlt in .env)");
  return writePool;
}

const FORBIDDEN = /\b(insert|update|delete|drop|alter|create|truncate|grant|revoke|copy|call|do|vacuum|reindex|notify|listen|set|reset|into)\b/i;

export async function runReadOnlyQuery(sql: string, params: unknown[] = []) {
  let q = sql.trim().replace(/;\s*$/, "");
  if (/;/.test(q)) throw new Error("Nur EINE einzelne Anweisung erlaubt.");
  if (!/^(select|with|explain)\b/i.test(q)) throw new Error("Nur SELECT-Abfragen erlaubt.");
  if (FORBIDDEN.test(q)) throw new Error("Verbotenes Schluesselwort.");
  const m = q.match(/\blimit\s+(\d+)/i);
  if (m) {
    if (parseInt(m[1], 10) > 200) q = q.replace(/\blimit\s+\d+/i, "LIMIT 200");
  } else {
    q += " LIMIT 200";
  }
  const { rows } = await pool.query(q, params);
  return { rows, returned: rows.length, limit: 200 };
}

export async function getSchema(tableFilter?: string) {
  // tableFilter gesetzt -> nur diese Tabelle, komplette Spaltenliste.
  // Sonst -> KOMPAKTE Tabelle (Tabelle, Spaltenzahl, Typen-Hash) statt
  // ~2000 Einzelzeilen - schont den Agenten-Context massiv.
  if (tableFilter) {
    const { rows } = await pool.query(
      `SELECT column_name, data_type FROM information_schema.columns
       WHERE table_schema = 'public' AND table_name = $1 ORDER BY ordinal_position`, [tableFilter]);
    return rows;
  }
  const { rows } = await pool.query(
    `SELECT table_name, count(*) AS spalten,
            string_agg(DISTINCT data_type, ', ' ORDER BY data_type) AS typen
     FROM information_schema.columns
     WHERE table_schema = 'public'
       AND (table_name LIKE 'idk\_%' OR table_name IN
            ('search_synonyms','search_profiles','search_history','pending_changes','status_notifications'))
     GROUP BY table_name ORDER BY table_name`);
  return rows;
}

// ---------- SUCHE ----------
export async function searchCandidates(filters: Record<string, unknown>, audience: string, questionText?: string) {
  const { rows } = await pool.query(
    "SELECT crm_search_candidates($1::jsonb, $2::text) AS result",
    [JSON.stringify(filters), audience]);
  // Historie automatisch mitschreiben (best effort)
  if (writePool) {
    writePool.query(
      "INSERT INTO search_history (question_text, filter, found) VALUES ($1, $2, $3)",
      [questionText ?? null, JSON.stringify(filters), rows[0]?.result?.found ?? null]
    ).catch(() => {});
  }
  return rows[0].result;
}

// ---------- PROFILE ----------
export async function getProfileFilter(name: string) {
  const { rows } = await pool.query(
    "SELECT filter FROM search_profiles WHERE name = $1 AND active", [name]);
  return rows[0]?.filter ?? null;
}

export async function saveProfile(name: string, filter: Record<string, unknown>) {
  await requireWriter().query(
    `INSERT INTO search_profiles (name, filter) VALUES ($1, $2)
     ON CONFLICT (name) DO UPDATE SET filter = EXCLUDED.filter, active = true`,
    [name, JSON.stringify(filter)]);
}

export async function listProfiles() {
  const { rows } = await pool.query(
    "SELECT id, name, filter, active, created_at FROM search_profiles ORDER BY name");
  return rows;
}

export async function deleteProfile(id: number) {
  await requireWriter().query("UPDATE search_profiles SET active = false WHERE id = $1", [id]);
}

// ---------- PROFIL-ANSICHTEN ----------
function redact(obj: any, audience: string) {
  if (audience !== "customer" || !obj) return obj;
  for (const f of CUSTOMER_HIDDEN_FIELDS) delete obj[f];
  return obj;
}

export async function getCandidateProfile(id: number, audience: string) {
  const { rows } = await pool.query(
    `SELECT k.*, g.kg_title, s.status_naziv
     FROM idk_kandidati k
     LEFT JOIN idk_kandidati_grupe g ON k.kandidat_group = g.kg_id
     LEFT JOIN idk_kandidat_status  s ON k.kandidat_status = s.status_id
     WHERE k.kandidat_id = $1`, [id]);
  return redact(rows[0] ?? null, audience);
}

export async function getFullProfile(id: number, audience: string) {
  const c = await getCandidateProfile(id, audience);
  if (!c) return null;
  const [langs, jobs, edu] = await Promise.all([
    pool.query("SELECT * FROM idk_kandidat_jezici WHERE kj_kandidatid = $1 ORDER BY kj_naziv", [id]),
    pool.query("SELECT * FROM idk_kandidat_radno_iskustvo WHERE kri_kandidat_id = $1 ORDER BY kri_darum_od DESC NULLS LAST", [id]),
    pool.query("SELECT * FROM idk_kandidat_edukacija WHERE ke_kandidat_id = $1 ORDER BY ke_datumod DESC NULLS LAST", [id]),
  ]);
  // Dokumente: NUR Metadaten - document_file ist Binaer (bytea) und wuerde
  // den Agenten-Context sprengen oder JSON kaputt machen
  let docs: unknown[] = [];
  try {
    const r = await pool.query(
      `SELECT document_id, document_name, document_special_type, document_desc,
              document_icon, document_datetime, document_group, document_employeeid
       FROM idk_documents WHERE document_dataid = $1 ORDER BY document_id DESC LIMIT 50`, [id]);
    docs = r.rows;
  } catch { /* Tabelle existiert nicht oder anders benannt */ }
  return { ...c, sprachen: langs.rows, berufserfahrung: jobs.rows, ausbildung: edu.rows, dokumente: docs };
}

// ---------- FREIGABE-WORKFLOW (Schreiben mit Freigabe) ----------
const EDITABLE = new Set<string>(EDITABLE_COLUMNS);

export async function proposeChange(candidateId: number, changes: Record<string, unknown>, reason?: string) {
  const bad = Object.keys(changes).filter((k) => !EDITABLE.has(k));
  if (bad.length) throw new Error("Nicht erlaubte Felder: " + bad.join(", "));
  if (!Object.keys(changes).length) throw new Error("Keine Aenderungen angegeben.");
  const { rows: cand } = await pool.query("SELECT 1 FROM idk_kandidati WHERE kandidat_id = $1", [candidateId]);
  if (!cand.length) throw new Error("Kandidat " + candidateId + " existiert nicht.");
  const { rows } = await requireWriter().query(
    `INSERT INTO pending_changes (candidate_id, changes, reason) VALUES ($1, $2, $3) RETURNING id`,
    [candidateId, JSON.stringify(changes), reason ?? null]);
  return Number(rows[0].id);
}

export async function listPending(status = "pending") {
  const { rows } = await requireWriter().query(
    "SELECT * FROM pending_changes WHERE status = $1 ORDER BY id DESC LIMIT 100", [status]);
  return rows.map((r) => ({ ...r, id: Number(r.id) }));
}

export async function applyChange(changeId: number, confirm: boolean) {
  if (!confirm) throw new Error("Freigabe fehlt: confirm muss true sein (menschliche Zustimmung erforderlich).");
  const w = requireWriter();
  // Atomar: Statuswechsel + Daten-UPDATE in EINER Transaktion.
  // UPDATE ... WHERE status='pending' RETURNING = Race-Condition-sicher
  // (zweiter paralleler Aufruf findet kein 'pending' mehr).
  const client = await w.connect();
  try {
    await client.query("BEGIN");
    const { rows } = await client.query(
      "UPDATE pending_changes SET status = 'applying' WHERE id = $1 AND status = 'pending' RETURNING *", [changeId]);
    const ch = rows[0];
    if (!ch) { await client.query("ROLLBACK"); throw new Error("Keine offene Aenderung mit ID " + changeId + " (bereits bearbeitet?)"); }
    const keys = Object.keys(ch.changes).filter((k) => EDITABLE.has(k));
    if (!keys.length) { await client.query("ROLLBACK"); throw new Error("Aenderung enthaelt keine gueltigen Felder mehr."); }
    const setSql = keys.map((k, i) => `${k} = $${i + 2}`).join(", ");
    const upd = await client.query(`UPDATE idk_kandidati SET ${setSql} WHERE kandidat_id = $1`,
      [ch.candidate_id, ...keys.map((k) => ch.changes[k])]);
    if (upd.rowCount === 0) { await client.query("ROLLBACK"); throw new Error("Kandidat " + ch.candidate_id + " nicht gefunden - nichts geaendert."); }
    await client.query("UPDATE pending_changes SET status = 'applied', decided_at = now() WHERE id = $1", [changeId]);
    await client.query("COMMIT");
    return { applied: true, candidate_id: ch.candidate_id, changes: ch.changes, kandidat_aktualisiert: upd.rowCount };
  } catch (e) {
    await client.query("ROLLBACK").catch(() => {});
    throw e;
  } finally {
    client.release();
  }
}

export async function rejectChange(changeId: number) {
  await requireWriter().query(
    "UPDATE pending_changes SET status = 'rejected', decided_at = now() WHERE id = $1 AND status = 'pending'",
    [changeId]);
}

// ---------- BENACHRICHTIGUNGEN ----------
export async function listNotifications(unackedOnly: boolean, limit: number) {
  const { rows } = await pool.query(
    `SELECT n.*, s.status_naziv AS new_status_name
     FROM status_notifications n
     LEFT JOIN idk_kandidat_status s ON n.new_status = s.status_id
     WHERE ($1::bool = false OR n.acked = false)
     ORDER BY n.id DESC LIMIT $2`, [unackedOnly, Math.min(limit, 100)]);
  return rows.map((r) => ({ ...r, id: Number(r.id) }));
}

export async function ackNotification(id: number) {
  await requireWriter().query("UPDATE status_notifications SET acked = true WHERE id = $1", [id]);
}

export async function setNotificationsEnabled(enabled: boolean) {
  await requireWriter().query(
    `INSERT INTO notification_settings (key, enabled) VALUES ('status_change', $1)
     ON CONFLICT (key) DO UPDATE SET enabled = EXCLUDED.enabled`, [enabled]);
}

// ---------- OPTIONEN / HISTORIE ----------
export async function getOptions(domain: string) {
  if (domain in STATIC_OPTIONS) return STATIC_OPTIONS[domain];
  const sql = OPTION_QUERIES[domain];
  if (!sql) throw new Error(`Domain '${domain}' unbekannt oder nicht konfiguriert (config.ts).`);
  const { rows } = await pool.query(sql);
  return rows;
}

export async function getHistory(limit: number) {
  const { rows } = await pool.query(
    "SELECT * FROM search_history ORDER BY id DESC LIMIT $1", [Math.min(limit, 100)]);
  return rows;
}
