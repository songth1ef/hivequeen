# -----------------------------------------------------------------------------
# nestwork x Aider installer (Windows)
#
# See install-aider.sh for rationale.
# -----------------------------------------------------------------------------

$ErrorActionPreference = "Stop"

$NestworkPath  = (Resolve-Path "$PSScriptRoot\..\..").Path
$BootstrapFile  = "$env:USERPROFILE\.aider-nestwork.md"

& (Join-Path $NestworkPath "scripts\install\generic.ps1") aider $BootstrapFile
if ($LASTEXITCODE -ne 0) {
    throw "generic installer failed (exit $LASTEXITCODE)"
}

Write-Host ""
Write-Host "i Aider has no global prompt file -- wire the bootstrap in one of 3 ways:"
Write-Host ""
Write-Host "  1. Add to ~/.aider.conf.yml:"
Write-Host "       read:"
Write-Host "         - $BootstrapFile"
Write-Host ""
Write-Host "  2. Run aider with the flag (per session):"
Write-Host "       aider --read $BootstrapFile"
Write-Host ""
Write-Host "  3. Set env var (via System Properties or in your PowerShell profile):"
Write-Host "       [Environment]::SetEnvironmentVariable('AIDER_READ','$BootstrapFile','User')"
