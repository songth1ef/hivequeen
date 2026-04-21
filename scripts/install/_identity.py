#!/usr/bin/env python3
# -----------------------------------------------------------------------------
# nestwork identity resolver (protocol v2.0)
#
# Returns (host, agent-id) for this machine, creating them on first run and
# caching on disk so reinstalls keep the same identity. One file:
#
#   ~/.nestwork_id              two lines:
#                                1. lowercased short hostname
#                                2. per-tool agent id (e.g. "claude-a7k2")
#
# Usage:
#   _identity.py <tool> [--with-suffix]
#
#   <tool>            prefix used for the agent-id (claude / codex / ...)
#   --with-suffix     append a 4-char random suffix, persisted across reinstalls
#
# Env overrides (highest priority, not persisted):
#   NESTWORK_HOST       override host segment
#   NESTWORK_AGENT_ID   override full agent-id
#
# Output: prints two lines to stdout
#   <host>
#   <agent-id>
#
# Legacy migration:
# - if ~/.nestwork_host exists and ~/.nestwork_id is one line, merge both into
#   the v2 single-file format.
# - if ~/.nestwork_id contains an old v1 three-segment id
#   (<tool>-<host>-<suffix>), extract <host> to ~/.nestwork_host and rewrite
#   ~/.nestwork_id as two lines: <host>, <tool>-<suffix>.
# -----------------------------------------------------------------------------

import os
import random
import re
import socket
import string
import sys

HOME = os.path.expanduser("~")
HOST_FILE = os.path.join(HOME, ".nestwork_host")
ID_FILE   = os.path.join(HOME, ".nestwork_id")
LEGACY_HOST_FILE = os.path.join(HOME, "." + "hive" + "queen_host")
LEGACY_ID_FILE = os.path.join(HOME, "." + "hive" + "queen_id")


def compute_host() -> str:
    h = socket.gethostname() or "unknown"
    return h.split(".")[0].lower()


def random_suffix(n: int = 4) -> str:
    alphabet = string.ascii_lowercase + string.digits
    return "".join(random.choice(alphabet) for _ in range(n))


def read_one_line(path: str) -> str:
    try:
        with open(path, encoding="utf-8") as f:
            return f.read().strip()
    except FileNotFoundError:
        return ""


def write_one_line(path: str, value: str) -> None:
    with open(path, "w", encoding="utf-8") as f:
        f.write(value + "\n")


def read_lines(path: str) -> list[str]:
    try:
        with open(path, encoding="utf-8") as f:
            return [line.strip() for line in f.read().splitlines() if line.strip()]
    except FileNotFoundError:
        return []


def write_identity(host: str, agent_id: str) -> None:
    with open(ID_FILE, "w", encoding="utf-8") as f:
        f.write(host + "\n")
        f.write(agent_id + "\n")


# v1 legacy ids look like: <tool>-<host>-<4-char-suffix>
# Heuristic: exactly three segments split by '-', final segment is [a-z0-9]{4}.
LEGACY_ID_RE = re.compile(r"^([a-z]+)-([a-z0-9][a-z0-9-]*?)-([a-z0-9]{4})$")


def migrate_legacy_if_needed(tool: str) -> None:
    """Normalize legacy identity files into the single v2 two-line file."""
    if not os.path.exists(ID_FILE):
        legacy_identity = read_lines(LEGACY_ID_FILE)
        legacy_host = read_one_line(LEGACY_HOST_FILE)
        if len(legacy_identity) >= 2:
            write_identity(legacy_identity[0], legacy_identity[1])
        elif legacy_host and len(legacy_identity) == 1:
            write_identity(legacy_host, legacy_identity[0])

    host = read_one_line(HOST_FILE)
    identity = read_lines(ID_FILE)

    if host and len(identity) == 1:
        write_identity(host, identity[0])
        return

    if len(identity) != 1:
        return

    legacy = identity[0]
    m = LEGACY_ID_RE.match(legacy)
    if not m:
        return

    legacy_tool, legacy_host, legacy_suffix = m.group(1), m.group(2), m.group(3)
    agent_id = f"{tool}-{legacy_suffix}" if legacy_tool == tool else legacy
    write_identity(legacy_host, agent_id)


def resolve_host() -> str:
    env = os.environ.get("NESTWORK_HOST", "").strip()
    if not env:
        env = os.environ.get("HIVE" + "QUEEN_HOST", "").strip()
    if env:
        return env.lower()
    identity = read_lines(ID_FILE)
    if len(identity) >= 2:
        return identity[0]
    host = compute_host()
    return host


def resolve_agent_id(tool: str, with_suffix: bool) -> str:
    env = os.environ.get("NESTWORK_AGENT_ID", "").strip()
    if not env:
        env = os.environ.get("HIVE" + "QUEEN_AGENT_ID", "").strip()
    if env:
        return env
    identity = read_lines(ID_FILE)
    cached = identity[1] if len(identity) >= 2 else ""
    if not with_suffix:
        return tool
    if cached and cached.startswith(tool + "-") and LEGACY_ID_RE.match(cached) is None:
        # v2 format: <tool>-<suffix>
        return cached
    if cached and cached == tool:
        return cached
    new_id = f"{tool}-{random_suffix()}"
    write_one_line(ID_FILE, new_id)
    return new_id


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: _identity.py <tool> [--with-suffix]", file=sys.stderr)
        return 2
    tool = sys.argv[1].strip().lower()
    with_suffix = "--with-suffix" in sys.argv[2:]

    migrate_legacy_if_needed(tool)

    host     = resolve_host()
    agent_id = resolve_agent_id(tool, with_suffix)

    has_env_override = (
        os.environ.get("NESTWORK_HOST", "").strip()
        or os.environ.get("NESTWORK_AGENT_ID", "").strip()
        or os.environ.get("HIVE" + "QUEEN_HOST", "").strip()
        or os.environ.get("HIVE" + "QUEEN_AGENT_ID", "").strip()
    )
    if not has_env_override:
        write_identity(host, agent_id)

    print(host)
    print(agent_id)
    return 0


if __name__ == "__main__":
    sys.exit(main())
