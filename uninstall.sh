#!/bin/bash
# uninstall.sh — Remove claude-hud-context-fix and restore original settings

set -euo pipefail

CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
SCRIPTS_DIR="$CLAUDE_DIR/scripts"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"

echo "=== claude-hud-context-fix uninstaller ==="
echo ""

# --- Restore settings.json ---
echo "[1/2] Restoring settings.json..."

if [ -f "$SETTINGS_FILE" ]; then
    restored=false

    # Try to restore from backup field
    restored=$(python3 - "$SETTINGS_FILE" <<'PYEOF'
import json, sys

settings_path = sys.argv[1]

with open(settings_path, 'r', encoding='utf-8') as f:
    settings = json.load(f)

backup = settings.pop('_statusLine_backup', None)
if backup:
    settings['statusLine'] = backup
    with open(settings_path, 'w', encoding='utf-8') as f:
        json.dump(settings, f, indent=2, ensure_ascii=False)
        f.write('\n')
    print('yes')
else:
    print('no')
PYEOF
)

    if [ "$restored" = "yes" ]; then
        echo "  Restored original statusLine configuration."
    else
        echo "  No backup found in settings.json. Checking for file backups..."
        # Try to find the most recent backup file
        latest_backup=$(ls -t "$SETTINGS_FILE.bak."* 2>/dev/null | head -1 || true)
        if [ -n "$latest_backup" ]; then
            cp "$latest_backup" "$SETTINGS_FILE"
            echo "  Restored from backup: $latest_backup"
        else
            echo "  No backup found. statusLine may need manual restoration."
        fi
    fi
else
    echo "  settings.json not found, nothing to restore."
fi

# --- Remove scripts ---
echo ""
echo "[2/2] Removing installed scripts..."

removed=0
for script in context-hud-wrapper.sh context-status.sh; do
    if [ -f "$SCRIPTS_DIR/$script" ]; then
        rm -f "$SCRIPTS_DIR/$script"
        echo "  Removed: $SCRIPTS_DIR/$script"
        removed=$((removed + 1))
    fi
done

if [ $removed -eq 0 ]; then
    echo "  No scripts found to remove."
fi

echo ""
echo "=== Uninstall complete! ==="
echo ""
echo "Restart Claude Code to apply changes."
