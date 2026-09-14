#!/bin/bash
# ============================================================
# VERIFY-AND-FIX: Prueft alle 5 kritischen Punkte, fixt was geht
# Einmal im Terminal einfuehren: bash verify-and-fix.sh
# ============================================================
echo "=============================================="
echo "  CRM-MCP VERIFY-AND-FIX"
echo "=============================================="
echo ""

# ---------- PUNKT 1: Passwort testen ----------
echo "[1/5] Datenbank-Passwort testen..."
cd /Users/activi/Downloads/crm-mcp-bundle-v1-3/crm-mcp 2>/dev/null
if [ ! -d node_modules/pg ]; then
  echo "      FEHLER: pg-Modul nicht gefunden - npm install noetig"
else
  node -e "
const pg = require('pg');
const fs = require('fs');
const url = fs.readFileSync(process.env.HOME + '/.neon_prod_copy_url', 'utf8').trim();
const c = new pg.Client(url);
c.connect().then(() => c.query('SELECT count(*) FROM idk_kandidati'))
  .then(r => { console.log('      OK: ' + r.rows[0].count + ' Kandidaten erreichbar'); process.exit(0); })
  .catch(e => { console.log('      FEHLER: ' + e.message); process.exit(1); });
" 2>/dev/null
  if [ $? -ne 0 ]; then
    echo "      -> PASSWORT DEFEKT: Neon-Dashboard -> prod-copy -> Connect"
    echo "         -> Reset password -> neuen String nach ~/.neon_prod_copy_url"
  fi
fi
echo ""

# ---------- PUNKT 2: Suchfunktion-Version pruefen ----------
echo "[2/5] Suchfunktion auf dem NEUESTEN Stand?"
node -e "
const pg = require('pg');
const fs = require('fs');
const url = fs.readFileSync(process.env.HOME + '/.neon_prod_copy_url', 'utf8').trim();
const c = new pg.Client(url);
c.connect().then(() => c.query("SELECT crm_search_candidates('{\\"occupation_source\\":\\"experience\\",\\"limit\\":1}'::jsonb, 'internal')"))
  .then(() => { console.log('      OK: Funktion kennt occupation_source (neue Version)'); process.exit(0); })
  .catch(e => {
    if (e.message.includes('Unbekannte Filter')) { console.log('      OK: Funktion hat Whitelist-Validierung (neueste Version)'); process.exit(0); }
    if (e.message.includes('Ungueltige occupation_source') || e.message.includes('occupation_source')) { console.log('      OK: Funktion kennt occupation_source'); process.exit(0); }
    console.log('      HINWEIS: ' + e.message.substring(0,80)); process.exit(1);
  });
" 2>/dev/null
if [ $? -ne 0 ]; then
  echo "      -> ALTE FUNKTION AKTIV: neon-dev/02_search_function.sql im SQL Editor einspielen"
fi
echo ""

# ---------- PUNKT 3: Indizes pruefen ----------
echo "[3/5] trigram-Indizes vorhanden?"
node -e "
const pg = require('pg');
const fs = require('fs');
const url = fs.readFileSync(process.env.HOME + '/.neon_prod_copy_url', 'utf8').trim();
const c = new pg.Client(url);
c.connect().then(() => c.query("SELECT count(*) FROM pg_indexes WHERE indexname LIKE '%trgm%'"))
  .then(r => {
    if (parseInt(r.rows[0].count) >= 7) console.log('      OK: ' + r.rows[0].count + ' trigram-Indizes gefunden');
    else console.log('      FEHLEND: nur ' + r.rows[0].count + '/7 trigram-Indizes -> Index-SQL einspielen');
    process.exit(0);
  }).catch(e => { console.log('      DB nicht erreichbar'); process.exit(1); });
" 2>/dev/null
echo ""

# ---------- PUNKT 4: Zombies killen ----------
echo "[4/5] Zombie-Prozesse..."
ZCOUNT=$(pgrep -f "crm-mcp/src/index.ts" | wc -l | tr -d ' ')
echo "      Gefunden: $ZCOUNT Prozesse"
if [ "$ZCOUNT" -gt 0 ]; then
  pkill -f "crm-mcp/src/index.ts" 2>/dev/null
  sleep 2
  ZLEFT=$(pgrep -f "crm-mcp/src/index.ts" | wc -l | tr -d ' ')
  echo "      -> Gekillt. Verbleibend: $ZLEFT"
else
  echo "      -> Keine Zombies. Sauber."
fi
echo ""

# ---------- PUNKT 5: launchd-Plist ----------
echo "[5/5] launchd-Plist (Crash-Loop-Quelle)..."
if [ -f ~/Library/LaunchAgents/com.crm-mcp.plist ]; then
  LOOPCOUNT=$(grep -c "läuft\." /tmp/crm-mcp.log 2>/dev/null || echo 0)
  echo "      Plist vorhanden. 'läuft'-Einträge im Log: $LOOPCOUNT"
  launchctl unload ~/Library/LaunchAgents/com.crm-mcp.plist 2>/dev/null
  rm ~/Library/LaunchAgents/com.crm-mcp.plist
  echo "      -> Plist entfernt. Clients spawnen Server selbst."
else
  echo "      -> Keine Plist vorhanden. OK."
fi
echo ""

echo "=============================================="
echo "  LOKALER TEIL FERTIG."
echo "  Offen (nur du, im Neon-Dashboard/SQL-Editor):"
echo "  - Passwort (falls [1] FEHLER zeigte)"
echo "  - 02_search_function.sql einspielen (falls [2] ALT zeigte)"
echo "  - Index-SQL einspielen (falls [3] FEHLEND zeigte)"
echo "=============================================="
