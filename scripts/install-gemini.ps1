# ─────────────────────────────────────────────
# hivequeen × Gemini CLI installer (Windows)
# ─────────────────────────────────────────────

$ErrorActionPreference = "Stop"

$HivequeenPath = (Resolve-Path "$PSScriptRoot\..").Path
$GeminiDir     = if ($env:GEMINI_HOME) { $env:GEMINI_HOME } else { "$env:USERPROFILE\.gemini" }
$AgentId       = "gemini-$env:COMPUTERNAME".ToLower()
$AgentDir      = "$HivequeenPath\agents\$AgentId"

Write-Host "-> hivequeen path : $HivequeenPath"
Write-Host "-> agent id       : $AgentId"
Write-Host "-> gemini home    : $GeminiDir"

# Python is required for the shared bootstrap helper
$PythonCmd = $null
foreach ($Cand in @("python3", "python", "py")) {
    if (Get-Command $Cand -ErrorAction SilentlyContinue) { $PythonCmd = $Cand; break }
}
if (-not $PythonCmd) {
    throw "python3 (or python / py) not found — required by hivequeen installer"
}

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

# 2. Inject hivequeen bootstrap into ~/.gemini/GEMINI.md (preserves user content).
New-Item -ItemType Directory -Force -Path $GeminiDir | Out-Null
& $PythonCmd (Join-Path $HivequeenPath "scripts\_install-bootstrap.py") `
    "$GeminiDir\GEMINI.md" $HivequeenPath $AgentId
if ($LASTEXITCODE -ne 0) {
    throw "GEMINI.md bootstrap injection failed (exit $LASTEXITCODE)"
}

Write-Host ""
Write-Host "OK hivequeen installed for Gemini CLI"
Write-Host "   agent  : $AgentId"
Write-Host "   memory : $MemoryFile"
Write-Host "   config : $GeminiDir\GEMINI.md"
Write-Host ""
Write-Host "i Gemini CLI has no session hooks; memory commit/push runs inside the"
Write-Host "  agent loop per the instructions written to GEMINI.md."
