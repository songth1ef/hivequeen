#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# hivequeen unified hook entry
#
# Usage (invoked by Claude Code settings.json hooks):
#   hook-hivequeen.sh pre  <agent-id>   -- PreToolUse  (Write/Edit on memory)
#   hook-hivequeen.sh post <agent-id>   -- PostToolUse (Write/Edit on memory)
#   hook-hivequeen.sh stop <agent-id>   -- Stop safety-net
#
# Design: atomic per-write sync.
# - pre:  pull --rebase before memory write; abort write on conflict
# - post: commit + push with retry; surface rebase conflict to Claude
# - stop: same as post (safety net for writes that skipped post)
# -----------------------------------------------------------------------------

set -u
PHASE="${1:-}"
AGENT_ID="${2:-}"
HIVEQUEEN_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MATCHER_SCRIPT="$HIVEQUEEN_PATH/scripts/hooks/_match-file.py"

[ -z "$PHASE" ] && exit 0
[ -z "$AGENT_ID" ] && exit 0

# -- Check whether the Write/Edit target is under agents/<id>/ -----------------
# Reads hook JSON from THIS script's stdin and forwards to the matcher python.
# Matcher exits 0 on match, 1 otherwise.
match_agent_file() {
  python3 "$MATCHER_SCRIPT" "$HIVEQUEEN_PATH" "$AGENT_ID"
}

# -- git pull --rebase, abort on conflict --------------------------------------
pull_rebase() {
  cd "$HIVEQUEEN_PATH" || return 1
  if git pull --rebase --autostash -q 2>/dev/null; then
    return 0
  fi
  git rebase --abort 2>/dev/null || true
  return 1
}

# -- commit + push with retry; warn on persistent conflict ---------------------
#
# IMPORTANT: scope all commits to agents/<agent-id>/ via an explicit pathspec.
# Without it, `git commit` includes every staged file, so if the user (or a
# prior tool call) left unrelated paths staged -- e.g. `git checkout upstream
# -- something` -- they would get vacuumed into a "memory: update" commit.
commit_push_retry() {
  cd "$HIVEQUEEN_PATH" || return 1
  local agent_path="agents/$AGENT_ID"
  git add "$agent_path/" >/dev/null 2>&1 || return 1
  git diff --cached --quiet -- "$agent_path/" && return 0
  git commit -m "memory: update $AGENT_ID" -q -- "$agent_path/" || return 1
  local attempt
  for attempt in 1 2 3; do
    if git push -q 2>/dev/null; then
      return 0
    fi
    # push rejected -- backoff with jitter (~0.5s, ~1s, ~2s) to reduce
    # thundering-herd when multiple agents commit concurrently, then
    # undo local commit, rebase, re-commit, retry.
    sleep "$(awk -v a="$attempt" 'BEGIN{srand(); printf "%.2f", (2^(a-1))*0.5 + rand()*0.3}')"
    git reset --soft HEAD~1 >/dev/null 2>&1
    if ! pull_rebase; then
      echo "[!] hivequeen[$AGENT_ID]: rebase conflict, memory not pushed, manual merge needed" >&2
      return 1
    fi
    git commit -m "memory: update $AGENT_ID" -q -- "$agent_path/" || return 1
  done
  echo "[!] hivequeen[$AGENT_ID]: push retried 3 times, all failed; local commit kept, will retry on next hook" >&2
  return 1
}

case "$PHASE" in
  pre)
    match_agent_file || exit 0
    pull_rebase || {
      echo "[!] hivequeen[$AGENT_ID]: upstream has conflicting changes, resolve manually before writing memory" >&2
      exit 2   # exit 2 blocks the Write/Edit tool in Claude Code
    }
    ;;
  post)
    match_agent_file || exit 0
    commit_push_retry || exit 0   # don't block; warning already emitted
    ;;
  stop)
    commit_push_retry || exit 0
    ;;
  *)
    exit 0
    ;;
esac
exit 0
