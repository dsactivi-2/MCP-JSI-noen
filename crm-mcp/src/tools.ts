// Zentrale Tool-Registrierung fuer BEIDE Transporte (stdio + HTTP).
// Wird von index.ts (stdio) und index-http.ts (HTTP) gemeinsam genutzt.
import { z } from "zod";
import * as db from "./db.js";
import { exportCandidates } from "./excel.js";

export interface ToolHelpers {
  ok: (obj: unknown) => any;
  err: (e: any) => any;
  audienceSchema: z.ZodDefault<z.ZodEnum<["internal", "customer"]>>;
  filterSchema: z.ZodRecord;
}

export function registerTools(server: any, { ok, err, audienceSchema, filterSchema }: ToolHelpers) {
  server.tool("search_candidates",
    "Kandidaten suchen - alle Filter der alten CRM-Hauptsuche. audience='customer' fuer externe Kunden (Kontakte versteckt).",
    { filters: filterSchema, audience: audienceSchema, question_text: z.string().optional(), profile: z.string().optional() },
    async ({ filters, audience, question_text, profile }: any) => {
      try {
        let merged: Record<string, unknown> = { ...filters };
        if (profile) {
          const pf = await db.getProfileFilter(profile);
          if (!pf) return err(new Error(`Profil '${profile}' nicht gefunden.`));
          merged = { ...pf, ...merged };
        }
        return ok(await db.searchCandidates(merged, audience, question_text));
      } catch (e: any) { return err(e); }
    });

  server.tool("save_search_profile", "Berufssuchprofil speichern.", { name: z.string(), filter: filterSchema },
    async ({ name, filter }: any) => { try { await db.saveProfile(name, filter); return ok({ saved: name }); } catch (e: any) { return err(e); } });
  server.tool("list_search_profiles", "Alle gespeicherten Profile.", {},
    async () => { try { return ok(await db.listProfiles()); } catch (e: any) { return err(e); } });
  server.tool("delete_search_profile", "Profil deaktivieren.", { id: z.number().int() },
    async ({ id }: any) => { try { await db.deleteProfile(id); return ok({ deactivated: id }); } catch (e: any) { return err(e); } });

  server.tool("get_candidate_profile", "Stammdaten + Gruppe + Status.", { id: z.number().int(), audience: audienceSchema },
    async ({ id, audience }: any) => { try { return ok(await db.getCandidateProfile(id, audience)); } catch (e: any) { return err(e); } });
  server.tool("get_full_profile", "Komplett: Stammdaten + Sprachen + Berufserfahrung + Ausbildung + Dokumente.",
    { id: z.number().int(), audience: audienceSchema },
    async ({ id, audience }: any) => { try { return ok(await db.getFullProfile(id, audience)); } catch (e: any) { return err(e); } });

  server.tool("export_candidates", "Excel-Export (max 500 Zeilen), immer als Datei.",
    { filters: filterSchema },
    async ({ filters }: any) => { try { return ok(await exportCandidates(filters)); } catch (e: any) { return err(e); } });

  server.tool("propose_candidate_change", "Aenderung VORSCHLAGEN (Freigabe noetig).",
    { candidate_id: z.number().int(), changes: z.record(z.any()), reason: z.string().optional() },
    async ({ candidate_id, changes, reason }: any) => {
      try { const id = await db.proposeChange(candidate_id, changes, reason); return ok({ vorgeschlagen: id, candidate_id, changes }); } catch (e: any) { return err(e); }
    });
  server.tool("list_pending_changes", "Offene Freigaben.", { status: z.enum(["pending", "applied", "rejected"]).default("pending") },
    async ({ status }: any) => { try { return ok(await db.listPending(status)); } catch (e: any) { return err(e); } });
  server.tool("apply_change", "NACH menschlichem OK ausfuehren (confirm=true).", { change_id: z.number().int(), confirm: z.boolean() },
    async ({ change_id, confirm }: any) => { try { return ok(await db.applyChange(change_id, confirm)); } catch (e: any) { return err(e); } });
  server.tool("reject_change", "Freigabe ablehnen.", { change_id: z.number().int() },
    async ({ change_id }: any) => { try { await db.rejectChange(change_id); return ok({ rejected: change_id }); } catch (e: any) { return err(e); } });

  server.tool("get_notifications", "Statusaenderungen.", { unacked_only: z.boolean().default(true), limit: z.number().int().min(1).max(100).default(50) },
    async ({ unacked_only, limit }: any) => { try { return ok(await db.listNotifications(unacked_only, limit)); } catch (e: any) { return err(e); } });
  server.tool("ack_notification", "Benachrichtigung quittieren.", { id: z.number().int() },
    async ({ id }: any) => { try { await db.ackNotification(id); return ok({ acked: id }); } catch (e: any) { return err(e); } });
  server.tool("set_notifications_enabled", "Benachrichtigungen an/aus.", { enabled: z.boolean() },
    async ({ enabled }: any) => { try { await db.setNotificationsEnabled(enabled); return ok({ enabled }); } catch (e: any) { return err(e); } });

  server.tool("get_filter_options", "Auswahlwerte fuer Filter-Domain.", { domain: z.string() },
    async ({ domain }: any) => { try { return ok(await db.getOptions(domain)); } catch (e: any) { return err(e); } });
  server.tool("get_search_history", "Letzte Suchen.", { limit: z.number().int().min(1).max(100).default(20) },
    async ({ limit }: any) => { try { return ok(await db.getHistory(limit)); } catch (e: any) { return err(e); } });
  server.tool("db_schema", "DB-Struktur (kompakt oder Tabelle).", { table: z.string().optional() },
    async ({ table }: any) => { try { return ok(await db.getSchema(table)); } catch (e: any) { return err(e); } });
  server.tool("run_query", "Nur read-only SELECT (LIMIT 200).", { sql: z.string(), params: z.array(z.union([z.string(), z.number(), z.boolean()])).optional() },
    async ({ sql, params }: any) => { try { return ok(await db.runReadOnlyQuery(sql, params ?? [])); } catch (e: any) { return err(e); } });
}
