# Refab Agent Notes

## Project Shape

This repository is a normal Roblox game project with a bundled local Studio
plugin and CLI helper.

```text
default.project.json      # Rojo place project. Use with rojo serve.
src/                      # Game code synced by Rojo.
assets/                   # Refab-managed .rbxm assets. Track these in Git.
.refab/manifest.json      # Refab asset registry.
plugins/refab/            # Roblox Studio plugin source/build project.
cli/                      # Rust local helper server for filesystem access.
```

## Commands

Run the game project:

```powershell
rojo serve default.project.json
```

Build/install the Studio plugin:

```powershell
rojo build plugins/refab/plugin.project.json --plugin Refab.rbxm
```

Run the helper:

```powershell
cargo run --manifest-path cli/Cargo.toml -- serve
```

Check helper state:

```powershell
cargo run --manifest-path cli/Cargo.toml -- status
cargo run --manifest-path cli/Cargo.toml -- scan
```

## Responsibilities

Rojo owns code sync from `src/`.

Refab plugin owns Studio UI, selection, serialization, deserialization, and
DataModel mutations.

Refab helper owns local filesystem reads/writes, scanning `assets/`, and
manifest updates.

Asset identity is the canonical source path, which is folder plus file name:
`assets/<RobloxService>/<Folders>/<AssetName>.rbxm`. Do not use a separate
asset name as another identity key; the path already contains the name. Export
writes bytes first, then records or updates the manifest entry for that source.

Do not serve `plugins/refab/plugin.project.json`; it is a plugin artifact, not a
DataModel place.

Do not ignore `assets/**/*.rbxm`; these are source artifacts for the asset
workflow.
