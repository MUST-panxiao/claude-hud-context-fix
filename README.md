# claude-hud-context-fix

**中文说明** | [English](#english)

## 问题背景

当通过 Anthropic 兼容的 API 代理（如智谱 GLM、DeepSeek 等）使用 Claude Code 时，[claude-hud](https://github.com/nicekid1/claude-hud) 插件的状态栏**上下文占用始终显示为 0%**，无法看到实际用量。

本工具通过读取会话转录文件（transcript）来**估算真实的上下文使用量**，并替换 HUD 中的上下文行，让你随时掌握上下文消耗情况。

## 效果预览

状态栏会显示如下格式的上下文进度条：

```
上下文 ████████░░░░░░░░░░░░ 40%
```

颜色随用量变化：绿色（<50%）→ 黄色（50%-75%）→ 红色（>75%）

## 功能特性

- 从会话转录文件估算真实上下文占用百分比
- 彩色进度条，一目了然
- 两种模式：HUD 包装模式 / 独立模式
- 一键安装 / 一键卸载
- 支持 macOS 和 Linux

## 前置条件

- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code)
- Python 3.x
- Node.js（仅 HUD 包装模式需要）

## 快速开始

### 一键安装

```bash
# 克隆仓库
git clone https://github.com/MUST-panxiao/claude-hud-context-fix.git
cd claude-hud-context-fix

# 安装：HUD 包装模式（需要 claude-hud 插件和 node）
bash install.sh

# 或安装：独立模式（不需要 claude-hud，也不需要 node）
bash install.sh --standalone
```

安装后重启 Claude Code 即可生效。

### 手动安装

1. 将脚本复制到 `~/.claude/scripts/`：

```bash
mkdir -p ~/.claude/scripts
cp context-hud-wrapper.sh ~/.claude/scripts/
cp context-status.sh ~/.claude/scripts/
chmod +x ~/.claude/scripts/*.sh
```

2. 编辑 `~/.claude/settings.json`，添加或修改 `statusLine` 字段：

**HUD 包装模式**（需要 claude-hud 插件）：
```json
{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/scripts/context-hud-wrapper.sh"
  }
}
```

**独立模式**（不需要 claude-hud）：
```json
{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/scripts/context-status.sh"
  }
}
```

## 工作原理

脚本通过以下步骤估算 token 用量：

1. 读取 `~/.claude/projects/` 下的会话转录文件（`.jsonl`）
2. 统计 `user` 和 `assistant` 消息的字符数
3. 估算 token 数 = `字符数 / 4 + 17000`（包含 system/tools 开销）
4. 除以上下文窗口大小（默认 200k）得到百分比

> **注意：** 新会话刚启动时可能显示约 9%，这是正常的。因为公式中包含 17000 token 的固定开销估算（system prompt、tools 定义、skills 等），即 `17000 / 200000 ≈ 8.5%`。建议关注整体变化趋势而非初始值。

### 环境变量

- `CLAUDE_CONTEXT_WINDOW` — 自定义上下文窗口大小（默认：`200000`）

### 根据模型调整上下文窗口

默认按 200k 上下文窗口计算。如果你使用的模型上下文窗口不同，需要在 `~/.claude/settings.json` 的 `env` 中设置 `CLAUDE_CONTEXT_WINDOW`：

```json
{
  "env": {
    "CLAUDE_CONTEXT_WINDOW": "128000"
  }
}
```

常见模型的上下文窗口参考：

| 模型 | 上下文窗口 | 设置值 |
|------|-----------|--------|
| Claude Sonnet / Opus | 200k | `200000` |
| GLM-5.1 | 128k | `128000` |
| GLM-4.7 | 128k | `128000` |
| DeepSeek-V3 | 128k | `128000` |
| GPT-4o | 128k | `128000` |
| GPT-4o-mini | 128k | `128000` |

## 卸载

```bash
cd claude-hud-context-fix
bash uninstall.sh
```

会自动恢复原始 `settings.json` 配置并删除已安装的脚本。

## 模式对比

| 特性 | HUD 包装模式 | 独立模式 |
|------|-------------|---------|
| 需要 claude-hud 插件 | 是 | 否 |
| 需要 Node.js | 是 | 否 |
| 显示 HUD 其他信息 | 是 | 否 |
| 上下文修复 | 是 | 是 |
| 启动开销 | 略高 | 极低 |

## 文件结构

```
claude-hud-context-fix/
├── README.md              # 说明文档
├── LICENSE                # MIT 协议
├── install.sh             # 一键安装脚本
├── uninstall.sh           # 一键卸载脚本
├── context-hud-wrapper.sh # 核心：包装 HUD + 修复上下文显示
└── context-status.sh      # 独立模式：仅显示上下文，不依赖 HUD
```

## 许可证

[MIT](LICENSE)

---

<a id="english"></a>

## Problem

When using Claude Code with third-party models through Anthropic-compatible API proxies, the claude-hud plugin's status bar always shows context usage as **0%**. This tool fixes that by calculating actual context usage from the conversation transcript.

## Preview

The status bar shows a color-coded progress bar:

```
上下文 ████████░░░░░░░░░░░░ 40%
```

Colors change with usage: green (<50%) → yellow (50-75%) → red (>75%)

## Features

- Accurate context percentage calculated from the actual conversation transcript
- Color-coded progress bar
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
git clone https://github.com/MUST-panxiao/claude-hud-context-fix.git
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

> **Note:** A fresh session may show ~9% at startup. This is expected — the formula includes a 17000 token fixed overhead estimate (system prompt, tool definitions, skills, etc.), i.e. `17000 / 200000 ≈ 8.5%`. Focus on the overall trend rather than the initial value.

### Environment Variables

- `CLAUDE_CONTEXT_WINDOW` — Override the default 200k context window size (default: `200000`)

### Adjusting Context Window for Your Model

The default calculation uses a 200k context window. If your model has a different window size, set `CLAUDE_CONTEXT_WINDOW` in `~/.claude/settings.json` under `env`:

```json
{
  "env": {
    "CLAUDE_CONTEXT_WINDOW": "128000"
  }
}
```

Common model context window sizes:

| Model | Context Window | Value |
|-------|---------------|-------|
| Claude Sonnet / Opus | 200k | `200000` |
| GLM-5.1 | 128k | `128000` |
| GLM-4.7 | 128k | `128000` |
| DeepSeek-V3 | 128k | `128000` |
| GPT-4o | 128k | `128000` |
| GPT-4o-mini | 128k | `128000` |

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
├── README.md              # Documentation
├── LICENSE                # MIT license
├── install.sh             # One-click installer
├── uninstall.sh           # One-click uninstaller
├── context-hud-wrapper.sh # Core: wraps HUD + fixes context
└── context-status.sh      # Standalone: context only, no HUD
```

## License

[MIT](LICENSE)
