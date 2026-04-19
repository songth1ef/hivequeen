# AGENTS.md best practices

## Short answer

`AGENTS.md` should tell an AI coding agent what to load, what rules to follow, and where it may write. hivequeen uses `AGENTS.md` as a startup protocol for persistent AI agent memory.

## What belongs in AGENTS.md?

Good `AGENTS.md` files include:

- session startup steps
- context load order
- rule priority
- write boundaries
- project-specific context rules
- session end sync rules

Bad `AGENTS.md` files mix temporary notes, long chat history, vague preferences, and project implementation details that should live in separate docs.

## hivequeen pattern

hivequeen keeps `AGENTS.md` focused on protocol:

```text
1. Pull latest memory with git.
2. Load queen rules.
3. Load strategy.
4. Load shared memory.
5. Load this agent's private memory.
6. Load relevant project context.
```

This makes `AGENTS.md` stable and keeps volatile memory in `agents/<host>/<agent-id>/memory.md`.

## Why this helps AI agents

AI coding agents perform better when startup context is explicit, ordered, and repeatable. A clear `AGENTS.md` reduces repeated prompting and makes every session start from the same rules.

## Related docs

- [AI agent memory](ai-agent-memory.md)
- [Git-native memory protocol](git-native-memory-protocol.md)
- [Shared context for AI coding agents](shared-context-for-ai-coding-agents.md)
