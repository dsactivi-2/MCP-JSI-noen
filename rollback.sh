#!/bin/bash
# Rollback auf letztes Backup
set -e
BACKUP=$(ls -1dt ~/.agents/skills/crm-kandidatensuche.bak.* 2>/dev/null | head -1)
if [ -z "$BACKUP" ]; then echo "Kein Backup gefunden"; exit 1; fi
DEST=~/.agents/skills/crm-kandidatensuche
rm -rf "$DEST"
cp -r "$BACKUP" "$DEST"
INST=$(grep -m1 '^version:' "$DEST/SKILL.md" 2>/dev/null | awk '{print $2}')
echo "Rollback auf: $BACKUP (v$INST)"
echo "Agenten-Client neu starten."
