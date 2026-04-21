#!/usr/bin/env bash
set -e

# -----------------------------------------------------------------------------
# nestwork protocol v1 -> v2 migration
#
# Rewrites the flat agents/<tool>-<host>-<suffix>/ layout into the new
# agents/<host>/<tool>[-<suffix>]/ layout. Safe to run multiple times:
# already-migrated directories are left alone.
#
# Run from the nestwork root (or pass its path as $1). The script uses
# `git mv` so history is preserved. It does NOT commit -- review the
# staged changes, then commit with a message like:
#
#     git commit -m "migrate: nestwork protocol v1 -> v2 layout"
#
# Safety:
#   - refuses to run on a dirty working tree (unless --force)
#   - ignores any directory whose name doesn't match the v1 format
#   - skips directories that already live under agents/<host>/
# -----------------------------------------------------------------------------

FORCE=0
NESTWORK_PATH=""

for arg in "$@"; do
  case "$arg" in
    --force) FORCE=1 ;;
    -h|--help)
      sed -n '3,20p' "$0"
      exit 0
      ;;
    *) NESTWORK_PATH="$arg" ;;
  esac
done

if [ -z "$NESTWORK_PATH" ]; then
  NESTWORK_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fi

cd "$NESTWORK_PATH"

if [ ! -d agents ]; then
  echo "ERROR: $NESTWORK_PATH/agents not found" >&2
  exit 1
fi

if [ "$FORCE" -ne 1 ] && ! git diff --quiet; then
  echo "ERROR: working tree has uncommitted changes. Commit or stash first, or pass --force." >&2
  exit 1
fi

shopt -s nullglob
moved=0
skipped=0

for d in agents/*/; do
  name="${d%/}"
  name="${name#agents/}"

  # Skip already-migrated host directories (they contain sub-agent dirs,
  # not a memory.md at their top level).
  if [ ! -f "agents/$name/memory.md" ] && [ -d "agents/$name" ]; then
    # Looks like a host folder already -- leave it alone.
    skipped=$((skipped + 1))
    continue
  fi

  # Parse v1 id: <tool>-<host>-<4-char-suffix> OR <tool>-<host>
  # Strategy: split on '-'. If last segment is exactly 4 [a-z0-9], treat
  # it as a suffix (claude-style). Otherwise tool-host only (codex-style).
  tool=""
  host=""
  suffix=""
  if [[ "$name" =~ ^([a-z]+)-([a-z0-9][a-z0-9-]*)-([a-z0-9]{4})$ ]]; then
    tool="${BASH_REMATCH[1]}"
    host="${BASH_REMATCH[2]}"
    suffix="${BASH_REMATCH[3]}"
    new_id="${tool}-${suffix}"
  elif [[ "$name" =~ ^([a-z]+)-([a-z0-9][a-z0-9-]*)$ ]]; then
    tool="${BASH_REMATCH[1]}"
    host="${BASH_REMATCH[2]}"
    new_id="${tool}"
  else
    echo "[skip] $name (does not match v1 naming)"
    skipped=$((skipped + 1))
    continue
  fi

  dest="agents/$host/$new_id"
  if [ -e "$dest" ]; then
    echo "[skip] $name -> $dest (destination already exists)"
    skipped=$((skipped + 1))
    continue
  fi

  mkdir -p "agents/$host"
  git mv "agents/$name" "$dest"
  echo "[moved] agents/$name -> $dest"
  moved=$((moved + 1))
done

echo ""
echo "migration summary: $moved moved, $skipped skipped"
echo ""
echo "Review with: git status"
echo "Commit with: git commit -m 'migrate: nestwork protocol v1 -> v2 layout'"
