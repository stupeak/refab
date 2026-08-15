# Refab Agent Notes

These notes are for AI/coder agents working on Refab. Keep user-facing docs
simple and workflow-focused; keep implementation detail here or in focused
developer docs.

## Project Shape

Refab is a normal Roblox game project with a bundled Studio plugin and Rust CLI.

```text
default.project.json      # Rojo place project. Use with rojo serve.
src/                      # Game code synced by Rojo.
assets/                   # Refab-managed .rbxm/.rbxmx assets. Track in Git.
plugin/                   # Roblox Studio plugin source/build project.
cli/                      # Rust CLI for local asset sync and plugin install.
docs/                     # User/developer docs and images.
.release-notes/           # Per-version GitHub Release notes.
tests/                    # Local verification scripts.
```

Do not serve `plugin/plugin.project.json`; it is a plugin artifact, not a
DataModel place.

## Ownership Rules

Rojo owns source code sync from `src/`.

Refab owns serialized Studio content under `assets/`.

Refab plugin owns:

- Studio UI
- Explorer selection handling
- `SerializationService` serialization/deserialization
- DataModel mutations when applying assets

Refab CLI owns:

- scanning `assets/**/*.rbxm` and `assets/**/*.rbxmx`
- reading/writing local asset bytes
- comparing local assets with plugin-provided bytes
- installing/updating the local Studio plugin through `refab install-plugin`

Refab must not take ownership of Rojo-managed project logic:

- `src/client`
- `src/server`
- `src/shared`
- controllers/services/source modules
- normal game code sync

Scripts can still exist inside serialized asset packages when they are part of
the Roblox asset being versioned.

## Asset Identity

Asset identity is the canonical source path:

```text
assets/<RobloxService>/<Folders>/<AssetName>.rbxm
```

The path already contains folder and name. Do not add a manifest or separate
asset id/name identity system unless the user explicitly changes the product
direction.

Examples:

```text
assets/Workspace/World/Boat.rbxm          -> Workspace.World.Boat
assets/StarterGui/Inventory.rbxm          -> StarterGui.Inventory
assets/ReplicatedStorage/Items/Sword.rbxm -> ReplicatedStorage.Items.Sword
```

When applying changed local assets to Roblox, replace the matching Instance by
path/name. Only new assets should insert new Instances.

Do not ignore `assets/**/*.rbxm` or `assets/**/*.rbxmx`; these are source
artifacts for the asset workflow.

## Development Workflow

For a new feature:

1. Identify whether the change belongs in the Studio plugin, the Rust CLI, docs,
   release automation, or tests.
2. Keep UI language user-facing. Avoid exposing internal terms like "helper" in
   README or plugin UI; prefer "Refab CLI" or direct workflow language.
3. Preserve the two primary product flows:
   - `To Roblox`: local files update the open place.
   - `To Local`: selected Studio Instances become local asset files.
4. Keep the plugin UI compact and tree-oriented. Show new/changed state with
   color and badges, but avoid noisy repeated text.
5. Keep CLI commands discoverable with `refab`, `refab help`, and
   `refab --version`.
6. Add focused tests when changing Rust behavior. At minimum, run the relevant
   local scripts before finishing.

Useful commands:

```powershell
rojo serve default.project.json
rojo build plugin/plugin.project.json --plugin Refab.rbxm
cargo run --manifest-path cli/Cargo.toml -- run
cargo run --manifest-path cli/Cargo.toml -- status
cargo run --manifest-path cli/Cargo.toml -- scan
cargo run --manifest-path cli/Cargo.toml -- --version
cargo run --manifest-path cli/Cargo.toml -- stop
cargo run --manifest-path cli/Cargo.toml -- install-plugin
```

Tests:

```powershell
.\tests\run-all.ps1
.\tests\cli\test.ps1
.\tests\plugin\build.ps1
```

## Versioning

When preparing a new version, update every version source that applies:

- `cli/Cargo.toml`
- `cli/Cargo.lock`
- `plugin/src/config/Settings.luau`
- README install snippets, especially the Rokit line
- `.release-notes/vX.Y.Z.md`
- `CHANGELOG.md`
- `docs/releasing.md` examples if they refer to the current release

Use semantic versioning:

- patch: fixes, polish, docs, small CLI/plugin improvements
- minor: new user-facing workflow or asset support
- major: breaking workflow or file layout changes

## Release Notes And Changelog

Every release should have both:

```text
.release-notes/vX.Y.Z.md
CHANGELOG.md
```

Release notes are for GitHub Releases:

- user-facing
- concise
- focused on what changed in the workflow
- no raw commit links or internal implementation noise

Changelog is for the repo history:

- grouped by version
- short bullets
- include CLI, plugin, docs, and workflow changes

The release workflow checks `.release-notes/<tag>.md`. If the file exists, it is
used as the GitHub Release body. If it does not exist, GitHub generated notes are
used as a fallback.

## Markdown Rules

README is for users. Keep it focused on:

- what Refab does
- how assets map between `assets/` and Roblox
- how to sync To Roblox / To Local
- how to install with Rokit and `refab install-plugin`
- supported asset scope

Avoid README sections that mostly explain internal architecture. Put that detail
in `AGENTS.md`, `docs/`, `plugin/README.md`, or `cli/README.md`.

When adding screenshots, put them in:

```text
docs/images/
```

Use centered images in README when they explain the workflow:

```html
<p align="center">
  <img src="docs/images/to-roblox.png" alt="Refab To Roblox view" width="720">
</p>
```

## CLI Install Behavior

`refab install-plugin` downloads:

```text
https://github.com/stupeak/refab/releases/download/v<cli-version>/Refab.rbxm
```

It writes to the local Roblox Studio Plugins folder and overwrites an existing
`Refab.rbxm`.

This command only works after the matching GitHub Release exists and includes
`Refab.rbxm`.

## Verification Expectations

Before finishing code changes, run the narrowest useful verification:

- plugin-only changes: `.\tests\plugin\build.ps1`
- CLI-only changes: `.\tests\cli\test.ps1`
- version/release/workflow changes: `.\tests\run-all.ps1`

If a command cannot be tested because it depends on a future GitHub Release, say
that explicitly.
