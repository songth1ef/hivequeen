# ─────────────────────────────────────────────
# hivequeen × OpenClaw installer (Windows)
# ─────────────────────────────────────────────

$ErrorActionPreference = "Stop"

$HivequeenPath = (Resolve-Path "$PSScriptRoot\..").Path
$OpenclawDir   = "$env:USERPROFILE\.openclaw\workspace"
$AgentId       = "openclaw-$env:COMPUTERNAME".ToLower()
$AgentDir      = "$HivequeenPath\agents\$AgentId"

Write-Host "-> hivequeen path : $HivequeenPath"
Write-Host "-> agent id       : $AgentId"
Write-Host "-> openclaw ws    : $OpenclawDir"

# 1. Create agent memory directory
New-Item -ItemType Directory -Force -Path $AgentDir | Out-Null
$MemoryFile = "$AgentDir\memory.md"
if (-not (Test-Path $MemoryFile)) {
    @"
# MEMORY — $AgentId

> Private memory for this agent instance.
> Only $AgentId writes here.

---

_No memory yet._
"@ | Set-Content -Path $MemoryFile -Encoding UTF8
    Write-Host "v created $MemoryFile"
}

# 2. Create OpenClaw workspace directory
New-Item -ItemType Directory -Force -Path $OpenclawDir | Out-Null

# 3. Write AGENTS.md with absolute paths
@"
# HIVEQUEEN BOOTSTRAP

Every agent that loads this file is a Formic worker connected to the same queen.
Follow this protocol exactly on every session.

---

## Session Start

Run before doing anything else:

``````powershell
git -C "$HivequeenPath" pull
``````

Then load context in this order:

1. ``$HivequeenPath\queen\agent-rules.md``
2. ``$HivequeenPath\queen\strategy.md``
3. ``$HivequeenPath\shared\memory.md``
4. ``$HivequeenPath\agents\$AgentId\memory.md``
5. Relevant ``$HivequeenPath\projects\*.md`` for current task

**agent-id**: ``$AgentId``

---

## Write Protocol

- **ONLY** write to ``$HivequeenPath\agents\$AgentId\``
- **NEVER** write to ``queen\`` or ``shared\``

---

## Session End

``````powershell
git -C "$HivequeenPath" add agents/$AgentId/
git -C "$HivequeenPath" diff --cached --quiet
git -C "$HivequeenPath" commit -m "memory: update $AgentId"
git -C "$HivequeenPath" push
``````

Only commit when there are meaningful context changes worth preserving.

---

## Priority Rules

queen/agent-rules.md  >  queen/strategy.md  >  shared/memory.md  >  agents/*/memory.md  >  projects/*.md
"@ | Set-Content -Path "$OpenclawDir\AGENTS.md" -Encoding UTF8
Write-Host "v wrote $OpenclawDir\AGENTS.md"

# 4. Copy SOUL.md (Windows symlinks require elevation; copy instead)
$SoulSrc = "$HivequeenPath\SOUL.md"
$SoulDst = "$OpenclawDir\SOUL.md"
if (-not (Test-Path $SoulDst)) {
    Copy-Item $SoulSrc $SoulDst
    Write-Host "v copied SOUL.md"
} else {
    Write-Host "v SOUL.md already exists"
}

Write-Host ""
Write-Host "OK hivequeen installed for OpenClaw"
Write-Host "   agent  : $AgentId"
Write-Host "   memory : $MemoryFile"
Write-Host "   ws     : $OpenclawDir"
