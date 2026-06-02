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

def estimate_tokens_for_content(content):
    """Estimate tokens from message content, handling images and tool results properly."""
    tokens = 0
    image_count = 0

    if isinstance(content, str):
        tokens += len(content) // 4
    elif isinstance(content, list):
        for item in content:
            if not isinstance(item, dict):
                continue
            item_type = item.get('type', '')

            if item_type == 'image':
                image_count += 1
            elif item_type == 'tool_result':
                item_str = json.dumps(item, ensure_ascii=False)
                tokens += min(len(item_str), 16000) // 4
            elif item_type == 'text':
                text = item.get('text', '')
                tokens += len(text) // 4
            elif item_type == 'tool_use':
                item_str = json.dumps(item, ensure_ascii=False)
                tokens += len(item_str) // 4
            elif item_type == 'thinking':
                text = item.get('thinking', '')
                tokens += len(text) // 4
            else:
                item_str = json.dumps(item, ensure_ascii=False)
                tokens += len(item_str) // 4

    tokens += image_count * 1000
    return tokens

try:
    msg_tokens = []
    with open(tp, 'r', encoding='utf-8', errors='ignore') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                data = json.loads(line)
                msg_type = data.get('type', '')
                if msg_type in ('user', 'assistant'):
                    msg = data.get('message', {})
                    content = msg.get('content', '')
                    t = estimate_tokens_for_content(content)
                    if t > 0:
                        msg_tokens.append(t)
            except (json.JSONDecodeError, KeyError, TypeError):
                continue

    overhead = int(os.environ.get('CLAUDE_SYSTEM_OVERHEAD', 30000))
    window = int(os.environ.get('CLAUDE_CONTEXT_WINDOW', 200000))

    # Count backwards — older messages beyond the context window have been compressed
    token_budget = window - overhead
    active_tokens = 0
    for t in reversed(msg_tokens):
        if active_tokens + t > token_budget:
            break
        active_tokens += t

    est_total = active_tokens + overhead
    pct = min(99, round(est_total / window * 100))

    c = '\033[32m' if pct < 50 else '\033[33m' if pct < 75 else '\033[31m'
    r = '\033[0m'
    dim = '\033[2m'

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
