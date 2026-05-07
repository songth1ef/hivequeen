# nestwork

[中文](README.zh.md) | English

Version: v0.3.0 | Protocol: 2.2

---

**Template it, clone it anywhere — your agents share one brain.**
A git-native memory protocol for AI agents, like the Formic hive mind in *Ender's Game* — every worker wired to the same queen, no individual memory, no conflicting selves, one distributed intelligence.

No plugins, no servers, no third-party dependencies. Just a git repo.

---

## Table of contents

- [What problem does it solve?](#what-problem-does-it-solve)
- [Core design principles](#core-design-principles)
- [How it works](#how-it-works)
- [Comparison with other approaches](#comparison-with-other-approaches)
- [Quickstart](#quickstart)
- [Customize your nest](#customize-your-nest)
- [v2.2 new: workflow/ and nestwork.config.json](#v22-new-workflow-and-nestworkconfigjson)
- [Real workflow examples](#real-workflow-examples)
- [Compile shared memory (distillation)](#compile-shared-memory-distillation)
- [Directory structure](#directory-structure)
- [File size limits and split protocol](#file-size-limits-and-split-protocol)
- [Why memory writes stay isolated](#why-memory-writes-stay-isolated)
- [Supported tools](#supported-tools)
- [Staying up to date](#staying-up-to-date)
- [FAQ](#faq)
- [Troubleshooting](#troubleshooting)
- [Inspired by](#inspired-by)

---

## What problem does it solve?

AI coding agents (Claude Code, Codex CLI, Gemini CLI, etc.) lose memory and context in these situations:

- Closing a session means starting from scratch next time
- Switching to a different machine resets all accumulated context
- Switching tools (Claude → Codex) loses preferences and habits
- Multiple agents collaborating cannot share understanding of project and user
- Team scenarios cannot persist project knowledge for later agents

Common solutions each have limitations:

| Approach | Limitation |
|---|---|
| Long system prompt in agent config file | Doesn't sync across devices, doesn't reuse across tools, painful to maintain |
| MCP memory server | Requires running a service, single point of failure, deploy per machine |
| Vendor-private memory (e.g. OpenAI Memory) | Vendor lock-in, closed, no cross-vendor migration |
| Hosted memory like claude-mem | Depends on third-party worker, possibly paid, privacy-sensitive |
| Self-hosted database + API | Heavy infrastructure, decoupled from agent, high maintenance cost |
| README/AGENT.md per project | No cross-project sharing, no place for user preferences |

**nestwork's answer: use a git repo as the agent's brain.** Each agent writes its memory to specific directories in a git repo; on next startup, `git pull` retrieves it across sessions, machines, and tools.

It's not a tool — it's a **protocol**. Any agent that can read a markdown file as system prompt can plug in.

---

## Core design principles

1. **Git is the only infrastructure**
   No servers, no databases, no third-party services. Git already solves "distributed storage + version control + conflict resolution"; reinventing it is a mistake.

2. **Read-write isolation = structurally conflict-free**
   Each agent owns its own directory (`agents/<host>/<agent-id>/`). Normal memory writes never collide with other agents. Combined with the "atomic per-write" hook architecture, even the race window inside a single Write/Edit is eliminated.

3. **Layered memory + strict priority chain**
   Different content types go in different layers. Conflicts resolve by priority — never merge. This avoids "everything mashed together, agent doesn't know what to follow".

4. **Template + private instance**
   `nestwork` (public template) evolves the protocol; each user creates a private instance via "Use this template". Private data never leaks; protocol updates are pulled selectively.

5. **Tool-neutral**
   AGENTS.md is the bootstrap source of truth; CLAUDE.md / SOUL.md / GEMINI.md are mirrors or links. Switching tools doesn't switch memory.

6. **The protocol itself evolves**
   `protocol-version` header `MAJOR.MINOR`. Private nests can pin a trusted version. MAJOR bumps require downstream action; MINOR is additive-compatible.

---

## How it works

### Repository structure (v2.2 protocol)

```
nestwork repo (your private queen)
├── queen/          ← read-only rules & strategy (you maintain)
│   ├── agent-rules.md       # behavior boundaries, highest priority
│   └── strategy.md          # current decision direction
├── agents/         ← each agent writes ONLY to its own directory
│   └── <host>/<agent-id>/   # one host per machine, one agent-id per tool
│       └── memory.md        # this agent's private memory
├── shared/         ← compiled cross-agent consensus (read-only)
│   └── memory.md
├── projects/       ← per-project context files
│   └── <project>.md
└── workflow/       ← v2.2+: portable cross-project workflow knowledge
    ├── README.md
    └── <topic>.md
```

Every machine that clones your queen gets the same brain. Each agent instance writes only to `agents/<host>/<agent-id>/`, so normal memory writes stay isolated.

### Priority chain

```
queen/agent-rules.md > queen/strategy.md > shared/memory.md > agents/*/*/memory.md > projects/*.md > workflow/*.md
```

Conflicts resolve by priority — **never merge**.

### Session lifecycle

```
Session start
  ↓
git pull --rebase                          (SessionStart hook auto)
  ↓
Load context by priority chain             (injected into agent system prompt)
  ↓
Agent self-orients (reads git log + strategy.md, gives state summary + next action)
  ↓
─── working ─────────────────────────────
  ↓
Write/Edit triggers PreToolUse hook
  ↓
git pull --rebase (prevent overwriting remote)
  ↓
Execute write
  ↓
PostToolUse hook: git add/commit/push
  ↓
(push fails → retry 3x, each with fresh pull)
─────────────────────────────────────────
  ↓
Session end
  ↓
Stop hook: safety-net commit+push (no-op when clean)
  ↓
SessionEnd hook: claude-mem export + local history sync (if enabled)
```

The race window collapses from "entire session" to "single write". Multi-agent collisions on the same machine virtually never happen.

---

## Comparison with other approaches

| Dimension | nestwork | MCP memory server | claude-mem | Vendor-private memory | Self-hosted DB |
|---|---|---|---|---|---|
| Infrastructure | git repo | local service | remote worker | vendor cloud | self-hosted |
| Cross-device | ✅ git pull | ❌ deploy per device | ✅ but needs worker | ✅ vendor account | depends |
| Cross-tool | ✅ any markdown-config agent | partial (needs MCP client) | Claude only | ❌ vendor lock-in | depends |
| Cross-account migration | ✅ change remote | ✅ | partial | ❌ | ✅ |
| Multi-agent collaboration | ✅ protocol-level | needs coordination | single-agent | single-vendor | depends |
| Offline | ✅ | depends | ❌ | ❌ | depends |
| Data ownership | 100% your git repo | 100% local | third-party worker | vendor | yours |
| Maintenance cost | low (you know git) | medium (need MCP) | medium (worker dep) | zero (but locked) | high |
| Privacy | private repo is enough | depends on deploy | third-party risk | depends on TOS | depends |

See [docs/comparisons/claude-mem.md](docs/comparisons/claude-mem.md).

---

## Quickstart

### 1. Create your private queen

Click **Use this template → Create a new repository** on GitHub. Set visibility to **Private** — your memory stays yours.

> **Why not Fork?**
> Forks are public by default and tied to the upstream repo. A private repo created from this template is fully yours.
> When nestwork ships updates, `git merge upstream/main` would conflict with your `queen/strategy.md`, `agents/`, `shared/` — files you intentionally diverged. The `update.sh` script syncs only the protocol layer, leaving your private data untouched.

### 2. Clone to each machine

```bash
git clone git@github.com:<you>/nestwork.git ~/nestwork
```

### 3. Install for your agent tool

**Claude Code (macOS / Linux)**
```bash
bash ~/nestwork/scripts/install/claude.sh
```

**Claude Code (Windows)**
```powershell
.\nestwork\scripts\install\claude.ps1
```

**Codex (macOS / Linux)**
```bash
bash ~/nestwork/scripts/install/codex.sh
```

**Codex (Windows)**
```powershell
.\nestwork\scripts\install\codex.ps1
```

**Gemini CLI / OpenClaw / Hermes / Aider** — same pattern, swap `claude` for the tool name. Full list in [Supported tools](#supported-tools).

Repeat on every machine. Same queen, different agent IDs, one shared brain.

### Prompt examples

Skip manual setup — paste one of these into a Claude Code session:

- **From scratch**
  > Read the README at https://github.com/songth1ef/nestwork and follow Quickstart: create a private queen repo from the template, clone it on this machine, and install Claude Code.

- **Discover configurable features**
  > Read the README at https://github.com/songth1ef/nestwork and list every configurable feature nestwork exposes (hooks, optional syncs, filters, …). Then recommend which ones to enable for my current machine.

---

## Customize your nest

### Your rules
Edit `queen/agent-rules.md` — behavior boundaries that apply to all agents (e.g. "respond in English", "lead with the conclusion"). Highest priority, cannot be overridden by any later context.

### Your strategy
Edit `queen/strategy.md` — current goals and decision direction. e.g. "prioritize small verifiable tools over platforms", "do not design complex systems before validating need".

### Your projects
Add `projects/<project-name>.md` — context loaded when working on that project. Naming, module boundaries, tech-stack rationale, lessons learned.

### Your workflow (v2.2+ new)
Add `workflow/<topic>.md` — portable workflow knowledge that survives across employers, projects, and machines. See next section.

---

## v2.2 new: workflow/ and nestwork.config.json

### Why `workflow/`?

Before v2.2, nestwork had 4 context layers: `queen/` `shared/` `agents/` `projects/`. One was missing:

**Portable user-level knowledge that survives across employers.**

Examples:
- Estimate by AI execution speed, not human-month
- Loading-state UI: skeleton screens for first paint, `v-loading` for refresh
- New repo init: build the 5-document skeleton (AGENT.md + conventions.md + domain.md + architecture.md + lessons.md)
- Migration checklist to restore full workflow on a new machine in 30 minutes

These aren't user facts (→ `shared/`), aren't project-specific (→ `projects/`), aren't behavior rules (→ `queen/`), but they **deserve to persist across employers, projects, and devices**. `workflow/` is for this layer.

### What goes in `workflow/`

| Belongs | Doesn't belong |
|---|---|
| Cross-project coding disciplines, estimation rules | Project-specific business rules → `projects/` |
| Tooling stack preferences, setup conventions | Cross-agent stable user facts → `shared/` |
| Skill assets, prompt templates | Single-agent transient observations → `agents/` |
| Migration / cross-machine deployment guides | One-off task notes |
| Methodologies useful across repos | Employer-confidential information (never in this repo) |

The deciding question: **"Will this still apply when I change employers?"** — Yes → `workflow/`; No → somewhere else.

### `nestwork.config.json` — external directory ingestion contract

Some working directory of yours (e.g. `~/work/some-employer-project/`) has content worth absorbing into nestwork's `projects/` or `workflow/`, but contains employer secrets, client names, internal codenames — can't copy directly.

`nestwork.config.json` is a metadata file placed in **the source working directory** (NOT inside nestwork) declaring:

- Which category this directory may be ingested into
- Required desensitization level
- Which terms must be redacted (employer names, client names, internal codenames)

**Minimal example** (in your working directory root):

```json
{
  "$schema": "https://github.com/songth1ef/nestwork/schemas/nestwork.config.schema.json",
  "version": "1.0",
  "ingest": {
    "target": "projects",
    "name": "some-project"
  },
  "desensitize": {
    "level": "strong",
    "custom_rules": [
      "<your-employer-name>",
      "<internal-codename>",
      "<client-name>"
    ]
  }
}
```

**Field semantics**:

| Field | Meaning |
|---|---|
| `ingest.target` | Where ingested content goes: `projects` / `workflow` / `null` (not ingestable) |
| `ingest.name` | Destination filename |
| `desensitize.level` | `none` (no transform) / `weak` (pattern replace from custom_rules) / `strong` (AI semantic desensitization + custom_rules) |
| `desensitize.custom_rules` | User-defined sensitive terms, layered on top of the global methodology |

**Key constraints**:
- Config files **only live in source directories**, never enter the nestwork repo
- Default `desensitize.level: "strong"`
- Agent detects ingestion candidate but **no config exists** → must stop and prompt user to create one; never silently ingest
- Ingestion direction is **one-way**: source → private nest (never private nest → upstream)

Full rules: [docs/workflow-protocol.md](docs/workflow-protocol.md) and `AGENTS.md` Sections 8, 9.

### Desensitization methodology

Upstream nestwork provides only methodology and prompt template ([docs/desensitization-prompt.md](docs/desensitization-prompt.md)) — **no specific employer/client/codename names**. Specific terms live in each user's `nestwork.config.json` `custom_rules`.

`strong` level invokes AI (Claude Haiku recommended — cheap and fast), following the prompt template:

1. Replace all `custom_rules` matches with placeholders (`<EMPLOYER>`, `<CLIENT-A>`, etc.)
2. Identify content that "leaks confidential info without naming directly" (internal API structure, unreleased features) and rewrite
3. Preserve portable methodology
4. Output structured JSON (desensitized content + redaction log + flagged passages for human review)
5. **Must be human-reviewed** before writing into nestwork

---

## Real workflow examples

### Scenario: multi-machine collaboration

You use Claude Code on both a macOS laptop and a Windows desktop. Both machines clone your private queen.

**Monday morning (laptop)**:
- Start Claude Code → SessionStart hook auto-pulls and injects context
- You say "continue last night's NestJS module work"
- Claude reads `agents/macbook/claude-xxx/memory.md` — sees last night's progress
- Also loads `shared/memory.md` — knows your tech-stack preferences (Vue 3 + NestJS)
- Picks up directly without re-explanation

**Same evening (desktop)**:
- Start Claude Code → auto-pull
- Agent sees the morning updates from `agents/macbook/claude-xxx/` (different host, but synced via git)
- You switch to a different task; this agent writes to its own `agents/desktop/claude-yyy/`

**Two agents never write each other's directory, but share all context via git.**

### Scenario: cross-tool migration

One day you want to try Codex CLI.

```bash
bash ~/nestwork/scripts/install/codex.sh
```

Codex reads `~/.codex/AGENTS.md` at startup, where the installer injected the nestwork bootstrap. It will:

- Pull your queen
- Read `queen/`, `shared/`, its own `agents/<host>/codex/memory.md`
- Know your preferences, past decisions, current project state

**Memory isn't in Anthropic's cloud or OpenAI's cloud — memory is in your git repo. Switching tools costs near zero.**

### Scenario: ingest employer project knowledge into your nest (v2.2+)

You're working in some employer project and find an architectural pattern worth recording (e.g., a NestJS module organization convention).

1. Create `nestwork.config.json` in the project root (see example above), with `custom_rules` listing employer names, internal codenames
2. Tell Claude Code:
   > Ingest the XX pattern from this project into mynestwork's `projects/<name>.md`, following nestwork.config.json desensitization
3. Agent reads config, invokes desensitization prompt, generates draft
4. You review, then it writes

Employer name never appears in the nest repo; methodology is preserved. When you change employers, that methodology is still with you.

---

## Compile shared memory (distillation)

After agents have accumulated memory, merge it into `shared/memory.md` using one of two strategies:

```bash
# Mechanical: concatenate every agents/*/*/memory.md, commit, push.
bash ~/nestwork/scripts/maintenance/compile.sh

# LLM-oriented, provider-agnostic: print a distillation prompt and feed
# it to any agent session manually.
python3 ~/nestwork/scripts/maintenance/distill.py

# Manual end-to-end with Codex: distill all agent memories, write
# shared/memory.md, commit, push. Replace <your-profile> with your
# Codex profile, or omit --profile if defaults are correct.
python3 ~/nestwork/scripts/maintenance/distill.py --run-codex --profile <your-profile>

# Preview the candidate shared/memory.md without writing it.
python3 ~/nestwork/scripts/maintenance/distill.py --run-codex --profile <your-profile> --dry-run
```

All variants leave the input agent memories untouched. `--run-codex` updates only `shared/memory.md` with commit message `memory: distill shared`. All agents pick up the new shared/memory.md on their next `git pull`.

### Distillation design tradeoffs

- **Shared is a union, not intersection** — never drops any agent's unique observations
- **Non-destructive** — each agent's private memory is preserved unchanged
- **Sub-agent review required** — checks for sensitive data, factual errors, contradictions, stale entries
- **Human confirmation required** — sub-agent only reports; human decides merge
- **Never delete** — only merge and add, no history removal

---

## Directory structure

```
nestwork/
├── AGENTS.md                   bootstrap source of truth (Codex, OpenClaw, Gemini, ...)
├── CLAUDE.md                   verbatim mirror of AGENTS.md (Claude Code loads this name)
├── SOUL.md                     short persona file (Hermes entry point)
├── queen/
│   ├── agent-rules.md          behavior rules — read-only for agents
│   └── strategy.md             decision direction — read-only for agents
├── agents/
│   └── <host>/<agent-id>/
│       └── memory.md           this agent's private memory
├── shared/
│   └── memory.md               compiled cross-agent memory
├── projects/
│   └── <project>.md            per-project context
├── workflow/                   v2.2+: portable cross-project workflow knowledge
│   ├── README.md
│   └── <topic>.md
├── docs/                       protocol methodology and external docs
│   ├── workflow-protocol.md       v2.2 workflow details
│   ├── desensitization-prompt.md  AI desensitization prompt template
│   ├── ai-agent-memory.md
│   ├── claude-code-memory.md
│   ├── codex-persistent-memory.md
│   ├── git-native-memory-protocol.md
│   ├── agents-md-best-practices.md
│   └── faq.md
├── schemas/
│   └── nestwork.config.schema.json   v2.2 config JSON Schema
└── scripts/
    ├── install/                   per-tool installers
    │   ├── claude.{sh,ps1}
    │   ├── codex.{sh,ps1}
    │   ├── gemini.{sh,ps1}
    │   ├── hermes.{sh,ps1}
    │   ├── openclaw.{sh,ps1}
    │   ├── aider.{sh,ps1}
    │   ├── generic.{sh,ps1}       any markdown-config CLI
    │   ├── _bootstrap.py          shared bootstrap injector
    │   └── _hooks.py              shared hook registrar (Claude Code)
    ├── hooks/                     runtime hooks
    │   ├── nestwork.sh            pre/post/stop entry
    │   ├── _match-file.py         stdin-based file matcher
    │   ├── export-claude-mem.sh   optional claude-mem bridge
    │   ├── sync-local-history.sh  optional local-history capture (wrapper)
    │   └── sync-local-history.py  optional local-history capture (worker)
    └── maintenance/               ops
        ├── compile.sh             aggregate agents/*/* into shared/ (mechanical)
        ├── distill.py             print prompt or run manual Codex distillation
        ├── sync-claude-md.sh      regenerate CLAUDE.md from AGENTS.md
        └── update.sh              pull upstream protocol layer
```

---

## File size limits and split protocol

### Universal rule (v2.2+)

**Any markdown file** in any Nestwork repository, when oversized, splits the same way: the original filename becomes a folder, the original file becomes an index (or `<folder>/index.md`), content splits by topic.

Example: `plan-all.md` (1200 lines) → `plan-all.md` (index) + `plan/plan-a.md` / `plan/plan-b.md` / `plan/plan-c.md`.

Files not listed in the table below use defaults: **soft limit 500 lines** (start considering a split), **hard limit 1000 lines** (must split before next write).

### Specific limits

| File | Max lines |
|---|---|
| `queen/agent-rules.md` | 80 |
| `queen/strategy.md` | 80 |
| `agents/<host>/<agent-id>/memory.md` | 200 |
| `shared/memory.md` | 500 |
| `projects/<name>.md` | 150 |
| `workflow/<topic>.md` | 200 |

**Example — split `agents/macbook/claude/memory.md` when it hits 150 lines:**

```
agents/macbook/claude/
├── memory.md          ← becomes an index
├── user_profile.md
├── feedback_collab.md
└── project_nestwork.md
```

`memory.md` after split:
```markdown
# MEMORY — claude-macbook

- [User Profile](user_profile.md) — role, stack, preferences
- [Collaboration](feedback_collab.md) — working style, corrections
- [Project: nestwork](project_nestwork.md) — goals, decisions
```

Agents read the index first, follow links only when relevant.

### Why have line limits?

LLM context windows are large but **attention degrades with token count**. Stuffing a 5000-line memory.md achieves low utilization. Splitting it into 5 topic files of 200-400 lines each + an index lets the agent read on-demand — better effective utilization.

---

## Why memory writes stay isolated

Each agent owns exactly one directory under `agents/`. No two agents write the same file. Normal git conflicts are structurally impossible.

| Path | Who writes | Conflict possible? |
|---|---|---|
| `queen/` | You (human) | No (one pair of hands) |
| `agents/<host>/<agent-id>/` | That agent only | No for normal memory writes |
| `shared/` | Explicit `compile.sh` / `distill.py --run-codex` only | Not during normal agent writes |
| `projects/` | agent or human | Theoretically possible if two agents write the same project file simultaneously, but PreToolUse hook's `git pull --rebase` largely mitigates |
| `workflow/` | agent or human | Same as above |

### Hook architecture (atomic per-write, introduced 2026-04-17)

Race window collapses from "entire session" to "single Write execution":

| Hook event | Action | Purpose |
|---|---|---|
| **SessionStart** | pull + inject agent-rules/strategy/shared/agent memory into additionalContext | replaces manual startup protocol |
| **PreToolUse** (Write\|Edit, scoped to `agents/<id>/`) | `git pull --rebase`; conflict → `exit 2` blocks write | prevents overwriting remote |
| **PostToolUse** (same scope) | `git add/commit/push`; push retry 3x with fresh pull each time | immediate sync |
| **Stop** | safety-net commit+push (no-op when clean) | fallback |
| **SessionEnd** | claude-mem export + local history sync | cross-machine reach |

---

## Supported tools

### Native installers (known config path)

| Tool | Vendor | Entry file | Install | Adaptation status |
|---|---|---|---|---|
| Claude Code | Anthropic | `~/.claude/CLAUDE.md` + hooks | `bash scripts/install/claude.sh` | Adapted, personally used |
| Codex CLI | OpenAI | `~/.codex/AGENTS.md` + compatibility | `bash scripts/install/codex.sh` | Adapted, personally used |
| Gemini CLI | Google | `~/.gemini/GEMINI.md` | `bash scripts/install/gemini.sh` | Installer exists, not personally verified |
| OpenClaw | open source | `~/.openclaw/workspace/AGENTS.md` | `bash scripts/install/openclaw.sh` | Installer exists, not personally verified |
| Hermes Agent | open source | `~/.hermes/SOUL.md` | `bash scripts/install/hermes.sh` | Installer exists, not personally verified |
| Aider | open source | `~/.aider-nestwork.md` (wired via `.aider.conf.yml` `read:`) | `bash scripts/install/aider.sh` | Installer exists, not personally verified |

Only Claude Code registers session hooks for atomic per-write memory sync. Other tools follow the session-end commit protocol written into their bootstrap config.

### Optional: capture local tool history

Claude Code keeps prompt history and plan artefacts under `~/.claude/`. Codex CLI keeps prompt history under `~/.codex/`. Mirror them into `agents/<host>/<id>/local/` so they travel with your queen across machines.

Opt-in per host — no env var, no re-install needed. Create `agents/<host>/settings.json` inside your queen (the host dir matching this machine):

```json
{ "sync_local_history": true }
```

Default is `false`. The setting is versioned with your queen, so each machine's host dir tracks its own toggle.

When enabled, Claude Code and Codex session hooks sync:

| Source | Target | Notes |
|---|---|---|
| `~/.claude/history.jsonl` | `local/history.jsonl` | redacted: `pastedContents` dropped, `$HOME` paths normalized, `sk-*`/`ghp_*`/`Bearer …` → `<REDACTED>` |
| `~/.claude/plans/` | `local/plans/` | plan-mode artefacts, mirrored |
| `~/.codex/history.jsonl` | `local/history.jsonl` | Codex agents only, same redaction pass |

`todos/` and `tasks/` are excluded — >99% are empty UUID-per-session bookkeeping.

### Via `install/generic.sh` (you confirm the config path)

Any CLI that loads a single markdown file at startup as system prompt can be bootstrapped in one line:

```bash
bash scripts/install/generic.sh <prefix> <config-path>
```

| Tool | Vendor | Suggested prefix |
|---|---|---|
| Qwen Code | Alibaba 通义 | `qwen` |
| OpenCode | open source | `opencode` |
| CodeBuddy Code | Tencent | `codebuddy` |
| iFlow CLI | Alibaba 心流 | `iflow` |
| Trae CLI / Solo | ByteDance | `trae` |
| Qoder | Alibaba | `qoder` |
| Kimi Code CLI | Moonshot | `kimi` |
| 通义灵码 CLI | Alibaba Cloud | `lingma` |

> **Tip**: Qwen Code is a Gemini CLI fork and may honour `~/.gemini/GEMINI.md` directly — try `install/gemini.sh` first.

### Workspace-level (IDE plugins, symlink)

| Tool | Target | Install |
|---|---|---|
| Cursor | `.cursor/rules/nestwork.md` | `ln -s AGENTS.md .cursor/rules/nestwork.md` |
| Windsurf | `.windsurf/rules/nestwork.md` | `ln -s AGENTS.md .windsurf/rules/nestwork.md` |
| Cline (VS Code) | `.clinerules/nestwork.md` | `ln -s AGENTS.md .clinerules/nestwork.md` |
| GitHub Copilot (repo) | `.github/copilot-instructions.md` | `ln -s AGENTS.md .github/copilot-instructions.md` |

### Not supported (and why)

| Tool | Reason |
|---|---|
| GitHub Copilot CLI (`gh copilot`) | Q&A style, no persistent instruction-file mechanism |
| Antigravity | IDE-first; CLI entrypoint is project-scoped, external bootstrap mechanism undocumented |
| CloudBase AI CLI | Gateway invoking downstream CLIs — install nestwork on the downstream tools instead |
| ChatDev | Simulated "software company" workflow, not a persistent single-agent loop |

---

## Staying up to date

Two paths — both keep your private data (`agents/`, `queen/`, `shared/`, `projects/`, `workflow/<topic>.md`) untouched.

### Manual (default recommended)

Open **Actions → Sync Nestwork upstream → Run workflow** whenever you want to pull the latest protocol-layer updates.

Most repos don't need template updates daily; manual review keeps protocol changes intentional.

### Automatic (optional)

The `.github/workflows/sync-upstream.yml` in your queen can run every Monday at 03:00 UTC, compare the protocol layer against upstream, and open a PR to your `main`. You review the diff and merge.

Scheduled sync is **off by default**. To enable:

1. Open **Settings → Secrets and variables → Actions → Variables**
2. Add a repository variable named `NESTWORK_AUTO_SYNC`
3. Set its value to `true`

PR create/update/reopen now uses the GitHub REST API instead of `gh pr ...` since some repos reject GraphQL PR mutations from Actions. If the default token is blocked, add an Actions secret named `NESTWORK_SYNC_TOKEN`; the workflow will prefer it automatically.

GitHub blocks `GITHUB_TOKEN` from pushing workflow-file changes, so `.github/workflows/` is **not** touched by the CI path — use the manual path below for workflow updates.

### Manual protocol refresh

```bash
bash ~/my-nest/scripts/maintenance/update.sh
```

Covers `scripts/`, `.github/workflows/`, `AGENTS.md`, `CLAUDE.md`, `SOUL.md`, both READMEs, `docs/`, `schemas/`, and `workflow/README.md` + `workflow/_template.md` (does NOT touch private content under `workflow/`).

---

## FAQ

### Why template instead of fork?

Forks are public by default and tightly coupled to upstream. Every upstream update creates merge conflicts with your private `queen/`, `agents/`, `shared/`. Template-created private repos have no shared git history and use `git checkout upstream/main -- <files>` for selective protocol-layer sync — private data is unaffected.

### Will my employer code be ingested into the nest?

No. Unless you explicitly create `nestwork.config.json` in the employer project root and tell the agent to ingest. Even then, `desensitize.level: "strong"` invokes AI desensitization that replaces employer/client/codename with placeholders, and **requires human review** before writing.

### Can tools other than Claude Code use nestwork?

Yes. Any CLI that loads markdown as system prompt at startup can be bootstrapped via `install/generic.sh`. But only Claude Code has hooks for atomic per-write sync. Other tools rely on "session-end commit" protocol — slightly larger race window, but rarely problematic in practice.

### Will multiple machines editing the same `projects/<name>.md` conflict?

Theoretically possible, practically rare. PreToolUse hook does `git pull --rebase` before each write, collapsing the race window to a single write. Two machines writing the same file **in the same second** is the only collision case. If it happens, the hook does `exit 2` and prompts manual merge.

### Where does `shared/memory.md` come from?

Not automatic. You must explicitly trigger distillation:

- `compile.sh` — concatenate all agent memories
- `distill.py` — LLM-driven distillation (recommended)

Distillation invokes a sub-agent for review, flagging sensitive data, factual contradictions, stale entries; you confirm the merge. Designed to be **non-destructive**: each agent's private memory is preserved.

### Can I store API keys in nestwork?

**No**. Even private repos are not recommended. GitHub vulnerabilities, account compromise, mistaken collaborator permissions all leak. Use environment variables or a dedicated secret store for API keys.

### How often does the protocol break?

Rarely. `protocol-version` uses `MAJOR.MINOR`: MAJOR changes require downstream action and **should be avoided**; MINOR is additive-compatible. v1 → v2.0 → v2.1 → v2.2 are all additive.

### How do you handle Chinese / English mixed usage?

- `queen/agent-rules.md` can specify "default to Chinese" as a behavior rule
- Agent memory and shared memory can mix; agent handles naturally
- Protocol-level field names, directory structure, and filenames are English (immutable)
- Naming convention: technical terms in English, behavior rules and domain knowledge in your preferred language

### What if I don't like git?

Then nestwork isn't for you. Git is the core, not optional. If you're not comfortable with git, this protocol is the wrong tool.

---

## Troubleshooting

### `bash scripts/install/claude.sh` fails

- **macOS / Linux**: check that `~/.claude/` exists and is writable
- **Windows Git Bash**: `hostname -s` is unsupported; the installer falls back to `hostname | cut -d. -f1`. If still failing, manually set `NESTWORK_HOST=desktop-xxx`

### Hook installed, but commits don't auto-push

Check in order:

1. `git -C $NESTWORK_PATH remote -v` — is remote correct?
2. `cat ~/.claude/settings.json` — is the hook registered?
3. `cat scripts/hooks/nestwork.sh` — is push being called?
4. Manual `git push` — does it require interactive credentials? (Hook runs non-interactive)

### Push fails after 3 retries

Usually expired GitHub credentials. Fix:

```bash
git -C $NESTWORK_PATH push  # see actual error
# Credential issue: use gh auth login, or reset SSH key
```

### `agents/<host>/<agent-id>/memory.md` has conflicts

PreToolUse hook should prevent this. If it happens, the hook didn't fire or you edited manually. Resolve:

```bash
git -C $NESTWORK_PATH status         # see conflict files
# Edit files to resolve conflict
git -C $NESTWORK_PATH add agents/<host>/<agent-id>/
git -C $NESTWORK_PATH rebase --continue
```

Per protocol Section 5, `agents/<host>/<agent-id>/` conflicts should take local (the agent owns its directory).

### Claude Code starts but doesn't auto-pull / inject context

Check SessionStart hook is registered:

```bash
cat ~/.claude/settings.json | grep -A 5 SessionStart
```

If missing, re-run installer: `bash scripts/install/claude.sh`.

### Agent IDs differ across machines

Check `~/.nestwork_id`:

```bash
cat ~/.nestwork_id
```

Each machine's `~/.nestwork_id` should differ (`<tool>-<4-char-random>`). If they match, you copied dotfiles — delete this file on the new machine to let the installer regenerate.

### I want to try without committing private info to GitHub

Run fully local:

```bash
git clone git@github.com:songth1ef/nestwork.git ~/local-nest
# never push to any remote
```

Or change remote to self-hosted git:

```bash
git remote set-url origin <your-private-git>
```

---

## Inspired by

*Ender's Game* — the Formic hive mind. Every worker wired to the same queen. No individual memory. No conflicting selves. One distributed intelligence.

nestwork carries this metaphor into AI agents: you (the human) are the queen; all your agent instances (Claude, Codex, Gemini, …) are workers; all wired to the same git repo = the same brain.

---

## Protocol evolution

- **v2.0** (2026-04-17): `agents/` reorganized to host-grouped layout (`agents/<host>/<agent-id>/`); atomic per-write hook architecture
- **v2.1** (2026-04-21): SessionStart hook auto-injects context
- **v2.2** (2026-05-07): new `workflow/` context layer + `nestwork.config.json` external ingestion contract + universal markdown split rule

Full protocol spec: [AGENTS.md](AGENTS.md). Changelog: [CHANGELOG.md](CHANGELOG.md) ([中文](CHANGELOG.zh.md)).

---

## Related docs

- [AGENTS.md](AGENTS.md) — protocol specification (most authoritative; agents read this at startup)
- [docs/workflow-protocol.md](docs/workflow-protocol.md) — v2.2 workflow details
- [docs/desensitization-prompt.md](docs/desensitization-prompt.md) — AI desensitization methodology
- [schemas/nestwork.config.schema.json](schemas/nestwork.config.schema.json) — `nestwork.config.json` JSON Schema
- [docs/ai-agent-memory.md](docs/ai-agent-memory.md)
- [docs/claude-code-memory.md](docs/claude-code-memory.md)
- [docs/codex-persistent-memory.md](docs/codex-persistent-memory.md)
- [docs/git-native-memory-protocol.md](docs/git-native-memory-protocol.md)
- [docs/agents-md-best-practices.md](docs/agents-md-best-practices.md)
- [docs/shared-context-for-ai-coding-agents.md](docs/shared-context-for-ai-coding-agents.md)
- [docs/faq.md](docs/faq.md)
- [docs/comparisons/claude-mem.md](docs/comparisons/claude-mem.md)
