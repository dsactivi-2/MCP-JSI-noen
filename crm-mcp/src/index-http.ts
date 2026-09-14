import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StreamableHTTPServerTransport } from "@modelcontextprotocol/sdk/server/streamableHttp.js";
import { z } from "zod";
import * as db from "./db.js";
import { exportCandidates } from "./excel.js";
import http from "http";
import { URL } from "url";

// ============================================================
// CRM-Such-MCP - REMOTE MODE (Streamable HTTP)
// Laeuft als echter Webserver, erreichbar von aussen.
// Auth: Bearer-Token (MCP_API_KEY) ODER hinter OAuth-Proxy
//       (Cloudflare Access / eigenes OAuth) - siehe DEPLOY.md
// Start: MCP_TRANSPORT=http node dist/index-http.js
//        oder: MCP_TRANSPORT=http MCP_API_KEY=geheim npm start
// ============================================================

const API_KEY = process.env.MCP_API_KEY || null;

const ok = (obj: unknown) => ({ content: [{ type: "text" as const, text: JSON.stringify(obj, null, 2) }] });
const err = (e: any) => ({ content: [{ type: "text" as const, text: `Fehler: ${e.message}` }], isError: true as const });
const audienceSchema = z.enum(["internal", "customer"]).default("internal");
const filterSchema = z.record(z.any());

const server = new McpServer({ name: "crm-suche", version: "1.6.0" });

// ---- Identische Tool-Registrierung wie stdio-Version (siehe index.ts) ----
// Damit beide Transporte 1:1 gleiche Tools liefern, wird die Registrierung
// in registerTools() zentral gepflegt (siehe tools.ts).
import { registerTools } from "./tools.js";
registerTools(server, { ok, err, audienceSchema, filterSchema });

// ---- HTTP-Server mit Auth-Check ----
const httpServer = http.createServer(async (req, res) => {
  // CORS (fuer Browser-Clients; im Produktivbetritt hinter Proxy eng einstellen)
  res.setHeader("Access-Control-Allow-Origin", process.env.MCP_CORS_ORIGIN || "*");
  res.setHeader("Access-Control-Allow-Methods", "GET, POST, DELETE, OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type, Authorization");

  if (req.method === "OPTIONS") { res.writeHead(204); res.end(); return; }

  // Auth: Bearer-Token pruefen (falls gesetzt). Hinter Cloudflare Access
  // kommt der Request schon authentifiziert an - dann MCP_API_KEY weglassen
  // und NUR den Proxy vertrauen (MCP_TRUST_PROXY=true).
  if (API_KEY) {
    const auth = req.headers.authorization || "";
    const token = auth.replace(/^Bearer\s+/i, "");
    if (token !== API_KEY) {
      res.writeHead(401, { "Content-Type": "application/json" });
      res.end(JSON.stringify({ error: "unauthorized", hint: "Authorization: Bearer <MCP_API_KEY>" }));
      return;
    }
  }

  const transport = new StreamableHTTPServerTransport({ serverInfo: { name: "crm-suche", version: "1.6.0" } });
  await server.connect(transport);
  await transport.handleRequest(req, res, new URL(req.url || "/", "http://localhost"));
});

const PORT = parseInt(process.env.MCP_PORT || "3000", 10);
httpServer.listen(PORT, () => {
  console.error(`CRM-Such-MCP v1.6.0 (HTTP) auf Port ${PORT} - Auth: ${API_KEY ? "API-Key" : "TRUST_PROXY/keine"}`);
});
