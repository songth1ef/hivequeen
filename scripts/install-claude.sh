#!/usr/bin/env bash
set -e

# ─────────────────────────────────────────────
# hivequeen × Claude Code installer
# ─────────────────────────────────────────────

HIVEQUEEN_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLAUDE_DIR="$HOME/.claude"
SETTINGS="$CLAUDE_DIR/settings.json"
HIVEQUEEN_ID_FILE="$HOME/.hivequeen_id"

# Generate or reuse agent-id (suffix is fixed per machine)
if [ -f "$HIVEQUEEN_ID_FILE" ]; then
  AGENT_ID="$(cat "$HIVEQUEEN_ID_FILE")"
else
  SUFFIX="$(cat /dev/urandom | tr -dc 'a-z0-9' | head -c 4)"
  HOST_SHORT="$(hostname -s 2>/dev/null || hostname | cut -d. -f1)"
  AGENT_ID="claude-$(echo "$HOST_SHORT" | tr '[:upper:]' '[:lower:]')-$SUFFIX"
  echo "$AGENT_ID" > "$HIVEQUEEN_ID_FILE"
fi

AGENT_DIR="$HIVEQUEEN_PATH/agents/$AGENT_ID"

echo "→ hivequeen path : $HIVEQUEEN_PATH"
echo "→ agent id       : $AGENT_ID"

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

# 2. Write global CLAUDE.md to bootstrap hivequeen
mkdir -p "$CLAUDE_DIR"
cat > "$CLAUDE_DIR/CLAUDE.md" <<EOF
# Global Startup Protocol

Before starting analysis, planning, or implementation, run:

\`\`\`bash
git -C $HIVEQUEEN_PATH pull --rebase
\`\`\`

Then load context from hivequeen in this order:

1. \`$HIVEQUEEN_PATH/queen/agent-rules.md\`
2. \`$HIVEQUEEN_PATH/queen/strategy.md\`
3. \`$HIVEQUEEN_PATH/shared/memory.md\`
4. \`$HIVEQUEEN_PATH/agents/$AGENT_ID/memory.md\`
5. Relevant \`$HIVEQUEEN_PATH/projects/*.md\` for current task

Write protocol: only write to \`$HIVEQUEEN_PATH/agents/$AGENT_ID/\`

See full protocol: \`$HIVEQUEEN_PATH/AGENTS.md\`
EOF
echo "✓ wrote $CLAUDE_DIR/CLAUDE.md"

# 3. Register hooks: PreToolUse / PostToolUse / Stop
#    Atomic per-write sync: pull before every memory Write/Edit,
#    commit+push right after. Stop hook remains as safety net.
mkdir -p "$CLAUDE_DIR"

if [ ! -f "$SETTINGS" ]; then
  echo '{}' > "$SETTINGS"
fi

python3 "$HIVEQUEEN_PATH/scripts/_install-hooks.py" \
  "$SETTINGS" "$HIVEQUEEN_PATH" "$AGENT_ID"

echo ""
echo "✅ hivequeen installed for Claude Code"
echo "   agent: $AGENT_ID"
echo "   memory: $AGENT_DIR/memory.md"
