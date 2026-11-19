#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR=""
PROMPT=""
MODEL="default"
ROLE="implementer"
RESUME_SESSION_ID=""
READ_ONLY="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-dir) PROJECT_DIR="$2"; shift 2 ;;
    --prompt)      PROMPT="$2"; shift 2 ;;
    --model)       MODEL="$2"; shift 2 ;;
    --role)        ROLE="$2"; shift 2 ;;
    --resume)      RESUME_SESSION_ID="$2"; shift 2 ;;
    --read-only)   READ_ONLY="true"; shift 1 ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

if [[ -z "$PROJECT_DIR" || -z "$PROMPT" ]]; then
  echo "Usage: claude-bridge.sh --project-dir <DIR> --prompt <TEXT> [--model <MODEL>] [--role <ROLE>] [--resume <SESSION_ID>] [--read-only]" >&2
  exit 2
fi

if [[ ! -d "$PROJECT_DIR" ]]; then
  echo "ProjectDir not found: $PROJECT_DIR" >&2
  exit 1
fi

if ! command -v claude >/dev/null 2>&1; then
  echo "Claude Code CLI ('claude') not found in PATH." >&2
  exit 1
fi

# Protect Claude subscription: prevent accidental fallback to pay-as-you-go Console API
unset ANTHROPIC_API_KEY

ORCH_DIR="$PROJECT_DIR/.orchestration"
mkdir -p "$ORCH_DIR"
# Logs contain full prompts and replies: keep them out of the project's git history by default
if [[ ! -e "$ORCH_DIR/.gitignore" ]]; then
  printf '*\n' > "$ORCH_DIR/.gitignore"
fi
LOG_FILE="$ORCH_DIR/comm_log.jsonl"
JS_DATA_FILE="$ORCH_DIR/dashboard_data.js"

CLI_ARGS=(-p "$PROMPT" --output-format json)
if [[ -n "$MODEL" && "$MODEL" != "default" ]]; then
  CLI_ARGS+=(--model "$MODEL")
fi
if [[ -n "$RESUME_SESSION_ID" ]]; then
  CLI_ARGS+=(--resume "$RESUME_SESSION_ID")
fi
if [[ "$READ_ONLY" == "true" ]]; then
  # --tools limits which built-in tools exist at all (--allowedTools alone only pre-approves them,
  # so user settings that allow Edit/Bash would still apply). --strict-mcp-config drops MCP servers,
  # whose tools could also write.
  READ_ONLY_TOOLS="Read,Grep,Glob"
  CLI_ARGS+=(--tools "$READ_ONLY_TOOLS" --allowedTools "$READ_ONLY_TOOLS" --strict-mcp-config)
fi

# Use python3 for reliable UTF-8 JSON encoding/decoding and millisecond timing
python3 - "$PROJECT_DIR" "$LOG_FILE" "$JS_DATA_FILE" "$MODEL" "$ROLE" "$RESUME_SESSION_ID" "$READ_ONLY" "$PROMPT" "${CLI_ARGS[@]}" <<'PYEOF'
import json
import os
import subprocess
import sys
import time
from datetime import datetime, timezone

project_dir, log_file, js_data_file, model, role, resume_id, read_only_str, prompt = sys.argv[1:9]
cli_args = sys.argv[9:]
read_only = read_only_str == "true"

def iso_now():
    return datetime.now(timezone.utc).astimezone().isoformat()

req_entry = {
    "timestamp": iso_now(),
    "direction": "neon_to_claude",
    "sender": "Gemini 4 Neon (Orchestrator)",
    "recipient": f"Claude Code ({model})",
    "role": role,
    "read_only": read_only,
    "session_id": resume_id,
    "message": prompt,
}
with open(log_file, "a", encoding="utf-8") as f:
    f.write(json.dumps(req_entry, ensure_ascii=False) + "\n")

env = os.environ.copy()
env.pop("ANTHROPIC_API_KEY", None)

start = time.monotonic()
proc = subprocess.run(
    ["claude", *cli_args],
    cwd=project_dir,
    stdin=subprocess.DEVNULL,
    capture_output=True,
    text=True,
    encoding="utf-8",
    errors="replace",
    env=env,
)
duration_ms = int((time.monotonic() - start) * 1000)

raw_out = (proc.stdout or "").strip()
raw_err = (proc.stderr or "").strip()
session_id_out = resume_id
reply_text = raw_out if raw_out else raw_err

try:
    parsed = json.loads(raw_out)
    if isinstance(parsed, dict):
        session_id_out = parsed.get("session_id") or session_id_out
        reply_text = parsed.get("result") or reply_text
except Exception:
    pass

res_entry = {
    "timestamp": iso_now(),
    "direction": "claude_to_neon",
    "sender": f"Claude Code ({model})",
    "recipient": "Gemini 4 Neon (Orchestrator)",
    "role": role,
    "read_only": read_only,
    "session_id": session_id_out,
    "duration_ms": duration_ms,
    "exit_code": proc.returncode,
    "message": reply_text,
}
with open(log_file, "a", encoding="utf-8") as f:
    f.write(json.dumps(res_entry, ensure_ascii=False) + "\n")

# The log is embedded as a single JSON string literal (never as raw code), and the dashboard parses it
# line by line, so a tampered comm_log.jsonl cannot execute script in the browser.
with open(log_file, "r", encoding="utf-8") as f:
    raw_log = f.read()

js_literal = json.dumps(raw_log).replace("<", "\\u003c")
with open(js_data_file, "w", encoding="utf-8") as f:
    f.write("window.ORCHESTRATION_LOGS_JSONL = " + js_literal + ";\n")

summary = {
    "status": "ok" if proc.returncode == 0 else "error",
    "exit_code": proc.returncode,
    "model": model,
    "role": role,
    "session_id": session_id_out,
    "duration_ms": duration_ms,
    "result": reply_text,
}
print(json.dumps(summary, ensure_ascii=False, indent=2))
PYEOF
