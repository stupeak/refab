use std::{
    fs,
    path::PathBuf,
    time::{SystemTime, UNIX_EPOCH},
};

use refab::{
    app::App,
    assets::AssetState,
    paths::{slash, CanonicalizeOrIntended, ASSETS_DIR},
};

fn temp_project() -> PathBuf {
    let id = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_nanos();
    let root = std::env::temp_dir().join(format!("refab-test-{id}"));
    fs::create_dir_all(root.join("assets")).unwrap();
    fs::write(root.join("default.project.json"), "{}").unwrap();
    root
}

#[test]
fn discovers_project_root_from_nested_directory() {
    let root = temp_project();
    let nested = root.join("src").join("client");
    fs::create_dir_all(&nested).unwrap();

    let app = App::discover(nested).unwrap();

    assert_eq!(app.project_root, root.canonicalize_or_intended());
    assert_eq!(
        app.assets_root.canonicalize_or_intended(),
        root.join(ASSETS_DIR).canonicalize_or_intended()
    );

    fs::remove_dir_all(root).unwrap();
}

#[test]
fn scans_rbxm_assets_as_clean_sorted_entries() {
    let root = temp_project();
    fs::create_dir_all(root.join("assets").join("Workspace")).unwrap();
    fs::create_dir_all(root.join("assets").join("StarterGui")).unwrap();
    fs::create_dir_all(root.join("assets").join("ServerStorage").join("Drops")).unwrap();
    fs::write(
        root.join("assets").join("Workspace").join("Rewards.rbxm"),
        b"workspace",
    )
    .unwrap();
    fs::write(
        root.join("assets")
            .join("StarterGui")
            .join("CurrencyUI.rbxm"),
        b"gui",
    )
    .unwrap();
    fs::write(root.join("assets").join("README.md"), b"ignored").unwrap();
    fs::write(
        root.join("assets")
            .join("ServerStorage")
            .join("Drops")
            .join("RewardChest.rbxm"),
        b"server",
    )
    .unwrap();

    let app = App::discover(root.clone()).unwrap();
    let assets = app.scan_assets().unwrap();

    assert_eq!(assets.len(), 3);
    assert_eq!(
        assets[0].source,
        "assets/ServerStorage/Drops/RewardChest.rbxm"
    );
    assert_eq!(assets[0].target, "ServerStorage.Drops.RewardChest");
    assert_eq!(assets[0].name, "RewardChest");
    assert_eq!(assets[0].size, 6);
    assert!(matches!(assets[0].status, AssetState::Clean));
    assert_eq!(assets[1].source, "assets/StarterGui/CurrencyUI.rbxm");
    assert_eq!(assets[1].target, "StarterGui.CurrencyUI");
    assert_eq!(assets[2].source, "assets/Workspace/Rewards.rbxm");
    assert_eq!(assets[2].target, "Workspace.Rewards");

    fs::remove_dir_all(root).unwrap();
}

#[test]
fn resolves_asset_paths_under_assets_root() {
    let root = temp_project();
    let app = App::discover(root.clone()).unwrap();

    let absolute = app.asset_absolute_path("assets/Workspace/Rewards").unwrap();

    assert_eq!(
        slash(absolute.strip_prefix(app.assets_root).unwrap()),
        "Workspace/Rewards.rbxm"
    );

    fs::remove_dir_all(root).unwrap();
}

#[test]
fn rejects_asset_paths_that_escape_assets_root() {
    let root = temp_project();
    let app = App::discover(root.clone()).unwrap();

    let error = app
        .asset_absolute_path("assets/Workspace/../../default.project.json")
        .unwrap_err();

    assert!(error.to_string().contains("cannot contain '..'"));

    fs::remove_dir_all(root).unwrap();
}
