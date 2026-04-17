#!/usr/bin/env bash
set -e

# ---------------------------------------------
# hivequeen x Gemini CLI installer
# ---------------------------------------------

HIVEQUEEN_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GEMINI_DIR="${GEMINI_HOME:-$HOME/.gemini}"
IDENTITY="$(python3 "$HIVEQUEEN_PATH/scripts/install/_identity.py" gemini)"
HOST="$(printf '%s\n' "$IDENTITY" | sed -n 1p)"
AGENT_ID="$(printf '%s\n' "$IDENTITY" | sed -n 2p)"
AGENT_DIR="$HIVEQUEEN_PATH/agents/$HOST/$AGENT_ID"

echo "-> hivequeen path : $HIVEQUEEN_PATH"
echo "-> host           : $HOST"
echo "-> agent id       : $AGENT_ID"
echo "-> gemini home    : $GEMINI_DIR"

# 1. Create this agent's memory directory
mkdir -p "$AGENT_DIR"
if [ ! -f "$AGENT_DIR/memory.md" ]; then
  cat > "$AGENT_DIR/memory.md" <<EOF
# MEMORY -- $HOST/$AGENT_ID

> Private memory for this agent instance.
> Only $HOST/$AGENT_ID writes here.

---

_No memory yet._
EOF
  echo "[ok] created $AGENT_DIR/memory.md"
fi

# 2. Inject hivequeen bootstrap into ~/.gemini/GEMINI.md (preserves user content).
mkdir -p "$GEMINI_DIR"
python3 "$HIVEQUEEN_PATH/scripts/install/_bootstrap.py" \
  "$GEMINI_DIR/GEMINI.md" "$HIVEQUEEN_PATH" "$HOST" "$AGENT_ID"

echo ""
echo "OK hivequeen installed for Gemini CLI"
echo "   agent  : $HOST/$AGENT_ID"
echo "   memory : $AGENT_DIR/memory.md"
echo "   config : $GEMINI_DIR/GEMINI.md"
echo ""
echo "[i] Gemini CLI has no session hooks; memory commit/push runs inside the"
echo "  agent loop per the instructions written to GEMINI.md."
