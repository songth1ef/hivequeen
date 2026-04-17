# ─────────────────────────────────────────────────────────────────────────────
# hivequeen x generic markdown-config installer (Windows)
#
# See install-generic.sh for full docs.
#
# Usage:
#   .\install-generic.ps1 <tool-prefix> <config-path>
#
# Examples:
#   .\install-generic.ps1 qwen  "$env:USERPROFILE\.qwen\QWEN.md"
#   .\install-generic.ps1 trae  "$env:USERPROFILE\.trae\system.md"
# ─────────────────────────────────────────────────────────────────────────────

param(
    [Parameter(Mandatory=$true, Position=0)] [string] $Prefix,
    [Parameter(Mandatory=$true, Position=1)] [string] $ConfigPath
)

$ErrorActionPreference = "Stop"

$HivequeenPath = (Resolve-Path "$PSScriptRoot\..").Path
$ConfigPath    = [Environment]::ExpandEnvironmentVariables($ConfigPath)
$Host          = $env:COMPUTERNAME.ToLower()
$AgentId       = "$Prefix-$Host"
$AgentDir      = "$HivequeenPath\agents\$AgentId"

Write-Host "-> hivequeen path : $HivequeenPath"
Write-Host "-> agent id       : $AgentId"
Write-Host "-> config target  : $ConfigPath"

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

# 2. Inject bootstrap into config file
$ConfigDir = Split-Path -Parent $ConfigPath
if ($ConfigDir) {
    New-Item -ItemType Directory -Force -Path $ConfigDir | Out-Null
}
& $PythonCmd (Join-Path $HivequeenPath "scripts\_install-bootstrap.py") `
    $ConfigPath $HivequeenPath $AgentId
if ($LASTEXITCODE -ne 0) {
    throw "bootstrap injection failed (exit $LASTEXITCODE)"
}

Write-Host ""
Write-Host "OK hivequeen installed for $Prefix"
Write-Host "   agent  : $AgentId"
Write-Host "   memory : $MemoryFile"
Write-Host "   config : $ConfigPath"
