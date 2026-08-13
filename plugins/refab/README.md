# Refab Plugin

This folder contains the Refab Roblox Studio plugin source and build project.

Build and install the plugin:

```powershell
rojo build plugins/refab/plugin.project.json --plugin Refab.rbxm
```

Build a local artifact:

```powershell
rojo build plugins/refab/plugin.project.json -o Refab.rbxm
```

Do not serve this project with Rojo Studio. It is a plugin artifact, not a
DataModel place.
