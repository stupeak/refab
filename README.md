# Refab

Refab is a Roblox Studio plugin for explicit asset packaging. It treats selected Studio objects as prefab-like `.rbxm` artifacts that can be committed to Git separately from Rojo-managed code.

The intended split is:

- Rojo: `src/client`, `src/server`, `src/shared`
- Refab: `assets/Workspace`, `assets/StarterGui`, `assets/ReplicatedStorage`
- Git: version control for both code and asset artifacts

## Project Structure

```text
default.project.json
src/
  main.plugin.luau
  config/
    Settings.luau
  core/
    AssetDefinition.luau
    AssetPathResolver.luau
    AssetValidator.luau
    PluginController.luau
  export/
    ExportService.luau
  import/
    ImportService.luau
  ui/
    MainWindow.luau
    ExportView.luau
    ImportView.luau
    components/
      AssetList.luau
      Button.luau
      Checkbox.luau
```

## Build

Install the pinned toolchain, then build:

```powershell
rokit install
rojo build -o Refab.rbxm
```

Install `Refab.rbxm` as a local Roblox Studio plugin.

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

The Import tab can prompt for multiple `.rbxm` or `.rbxmx` files and display them for selection. Native plugin-only import is intentionally guarded because current Roblox APIs expose selected local files as `File` objects but do not provide a supported API to deserialize arbitrary local `.rbxm` contents into live Instances.

When Roblox adds such an API, or when a local bridge is added, the import service can be extended without rewriting the UI or path resolver.

## Supported Asset Types

V1 export supports:

- `Model`
- `Folder`
- `ScreenGui`

V1 supported roots:

- `Workspace`
- `StarterGui`
- `ReplicatedStorage`

Scripts are allowed inside selected assets but shown with a warning because Refab is intended for assets, while Rojo remains responsible for code.

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
