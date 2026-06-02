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
                # Cap each tool result to avoid huge file reads / web pages
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

    # Images: ~1000 tokens each (resolution-dependent, but reasonable avg)
    tokens += image_count * 1000
    return tokens

try:
    # Collect all user/assistant messages with their token estimates
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

    # System prompt + tool definitions overhead
    overhead = int(os.environ.get('CLAUDE_SYSTEM_OVERHEAD', 30000))
    window = int(os.environ.get('CLAUDE_CONTEXT_WINDOW', 200000))

    # Count backwards from most recent messages — older messages beyond
    # the context window have been compressed/summarized
    token_budget = window - overhead
    active_tokens = 0
    for t in reversed(msg_tokens):
        if active_tokens + t > token_budget:
            break
        active_tokens += t

    est_total = active_tokens + overhead
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
