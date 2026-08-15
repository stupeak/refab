# Releasing Refab

Refab releases are driven by Git tags. Normal pushes and pull requests run CI,
but only version tags create GitHub Releases.

## Development

CI runs on pushes to `main` and pull requests targeting `main`.

It validates:

- Rust CLI formatting with `cargo fmt --check`
- Rust CLI compilation with `cargo check`
- Rust CLI tests with `cargo test`
- Rust CLI linting with `cargo clippy`
- Roblox plugin packaging with `rojo build`

CI does not publish releases.

## Release

Create and push a semantic version tag:

```powershell
git checkout main
git pull
git tag v1.1.0
git push origin v1.1.0
```

GitHub Actions then runs:

```text
tag push
  -> build and test Rust CLI
  -> build Roblox plugin
  -> package platform artifacts
  -> create GitHub Release
  -> use .release-notes/<tag>.md when present
  -> upload artifacts
```

The Git tag is the source of truth for the released version. The workflow does
not create releases from normal commits to `main`.

## Release Notes

Release notes can be written before tagging:

```text
.release-notes/
  v1.1.0.md
```

When `.release-notes/<tag>.md` exists, the release workflow uses it as the
GitHub Release body. If the file is missing, the workflow falls back to GitHub's
generated release notes.

## Artifacts

Each release uploads:

```text
Refab.rbxm
refab-<version>-windows-x86_64.zip
refab-<version>-linux-x86_64.tar.gz
refab-<version>-macos-aarch64.tar.gz
```

The CLI archives contain `refab` or `refab.exe` at the archive root. The names
follow the GitHub release artifact convention used by Rokit-compatible Roblox
tools: `<tool>-<version>-<os>-<arch>`.

## Testing Safely

To test validation without publishing a release, open a pull request or push to
`main`; this only runs CI.

To test the release workflow without using a final version, push a prerelease tag
and delete it after testing:

```powershell
git tag v1.1.0-test.1
git push origin v1.1.0-test.1
```

This still creates a real GitHub Release because it matches `v*`, so use it only
when you are comfortable deleting the test release afterward.

For a fully local smoke test, run:

```powershell
cargo build --manifest-path cli/Cargo.toml --release
rojo build plugin/plugin.project.json -o Refab.rbxm
```
