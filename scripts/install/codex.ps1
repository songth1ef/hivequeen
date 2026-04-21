# ---------------------------------------------
# nestwork x Codex installer (Windows)
# ---------------------------------------------

$ErrorActionPreference = "Stop"

$NestworkPath = (Resolve-Path "$PSScriptRoot\..\..").Path
$CodexDir = "$env:USERPROFILE\.codex"
$CodexAgents = "$CodexDir\AGENTS.md"
$CodexInstructions = "$CodexDir\instructions.md"
$Settings = "$CodexDir\config.json"

$PythonCmd = $null
foreach ($Cand in @("python3", "python", "py")) {
    if (Get-Command $Cand -ErrorAction SilentlyContinue) { $PythonCmd = $Cand; break }
}
if (-not $PythonCmd) {
    throw "python3 (or python / py) not found -- required by nestwork installer"
}

$IdentityLines = & $PythonCmd (Join-Path $NestworkPath "scripts\install\_identity.py") codex
if ($LASTEXITCODE -ne 0) { throw "identity resolver failed (exit $LASTEXITCODE)" }
$NestHost = $IdentityLines[0].Trim()
$AgentId  = $IdentityLines[1].Trim()
$AgentDir = "$NestworkPath\agents\$NestHost\$AgentId"

Write-Host "-> nestwork path : $NestworkPath"
Write-Host "-> host           : $NestHost"
Write-Host "-> agent id       : $AgentId"

# 1. Create this agent's memory directory
New-Item -ItemType Directory -Force -Path $AgentDir | Out-Null
$MemoryFile = "$AgentDir\memory.md"
if (-not (Test-Path $MemoryFile)) {
    @"
# MEMORY -- $NestHost/$AgentId

> Private memory for this agent instance.
> Only $NestHost/$AgentId writes here.

---

_No memory yet._
"@ | Set-Content -Path $MemoryFile -Encoding UTF8
    Write-Host "v created $MemoryFile"
}

# 2. Inject nestwork bootstrap (marker-preserved).
New-Item -ItemType Directory -Force -Path $CodexDir | Out-Null
& $PythonCmd (Join-Path $NestworkPath "scripts\install\_bootstrap.py") `
    "$CodexAgents" $NestworkPath $NestHost $AgentId
if ($LASTEXITCODE -ne 0) {
    throw "Codex AGENTS.md bootstrap injection failed (exit $LASTEXITCODE)"
}
& $PythonCmd (Join-Path $NestworkPath "scripts\install\_bootstrap.py") `
    "$CodexInstructions" $NestworkPath $NestHost $AgentId
if ($LASTEXITCODE -ne 0) {
    throw "Codex instructions.md compatibility bootstrap injection failed (exit $LASTEXITCODE)"
}

# 3. Register session end hook in config.json
if (-not (Test-Path $Settings)) {
    '{}' | Set-Content -Path $Settings -Encoding UTF8
}

$AgentRel = "agents/$NestHost/$AgentId"
$HookCmd = "Set-Location -LiteralPath `"$NestworkPath`"; git pull --rebase --autostash -q; if (`$LASTEXITCODE -ne 0) { exit `$LASTEXITCODE }; & `"$PythonCmd`" `"$NestworkPath\scripts\hooks\sync-local-history.py`" `"$NestworkPath`" $NestHost $AgentId; if (`$LASTEXITCODE -ne 0) { exit `$LASTEXITCODE }; git add $AgentRel/; if (`$LASTEXITCODE -ne 0) { exit `$LASTEXITCODE }; git diff --cached --quiet -- $AgentRel/; if (`$LASTEXITCODE -ne 0) { git commit -m 'memory: update $NestHost/$AgentId' -- $AgentRel/; if (`$LASTEXITCODE -ne 0) { exit `$LASTEXITCODE } }; git push -q"

$SettingsObj = Get-Content $Settings -Raw | ConvertFrom-Json

if (-not $SettingsObj.session) {
    $SettingsObj | Add-Member -NotePropertyName session -NotePropertyValue @{}
}
$SettingsObj.session | Add-Member -NotePropertyName end_hook -NotePropertyValue $HookCmd -Force

$SettingsObj | ConvertTo-Json -Depth 10 | Set-Content -Path $Settings -Encoding UTF8
Write-Host "v registered session end hook in $Settings"

Write-Host ""
Write-Host "OK nestwork installed for Codex"
Write-Host "   agent: $NestHost/$AgentId"
Write-Host "   memory: $MemoryFile"
