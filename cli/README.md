# Refab CLI

Rust CLI for Refab local asset sync.

Run from the repository root:

```powershell
cargo run --manifest-path cli/Cargo.toml -- run
```

Useful checks:

```powershell
cargo run --manifest-path cli/Cargo.toml -- status
cargo run --manifest-path cli/Cargo.toml -- scan
cargo run --manifest-path cli/Cargo.toml -- --version
cargo run --manifest-path cli/Cargo.toml -- stop
```

The CLI listens on:

```text
http://127.0.0.1:34874
```

It handles local asset operations:

- scan `assets/**/*.rbxm`
- read `.rbxm` bytes
- write `.rbxm` bytes

Asset identity comes from the file path:

```text
assets/<RobloxService>/<Folders>/<AssetName>.rbxm
```

The Studio plugin owns Roblox Instance operations:

- selection
- `SerializationService:SerializeInstancesAsync`
- `SerializationService:DeserializeInstancesAsync`
- inserting Instances into the DataModel
