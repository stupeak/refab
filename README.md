# Refab

Refab is a Roblox Studio plugin for explicit asset packaging. It treats selected Studio objects as prefab-like `.rbxm` artifacts that can be committed to Git separately from Rojo-managed code.

This repository is shaped like a normal Roblox game project. Refab lives inside
`plugins/refab` as a local development plugin for the project.

The intended split is:

- Rojo: `src/client`, `src/server`, `src/shared`
- Refab: `assets/Workspace`, `assets/StarterGui`, `assets/ReplicatedStorage`
- Git: version control for both code and asset artifacts

## Project Structure

```text
src/
  client/
  server/
  shared/
assets/
  ...
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

Refab does not need `rojo serve` for V1 testing. Build the plugin, open Studio,
then enable Refab from the Plugins tab.

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

## Project Workflow

Refab is an asset workflow layer beside Rojo:

```text
src/    -> Rojo  -> code/tree sync
assets/ -> Refab -> managed asset packages
```

On first use, set `Project Root` in the Refab panel, for example:

```text
C:/Roblox Projects/my-game
```

Refab stores this per place/experience with plugin settings. The `Assets Folder`
defaults to `assets`.

Roblox Studio plugin APIs do not currently expose a native folder picker for
arbitrary project roots, so V1 uses a text field for the root path.

V1 still uses Roblox Studio's native save/import dialogs because plugin-only
Luau cannot silently read/write arbitrary project files. Refab now uses the
saved project root to show and suggest exact asset paths like:

```text
C:/Roblox Projects/my-game/assets/Workspace/World/Boat.rbxm
```

Dialog avoidance and folder scanning are V2 bridge/CLI work, not V1.

## Export Workflow

1. Select supported objects in Explorer.
2. Open the Refab toolbar button.
3. Use the Export tab.
4. Select or deselect individual assets.
5. Click `EXPORT SELECTED`.
6. Save each prompted `.rbxm` file into the matching `assets/...` path.

Refab suggests paths such as:

```text
assets/Workspace/World/Boat.rbxm
assets/StarterGui/Inventory.rbxm
assets/ReplicatedStorage/Items/Sword.rbxm
```

## Import Workflow

The Import tab can prompt for multiple `.rbxm` or `.rbxmx` files and display
them for selection. Plugin-only Refab cannot scan `assets/` automatically
because Roblox Studio plugin APIs do not expose directory listing or arbitrary
filesystem reads. Native plugin-only import is intentionally guarded because
current Roblox APIs expose selected local files as `File` objects but do not
provide a supported API to deserialize arbitrary local `.rbxm` contents into
live Instances.

When Roblox adds such an API, or when a local bridge is added, the import service can be extended without rewriting the UI or path resolver.

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
- `Plugin:PromptSaveSelectionAsync()` to save selected Instances as `.rbxm`.
- `StudioService:PromptImportFilesAsync()` to prompt for local files.
- `ChangeHistoryService:TryBeginRecording()` and `FinishRecording()` around import mutations when importable Instances are available.

Known limitations:

- Roblox plugins cannot silently write arbitrary local filesystem paths. Export uses the official save prompt.
- The save API accepts a suggested file name, but the user still chooses the final location.
- `StudioService:PromptImportFilesAsync()` exposes local files to plugins, but official APIs do not expose a native `.rbxm` deserializer for plugin Luau.
- File picker results do not provide a reliable repository-relative `assets/...` path, so exact hierarchy import needs either user-provided metadata, a naming convention, or a local bridge.
- `InstanceFileSyncService` reports file sync state for instances already involved in Studio file sync; it is not a general `.rbxm` import/export system.

Official references:

- https://create.roblox.com/docs/reference/engine/classes/Plugin
- https://create.roblox.com/docs/reference/engine/classes/StudioService/PromptImportFilesAsync
- https://create.roblox.com/docs/reference/engine/classes/File
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
7. Attempt import of one `.rbxm` and verify the limitation message.
8. Attempt import of multiple `.rbxm` files and verify the limitation message.
9. Validate path preview for `Workspace`.
10. Validate path preview for `StarterGui`.
11. Validate path preview for `ReplicatedStorage`.
12. Select an unsupported object and verify the error.
13. Open export with empty selection and verify the empty-state message.
14. Select an invalid file and verify the import error path.
15. Attempt a duplicate asset workflow and decide replace/keep-both behavior for a future bridge.
16. When actual import insertion is available, verify Studio undo restores the previous hierarchy.

## Future Improvements

- Add a small local filesystem bridge that can map exact repository paths and decode `.rbxm` safely.
- Add duplicate handling options: replace, keep both, or skip.
- Add metadata sidecars for stable asset IDs and intended parent paths.
- Add more roots, such as `StarterPlayer`, `ServerStorage`, and `StarterPack`.
- Add automated Luau checks once a Roblox/Luau toolchain is chosen for this repo.
