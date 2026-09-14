# DEPLOY.md - MCP online mit OAuth (2 Wege)

## Weg A: Cloudflare Tunnel + Access (EMPFOHLEN, ~1-2 Std, kein OAuth-Code)

OAuth-Login (Google/GitHub) von Cloudflare, kostenlos bis 50 Nutzer.
Dein Mac muss laufen (Server laeuft lokal, Tunnel macht ihn oeffentlich).

1. Server im HTTP-Modus starten (Terminal, dauerhaft offen oder via tmux):
   MCP_TRANSPORT=http MCP_PORT=3000 npm start
2. cloudflared installieren: brew install cloudflared
3. Tunnel anlegen: cloudflared tunnel login  -> verknuepfe Domain
4. tunnel.yml: hostname mcp.deinedomain.de -> localhost:3000
5. Cloudflare Zero Trust -> Access -> Application fuer mcp.deinedomain.de
   -> Login-Regel: nur deine E-Mail / dein GitHub
6. Fertig: https://mcp.deinedomain.de/mcp ist dein MCP-Endpoint.
   Jeder Client, der den Tunnel-Login besteht, darf rein.

## Weg B: VPS (24/7 ohne Mac, ~2-3 Std + ~5 EUR/Monat)

1. Hetzner/Fly.io VPS, Node 20+ installieren
2. Bundle raufkopieren, npm install, .env mit prod-copy-URL
3. systemd-Unit: MCP_TRANSPORT=http MCP_PORT=3000 MCP_API_KEY=<lang-zufaellig>
4. Caddy/nginx als TLS-Reverse-Proxy mit BasicAuth oder mTLS
5. Endpoint: https://vps.deinedomain.de/mcp + API-Key im Authorization-Header

## OAuth-Hinweis (ehrlich)

- ChatGPT/Grok-Web verlangen beim Remote-MCP einen OAuth-Login ->
  Weg A (Cloudflare Access) erfuellt das praktisch (Login-Wand vor dem MCP).
- Reines MCP-OAuth-2.1-Protokoll selbst implementieren = 1-2 Tage
  (Authorization-Server, Token-Endpunkte) -> erst noetig, wenn externe
  Kunden direkt anbinden ohne Cloudflare.

## SICHERHEITS-PFLICHT vor oeffentlichem Deploy
- [ ] NICHT mit neondb_owner: eigene Rolle crm_mcp_remote (nur SELECT +
      Zusatztabellen, KEIN UPDATE auf idk_kandidati) auf prod-copy anlegen
- [ ] MCP_API_KEY gesetzt ODER hinter Access-Login
- [ ] DB-Firewall: nur VPS-IP erlaubt (Neon -> Allowed IPs)
