# decisions/

Architecture Decision Records (ADRs) for **nestwork itself** and its protocol.

## Scope

This directory captures decisions about how nestwork works:

- Why a particular protocol layer exists (or doesn't)
- Why a directory naming convention was chosen
- Why a specific tool was supported / dropped
- Why a feature proposal was rejected

It is **not** for project-internal decisions. Project ADRs belong in that
project's repo (typically under `docs/architecture.md` or `decisions/`).

See `AGENTS.md` §10 for the layer-boundary rules.

## File naming

```
decisions/YYYY-MM-DD-<short-slug>.md
```

Date-prefixed for chronological browsing. Slug uses hyphens, lowercase,
3-6 words.

Examples:

- `2026-05-08-no-runs-directory.md`
- `2026-05-08-projects-md-five-fields.md`

## Template

Copy `_template.md` and fill in. Keep ADRs short — one screen if possible.
The most important section is **Reason**: capture *why* this option was
preferred over the alternatives. Future readers can re-derive the decision
from context, but only if you record the trade-offs explicitly.

## Status lifecycle

- `proposed` — under discussion
- `accepted` — current standing decision
- `rejected` — considered, not adopted (still useful to record so it isn't relitigated)
- `superseded` — replaced by a later ADR; reference the new one in `supersedes:`
