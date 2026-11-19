# Antigravity × Claude Code Orchestrator

[日本語版 README はこちら (README.ja.md)](./README.ja.md)

A global skill for **Google Antigravity** that pairs **Gemini 4 Neon** (as Lead Architect & Orchestrator) with your local **Claude Code CLI** (Claude Opus 5.5 / Sonnet 5.5) and native Antigravity subagents.

Designed to stay **compliant with official consumer subscriptions** (Google AI Pro/Ultra + Claude Max/Pro) without extracting OAuth tokens or using third-party proxy harnesses.

---

## Features

- **1M-Context Lead Orchestration (Gemini 4 Neon)**: Neon analyzes the full repository, plans architecture, decomposes tasks, and passes only concise, targeted briefs to Claude Code to conserve subscription quota.
- **Subscription-Safe Bridge (`claude-bridge.ps1` / `claude-bridge.sh`)**:
  - Invokes your unmodified local `claude` CLI binary directly.
  - Automatically unsets `ANTHROPIC_API_KEY` during execution to prevent accidental fallback to pay-as-you-go Console API billing.
  - Supports `--read-only` / `-ReadOnly` mode for safe cross-model code reviews (only `Read,Grep,Glob` are made available and MCP servers are disabled, regardless of your Claude Code permission settings).
- **Bidirectional Multi-Turn Dialogue**: Captures and reuses Claude Code `session_id` (`--resume`) so Neon and Claude Code can iterate across multiple turns in the same conversation context.
- **Visual GUI Monitoring**:
  - Updates an Antigravity Artifact (`orchestration-board.md`) inside the Antigravity GUI pane.
  - Automatically logs every message to `.orchestration/comm_log.jsonl` and generates `.orchestration/dashboard_data.js` so you can open `.orchestration/dashboard.html` directly in your browser (works offline via `file://`).
  - The logs contain full prompts and replies, so the bridge writes `.orchestration/.gitignore` (`*`) to keep them out of your project's git history.
- **Cross-Platform**: Includes both Windows PowerShell (`claude-bridge.ps1`) and macOS/Linux Bash (`claude-bridge.sh`) bridges.

---

## Prerequisites

1. **Google Antigravity** (Desktop App, IDE, or `agy` CLI) with Gemini 4 Neon.
2. **Official Claude Code CLI** installed and logged in with your Claude subscription:
   ```bash
   claude auth status
   # If not logged in:
   claude auth login
   ```
   > **Note:** Using `claude-opus-5-5` requires Claude Code CLI `2.1.280+` (`claude update`). If you are on an older version, pass `-Model default` / `--model default`.
   > **Windows:** the bridge only runs a real `claude.exe` (native installer or a current npm package). `.cmd` / `.ps1` wrappers are refused because cmd.exe quoting could let a crafted prompt inject shell commands.
3. *(macOS / Linux only)* `python3` available in `PATH` (used by `claude-bridge.sh` for UTF-8 JSON handling).

---

## Installation

### Windows (PowerShell)
```powershell
git clone https://github.com/rtonf/antigravity-claude-orchestrator.git
cd antigravity-claude-orchestrator
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

### macOS / Linux
```bash
git clone https://github.com/rtonf/antigravity-claude-orchestrator.git
cd antigravity-claude-orchestrator
bash ./install.sh
```

This installs the skill globally to `~/.gemini/config/skills/neon-claude-orchestrator/`, making it automatically discoverable across all Antigravity workspaces.

---

## Usage

1. Open any project workspace in **Google Antigravity**.
2. Select **Gemini 4 Neon** as your model.
3. Start with a prompt like:

```text
Use the neon-claude-orchestrator skill for this project.
[Project Overview]
(Describe your goal, tech stack, and constraints here)

First, create the architecture plan, set up orchestration-board.md and .orchestration/dashboard.html, and then delegate tasks appropriately between Claude Code and subagents.
```

> **Tip (First Run Permission):** Because `claude` needs network access and `~/.claude`, Antigravity will ask for approval to run the bridge script outside the sandbox on the first call. Selecting **Always Allow** enables smooth hands-free orchestration afterward.

---

## Repository Structure

```text
antigravity-claude-orchestrator/
├── README.md
├── README.ja.md
├── LICENSE
├── install.ps1
├── install.sh
└── skills/
    └── neon-claude-orchestrator/
        ├── SKILL.md
        ├── scripts/
        │   ├── claude-bridge.ps1
        │   └── claude-bridge.sh
        └── resources/
            └── dashboard.html
```

---

## License

[MIT](./LICENSE)
