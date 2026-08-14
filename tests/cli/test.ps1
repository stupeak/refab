param()

$ErrorActionPreference = "Stop"

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
Set-Location $RepoRoot

function Step {
    param([string]$Name)
    Write-Host ""
    Write-Host "==> $Name" -ForegroundColor Cyan
}

Step "Rust format"
cargo fmt --manifest-path cli/Cargo.toml --all -- --check

Step "Rust check"
cargo check --manifest-path cli/Cargo.toml --locked

Step "Rust tests"
cargo test --manifest-path cli/Cargo.toml --locked

Step "Rust clippy"
cargo clippy --manifest-path cli/Cargo.toml --locked -- -D warnings

Step "CLI version"
cargo run --quiet --manifest-path cli/Cargo.toml -- --version
cargo run --quiet --manifest-path cli/Cargo.toml -- -V
cargo run --quiet --manifest-path cli/Cargo.toml -- version

Step "CLI help"
cargo run --quiet --manifest-path cli/Cargo.toml -- help

Step "CLI project status"
cargo run --quiet --manifest-path cli/Cargo.toml -- status | Out-Host

Step "CLI asset scan"
cargo run --quiet --manifest-path cli/Cargo.toml -- scan | Out-Host

Step "CLI run and stop"
$process = Start-Process `
    -FilePath cargo `
    -ArgumentList @("run", "--quiet", "--manifest-path", "cli/Cargo.toml", "--", "run") `
    -WorkingDirectory $RepoRoot `
    -WindowStyle Hidden `
    -PassThru

try {
    Start-Sleep -Seconds 2
    cargo run --quiet --manifest-path cli/Cargo.toml -- status | Out-Host
    cargo run --quiet --manifest-path cli/Cargo.toml -- stop
    Start-Sleep -Seconds 1

    if (-not $process.HasExited) {
        throw "Refab helper did not stop cleanly."
    }
}
finally {
    if (-not $process.HasExited) {
        Stop-Process -Id $process.Id -Force
    }
}

Step "Done"
Write-Host "Refab CLI checks passed." -ForegroundColor Green
