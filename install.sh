#!/bin/bash
# CRM-MCP Bundle - Skill-Installer (idempotent, Backup-Rotation, Verifikation)
# Aufruf: bash install.sh [--check]
set -e
SKILL_SRC="$(cd "$(dirname "$0")" && pwd)/skills/crm-kandidatensuche"
DEST=~/.agents/skills/crm-kandidatensuche
BACKUP_DIR=~/.agents/skills

VERSION=$(grep -m1 '^version:' "$SKILL_SRC/SKILL.md" | awk '{print $2}')

if [ "$1" = "--check" ]; then
  echo "Bundle:      crm-kandidatensuche v$VERSION"
  if [ -f "$DEST/SKILL.md" ]; then
    INST=$(grep -m1 '^version:' "$DEST/SKILL.md" | awk '{print $2}')
    echo "Installiert: v$INST"
    [ "$INST" = "$VERSION" ] && echo "Status: AKTUELL" || echo "Status: VERALTET -> bash install.sh"
  else
    echo "Status: NICHT INSTALLIERT -> bash install.sh"
  fi
  exit 0
fi

echo "Installiere crm-kandidatensuche v$VERSION"

# Backup (bei Update), dann Rotation: max. 2 Backups behalten
if [ -d "$DEST" ]; then
  cp -r "$DEST" "$BACKUP_DIR/crm-kandidatensuche.bak.$(date +%Y%m%d-%H%M%S)"
  ls -1dt "$BACKUP_DIR"/crm-kandidatensuche.bak.* 2>/dev/null | tail -n +3 | xargs rm -rf 2>/dev/null || true
  echo "Backup angelegt (alte Version), Rotation auf 2"
fi

mkdir -p "$DEST"
cp -r "$SKILL_SRC/." "$DEST/"   # WICHTIG: /. verhindert Verschachtelung

# Verifikation vor Erfolgsmeldung
INST=$(grep -m1 '^version:' "$DEST/SKILL.md" | awk '{print $2}')
for f in SKILL.md TOOLS.md AGENTS.md CHANGELOG.md; do
  [ -f "$DEST/$f" ] || { echo "FEHLER: $f fehlt nach Installation"; exit 1; }
done
[ "$INST" = "$VERSION" ] || { echo "FEHLER: Version $INST != erwartet $VERSION"; exit 1; }

echo "Installiert nach $DEST (v$INST):"
ls -la "$DEST"
echo "FERTIG + VERIFIZIERT nach $DEST"

# Optional: Codex-Globalanleitung mergen (nur wenn ~/.codex existiert)
if [ -d ~/.codex ] && [ -f "$SKILL_SRC/CODEX-AGENTS.md" ]; then
  if [ -f ~/.codex/AGENTS.md ]; then
    cp ~/.codex/AGENTS.md ~/.codex/AGENTS.md.bak.$(date +%Y%m%d-%H%M%S)
    ls -1dt ~/.codex/AGENTS.md.bak.* 2>/dev/null | tail -n +3 | xargs rm -f 2>/dev/null || true
  fi
  cp "$SKILL_SRC/CODEX-AGENTS.md" ~/.codex/AGENTS.md
  chmod 600 ~/.codex/AGENTS.md
  echo "Codex: ~/.codex/AGENTS.md ersetzt (Backup + Dateirechte 600)"
fi
echo "Agenten-Clients neu starten, dann Testanfrage stellen."
