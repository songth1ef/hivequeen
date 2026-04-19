# Claude Code memory

## Short answer

hivequeen gives Claude Code persistent memory by injecting a startup protocol into `~/.claude/CLAUDE.md` and registering hooks that sync Claude's own memory directory with git.

## How it works with Claude Code

The Claude Code installer:

1. Creates `agents/<host>/<agent-id>/memory.md`.
2. Injects the hivequeen startup protocol into `~/.claude/CLAUDE.md`.
3. Registers Claude Code hooks for memory writes.
4. Pulls latest memory before writes and commits memory after writes.

Install on macOS or Linux:

```bash
bash ~/hivequeen/scripts/install/claude.sh
```

Install on Windows:

```powershell
.\hivequeen\scripts\install\claude.ps1
```

## Why Claude Code users need this

Claude Code can read instruction files, but project rules and long-term context can drift across machines and projects. hivequeen gives Claude Code a shared context layer backed by git history.

## What gets loaded at session start?

Claude Code loads:

- `queen/agent-rules.md`
- `queen/strategy.md`
- `shared/memory.md`
- `agents/<host>/<agent-id>/memory.md`
- relevant `projects/*.md`

## Related docs

- [AI agent memory](ai-agent-memory.md)
- [Git-native memory protocol](git-native-memory-protocol.md)
- [hivequeen vs claude-mem](comparisons/claude-mem.md)
