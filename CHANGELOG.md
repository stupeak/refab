# Changelog

## v1.1.2

- Fixed `To Roblox` showing already-applied local assets as changed after
  applying them to the place.
- Refab now records the applied local file hash on the target Instance so the
  asset tree can avoid false changed states caused by plugin metadata.

## v1.1.1

- Added `refab install-plugin` to install or update `Refab.rbxm` in the local
  Roblox Studio Plugins folder.
- Updated installation docs around the Rokit-first workflow.

## v1.1.0

- Added cleaner `To Roblox` and `To Local` tree views.
- Improved new and changed asset indicators.
- Added clearer CLI commands for `run`, `stop`, `status`, `scan`, and version.
- Improved connection messages when the local CLI is unavailable.
- Expanded supported Roblox asset roots.
