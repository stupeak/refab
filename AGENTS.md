# Refab Agent Notes

## Project Shape

This repository is a normal Roblox game project with a bundled local Studio
plugin and CLI helper.

```text
default.project.json      # Rojo place project. Use with rojo serve.
src/                      # Game code synced by Rojo.
assets/                   # Refab-managed .rbxm assets. Track these in Git.
plugin/                  # Roblox Studio plugin source/build project.
cli/                      # Rust local helper server for filesystem access.
```

## Commands

Run the game project:

```powershell
rojo serve default.project.json
```

Build/install the Studio plugin:

```powershell
rojo build plugin/plugin.project.json --plugin Refab.rbxm
```

Run the helper:

```powershell
cargo run --manifest-path cli/Cargo.toml -- run
```

Check helper state:

```powershell
cargo run --manifest-path cli/Cargo.toml -- status
cargo run --manifest-path cli/Cargo.toml -- scan
cargo run --manifest-path cli/Cargo.toml -- --version
cargo run --manifest-path cli/Cargo.toml -- stop
```

Run the full local verification suite:

```powershell
.\tests\run-all.ps1
```

Run focused suites:

```powershell
.\tests\cli\test.ps1
.\tests\plugin\build.ps1
```

## Responsibilities

Rojo owns code sync from `src/`.

Refab plugin owns Studio UI, selection, serialization, deserialization, and
DataModel mutations.

Refab helper owns local filesystem reads/writes and scanning `assets/**/*.rbxm`.

Refab assets are serialized Studio content, not Rojo source folders. Do not add
ownership of `src/client`, `src/server`, `src/shared`, controllers, services, or
Rojo-managed project logic to Refab. Scripts can still exist inside serialized
asset packages when they are part of the Roblox asset being versioned.

Asset identity is the canonical source path, which is folder plus file name:
`assets/<RobloxService>/<Folders>/<AssetName>.rbxm`. Do not use a separate
asset name as another identity key; the path already contains the name. Export
writes bytes directly under assets/<RobloxService>/...

Do not serve `plugin/plugin.project.json`; it is a plugin artifact, not a
DataModel place.

Do not ignore `assets/**/*.rbxm`; these are source artifacts for the asset
workflow.
