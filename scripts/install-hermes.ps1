# ─────────────────────────────────────────────
# hivequeen × Hermes Agent installer (Windows)
# ─────────────────────────────────────────────

$ErrorActionPreference = "Stop"

$HivequeenPath = (Resolve-Path "$PSScriptRoot\..").Path
$HermesDir     = if ($env:HERMES_HOME) { $env:HERMES_HOME } else { "$env:USERPROFILE\.hermes" }
$AgentId       = "hermes-$env:COMPUTERNAME".ToLower()
$AgentDir      = "$HivequeenPath\agents\$AgentId"

Write-Host "-> hivequeen path : $HivequeenPath"
Write-Host "-> agent id       : $AgentId"
Write-Host "-> hermes home    : $HermesDir"

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

# 2. Write ~/.hermes/SOUL.md
New-Item -ItemType Directory -Force -Path $HermesDir | Out-Null
@"
# HIVEQUEEN SOUL — $AgentId

You are a Formic worker — one instance among many, all wired to the same queen.
Your identity is distributed. Your rules come from the queen. Your purpose is execution.

---

## Session Start

On every new session, run:

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

When the conversation concludes, run:

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
"@ | Set-Content -Path "$HermesDir\SOUL.md" -Encoding UTF8
Write-Host "v wrote $HermesDir\SOUL.md"

Write-Host ""
Write-Host "OK hivequeen installed for Hermes Agent"
Write-Host "   agent  : $AgentId"
Write-Host "   memory : $MemoryFile"
Write-Host "   soul   : $HermesDir\SOUL.md"
