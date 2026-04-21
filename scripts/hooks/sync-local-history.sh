#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# hivequeen local-history sync (thin wrapper)
#
# Gated by HIVEQUEEN_SYNC_LOCAL_HISTORY=1; otherwise no-op.
# Delegates to sync-local-history.py to keep redaction logic in one place.
#
# Called from the Stop hook chain installed by scripts/install/_hooks.py.
# -----------------------------------------------------------------------------

set -u

HOST_ID="${1:-${HIVEQUEEN_HOST:-}}"
AGENT_ID="${2:-${HIVEQUEEN_AGENT_ID:-}}"
HIVEQUEEN_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

[ "${HIVEQUEEN_SYNC_LOCAL_HISTORY:-0}" = "1" ] || exit 0
[ -z "$HOST_ID" ] && exit 0
[ -z "$AGENT_ID" ] && exit 0

python3 "$HIVEQUEEN_PATH/scripts/hooks/sync-local-history.py" \
  "$HIVEQUEEN_PATH" "$HOST_ID" "$AGENT_ID" || exit 0
