#!/usr/bin/env bash
set -e

# ─────────────────────────────────────────────
# hivequeen × Gemini CLI installer
# ─────────────────────────────────────────────

HIVEQUEEN_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GEMINI_DIR="${GEMINI_HOME:-$HOME/.gemini}"
HOST_SHORT="$(hostname -s 2>/dev/null || hostname | cut -d. -f1)"
AGENT_ID="gemini-$(echo "$HOST_SHORT" | tr '[:upper:]' '[:lower:]')"
AGENT_DIR="$HIVEQUEEN_PATH/agents/$AGENT_ID"

echo "→ hivequeen path : $HIVEQUEEN_PATH"
echo "→ agent id       : $AGENT_ID"
echo "→ gemini home    : $GEMINI_DIR"

# 1. Create this agent's memory directory
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

# 2. Inject hivequeen bootstrap into ~/.gemini/GEMINI.md (preserves user content).
mkdir -p "$GEMINI_DIR"
python3 "$HIVEQUEEN_PATH/scripts/_install-bootstrap.py" \
  "$GEMINI_DIR/GEMINI.md" "$HIVEQUEEN_PATH" "$AGENT_ID"

echo ""
echo "✅ hivequeen installed for Gemini CLI"
echo "   agent  : $AGENT_ID"
echo "   memory : $AGENT_DIR/memory.md"
echo "   config : $GEMINI_DIR/GEMINI.md"
echo ""
echo "ℹ Gemini CLI has no session hooks; memory commit/push runs inside the"
echo "  agent loop per the instructions written to GEMINI.md."
