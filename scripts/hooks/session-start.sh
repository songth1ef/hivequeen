#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# nestwork SessionStart hook
#
# Usage (registered by installer in Claude Code settings.json):
#   session-start.sh <host> <agent-id>
#
# Behavior:
#   - Pull latest nestwork (rebase, autostash) so context is fresh.
#   - Emit the canonical context bundle to stdout: agent-rules, strategy,
#     shared memory, this agent's private memory. Claude Code injects stdout
#     into the session as additional context.
#   - Always exit 0. SessionStart must never block session startup.
# -----------------------------------------------------------------------------

set -u
HOST_ID="${1:-}"
AGENT_ID="${2:-}"
NESTWORK_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

[ -z "$HOST_ID" ] && exit 0
[ -z "$AGENT_ID" ] && exit 0

cd "$NESTWORK_PATH" || exit 0

# Refresh, but never block on failure (offline, conflict, etc.)
git pull --rebase --autostash -q 2>/dev/null || git rebase --abort 2>/dev/null || true

emit_file() {
  local label="$1" path="$2"
  if [ -f "$path" ]; then
    printf '\n=== %s (%s) ===\n' "$label" "$path"
    cat "$path"
  fi
}

printf 'nestwork context bundle for %s/%s\n' "$HOST_ID" "$AGENT_ID"
emit_file "agent-rules"   "queen/agent-rules.md"
emit_file "strategy"      "queen/strategy.md"
emit_file "shared memory" "shared/memory.md"
emit_file "agent memory"  "agents/$HOST_ID/$AGENT_ID/memory.md"

# workflow/: portable user-level knowledge (lowest-priority context layer,
# AGENTS.md §8). Always-relevant across sessions, so injected here rather
# than left for on-demand Read. Skip _template.md (authoring scaffold, not
# content).
if [ -d workflow ]; then
  for f in workflow/*.md; do
    [ -f "$f" ] || continue
    base="$(basename "$f")"
    [ "$base" = "_template.md" ] && continue
    emit_file "workflow/${base%.md}" "$f"
  done
fi

exit 0
