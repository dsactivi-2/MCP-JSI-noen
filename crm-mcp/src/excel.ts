import ExcelJS from "exceljs";
import { EXPORT_MAX_ROWS } from "./config.js";
import { pool } from "./db.js";
import * as fs from "fs";
import * as os from "os";
import * as path from "path";

export async function exportCandidates(filters: Record<string, unknown>): Promise<{ path?: string; base64?: string; rows: number }> {
  // Bis EXPORT_MAX_ROWS seitenweise auslesen (Funktion liefert max. 50 pro Aufruf)
  const all: any[] = [];
  let offset = 0;
  let found = Infinity;
  while (all.length < EXPORT_MAX_ROWS && all.length < found) {
    const f = { ...filters, limit: 50, offset };
    const { rows } = await pool.query("SELECT crm_search_candidates($1::jsonb, 'internal') AS result", [JSON.stringify(f)]);
    const r = rows[0].result;
    found = r.found;
    if (!r.candidates.length) break;
    all.push(...r.candidates);
    offset += r.candidates.length;
  }
  const data = all.slice(0, EXPORT_MAX_ROWS);

  const wb = new ExcelJS.Workbook();
  const ws = wb.addWorksheet("Kandidaten");
  if (data.length) {
    ws.columns = Object.keys(data[0]).map((k) => ({ header: k, key: k, width: 18 }));
    ws.getRow(1).font = { bold: true };
    data.forEach((r) => ws.addRow(r));
  }
  const buf = await wb.xlsx.writeBuffer();

  // Immer als Datei ausgeben - Base64 (500 Zeilen) wuerde den Agenten-Context sprengen.
  // Ohne EXPORT_DIR: nach os.tmpdir() + Hinweis verschieben.
  const dir = process.env.EXPORT_DIR || os.tmpdir();
  const file = path.join(dir, `kandidaten_export_${Date.now()}.xlsx`);
  fs.mkdirSync(dir, { recursive: true });
  fs.writeFileSync(file, Buffer.from(buf));
  return {
    datei: file,
    zeilen: data.length,
    hinweis: process.env.EXPORT_DIR ? undefined :
      `EXPORT_DIR nicht gesetzt - Datei liegt in ${os.tmpdir()} (verschieben nach ~/Documents empfohlen)`,
  };
}
