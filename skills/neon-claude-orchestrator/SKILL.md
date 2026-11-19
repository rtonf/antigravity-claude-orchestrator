---
name: neon-claude-orchestrator
description: >-
  Orchestrate software projects using Google Antigravity (Gemini 4 Neon) as the
  lead architect and context manager while delegating specialized coding, deep
  debugging, and cross-model code reviews to your local Claude Code CLI (Claude
  Opus 5.5 / Sonnet 5.5 via Claude Max / Pro subscription) and native
  Antigravity subagents. Includes bidirectional session handoff, subscription-safe
  execution, and a GUI communication dashboard. Use when the user wants
  multi-agent orchestration between Antigravity and Claude Code.
---

# Antigravity × Claude Code Orchestrator

Google Antigravity (**Gemini 4 Neon**) acts as the **Orchestrator (Lead Architect & Context Manager)** leveraging its 1M-token context window, while your local **Claude Code CLI** (using your official Claude subscription) and **Antigravity Subagents / Swarm** act as specialized workers.

---

## 1. Architecture & Role Assignment

| Role | Engine / Model | Responsibilities |
| :--- | :--- | :--- |
| **Orchestrator (Lead)** | **Antigravity (Gemini 4 Neon)** | Requirements intake, 1M-context repo analysis, architecture & `/plan`, task decomposition, worker dispatch, integration, final verification. |
| **Elite Coder / Reviewer** | **Claude Code (`claude-opus-5-5`)** | Complex algorithm design, hard debugging, security/architecture cross-review, multi-file precision refactoring. |
| **Standard Coder** | **Claude Code (`claude-sonnet-5-5`)** | Routine feature implementation, unit tests, medium-complexity edits (conserves subscription quota). |
| **Parallel / Utility Workers** | **Antigravity Subagents / Swarm** (`research`, `browser`, lightweight models such as `Hydrogen`) | Broad codebase research, web lookup, browser UI verification, parallel boilerplate generation. |

---

## 2. Subscription Safety & Compliance Rules (CRITICAL)

1. **Never extract or hijack OAuth tokens.** Always invoke the unmodified official local `claude` CLI binary.
2. **Prevent accidental pay-as-you-go API fallback:** Use the bundled helper script (`claude-bridge.ps1` on Windows or `claude-bridge.sh` on macOS/Linux), which temporarily unsets `ANTHROPIC_API_KEY` before invoking `claude` so calls stay inside your Claude subscription.
3. **Sandbox note:** `claude` requires network access and access to `~/.claude`. Invoke the bridge script with `BypassSandbox: true` using a clean, prefix-approvable command shape (no shell command substitutions or complex pipelines).
4. **Minimize Claude quota burn:** Never ask Claude Code to "explore the whole repository". First locate relevant files using Neon's 1M context, then pass **only the concise task brief, target file paths, constraints, and acceptance criteria**.

---

## 3. Orchestration Workflow (Step-by-Step)

### Phase 1: Intake & Workspace Setup
1. Clarify the user's project overview, goals, and constraints.
2. Create an `.orchestration/` directory in the project root (add `.orchestration/` to `.gitignore` if the user does not want local logs committed).
3. Copy `resources/dashboard.html` from this skill directory into `<PROJECT_DIR>/.orchestration/dashboard.html` so the user can visually inspect all agent-to-agent conversations in a browser.
4. Create/update an Antigravity Artifact named `orchestration-board.md` (`UserFacing: true`) to display the live task plan, worker assignments, and communication timeline inside the Antigravity GUI pane.

### Phase 2: Task Decomposition & Dispatch
Split work into independent units with **non-overlapping file ownership**:
- **For parallel research / browser checks / lightweight edits:** Use `invoke_subagent` (`research`, `browser`, or `self` with `Workspace: "share"` for parallel edits) or `swarm`.
- **For heavy implementation or cross-review via Claude Code:** Run the bridge script with `BypassSandbox: true`:

#### Windows (PowerShell)
```powershell
powershell -ExecutionPolicy Bypass -File "$HOME\.gemini\config\skills\neon-claude-orchestrator\scripts\claude-bridge.ps1" -ProjectDir "<PROJECT_PATH>" -Model "claude-opus-5-5" -Role "implementer" -Prompt "<CONCISE_TASK_PROMPT>"
```

#### macOS / Linux (Bash)
```bash
bash "$HOME/.gemini/config/skills/neon-claude-orchestrator/scripts/claude-bridge.sh" --project-dir "<PROJECT_PATH>" --model "claude-opus-5-5" --role "implementer" --prompt "<CONCISE_TASK_PROMPT>"
```

**Parameters:**
- `Model` / `--model`: `claude-opus-5-5` (requires Claude Code CLI `2.1.280+`), `claude-sonnet-5-5`, or `default` (uses your CLI's current default model without hardcoding a version).
- `Role` / `--role`: `implementer`, `reviewer`, `debugger`, or `architect`.
- `-ReadOnly` / `--read-only`: Restricts Claude Code to read-only inspection tools (`Read,Grep,Glob,LS`) for safe code review or architecture consultation.
- `-ResumeSessionId` / `--resume`: Pass the `session_id` returned by a previous call to continue the **same Claude Code conversation** for multi-turn bidirectional dialogue.

### Phase 3: Bidirectional Communication & Handoff
- **Multi-turn Neon <-> Claude Code dialogue:** Capture `session_id` from the JSON output of the bridge script. When Neon needs to follow up, challenge a design, or send test failures back to Claude Code, pass that `session_id` via `-ResumeSessionId` / `--resume`.
- **Continuing an existing Claude Code CLI session:** If the user wants to bridge an existing CLI conversation, pass its session ID via `-ResumeSessionId` / `--resume`.
- **Sharing context with Claude Desktop:** Claude Desktop chats are cloud-stored and cannot be scraped directly. Write shared summaries to `.orchestration/handoff.md` so the user (or a shared Filesystem MCP) can exchange context cleanly.

### Phase 4: Cross-Model Verification & GUI Sync
1. After Claude Code finishes an implementation, **Neon reviews the git diff and runs tests**.
2. After Neon finishes a major design or implementation, invoke Claude Code in read-only mode (`-ReadOnly` / `--read-only`) with `claude-opus-5-5` for an independent **cross-model review**.
3. Keep both views updated:
   - `.orchestration/comm_log.jsonl` & `.orchestration/dashboard_data.js` (updated automatically by the bridge script).
   - The Antigravity Artifact `orchestration-board.md` with a concise timeline table of delegated tasks, Claude responses, and current status.

---

## 4. Reporting to the User

- Summarize progress cleanly in the `orchestration-board.md` Artifact instead of dumping raw JSON.
- Point the user to `.orchestration/dashboard.html` whenever they want a chat-style timeline of Neon <-> Claude Code exchanges.
- Clearly attribute which model handled each task (`Neon`, `Claude Opus 5.5`, `Claude Sonnet 5.5`, or `Subagent`).
