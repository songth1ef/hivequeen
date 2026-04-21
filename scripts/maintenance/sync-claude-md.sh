#!/usr/bin/env bash
set -e

# -----------------------------------------------------------------------------
# sync CLAUDE.md from AGENTS.md
#
# Claude Code loads CLAUDE.md; Codex / OpenClaw / others load AGENTS.md.
# Keeping the two files in lockstep means editing AGENTS.md and running
# this script to regenerate CLAUDE.md, preserving the small HTML-comment
# header that flags CLAUDE.md as a generated mirror.
# -----------------------------------------------------------------------------

NESTWORK_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SRC="$NESTWORK_PATH/AGENTS.md"
DST="$NESTWORK_PATH/CLAUDE.md"

if [ ! -f "$SRC" ]; then
  echo "ERROR: $SRC not found" >&2
  exit 1
fi

# Emit the 'mirror of AGENTS.md' header, then the full AGENTS.md body.
cat > "$DST" <<'HEADER'
<!--
  This file is a verbatim mirror of AGENTS.md.

  Two real files exist because Claude Code loads CLAUDE.md and
  Codex / OpenClaw / etc. load AGENTS.md, and Windows clones without
  symlink support were receiving a broken 9-byte text file when this
  was a symlink.

  Edit AGENTS.md as the source of truth, then run:

      bash scripts/maintenance/sync-claude-md.sh

  to regenerate CLAUDE.md. Drift between the two files is a bug.
-->

HEADER
cat "$SRC" >> "$DST"

echo "regenerated $DST from $SRC"

# Warn if git sees a diff so callers know to commit.
if command -v git >/dev/null 2>&1; then
  cd "$NESTWORK_PATH"
  if ! git diff --quiet -- CLAUDE.md; then
    echo "note: CLAUDE.md has uncommitted changes -- remember to commit"
  fi
fi
