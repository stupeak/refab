param(
    [switch]$SkipPlugin
)

$ErrorActionPreference = "Stop"

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $RepoRoot

& (Join-Path $PSScriptRoot "cli\test.ps1")

if (-not $SkipPlugin) {
    & (Join-Path $PSScriptRoot "plugin\build.ps1")
}

Write-Host ""
Write-Host "Refab checks passed." -ForegroundColor Green
