#!/bin/bash
# context-hud-wrapper.sh
# Wraps claude-hud and replaces the context line with an accurate percentage
# Works with non-standard models (e.g. glm-5.1) where HUD shows 0%
#
# Usage: echo '{"transcript_path":"...","cwd":"..."}' | bash context-hud-wrapper.sh

set -euo pipefail

# --- Save stdin (can only be read once) ---
stdin_tmp=$(mktemp)
trap 'rm -f "$stdin_tmp"' EXIT
cat > "$stdin_tmp" 2>/dev/null

# --- Run original claude-hud ---
# Find the latest installed version of claude-hud
plugin_base="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/plugins/cache/claude-hud/claude-hud"
hud_output=""
if [ -d "$plugin_base" ]; then
    latest_dir=$(find "$plugin_base" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; 2>/dev/null \
        | sort -t. -k1,1n -k2,2n -k3,3n -k4,4n | tail -1)
    if [ -n "$latest_dir" ] && [ -f "$plugin_base/$latest_dir/dist/index.js" ]; then
        hud_output=$(cat "$stdin_tmp" | node "$plugin_base/$latest_dir/dist/index.js" 2>/dev/null || true)
    fi
fi

# --- Extract paths from stdin ---
stdin_data=$(cat "$stdin_tmp")

transcript_path=$(python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('transcript_path', ''))
except:
    print('')
" <<< "$stdin_data" 2>/dev/null || true)

cwd=$(python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('cwd', ''))
except:
    print('')
" <<< "$stdin_data" 2>/dev/null || true)

# --- Locate transcript file ---
if [ -z "$transcript_path" ] || [ ! -f "$transcript_path" ]; then
    if [ -n "$cwd" ]; then
        encoded=$(echo "$cwd" | sed 's/\//-/g')
        proj_dir="$HOME/.claude/projects/$encoded"
        if [ -d "$proj_dir" ]; then
            transcript_path=$(ls -t "$proj_dir"/*.jsonl 2>/dev/null | head -1 || true)
        fi
    fi
fi

# --- Calculate context percentage ---
ctx_replacement=""
if [ -n "$transcript_path" ] && [ -f "$transcript_path" ]; then
    ctx_replacement=$(python3 - "$transcript_path" <<'PYEOF' 2>/dev/null || true
import json, sys, os

tp = sys.argv[1]
try:
    total_chars = 0
    with open(tp, 'r', encoding='utf-8', errors='ignore') as f:
        for line in f:
            try:
                data = json.loads(line.strip())
                if data.get('type') in ('user', 'assistant'):
                    total_chars += len(json.dumps(data.get('message', ''), ensure_ascii=False))
            except (json.JSONDecodeError, KeyError, TypeError):
                continue

    # Estimate tokens (chars / 4) + system/tools overhead (~17k)
    est = total_chars // 4 + 17000
    # Try to detect context window from env or use default 200k
    window = int(os.environ.get('CLAUDE_CONTEXT_WINDOW', 200000))
    pct = min(99, round(est / window * 100))

    # Colors
    c = '\033[32m' if pct < 50 else '\033[33m' if pct < 75 else '\033[31m'
    r = '\033[0m'
    dim = '\033[2m'

    # Progress bar (20 blocks)
    filled = chr(9608) * (pct // 5)
    empty = chr(9617) * (20 - pct // 5)

    print(f'{dim}上下文{r} {dim}{c}{filled}{r}{dim}{empty}{r} {c}{pct}%{r}', end='')
except Exception:
    pass
PYEOF
)
fi

# --- Replace context line in HUD output ---
if [ -n "$ctx_replacement" ] && [ -n "$hud_output" ]; then
    echo "$hud_output" | python3 -c "
import sys
rep = sys.argv[1]
first = True
for line in sys.stdin:
    if '上下文' in line or 'context' in line.lower():
        if first:
            print(rep)
            first = False
        # skip duplicate context lines from HUD
    else:
        print(line, end='')
" "$ctx_replacement" 2>/dev/null
elif [ -n "$ctx_replacement" ]; then
    # No HUD output but we have context info — just print it
    echo "$ctx_replacement"
else
    # Fallback: print original HUD output unchanged
    echo "$hud_output"
fi
