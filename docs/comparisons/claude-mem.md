# nestwork vs claude-mem

## Short answer

nestwork is a git-native memory protocol for multiple AI coding agents. claude-mem is a Claude-focused memory tool. Use nestwork when you want shared context across Claude Code, Codex CLI, Gemini CLI, and other agents without running a memory server.

## Comparison

| Question | nestwork | claude-mem |
|---|---|---|
| Primary model | Git repository protocol | Claude-oriented memory integration |
| Storage | Markdown files in git | Tool-specific memory store |
| Multi-agent support | Designed for multiple agent tools | Primarily Claude-focused |
| Cross-machine sync | Git pull, commit, push | Depends on tool setup |
| Server required | No | Depends on deployment mode |
| Human-readable memory | Yes | Depends on memory format |

## When nestwork is a better fit

Use nestwork if:

- You want one memory protocol for multiple AI coding agents.
- You want memory changes in git history.
- You want private memory directories per machine and agent.
- You prefer Markdown files over a service dependency.
- You want startup context through `AGENTS.md`, `CLAUDE.md`, or similar instruction files.

## When claude-mem may be a better fit

Use claude-mem if:

- You only use Claude.
- You want a Claude-specific memory workflow.
- You prefer a dedicated memory tool over a git protocol.

## Related docs

- [AI agent memory](../ai-agent-memory.md)
- [Claude Code memory](../claude-code-memory.md)
- [Git-native memory protocol](../git-native-memory-protocol.md)
