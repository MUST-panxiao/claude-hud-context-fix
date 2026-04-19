#!/bin/bash
# install.sh — One-click installer for claude-hud-context-fix
#
# Usage: bash install.sh [--standalone]
#   --standalone  Use standalone mode (no claude-hud dependency)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
SCRIPTS_DIR="$CLAUDE_DIR/scripts"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"
STANDALONE=false

# Parse arguments
for arg in "$@"; do
    case "$arg" in
        --standalone) STANDALONE=true ;;
        *) echo "Unknown argument: $arg"; exit 1 ;;
    esac
done

echo "=== claude-hud-context-fix installer ==="
echo ""

# --- Check dependencies ---
echo "[1/4] Checking dependencies..."

missing=()
if ! command -v python3 &>/dev/null; then
    missing+=("python3")
fi

if [ "$STANDALONE" = false ]; then
    if ! command -v node &>/dev/null; then
        missing+=("node")
    fi
fi

if [ ${#missing[@]} -gt 0 ]; then
    echo "ERROR: Missing dependencies: ${missing[*]}"
    echo "Please install them before continuing."
    exit 1
fi
echo "  All dependencies found."

# --- Create scripts directory ---
echo ""
echo "[2/4] Installing scripts to $SCRIPTS_DIR..."
mkdir -p "$SCRIPTS_DIR"

# Copy scripts and make executable
if [ "$STANDALONE" = true ]; then
    cp "$SCRIPT_DIR/context-status.sh" "$SCRIPTS_DIR/context-status.sh"
    chmod +x "$SCRIPTS_DIR/context-status.sh"
    INSTALLED_SCRIPT="context-status.sh"
    echo "  Installed: context-status.sh (standalone mode)"
else
    cp "$SCRIPT_DIR/context-hud-wrapper.sh" "$SCRIPTS_DIR/context-hud-wrapper.sh"
    chmod +x "$SCRIPTS_DIR/context-hud-wrapper.sh"
    INSTALLED_SCRIPT="context-hud-wrapper.sh"
    echo "  Installed: context-hud-wrapper.sh (HUD wrapper mode)"
fi

# --- Backup and update settings ---
echo ""
echo "[3/4] Updating settings.json..."

if [ -f "$SETTINGS_FILE" ]; then
    # Backup existing settings
    cp "$SETTINGS_FILE" "$SETTINGS_FILE.bak.$(date +%Y%m%d%H%M%S)"
    echo "  Backed up existing settings.json"

    # Update statusLine using python3
    python3 - "$SETTINGS_FILE" "$INSTALLED_SCRIPT" <<'PYEOF'
import json, sys

settings_path = sys.argv[1]
script_name = sys.argv[2]

with open(settings_path, 'r', encoding='utf-8') as f:
    settings = json.load(f)

# Save old statusLine config for uninstall reference
old_statusline = settings.get('statusLine', None)
if old_statusline:
    settings['_statusLine_backup'] = old_statusline

settings['statusLine'] = {
    'type': 'command',
    'command': f'bash ~/.claude/scripts/{script_name}'
}

with open(settings_path, 'w', encoding='utf-8') as f:
    json.dump(settings, f, indent=2, ensure_ascii=False)
    f.write('\n')

print(f"  Updated statusLine to: bash ~/.claude/scripts/{script_name}")
PYEOF

else
    echo "  WARNING: $SETTINGS_FILE not found."
    echo "  Creating a minimal settings.json..."
    mkdir -p "$(dirname "$SETTINGS_FILE")"
    python3 - "$SETTINGS_FILE" "$INSTALLED_SCRIPT" <<'PYEOF'
import json, sys

settings_path = sys.argv[1]
script_name = sys.argv[2]

settings = {
    'statusLine': {
        'type': 'command',
        'command': f'bash ~/.claude/scripts/{script_name}'
    }
}

with open(settings_path, 'w', encoding='utf-8') as f:
    json.dump(settings, f, indent=2, ensure_ascii=False)
    f.write('\n')

print(f"  Created settings.json with statusLine: bash ~/.claude/scripts/{script_name}")
PYEOF
fi

# --- Verify ---
echo ""
echo "[4/4] Verifying installation..."
if [ -f "$SCRIPTS_DIR/$INSTALLED_SCRIPT" ]; then
    echo "  OK: $SCRIPTS_DIR/$INSTALLED_SCRIPT exists and is executable"
else
    echo "  ERROR: Script not found after installation!"
    exit 1
fi

echo ""
echo "=== Installation complete! ==="
echo ""
if [ "$STANDALONE" = true ]; then
    echo "Mode: Standalone (no claude-hud dependency)"
else
    echo "Mode: HUD Wrapper (enhances claude-hud with accurate context %)"
fi
echo ""
echo "Restart Claude Code to see the changes."
echo ""
echo "To uninstall: bash $SCRIPT_DIR/uninstall.sh"
