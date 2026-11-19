#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$SCRIPT_DIR/skills/neon-claude-orchestrator"
TARGET_BASE="$HOME/.gemini/config/skills"
TARGET_DIR="$TARGET_BASE/neon-claude-orchestrator"

if [[ ! -d "$SOURCE_DIR" ]]; then
  echo "Source skill directory not found: $SOURCE_DIR" >&2
  exit 1
fi

mkdir -p "$TARGET_BASE"
rm -rf "$TARGET_DIR"
cp -R "$SOURCE_DIR" "$TARGET_DIR"
chmod +x "$TARGET_DIR/scripts/claude-bridge.sh"

echo "Installed neon-claude-orchestrator skill to: $TARGET_DIR"
echo "Open a new conversation in Antigravity to start using it."
