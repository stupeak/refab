# Refab — Roblox Asset Packaging Plugin

You are an experienced Roblox Studio Plugin engineer and Roblox tooling architect.

Your task is to build a complete Roblox Studio Plugin called:

    Refab

The project will be created entirely inside the current working directory.

IMPORTANT:

Do not merely explain the implementation.

You must inspect the current folder, create the project structure, write the source code, configure Rojo if needed, and produce a working Roblox Studio plugin project.

==================================================
1. PROJECT CONTEXT
==================================================

I am developing a Roblox game with a small 2-person team.

Our game code is already managed with Rojo.

The existing game repository has approximately this structure:

    src/
    ├── client/
    ├── server/
    └── shared/

Rojo is responsible for syncing CODE.

Do NOT redesign or replace the existing code architecture.

The problem this plugin solves is ASSET WORKFLOW, not code synchronization.

The desired game repository should eventually look like:

    project/
    ├── src/
    │   ├── client/
    │   ├── server/
    │   └── shared/
    │
    └── assets/
        ├── Workspace/
        ├── StarterGui/
        └── ReplicatedStorage/

The assets folder should conceptually mirror the relevant Roblox Explorer hierarchy.

For example:

    Workspace
    └── World
        ├── Boat
        └── Dock

should become:

    assets/
    └── Workspace/
        └── World/
            ├── Boat.rbxm
            └── Dock.rbxm

And:

    StarterGui
    └── Inventory

should become:

    assets/
    └── StarterGui/
        └── Inventory.rbxm


==================================================
2. WHY THIS TOOL EXISTS
==================================================

I want to bring a Unity-like asset workflow into Roblox.

The core mental model is:

    Unity Prefab
        ↓
    Versionable asset artifact
        ↓
    Git

Refab should bring a similar prefab/asset ownership model into Roblox.

In Unity, a team can conceptually work like:

    Feature A
        ↓
    Prefabs / UI / animations / scene objects
        ↓
    Git commit
        ↓
    Merge

while another developer works independently on:

    Feature B
        ↓
    Prefabs / UI / animations / scene objects
        ↓
    Git commit
        ↓
    Merge

The goal is to keep feature work isolated and minimize conflicts.

I want a similar workflow in Roblox:

    Feature A
        ↓
    Edit Roblox assets in Studio
        ↓
    Export assets as .rbxm
        ↓
    Git commit

    Feature B
        ↓
    Edit Roblox assets in Studio
        ↓
    Export assets as .rbxm
        ↓
    Git commit

Then:

    merge into develop
        ↓
    import all required .rbxm assets
        ↓
    test
        ↓
    fix
        ↓
    export again
        ↓
    merge/release

The important concept is:

    .rbxm = asset artifact / prefab-like unit

This is NOT intended to be a realtime synchronization system.

The desired workflow is explicit:

    Studio
       ↓
    Export
       ↓
    Git
       ↓
    Merge
       ↓
    Import
       ↓
    Studio

Refab is intended to bring the useful asset ownership model of Unity Prefabs into Roblox without attempting to make Roblox behave exactly like Unity.


==================================================
3. PROBLEMS WITH EXISTING WORKFLOWS
==================================================

Rojo is excellent for code synchronization.

However, I do NOT want to use Rojo as the primary solution for this asset workflow.

The current Rojo workflow is primarily designed around filesystem ↔ Roblox DataModel synchronization.

I already use Rojo for:

    client code
    server code
    shared code

That part is solved.

The missing abstraction is:

    "prefab / asset package"

I want an asset to be independently exportable, versionable and importable.

I do not want the whole Roblox DataModel to become one giant synchronization unit.

I want:

    Boat.rbxm
    Dock.rbxm
    Inventory.rbxm
    Shop.rbxm

to behave conceptually more like Unity prefabs/assets.

This makes feature-based Git workflows easier and reduces accidental conflicts.

--------------------------------------------------

RbxSync should also NOT be treated as the core architecture.

RbxSync is useful for filesystem/DataModel synchronization and has more advanced synchronization concepts.

However, the goal here is intentionally different.

I do NOT want:

    realtime mirroring
    continuous bidirectional synchronization
    another serialization format as the primary source of truth
    complex sync state management

I want:

    explicit export
    explicit import
    .rbxm artifacts
    Git as version control
    Roblox Studio as the editing environment

The purpose is not to clone RbxSync.

The purpose is to create a lightweight "Unity-like prefab/asset packaging workflow" for a small Roblox team.

Do not over-engineer this into a general synchronization framework.


==================================================
4. CORE PRODUCT REQUIREMENT
==================================================

Build a Roblox Studio Plugin named:

    Refab

