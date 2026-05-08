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

# Upstream protocol-version check (AGENTS.md §11, v2.3+).
# Advisory only: emit a notice if upstream MAJOR.MINOR is greater than local.
# 24h cache to avoid hitting the network every session start. Never blocks.
check_upstream_version() {
  local cache_dir="${HOME:-/tmp}/.cache/nestwork"
  local cache_file="${cache_dir}/upstream-check"
  local upstream_url="https://raw.githubusercontent.com/songth1ef/nestwork/main/AGENTS.md"
  local now upstream_ver=""
  local local_ver=""
  now="$(date +%s 2>/dev/null || echo 0)"

  local_ver="$(grep -oE 'protocol-version: [0-9]+\.[0-9]+' AGENTS.md 2>/dev/null | awk '{print $2}')"
  [ -z "$local_ver" ] && return 0

  # Use cache if fresh (< 24h)
  if [ -f "$cache_file" ]; then
    local cached_ts="" cached_ver=""
    read -r cached_ts cached_ver < "$cache_file" 2>/dev/null || true
    if [ -n "$cached_ts" ] && [ -n "$cached_ver" ] && \
       [ "$((now - cached_ts))" -lt 86400 ] 2>/dev/null; then
      upstream_ver="$cached_ver"
    fi
  fi

  # Fetch if cache cold/stale; fail silently on network errors
  if [ -z "$upstream_ver" ]; then
    upstream_ver="$(curl -sf -m 3 "$upstream_url" 2>/dev/null \
      | grep -oE 'protocol-version: [0-9]+\.[0-9]+' \
      | awk '{print $2}')"
    if [ -n "$upstream_ver" ]; then
      mkdir -p "$cache_dir" 2>/dev/null || true
      printf '%s %s\n' "$now" "$upstream_ver" > "$cache_file" 2>/dev/null || true
    fi
  fi

  [ -z "$upstream_ver" ] && return 0
  [ "$upstream_ver" = "$local_ver" ] && return 0

  # Compare with sort -V; advise only when upstream is strictly newer.
  local newer
  newer="$(printf '%s\n%s\n' "$local_ver" "$upstream_ver" | sort -V | tail -n1)"
  if [ "$newer" = "$upstream_ver" ]; then
    printf '\n=== upstream protocol check ===\n'
    printf 'Local protocol-version: %s\n' "$local_ver"
    printf 'Upstream protocol-version: %s (newer)\n' "$upstream_ver"
    printf '\n[!IMPORTANT] A newer nestwork protocol is available.\n'
    printf 'Action: ask the agent to run `bash scripts/maintenance/update.sh`.\n'
    printf 'The updater shows incoming changes and prompts before applying. Your\n'
    printf 'private data (agents/, queen/, shared/, projects/) is never touched.\n'
  fi
}
check_upstream_version || true

exit 0
