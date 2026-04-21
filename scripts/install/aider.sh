#!/usr/bin/env bash
set -e

# -----------------------------------------------------------------------------
# nestwork x Aider installer
#
# Aider doesn't auto-load a single global "instructions" file the way Claude
# Code or Gemini CLI do. Instead it takes a YAML config (~/.aider.conf.yml)
# with a `read:` list of context files, or a CLI flag `--read <file>`, or the
# `AIDER_READ` env var.
#
# Approach:
#   - Create an aider-specific agent-id and memory dir
#   - Write the nestwork bootstrap into ~/.aider-nestwork.md (via the
#     generic bootstrap helper, so the marker-block preservation still works)
#   - Print instructions for three ways to wire it into the user's aider
#     workflow -- we do NOT silently mutate ~/.aider.conf.yml because the
#     user may already have their own `read:` entries and yaml merging from
#     shell is fragile
# -----------------------------------------------------------------------------

NESTWORK_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BOOTSTRAP_FILE="$HOME/.aider-nestwork.md"

bash "$NESTWORK_PATH/scripts/install/generic.sh" aider "$BOOTSTRAP_FILE"

cat <<INSTRUCTIONS

[i] Aider has no global prompt file -- wire the bootstrap in one of 3 ways:

  1. Add to ~/.aider.conf.yml:
       read:
         - $BOOTSTRAP_FILE

  2. Run aider with the flag (per session):
       aider --read $BOOTSTRAP_FILE

  3. Export in your shell profile (~/.bashrc / ~/.zshrc):
       export AIDER_READ="$BOOTSTRAP_FILE"

INSTRUCTIONS
