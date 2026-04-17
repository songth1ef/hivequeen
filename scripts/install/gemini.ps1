# ---------------------------------------------
# hivequeen x Gemini CLI installer (Windows)
# ---------------------------------------------

$ErrorActionPreference = "Stop"

$HivequeenPath = (Resolve-Path "$PSScriptRoot\..\..").Path
$GeminiDir     = if ($env:GEMINI_HOME) { $env:GEMINI_HOME } else { "$env:USERPROFILE\.gemini" }

# Python is required for the shared bootstrap helper
$PythonCmd = $null
foreach ($Cand in @("python3", "python", "py")) {
    if (Get-Command $Cand -ErrorAction SilentlyContinue) { $PythonCmd = $Cand; break }
}
if (-not $PythonCmd) {
    throw "python3 (or python / py) not found -- required by hivequeen installer"
}

$IdentityLines = & $PythonCmd (Join-Path $HivequeenPath "scripts\install\_identity.py") gemini
if ($LASTEXITCODE -ne 0) { throw "identity resolver failed (exit $LASTEXITCODE)" }
$HiveHost = $IdentityLines[0].Trim()
$AgentId  = $IdentityLines[1].Trim()
$AgentDir = "$HivequeenPath\agents\$HiveHost\$AgentId"

Write-Host "-> hivequeen path : $HivequeenPath"
Write-Host "-> host           : $HiveHost"
Write-Host "-> agent id       : $AgentId"
Write-Host "-> gemini home    : $GeminiDir"

# 1. Create agent memory directory
New-Item -ItemType Directory -Force -Path $AgentDir | Out-Null
$MemoryFile = "$AgentDir\memory.md"
if (-not (Test-Path $MemoryFile)) {
    @"
# MEMORY -- $HiveHost/$AgentId

> Private memory for this agent instance.
> Only $HiveHost/$AgentId writes here.

---

_No memory yet._
"@ | Set-Content -Path $MemoryFile -Encoding UTF8
    Write-Host "v created $MemoryFile"
}

# 2. Inject hivequeen bootstrap into ~/.gemini/GEMINI.md (preserves user content).
New-Item -ItemType Directory -Force -Path $GeminiDir | Out-Null
& $PythonCmd (Join-Path $HivequeenPath "scripts\install\_bootstrap.py") `
    "$GeminiDir\GEMINI.md" $HivequeenPath $HiveHost $AgentId
if ($LASTEXITCODE -ne 0) {
    throw "GEMINI.md bootstrap injection failed (exit $LASTEXITCODE)"
}

Write-Host ""
Write-Host "OK hivequeen installed for Gemini CLI"
Write-Host "   agent  : $HiveHost/$AgentId"
Write-Host "   memory : $MemoryFile"
Write-Host "   config : $GeminiDir\GEMINI.md"
Write-Host ""
Write-Host "i Gemini CLI has no session hooks; memory commit/push runs inside the"
Write-Host "  agent loop per the instructions written to GEMINI.md."