Refab should provide a GUI with at least two modes:

    EXPORT
    IMPORT


==================================================
5. EXPORT REQUIREMENTS
==================================================

The developer selects objects from the normal Roblox Studio Explorer.

The plugin reads the current Studio Selection.

Example:

    Workspace
    └── World
        ├── Boat
        ├── Dock
        └── House

Developer selects:

    Boat
    Dock

The plugin should show something like:

    EXPORT

    Selected Assets:

    [x] Boat       Model
    [x] Dock       Model

    [Select All]
    [Deselect All]

    [ EXPORT SELECTED ]

The developer must be able to:

    select all
    deselect all
    individually select/deselect assets


==================================================
6. EXPORT TARGET PATH
==================================================

The asset's Roblox hierarchy should determine its conceptual filesystem path.

Examples:

    Workspace.World.Boat

becomes:

    assets/Workspace/World/Boat.rbxm


    StarterGui.Inventory

becomes:

    assets/StarterGui/Inventory.rbxm


    ReplicatedStorage.Items.Sword

becomes:

    assets/ReplicatedStorage/Items/Sword.rbxm

The plugin should preserve the Roblox Explorer hierarchy concept.

Do not create arbitrary unrelated asset directories.

The filesystem should be understandable to a developer who knows Roblox Explorer.

If the current Roblox Plugin API does not allow direct arbitrary filesystem writes, DO NOT fake it.

Investigate the current official Roblox Studio Plugin APIs first.

Determine the best supported approach for:

    saving selection as .rbxm
    importing .rbxm
    interacting with local files
    determining whether a local file can be written/read directly

If a native API requires a file picker, use it for the first implementation.

If a local helper/bridge is genuinely required, isolate it behind an interface and explain why.


==================================================
7. IMPORT REQUIREMENTS
==================================================

The plugin must support importing multiple .rbxm assets.

The UI should allow:

    Select All
    Deselect All
    individual selection

Example:

    IMPORT

    Workspace/World/
        [x] Boat.rbxm
        [x] Dock.rbxm
        [ ] House.rbxm

    StarterGui/
        [x] Inventory.rbxm

    [Select All]
    [Deselect All]

    [ IMPORT SELECTED ]

The imported asset should be inserted into the correct Roblox Explorer location based on its asset path.

For example:

    assets/Workspace/World/Boat.rbxm

should conceptually import into:

    Workspace.World


==================================================
8. SUPPORTED ASSET TYPES — V1
==================================================

Keep V1 intentionally small.

Primary supported asset types:

    Model
    Folder
    ScreenGui

Models may contain:

    Parts
    MeshParts
    Attachments
    Welds
    Constraints
    ProximityPrompts
    UI objects where appropriate
    other normal Instance children

A Part does NOT need to be treated as a first-class standalone asset unless necessary.

The important concept is that a Model is an asset.

Example:

    Boat
        ├── Hull
        ├── Seat
        ├── Engine
        └── ProximityPrompt

should be exported as:

    Boat.rbxm

Do NOT attempt to solve Terrain, Camera, Lighting, animation asset management, or arbitrary runtime state in V1.

Those can be future extensions.

Scripts should NOT be part of this asset pipeline when they are already managed by Rojo.

Do not duplicate code synchronization.


==================================================
9. ROOT LOCATIONS — V1
==================================================

Only support these initial roots:

    Workspace
    StarterGui
    ReplicatedStorage

Architecture should make it easy to add:

    StarterPlayer
    ServerStorage
    StarterPack
    etc.

later.

Do not force the developer to configure arbitrary roots in V1.


==================================================
10. IMPORTANT: CODE VS ASSET RESPONSIBILITY
==================================================

The existing game project uses:

    src/client
    src/server
    src/shared

Rojo manages these.

Refab manages:

    assets/

Therefore the conceptual architecture is:

    Game Repository

    ├── src/
    │   ├── client/
    │   ├── server/
    │   └── shared/
    │
    └── assets/
        ├── Workspace/
        ├── StarterGui/
        └── ReplicatedStorage/

Code synchronization:

    Rojo

Asset packaging:

    Refab

Version control:

    Git


==================================================
11. PLUGIN UI
==================================================

Use a DockWidgetPluginGui.

Create a toolbar button:

    Refab

Clicking it opens the plugin window.

Basic UI:

    ┌───────────────────────────────┐
    │ Refab                         │
    ├───────────────────────────────┤
    │ [ EXPORT ]      [ IMPORT ]    │
    ├───────────────────────────────┤
    │                               │
    │ current mode                  │
    │                               │
    │ asset list                    │
    │                               │
    │ [Select All] [Deselect All]   │
    │                               │
    │       [ ACTION ]              │
    └───────────────────────────────┘

