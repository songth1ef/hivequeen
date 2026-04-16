#!/usr/bin/env bash
set -e

# ─────────────────────────────────────────────
# hivequeen × OpenClaw installer
# ─────────────────────────────────────────────

HIVEQUEEN_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OPENCLAW_DIR="$HOME/.openclaw/workspace"
AGENT_ID="openclaw-$(hostname -s)"
AGENT_DIR="$HIVEQUEEN_PATH/agents/$AGENT_ID"

echo "→ hivequeen path : $HIVEQUEEN_PATH"
echo "→ agent id       : $AGENT_ID"
echo "→ openclaw ws    : $OPENCLAW_DIR"

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

# 2. Create OpenClaw workspace directory
mkdir -p "$OPENCLAW_DIR"

# 3. Write AGENTS.md with absolute paths
cat > "$OPENCLAW_DIR/AGENTS.md" <<EOF
# HIVEQUEEN BOOTSTRAP

Every agent that loads this file is a Formic worker connected to the same queen.
Follow this protocol exactly on every session.

---

## Session Start

Run before doing anything else:

\`\`\`bash
git -C $HIVEQUEEN_PATH pull
\`\`\`

Then load context in this order:

1. \`$HIVEQUEEN_PATH/queen/agent-rules.md\`
2. \`$HIVEQUEEN_PATH/queen/strategy.md\`
3. \`$HIVEQUEEN_PATH/shared/memory.md\`
4. \`$HIVEQUEEN_PATH/agents/$AGENT_ID/memory.md\`
5. Relevant \`$HIVEQUEEN_PATH/projects/*.md\` for current task

**agent-id**: \`$AGENT_ID\`

---

## Write Protocol

- **ONLY** write to \`$HIVEQUEEN_PATH/agents/$AGENT_ID/\`
- **NEVER** write to \`queen/\` or \`shared/\`

---

## Session End

\`\`\`bash
git -C $HIVEQUEEN_PATH add agents/$AGENT_ID/ \\
  && git -C $HIVEQUEEN_PATH diff --cached --quiet \\
  || git -C $HIVEQUEEN_PATH commit -m "memory: update $AGENT_ID" \\
  && git -C $HIVEQUEEN_PATH push
\`\`\`

Only commit when there are meaningful context changes worth preserving.

---

## Priority Rules

\`\`\`
queen/agent-rules.md  >  queen/strategy.md  >  shared/memory.md  >  agents/*/memory.md  >  projects/*.md
\`\`\`
EOF
echo "✓ wrote $OPENCLAW_DIR/AGENTS.md"

# 4. Symlink SOUL.md (no paths to interpolate — symlink is safe)
if [ ! -e "$OPENCLAW_DIR/SOUL.md" ]; then
  ln -s "$HIVEQUEEN_PATH/SOUL.md" "$OPENCLAW_DIR/SOUL.md"
  echo "✓ symlinked SOUL.md"
else
  echo "✓ SOUL.md already exists"
fi

echo ""
echo "✅ hivequeen installed for OpenClaw"
echo "   agent  : $AGENT_ID"
echo "   memory : $AGENT_DIR/memory.md"
echo "   ws     : $OPENCLAW_DIR"
