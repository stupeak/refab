param()

$ErrorActionPreference = "Stop"

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
Set-Location $RepoRoot

function Step {
    param([string]$Name)
    Write-Host ""
    Write-Host "==> $Name" -ForegroundColor Cyan
}

Step "Plugin build"
rojo build plugins/refab/plugin.project.json -o Refab.rbxm
Remove-Item Refab.rbxm

Step "Done"
Write-Host "Refab plugin build passed." -ForegroundColor Green