Keep the UI simple and functional.

Do not spend time on visual polish before the workflow works.


==================================================
12. EXPORT UX
==================================================

The preferred workflow:

1. Developer selects objects in Roblox Explorer.
2. Open Refab.
3. Click Export.
4. Plugin displays selected objects.
5. Developer can select/deselect individual objects.
6. Developer can Select All / Deselect All.
7. Click Export Selected.
8. Plugin saves .rbxm artifacts.

Example:

    Explorer selection:

        Boat
        Dock
        Inventory

    Refab:

        [x] Boat
        [x] Dock
        [x] Inventory

        [Select All]
        [Deselect All]

        [ EXPORT SELECTED ]


==================================================
13. IMPORT UX
==================================================

Import should allow multiple .rbxm files.

The plugin should display the selected files before importing.

Example:

    [x] Boat.rbxm
    [x] Dock.rbxm
    [ ] House.rbxm

    [Select All]
    [Deselect All]

    [ IMPORT SELECTED ]


==================================================
14. FILE / INSTANCE PATH MAPPING
==================================================

Create a dedicated abstraction:

    AssetPathResolver

Responsibilities:

    Instance → asset path
    asset path → Roblox parent location

Examples:

    Workspace.World.Boat
        ↔
    Workspace/World/Boat.rbxm

    StarterGui.Inventory
        ↔
    StarterGui/Inventory.rbxm

Do not spread path logic throughout the codebase.


==================================================
15. ARCHITECTURE
==================================================

Use a clean but lightweight architecture.

Suggested structure:

    src/
    ├── main.plugin.luau
    │
    ├── core/
    │   ├── PluginController.luau
    │   ├── AssetDefinition.luau
    │   ├── AssetValidator.luau
    │   └── AssetPathResolver.luau
    │
    ├── export/
    │   └── ExportService.luau
    │
    ├── import/
    │   └── ImportService.luau
    │
    ├── ui/
    │   ├── MainWindow.luau
    │   ├── ExportView.luau
    │   ├── ImportView.luau
    │   └── components/
    │       ├── Button.luau
    │       ├── Checkbox.luau
    │       └── AssetList.luau
    │
    └── config/
        └── Settings.luau

Do not create unnecessary abstractions.

Prefer small modules with clear responsibilities.


==================================================
16. IMPORTANT ROBLOX API RESEARCH
==================================================

Before implementing the import/export core, inspect the CURRENT Roblox Studio Plugin APIs.

Pay particular attention to:

    Selection
    Plugin
    DockWidgetPluginGui
    Plugin:PromptSaveSelectionAsync
    StudioService:PromptImportFilesAsync
    File
    InstanceFileSyncService
    ChangeHistoryService

Do not rely on outdated blog posts.

Use the current official Roblox Creator documentation where possible.

The most important technical question is:

    Can Refab reliably perform:

        Studio Instance
            ↓
        .rbxm
            ↓
        local filesystem

    and:

        .rbxm
            ↓
        Studio Instance

using supported APIs?

If not, identify the exact limitation.

Do NOT silently invent an API.

If a native API is insufficient, implement the closest practical architecture and isolate the limitation behind an interface.

For example:

    IAssetFileProvider

so the rest of the plugin does not depend on the implementation detail.


==================================================
17. DO NOT BUILD A REALTIME SYNC SYSTEM
==================================================

This is NOT:

    RbxSync clone
    Rojo clone
    realtime filesystem watcher
    two-way continuous synchronization system

The desired workflow is:

    Export
       ↓
    Git
       ↓
    Merge
       ↓
    Import
       ↓
    Test

Explicit commands are preferred.

Refab is an asset packaging / prefab workflow tool.


==================================================
18. GIT / TEAM WORKFLOW
==================================================

The final workflow should support:

Developer A:

    Feature A
      ↓
    create/edit assets
      ↓
    Export
      ↓
    assets/FeatureAsset.rbxm
      ↓
    Git commit


Developer B:

    Feature B
      ↓
    create/edit assets
      ↓
    Export
      ↓
    assets/OtherAsset.rbxm
      ↓
    Git commit

Then:

    merge develop
       ↓
    Import assets
       ↓
    Test

The key objective is minimizing asset conflicts by keeping feature assets as independent artifacts.

Do not introduce a giant project-level binary scene as the source of truth.


==================================================
19. UNITY MENTAL MODEL
==================================================

