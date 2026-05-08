# Changelog

[English](CHANGELOG.md) | [中文](CHANGELOG.zh.md)

## v0.5.0 - 2026-05-08

### Protocol v2.3

Clarifies the boundary between nestwork (cross-repo coordination layer) and the per-repo 5-doc skeleton, and adds a passive upstream-version check so downstream instances can notice protocol updates without polling.

- **AGENTS.md §10 added** — defines the boundary between nestwork and each repo's own 5-doc skeleton (`AGENT.md` / `docs/conventions.md` / `docs/domain.md` / `docs/architecture.md` / `docs/lessons.md`). Test: "Will this still apply after I change employers?" If yes → nestwork `workflow/`; if no → the repo.
- **`projects/<name>.md` 5-field convention** (§10.1) — `Current Goal` / `Current State` / `Next Action` / `Do Not` / `Last Verified`. Recommended, not enforced. Template ships at `projects/_template.md`.
- **`decisions/` for protocol-level ADRs only** (§10.2) — captures decisions about nestwork itself / its protocol. Project-level ADRs stay in the repo. Files named `YYYY-MM-DD-<slug>.md`. Template at `decisions/_template.md`; scope and status lifecycle in `decisions/README.md`.
- **`workflow/lessons.md` for cross-repo lessons** (§10.3) — repo-level `docs/lessons.md` (5-doc #5) covers project-internal lessons. Lessons that travel across repos go here. Upstream does **not** ship this file; each user creates it as lessons accumulate.
- **AGENTS.md §11 added** — SessionStart hook performs a 3-second non-blocking check against upstream's `protocol-version`. 24h cache; silent on network failure; advisory message only when upstream MAJOR.MINOR is strictly greater than local. Never auto-applies.

### Added

- `projects/_template.md` — 5-field project snapshot template
- `decisions/_template.md` — protocol-level ADR template
- `decisions/README.md` — scope, naming, status lifecycle for protocol ADRs

### Changed

- `scripts/hooks/session-start.sh` — added upstream version check (advisory only)
- `scripts/maintenance/update.sh` — PROTOCOL_FILES now includes `projects/_template.md` / `decisions/_template.md` / `decisions/README.md`

---

## v0.4.0 - 2026-05-07

### Protocol v2.2

Adds a portable workflow context layer and a contract for ingesting external working directories into private nest instances.

- **New top-level `workflow/` directory** — portable cross-project knowledge (coding disciplines, tooling, methodologies, migration guides). Lowest priority. See `AGENTS.md` Section 8.
- **New `nestwork.config.json` contract** — external working directories declare ingestion target and desensitization rules via this file, which **lives only in the source directory and never enters any Nestwork repo**. See `AGENTS.md` Section 9.
- **Universal markdown split rule** — any oversized md file follows the same pattern: original filename becomes a folder, original file becomes an index (or `<folder>/index.md`). Files not listed in the size table use defaults (soft 500 / hard 1000 lines). See `AGENTS.md` Section 6.
- **Priority chain extended** — `queen/agent-rules.md > queen/strategy.md > shared/memory.md > agents/*/*/memory.md > projects/*.md > workflow/*.md`.

### Added

- `docs/workflow-protocol.md` — full rules and three-tier model for `workflow/`
- `docs/desensitization-prompt.md` — AI desensitization prompt template (methodology only, no specific names)
- `schemas/nestwork.config.schema.json` — JSON Schema for `nestwork.config.json`
- `workflow/README.md` + `workflow/_template.md` — workflow scaffolding
- `CHANGELOG.zh.md` — Chinese-maintained changelog

### Changed

- `update.sh` sync scope adds `docs/`, `schemas/`, `workflow/README.md`, `workflow/_template.md`. Private workflow content is **never** touched.
- `README.md` / `README.zh.md` add workflow/ section, directory tree update, file-size table workflow row
- `AGENTS.md` and `CLAUDE.md` synchronously upgraded to protocol-version 2.2

### Compatibility

- Additive-compatible. Existing agents need no action.
- v2.1 private nests can selectively pull v2.2 protocol layer with zero impact on private data.

---

## v0.3.0 - 2026-04-22

- Protocol v2.1: split Stop-hook workload. Stop now only runs the lightweight `nestwork.sh stop` safety-net commit+push; the heavier `export-claude-mem.sh` + `sync-local-history.sh` pair moved to a new SessionEnd hook so it runs once at true session end instead of every turn (including `/clear`, resume, compact).
- `_hooks.py` registers the new `SessionEnd` event; existing installs are cleanly superseded on re-run (old Stop composite command is recognised and removed by `is_nestwork_hook`).
- Additive-compatible: existing agents keep working until they re-run the installer.

## v0.2.0 - 2026-04-19

- Introduced protocol v2 host/agent layout: `agents/<host>/<agent-id>/`.
- Added and hardened installers for Claude Code, Codex CLI, Gemini CLI, OpenClaw, Hermes Agent, Aider, and generic markdown-config tools.
- Aligned identity persistence with the protocol v2 two-line `~/.nestwork_id` format.
- Hardened Codex Windows session hook generation for Windows PowerShell 5.1.
- Added answer-ready GitHub docs, `llms.txt`, and repository-first GEO content for AI agent memory searches.
- Added tests for installer syntax, identity migration, protocol docs, and GEO content assets.

## v0.1.0 - 2026-04-17

- Created the initial nestwork protocol template.
- Added `queen/`, `agents/`, `shared/`, and `projects/` repository layout.
- Added startup instructions through `AGENTS.md` and `CLAUDE.md`.
