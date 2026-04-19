#!/bin/bash
# context-status.sh — Standalone context percentage display (no claude-hud dependency)
#
# Usage:
#   echo '{"transcript_path":"/path/to/transcript.jsonl"}' | bash context-status.sh
#   echo '{}' | bash context-status.sh   # auto-detects from cwd
#
# Can be used as a standalone statusLine command without claude-hud.

set -euo pipefail

# Read stdin JSON
stdin_data=$(cat 2>/dev/null || echo '{}')

# Extract transcript_path and cwd
eval "$(python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
except:
    d = {}
tp = d.get('transcript_path', '')
cwd = d.get('cwd', '')
print(f'transcript_path=\"{tp}\"')
print(f'cwd=\"{cwd}\"')
" <<< "$stdin_data" 2>/dev/null || echo 'transcript_path="" cwd=""')"

# Locate transcript file
if [ -z "$transcript_path" ] || [ ! -f "$transcript_path" ]; then
    if [ -n "$cwd" ]; then
        encoded=$(echo "$cwd" | sed 's/\//-/g')
        proj_dir="$HOME/.claude/projects/$encoded"
        if [ -d "$proj_dir" ]; then
            transcript_path=$(ls -t "$proj_dir"/*.jsonl 2>/dev/null | head -1 || true)
        fi
    fi
fi

if [ -z "$transcript_path" ] || [ ! -f "$transcript_path" ]; then
    echo "CTX: ?"
    exit 0
fi

# Calculate and display context percentage
python3 - "$transcript_path" <<'PYEOF' 2>/dev/null || echo "CTX: ?"
import json, sys, os

tp = sys.argv[1]
try:
    total_chars = 0
    with open(tp, 'r', encoding='utf-8', errors='ignore') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                data = json.loads(line)
                msg_type = data.get('type', '')
                if msg_type in ('user', 'assistant'):
                    msg = json.dumps(data.get('message', ''), ensure_ascii=False)
                    total_chars += len(msg)
            except (json.JSONDecodeError, KeyError, TypeError):
                continue

    est_tokens = total_chars // 4
    est_total = est_tokens + 17000
    window = int(os.environ.get('CLAUDE_CONTEXT_WINDOW', 200000))
    pct = min(99, round(est_total / window * 100))

    # Colors
    if pct < 50:
        color = '\033[32m'   # green
    elif pct < 75:
        color = '\033[33m'   # yellow
    else:
        color = '\033[31m'   # red
    reset = '\033[0m'

    # Progress bar
    filled = pct // 5
    empty = 20 - filled
    bar = chr(9608) * filled + chr(9617) * empty

    print(f'{color}CTX {bar} {pct}%{reset}', end='')
except Exception:
    print('CTX: ?')
PYEOF
