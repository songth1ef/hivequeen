# ---------------------------------------------
# hivequeen x Claude Code installer (Windows)
# ---------------------------------------------

$ErrorActionPreference = "Stop"

$HivequeenPath = (Resolve-Path "$PSScriptRoot\..\..").Path
$ClaudeDir     = "$env:USERPROFILE\.claude"
$Settings      = "$ClaudeDir\settings.json"

# Python is required for the shared installer helpers
$PythonCmd = $null
foreach ($Cand in @("python3", "python", "py")) {
    if (Get-Command $Cand -ErrorAction SilentlyContinue) { $PythonCmd = $Cand; break }
}
if (-not $PythonCmd) {
    throw "python3 (or python / py) not found -- required by hivequeen installer"
}

# Resolve (host, agent-id) via shared identity helper. Claude uses a random
# suffix so multiple installs on one machine stay distinct.
$IdentityLines = & $PythonCmd (Join-Path $HivequeenPath "scripts\install\_identity.py") claude --with-suffix
if ($LASTEXITCODE -ne 0) { throw "identity resolver failed (exit $LASTEXITCODE)" }
$HiveHost = $IdentityLines[0].Trim()
$AgentId  = $IdentityLines[1].Trim()
$AgentDir = "$HivequeenPath\agents\$HiveHost\$AgentId"

Write-Host "-> hivequeen path : $HivequeenPath"
Write-Host "-> host           : $HiveHost"
Write-Host "-> agent id       : $AgentId"

# 1. Create this agent's memory directory
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

# 2. Inject hivequeen bootstrap into global CLAUDE.md (preserves user content).
New-Item -ItemType Directory -Force -Path $ClaudeDir | Out-Null
& $PythonCmd (Join-Path $HivequeenPath "scripts\install\_bootstrap.py") `
    "$ClaudeDir\CLAUDE.md" $HivequeenPath $HiveHost $AgentId
if ($LASTEXITCODE -ne 0) {
    throw "CLAUDE.md bootstrap injection failed (exit $LASTEXITCODE)"
}

# 3. Register Pre/Post/Stop hooks via shared Python helper
#    (avoids PowerShell's ConvertTo-Json bug on nested single-element arrays).
if (-not (Test-Path $Settings)) {
    '{}' | Set-Content -Path $Settings -Encoding UTF8
}
& $PythonCmd (Join-Path $HivequeenPath "scripts\install\_hooks.py") `
    $Settings $HivequeenPath $HiveHost $AgentId
if ($LASTEXITCODE -ne 0) {
    throw "hook installation failed (exit $LASTEXITCODE)"
}

Write-Host ""
Write-Host "OK hivequeen installed for Claude Code"
Write-Host "   agent : $HiveHost/$AgentId"
Write-Host "   memory: $MemoryFile"
