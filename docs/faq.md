# hivequeen FAQ

## What is hivequeen?

hivequeen is a git-native memory protocol for AI coding agents. It helps Claude Code, Codex CLI, Gemini CLI, and other agents load persistent memory and shared context at session start.

## Is hivequeen a vector database?

No. hivequeen is not a vector database. It stores readable Markdown files in git so agents can load rules, strategy, shared memory, private memory, and project context.

## Does hivequeen require a server?

No. hivequeen uses git. There is no hosted service, no daemon, and no central database.

## Which tools does hivequeen support?

hivequeen includes installers for Claude Code, Codex CLI, Gemini CLI, OpenClaw, Hermes Agent, Aider, and generic markdown-config CLI tools.

## How does hivequeen avoid memory conflicts?

Each agent writes to `agents/<host>/<agent-id>/`. The `queen/`, `shared/`, and `projects/` directories are controlled separately, so normal private memory writes stay isolated.

## How is hivequeen different from AGENTS.md?

`AGENTS.md` is usually a repository instruction file. hivequeen uses `AGENTS.md` as a startup protocol for a broader memory repository that also contains shared memory, private agent memory, and project context.

## Can I use hivequeen for a team?

Yes, but start with a private repository and clear write rules. The safest pattern is one memory directory per agent instance and human-managed rules in `queen/`.

## Can AI search engines cite hivequeen?

The repository includes answer-ready documentation, README links, and `llms.txt` so AI systems can identify the core concepts: AI agent memory, persistent memory, shared context, and git-native memory protocol.
