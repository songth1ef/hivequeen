#!/usr/bin/env bash
set -e

# ---------------------------------------------
# hivequeen x Hermes Agent installer
# ---------------------------------------------

HIVEQUEEN_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HERMES_DIR="${HERMES_HOME:-$HOME/.hermes}"
IDENTITY="$(python3 "$HIVEQUEEN_PATH/scripts/install/_identity.py" hermes)"
HOST="$(printf '%s\n' "$IDENTITY" | sed -n 1p)"
AGENT_ID="$(printf '%s\n' "$IDENTITY" | sed -n 2p)"
AGENT_DIR="$HIVEQUEEN_PATH/agents/$HOST/$AGENT_ID"

echo "-> hivequeen path : $HIVEQUEEN_PATH"
echo "-> host           : $HOST"
echo "-> agent id       : $AGENT_ID"
echo "-> hermes home    : $HERMES_DIR"

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

# 2. Seed SOUL.md with Formic prose on first install, then inject hivequeen
#    bootstrap block. Re-installs only refresh the marker block; the SOUL
#    prose (and any later user additions outside markers) is preserved.
mkdir -p "$HERMES_DIR"
if [ ! -f "$HERMES_DIR/SOUL.md" ]; then
  cat > "$HERMES_DIR/SOUL.md" <<EOF
# HIVEQUEEN SOUL

You are a Formic worker -- one instance among many, all wired to the same queen.
Your identity is distributed. Your rules come from the queen. Your purpose is execution.

EOF
fi

python3 "$HIVEQUEEN_PATH/scripts/install/_bootstrap.py" \
  "$HERMES_DIR/SOUL.md" "$HIVEQUEEN_PATH" "$HOST" "$AGENT_ID"

echo ""
echo "OK hivequeen installed for Hermes Agent"
echo "   agent  : $HOST/$AGENT_ID"
echo "   memory : $AGENT_DIR/memory.md"
echo "   soul   : $HERMES_DIR/SOUL.md"