Use the following conceptual mapping:

    Unity                     Roblox

    Prefab                 →   .rbxm asset
    Scene hierarchy        →   Explorer hierarchy
    Assets folder          →   assets/
    Prefab export          →   Refab Export
    Prefab import          →   Refab Import
    Git                    →   Git
    Scene/GameObject       →   Roblox DataModel/Instance

The goal is NOT to make Roblox behave exactly like Unity.

The goal is to bring the useful asset ownership model from Unity into Roblox:

    "This feature owns these assets."

instead of:

    "Everyone edits the same giant Studio state."


==================================================
20. DEVELOPMENT PROCESS
==================================================

Work incrementally.

PHASE 0 — SPIKE

Before building the complete UI:

1. Create minimal plugin.
2. Get Selection.
3. Save selected instance using the official Roblox API.
4. Import an .rbxm using official APIs if possible.
5. Determine how the imported asset becomes an Instance.
6. Verify what filesystem access is actually available.

Do not continue blindly if an API limitation blocks the desired workflow.

Document the result.

PHASE 1 — BASIC PLUGIN

Implement:

    toolbar button
    dock widget
    export view
    import view

PHASE 2 — EXPORT

Implement:

    Explorer selection
    validation
    multi-selection
    Select All
    Deselect All
    .rbxm export

PHASE 3 — IMPORT

Implement:

    multi-file selection
    Select All
    Deselect All
    .rbxm import
    target path resolution

PHASE 4 — PATH MAPPING

Implement:

    Workspace
    StarterGui
    ReplicatedStorage

and:

    Instance → filesystem path
    filesystem path → Roblox parent

PHASE 5 — POLISH

Add:

    status messages
    errors
    warnings
    empty states
    success feedback

Only after functionality works.


==================================================
21. ERROR HANDLING
==================================================

Never silently fail.

Examples:

    No selection

        "No supported assets selected."

    Unsupported type

        "Camera is not supported."

    Invalid root

        "This asset is outside a supported root."

    Import failure

        "Failed to import Boat.rbxm."

Show useful error information.


==================================================
22. CHANGE HISTORY
==================================================

Use ChangeHistoryService where appropriate so importing assets can be undone through Roblox Studio's normal undo system.

An import operation should ideally behave as one logical Studio change where practical.


==================================================
23. CODE QUALITY
==================================================

Use Luau with strict typing where practical.

Prefer:

    --!strict

Use clear type definitions for:

    AssetDefinition
    AssetStatus
    AssetPath

Avoid global state.

Avoid giant modules.

Avoid hidden coupling between UI and filesystem logic.

UI should call services.

Services should not directly manipulate UI.

Example:

    ExportView
        ↓
    ExportService
        ↓
    AssetPathResolver
        ↓
    Roblox Studio API


==================================================
24. TESTING
==================================================

Create a simple test plan.

At minimum test:

    1. Export one Model.
    2. Export multiple Models.
    3. Deselect one asset.
    4. Select All.
    5. Deselect All.
    6. Export a ScreenGui.
    7. Import one asset.
    8. Import multiple assets.
    9. Import into Workspace.
    10. Import into StarterGui.
    11. Import into ReplicatedStorage.
    12. Unsupported object.
    13. Empty selection.
    14. Invalid file.
    15. Duplicate asset.
    16. Undo import.

Do not claim a test passes unless you actually performed it.


==================================================
25. FINAL DELIVERABLE
==================================================

When finished, the working directory should contain:

    default.project.json
    src/
    README.md

and any required configuration files.

README.md must explain:

    what Refab does
    why it exists
    project structure
    how to build it with Rojo
    how to install/use the plugin
    Export workflow
    Import workflow
    supported asset types
    known Roblox API limitations
    future improvements


==================================================
26. IMPORTANT AGENT BEHAVIOR
==================================================

You are working directly in the repository.

Do not stop at architecture documentation.

Inspect the repository.

Create files.

Implement the plugin.

Build/test it where possible.

If a Roblox Studio API cannot be executed in the current environment, clearly distinguish:

    "implemented but requires Studio testing"

from:

    "verified working."

Do not fabricate Roblox API behavior.

If you discover that the original requirement cannot be fully achieved using Plugin-only APIs, do not abandon the project.

Instead:

1. Identify the exact limitation.
2. Find the closest supported solution.
3. Keep the architecture modular so a future filesystem bridge can be added.
4. Continue implementing everything that can be implemented safely.

The final result should be a real, maintainable Roblox Studio Plugin project called **Refab**, not a code sample.

The core philosophy is:

    Rojo → Code
    Refab → Prefabs / Assets
    Git  → Version Control

Refab should make Roblox asset development feel closer to the clean feature-based asset workflow developers are familiar with from Unity, while remaining a lightweight and native Roblox Studio workflow.