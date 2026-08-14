use std::path::Path;

use refab::paths::{asset_name, infer_target, is_asset_file, normalize_asset_source, slash};

#[test]
fn normalizes_asset_sources_for_helper_requests() {
    assert_eq!(
        slash(normalize_asset_source("assets/Workspace/Rewards").unwrap()),
        "Workspace/Rewards.rbxm"
    );
    assert_eq!(
        slash(normalize_asset_source("\\StarterGui\\CurrencyUI.rbxmx").unwrap()),
        "StarterGui/CurrencyUI.rbxmx"
    );
}

#[test]
fn rejects_parent_directory_segments() {
    let error = normalize_asset_source("assets/Workspace/../Secrets.rbxm").unwrap_err();
    assert!(error.to_string().contains("cannot contain '..'"));
}

#[test]
fn infers_roblox_target_from_asset_folder_path() {
    assert_eq!(
        infer_target("StarterGui/Hud/CurrencyUI.rbxm"),
        "StarterGui.Hud.CurrencyUI"
    );
    assert_eq!(
        infer_target("Workspace\\Rewards.rbxmx"),
        "Workspace.Rewards"
    );
}

#[test]
fn derives_asset_name_from_file_stem() {
    assert_eq!(asset_name("Workspace/Rewards.rbxm"), "Rewards");
    assert_eq!(
        asset_name("StarterGui/Ui Pack Version 5 By Zxgly.rbxm"),
        "Ui Pack Version 5 By Zxgly"
    );
}

#[test]
fn detects_supported_asset_files_case_insensitively() {
    assert!(is_asset_file(Path::new("Thing.RBXM")));
    assert!(is_asset_file(Path::new("Thing.rbxmx")));
    assert!(!is_asset_file(Path::new("README.md")));
}
