# ─────────────────────────────────────────────
# hivequeen x Claude Code installer (Windows)
# ─────────────────────────────────────────────

$ErrorActionPreference = "Stop"

$HivequeenPath = (Resolve-Path "$PSScriptRoot\..").Path
$ClaudeDir     = "$env:USERPROFILE\.claude"
$Settings      = "$ClaudeDir\settings.json"
$IdFile        = "$env:USERPROFILE\.hivequeen_id"

# Generate or reuse agent-id. Persist in ~/.hivequeen_id so the Windows and
# Git-Bash installers share the same identity on this machine.
if (Test-Path $IdFile) {
    $AgentId = (Get-Content $IdFile -Raw).Trim()
} else {
    $Chars  = [char[]]([char[]]'abcdefghijklmnopqrstuvwxyz' + [char[]]'0123456789')
    $Suffix = -join (1..4 | ForEach-Object { $Chars | Get-Random })
    $Host   = $env:COMPUTERNAME.ToLower()
    $AgentId = "claude-$Host-$Suffix"
    Set-Content -Path $IdFile -Value $AgentId -Encoding ASCII -NoNewline
}

$AgentDir = "$HivequeenPath\agents\$AgentId"

Write-Host "-> hivequeen path : $HivequeenPath"
Write-Host "-> agent id       : $AgentId"

# 1. Create this agent's memory directory
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

# 2. Write global CLAUDE.md
New-Item -ItemType Directory -Force -Path $ClaudeDir | Out-Null
@"
# Global Startup Protocol

Before starting analysis, planning, or implementation, run:

``````powershell
git -C "$HivequeenPath" pull --rebase
``````

Then load context from hivequeen in this order:

1. ``$HivequeenPath\queen\agent-rules.md``
2. ``$HivequeenPath\queen\strategy.md``
3. ``$HivequeenPath\shared\memory.md``
4. ``$HivequeenPath\agents\$AgentId\memory.md``
5. Relevant ``$HivequeenPath\projects\*.md`` for current task

Write protocol: only write to ``$HivequeenPath\agents\$AgentId\``

See full protocol: ``$HivequeenPath\AGENTS.md``
"@ | Set-Content -Path "$ClaudeDir\CLAUDE.md" -Encoding UTF8
Write-Host "v wrote $ClaudeDir\CLAUDE.md"

# 3. Register hooks via shared Python helper (avoids PowerShell's
#    ConvertTo-Json bug on nested single-element arrays).
if (-not (Test-Path $Settings)) {
    '{}' | Set-Content -Path $Settings -Encoding UTF8
}

$PythonCmd = $null
foreach ($Cand in @("python3", "python", "py")) {
    if (Get-Command $Cand -ErrorAction SilentlyContinue) { $PythonCmd = $Cand; break }
}
if (-not $PythonCmd) {
    throw "python3 (or python / py) not found — required for hook registration"
}

$InstallerPy = Join-Path $HivequeenPath "scripts\_install-hooks.py"
& $PythonCmd $InstallerPy $Settings $HivequeenPath $AgentId
if ($LASTEXITCODE -ne 0) {
    throw "hook installation failed (exit $LASTEXITCODE)"
}

Write-Host ""
Write-Host "OK hivequeen installed for Claude Code"
Write-Host "   agent : $AgentId"
Write-Host "   memory: $MemoryFile"
