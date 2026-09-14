import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import { registerTools } from "./tools.js";

// Remote-Modus: MCP_TRANSPORT=http -> HTTP-Server starten
if (process.env.MCP_TRANSPORT === "http") {
  await import("./index-http.js");
} else {
  const server = new McpServer({ name: "crm-suche", version: "1.6.0" });
  const ok = (obj: unknown) => ({ content: [{ type: "text" as const, text: JSON.stringify(obj, null, 2) }] });
  const err = (e: any) => ({ content: [{ type: "text" as const, text: `Fehler: ${e.message}` }], isError: true as const });
  registerTools(server, {
    ok, err,
    audienceSchema: z.enum(["internal", "customer"]).default("internal"),
    filterSchema: z.record(z.any()),
  });
  await server.connect(new StdioServerTransport());
  console.error("CRM-Such-MCP v1.6.0 läuft (stdio).");
}
