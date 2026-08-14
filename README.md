# Refab

Refab is a Roblox Studio plugin for explicit asset packaging. It treats selected Studio objects as prefab-like `.rbxm` artifacts that can be committed to Git separately from Rojo-managed code.

This repository is shaped like a normal Roblox game project. Refab lives inside
`plugins/refab` as a local development plugin for the project.

The intended split is:

- Rojo: `src/client`, `src/server`, `src/shared`
- Refab: `assets/Workspace`, `assets/StarterGui`, `assets/ReplicatedStorage`
- Refab helper: local filesystem access for `assets/**/*.rbxm`
- Git: version control for both code and asset artifacts

## Project Structure

```text
src/
  client/
  server/
  shared/
assets/
  ...
cli/
  Cargo.toml
  src/main.rs
plugins/
  refab/
    plugin.project.json
    src/
      main.plugin.luau
      config/
      core/
      export/
      import/
      ui/
default.project.json
```

## Build

Refab is a Studio plugin, not a place. The plugin build project is
`plugins/refab/plugin.project.json`, whose root is
`plugins/refab/src/main.plugin.luau`. Rojo 7.7.0 treats `.plugin.luau` scripts
as plugin-run-context scripts.

Install the pinned toolchain, then build the local plugin:

```powershell
rokit install
rojo build plugins/refab/plugin.project.json --plugin Refab.rbxm
```

Rojo writes `Refab.rbxm` into Roblox Studio's local plugins folder.

For a plain artifact in this repository instead, run:

```powershell
rojo build plugins/refab/plugin.project.json -o Refab.rbxm
```

Refab itself does not use `rojo serve`. Build the plugin, open Studio, then
enable Refab from the Plugins tab.

On Windows, the local plugin folder is usually:

```text
%LOCALAPPDATA%\Roblox\Plugins
```

Studio scans local plugins when Studio starts. After building or copying a
local `.rbxm` plugin, fully restart Roblox Studio before testing it.

For Rojo Studio sync, use the root `default.project.json`:

```powershell
rojo serve default.project.json
```

Do not serve `plugins/refab/plugin.project.json`. It is intentionally a
model/plugin artifact, not a place, so the Rojo Studio plugin will reject it
with "Cannot sync a model as a place."

## Helper CLI

Run the helper from the repository root when you want Refab to read/write local
`.rbxm` files without Studio save dialogs:

```powershell
cargo run --manifest-path cli/Cargo.toml -- serve
```

Useful diagnostics:

```powershell
cargo run --manifest-path cli/Cargo.toml -- status
cargo run --manifest-path cli/Cargo.toml -- scan
```

The helper listens on:

```text
http://127.0.0.1:34874
```

It scans `assets/`, writes `.rbxm` bytes received from the plugin, and reads
`.rbxm` bytes for import. The folder structure is the source of truth.

## Project Workflow

Refab is an asset workflow layer beside Rojo:

```text
src/    -> Rojo  -> code/tree sync
assets/ -> Refab -> managed asset packages
```

With the helper running, Refab can write serialized `.rbxm` bytes directly into
`assets/` and read local `.rbxm` files for import. Without the helper, the
sync UI is hidden because Roblox Studio plugins cannot scan or write arbitrary
project folders by themselves.

```text
C:/Roblox Projects/my-game/assets/Workspace/World/Boat.rbxm
```

The key split is: `SerializationService` gives the plugin `.rbxm` bytes, while
the helper writes/reads those bytes on disk.

## Export Workflow

1. Select supported objects in Explorer.
2. Open the Refab toolbar button.
3. Use the Export tab.
4. Select or deselect individual assets.
5. Run `cargo run --manifest-path cli/Cargo.toml -- serve`.
6. Click `SAVE TO LOCAL`.
7. Refab serializes the Instance and asks the helper to write the `.rbxm` file.

Refab suggests paths such as:

