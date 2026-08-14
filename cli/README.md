# Refab Helper CLI

Rust local filesystem helper for the Refab Roblox Studio plugin.

Run from the repository root:

```powershell
cargo run --manifest-path cli/Cargo.toml -- serve
```

Useful checks:

```powershell
cargo run --manifest-path cli/Cargo.toml -- status
cargo run --manifest-path cli/Cargo.toml -- scan
```

The helper listens on:

```text
http://127.0.0.1:34874
```

It owns local filesystem operations that Roblox Studio plugins cannot perform:

- scan `assets/**/*.rbxm`
- read `.rbxm` bytes
- write `.rbxm` bytes
- update `.refab/manifest.json`

The Studio plugin owns Roblox Instance operations:

- selection
- `SerializationService:SerializeInstancesAsync`
- `SerializationService:DeserializeInstancesAsync`
- inserting Instances into the DataModel
