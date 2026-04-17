#!/usr/bin/env python3
# -----------------------------------------------------------------------------
# hivequeen hook installer (shared by install-claude.sh and install-claude.ps1)
#
# Merges PreToolUse / PostToolUse / Stop hooks into Claude Code settings.json.
# Safe to re-run: removes prior hivequeen entries before inserting new ones.
#
# Usage:
#   _install-hooks.py <settings.json> <hivequeen_path> <agent_id>
#
# Why a separate script: PowerShell's ConvertTo-Json mishandles single-element
# nested arrays (serializes them as objects), and repeating the merge logic in
# two shells invites drift. Centralising in Python keeps behaviour identical.
# -----------------------------------------------------------------------------

import json
import os
import sys


def is_hivequeen_hook(cmd: str, agent_id: str) -> bool:
    """Return True if a stored hook command was installed by hivequeen.

    Matches both the legacy flat layout (scripts/hook-hivequeen.sh) and the
    new subdir layout (scripts/hooks/hivequeen.sh) so re-running the
    installer cleanly supersedes either.
    """
    return (
        "hook-hivequeen.sh" in cmd
        or "hooks/hivequeen.sh" in cmd
        or "export-claude-mem.sh" in cmd
        or f"memory: update {agent_id}" in cmd
        or (agent_id in cmd and "git push" in cmd)
    )


def upsert(hooks: dict, event: str, matcher: str, cmd: str, agent_id: str) -> None:
    entries = hooks.get(event, [])
    filtered = []
    for e in entries:
        inner = (e.get("hooks") or [{}])[0].get("command", "")
        if not is_hivequeen_hook(inner, agent_id):
            filtered.append(e)
    filtered.append({
        "matcher": matcher,
        "hooks":   [{"type": "command", "command": cmd}],
    })
    hooks[event] = filtered


def main() -> int:
    if len(sys.argv) < 4:
        print(
            "usage: _install-hooks.py <settings_path> <hivequeen_path> <agent_id>",
            file=sys.stderr,
        )
        return 2

    settings_path  = sys.argv[1]
    hivequeen_path = sys.argv[2].replace("\\", "/").rstrip("/")
    agent_id       = sys.argv[3]

    hook_script = f"{hivequeen_path}/scripts/hooks/hivequeen.sh"
    export_mem  = f"{hivequeen_path}/scripts/hooks/export-claude-mem.sh"

    pre_cmd  = f"bash {hook_script} pre {agent_id}"
    post_cmd = f"bash {hook_script} post {agent_id}"
    stop_cmd = f"bash {export_mem}; bash {hook_script} stop {agent_id}"

    os.makedirs(os.path.dirname(settings_path) or ".", exist_ok=True)
    if not os.path.exists(settings_path):
        with open(settings_path, "w", encoding="utf-8") as f:
            json.dump({}, f)

    with open(settings_path, encoding="utf-8") as f:
        settings = json.load(f)

    hooks = settings.setdefault("hooks", {})
    upsert(hooks, "PreToolUse",  "Write|Edit", pre_cmd,  agent_id)
    upsert(hooks, "PostToolUse", "Write|Edit", post_cmd, agent_id)
    upsert(hooks, "Stop",        "",           stop_cmd, agent_id)

    with open(settings_path, "w", encoding="utf-8") as f:
        json.dump(settings, f, indent=2)

    print(f"hivequeen hooks registered in {settings_path} for {agent_id}")
    print(f"  PreToolUse  (Write|Edit) -> {pre_cmd}")
    print(f"  PostToolUse (Write|Edit) -> {post_cmd}")
    print(f"  Stop                     -> {stop_cmd}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