```text
assets/Workspace/World/Boat.rbxm
assets/StarterGui/Inventory.rbxm
assets/ReplicatedStorage/Items/Sword.rbxm
```

Refab identifies an asset by its canonical source path. That path is the folder
plus file name, for example `assets/Workspace/World/Boat.rbxm`. The display name
is metadata; it is not a second identity key.

## Import Workflow

With the helper running, the Import tab loads `assets/**/*.rbxm` from
`GET /assets`. Importing reads `.rbxm` bytes from the helper, converts them back
to a Luau `buffer`, and calls `SerializationService:DeserializeInstancesAsync`.

The helper-backed path is the only intended local workflow. Roblox-only file
pickers are not used because they do not preserve the project-relative folder
path needed for `assets/<RobloxService>/...` mapping.

## Supported Asset Types

V1 export supports any archivable Instance under a supported root. Refab no
longer blocks `Part`, `MeshPart`, UI objects, or other normal asset objects just
because they are not `Model`.

V1 supported roots:

- `Workspace`
- `StarterGui`
- `ReplicatedStorage`

Scripts can be part of `.rbxm` asset packages. Refab exports the selected
archivable Instance tree as the asset artifact and does not block or warn on
scripts.

## Managed Asset Metadata

When exporting, Refab registers the selected root Instance as a managed asset by
setting attributes on that Instance:

```text
RefabAssetId
RefabSourcePath
RefabTargetPath
RefabVersion
```

Refab only treats Instances with `RefabAssetId` as managed. This is the first
step toward the planned incremental sync model where unmanaged Workspace objects
are never touched.

## API Spike Findings

The plugin uses current native Studio APIs:

- `Selection:Get()` to read Explorer selection.
- `Plugin:CreateDockWidgetPluginGuiAsync()` for the docked UI.
- `SerializationService:SerializeInstancesAsync()` to serialize selected
  Instances as `.rbxm` bytes.
- `SerializationService:DeserializeInstancesAsync()` to deserialize helper-read
  `.rbxm` bytes into Instances.
- `HttpService:RequestAsync()` to communicate with the local helper.
- `ChangeHistoryService:TryBeginRecording()` and `FinishRecording()` around import mutations when importable Instances are available.

Known limitations:

- Roblox plugins cannot silently write arbitrary local filesystem paths. Refab
  uses the helper for filesystem writes.
- Plugin-only folder scanning is not available. Refab uses the helper to scan
  `assets/`.
- The helper must be running for no-dialog export/import.
- `InstanceFileSyncService` reports file sync state for instances already involved in Studio file sync; it is not a general `.rbxm` import/export system.

Official references:

- https://create.roblox.com/docs/reference/engine/classes/Plugin
- https://create.roblox.com/docs/reference/engine/classes/ChangeHistoryService
- https://create.roblox.com/docs/reference/engine/classes/InstanceFileSyncService

## Test Plan

These require Roblox Studio:

1. Export one `Model`.
2. Export multiple `Model` instances.
3. Deselect one asset before export.
4. Select All.
5. Deselect All.
6. Export a `ScreenGui`.
7. Run helper import for one `.rbxm` and verify the Instance appears under the mapped root.
8. Run helper import for multiple `.rbxm` files and verify all selected assets import.
9. Validate path preview for `Workspace`.
10. Validate path preview for `StarterGui`.
11. Validate path preview for `ReplicatedStorage`.
12. Select an unsupported object and verify the error.
13. Open export with empty selection and verify the empty-state message.
14. Place an asset under an unsupported `assets/<Root>` folder and verify the import error path.
15. Attempt a duplicate asset workflow and decide replace/keep-both behavior for a future bridge.
16. Verify Studio undo restores the previous hierarchy after helper import.

## Future Improvements

- Add duplicate handling options: replace, keep both, or skip.
- Add more roots, such as `StarterPlayer`, `ServerStorage`, and `StarterPack`.
- Add automated Luau checks once a Roblox/Luau toolchain is chosen for this repo.
