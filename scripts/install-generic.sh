#!/usr/bin/env bash
set -e

# ─────────────────────────────────────────────────────────────────────────────
# hivequeen × generic markdown-config installer
#
# Works for any AI CLI that loads a single markdown file at startup as its
# system prompt / instructions / rules. Writes the hivequeen bootstrap block
# into that file using the same marker-block convention as install-claude.
#
# Usage:
#   bash install-generic.sh <tool-prefix> <config-path>
#
# Examples:
#   # Qwen Code (based on Gemini CLI; confirm path with `qwen --help`)
#   bash install-generic.sh qwen ~/.qwen/QWEN.md
#
#   # OpenCode (check tool docs for the exact rules file)
#   bash install-generic.sh opencode ~/.config/opencode/prompt.md
#
#   # Any other tool — pass its rules/instructions path
#   bash install-generic.sh <prefix> <path>
#
# The script:
#   - Generates a deterministic agent-id: "<prefix>-<lowercase-hostname>"
#   - Creates agents/<agent-id>/memory.md if missing
#   - Injects (or updates) the hivequeen bootstrap block in the target file
#     via scripts/_install-bootstrap.py (preserves any non-hivequeen content)
#
# Does NOT register hooks — only Claude Code has a PreToolUse-style hook
# system that hivequeen can plug into. All other tools rely on the session
# instructions (written into the config file) to commit+push memory manually
# at session end.
# ─────────────────────────────────────────────────────────────────────────────

HIVEQUEEN_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PREFIX="${1:-}"
CONFIG_PATH="${2:-}"

if [ -z "$PREFIX" ] || [ -z "$CONFIG_PATH" ]; then
  cat >&2 <<USAGE
usage: bash install-generic.sh <tool-prefix> <config-path>

example:
  bash install-generic.sh qwen ~/.qwen/QWEN.md
  bash install-generic.sh opencode ~/.config/opencode/prompt.md

<tool-prefix>: short identifier used in agent-id (e.g. qwen, opencode, trae)
<config-path>: absolute or ~-relative path to the tool's prompt/rules file
USAGE
  exit 2
fi

# Expand ~ in config path
eval CONFIG_PATH="$CONFIG_PATH"

# Generate agent-id: <prefix>-<host> (matches codex/hermes/openclaw pattern)
HOST_SHORT="$(hostname -s 2>/dev/null || hostname | cut -d. -f1)"
AGENT_ID="${PREFIX}-$(echo "$HOST_SHORT" | tr '[:upper:]' '[:lower:]')"
AGENT_DIR="$HIVEQUEEN_PATH/agents/$AGENT_ID"

echo "→ hivequeen path : $HIVEQUEEN_PATH"
echo "→ agent id       : $AGENT_ID"
echo "→ config target  : $CONFIG_PATH"

# 1. Create agent memory directory
mkdir -p "$AGENT_DIR"
if [ ! -f "$AGENT_DIR/memory.md" ]; then
  cat > "$AGENT_DIR/memory.md" <<EOF
# MEMORY — $AGENT_ID

> Private memory for this agent instance.
> Only $AGENT_ID writes here.

---

_No memory yet._
EOF
  echo "✓ created $AGENT_DIR/memory.md"
fi

# 2. Inject bootstrap into the tool's config file
CONFIG_DIR="$(dirname "$CONFIG_PATH")"
mkdir -p "$CONFIG_DIR"
python3 "$HIVEQUEEN_PATH/scripts/_install-bootstrap.py" \
  "$CONFIG_PATH" "$HIVEQUEEN_PATH" "$AGENT_ID"

echo ""
echo "✅ hivequeen installed for $PREFIX"
echo "   agent  : $AGENT_ID"
echo "   memory : $AGENT_DIR/memory.md"
echo "   config : $CONFIG_PATH"
