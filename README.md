# claude-hud-context-fix

> Fix the 0% context display issue in Claude Code's HUD when using non-standard models (e.g., GLM, DeepSeek via Anthropic-compatible APIs).

When using Claude Code with third-party models through Anthropic-compatible API proxies, the claude-hud plugin's status bar always shows context usage as **0%**. This tool fixes that by calculating actual context usage from the conversation transcript.

## Features

- Accurate context percentage calculated from the actual conversation transcript
- Color-coded progress bar (green < 50%, yellow 50-75%, red > 75%)
- Two modes: HUD wrapper (enhances claude-hud) or standalone
- One-click install/uninstall
- Supports both macOS and Linux

## Prerequisites

- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code)
- Python 3.x
- Node.js (required only for HUD wrapper mode)

## Quick Start

### One-Click Install

```bash
# Clone the repo
git clone https://github.com/panxiao-geek/claude-hud-context-fix.git
cd claude-hud-context-fix

# Install (HUD wrapper mode — requires claude-hud plugin and node)
bash install.sh

# Or install standalone mode (no claude-hud dependency)
bash install.sh --standalone
```

Restart Claude Code after installation.

### Manual Install

1. Copy scripts to `~/.claude/scripts/`:

```bash
mkdir -p ~/.claude/scripts
cp context-hud-wrapper.sh ~/.claude/scripts/
cp context-status.sh ~/.claude/scripts/
chmod +x ~/.claude/scripts/*.sh
```

2. Edit `~/.claude/settings.json`, add or update the `statusLine` field:

**HUD wrapper mode** (requires claude-hud plugin):
```json
{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/scripts/context-hud-wrapper.sh"
  }
}
```

**Standalone mode** (no claude-hud needed):
```json
{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/scripts/context-status.sh"
  }
}
```

## How It Works

The scripts estimate token usage by:

1. Reading the conversation transcript (`.jsonl` file) from `~/.claude/projects/`
2. Counting characters in `user` and `assistant` messages
3. Estimating tokens as `total_chars / 4 + 17000` (system/tools overhead)
4. Calculating percentage against a 200k token context window

### Environment Variables

- `CLAUDE_CONTEXT_WINDOW` — Override the default 200k context window size (default: `200000`)

## Uninstall

```bash
cd claude-hud-context-fix
bash uninstall.sh
```

This restores your original `settings.json` and removes the installed scripts.

## Modes Comparison

| Feature | HUD Wrapper | Standalone |
|---------|-------------|------------|
| Requires claude-hud plugin | Yes | No |
| Requires Node.js | Yes | No |
| Shows other HUD info | Yes | No |
| Context fix | Yes | Yes |
| Startup overhead | Slightly more | Minimal |

## File Structure

```
claude-hud-context-fix/
├── README.md              # This file
├── LICENSE                # MIT license
├── install.sh             # One-click installer
├── uninstall.sh           # One-click uninstaller
├── context-hud-wrapper.sh # Core: wraps HUD + fixes context
└── context-status.sh      # Standalone: context only, no HUD
```

## License

[MIT](LICENSE)
