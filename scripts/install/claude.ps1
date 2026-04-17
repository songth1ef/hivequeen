# ---------------------------------------------
# hivequeen x Claude Code installer (Windows)
# ---------------------------------------------

$ErrorActionPreference = "Stop"

$HivequeenPath = (Resolve-Path "$PSScriptRoot\..\..").Path
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
# MEMORY -- $AgentId

> Private memory for this agent instance.
> Only $AgentId writes here.

---

_No memory yet._
"@ | Set-Content -Path $MemoryFile -Encoding UTF8
    Write-Host "v created $MemoryFile"
}

# Python is required for the shared installer helpers
$PythonCmd = $null
foreach ($Cand in @("python3", "python", "py")) {
    if (Get-Command $Cand -ErrorAction SilentlyContinue) { $PythonCmd = $Cand; break }
}
if (-not $PythonCmd) {
    throw "python3 (or python / py) not found -- required by hivequeen installer"
}

# 2. Inject hivequeen bootstrap into global CLAUDE.md (preserves user content).
New-Item -ItemType Directory -Force -Path $ClaudeDir | Out-Null
& $PythonCmd (Join-Path $HivequeenPath "scripts\install\_bootstrap.py") `
    "$ClaudeDir\CLAUDE.md" $HivequeenPath $AgentId
if ($LASTEXITCODE -ne 0) {
    throw "CLAUDE.md bootstrap injection failed (exit $LASTEXITCODE)"
}

# 3. Register Pre/Post/Stop hooks via shared Python helper
#    (avoids PowerShell's ConvertTo-Json bug on nested single-element arrays).
if (-not (Test-Path $Settings)) {
    '{}' | Set-Content -Path $Settings -Encoding UTF8
}
& $PythonCmd (Join-Path $HivequeenPath "scripts\install\_hooks.py") `
    $Settings $HivequeenPath $AgentId
if ($LASTEXITCODE -ne 0) {
    throw "hook installation failed (exit $LASTEXITCODE)"
}

Write-Host ""
Write-Host "OK hivequeen installed for Claude Code"
Write-Host "   agent : $AgentId"
Write-Host "   memory: $MemoryFile"
