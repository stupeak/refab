use anyhow::{anyhow, Result};
use sha2::{Digest, Sha256};
use std::path::{Path, PathBuf};

pub const ASSETS_DIR: &str = "assets";

pub trait CanonicalizeOrIntended {
    fn canonicalize_or_intended(&self) -> PathBuf;
}

impl CanonicalizeOrIntended for Path {
    fn canonicalize_or_intended(&self) -> PathBuf {
        self.canonicalize().unwrap_or_else(|_| self.to_path_buf())
    }
}

pub fn find_project_root(start: &Path) -> PathBuf {
    let mut current = start.canonicalize_or_intended();
    loop {
        if current.join("default.project.json").exists() {
            return current;
        }
        if !current.pop() {
            return start.canonicalize_or_intended();
        }
    }
}

pub fn normalize_asset_source(source: &str) -> Result<PathBuf> {
    let mut normalized = source.replace('\\', "/").trim_start_matches('/').to_owned();
    if let Some(stripped) = normalized.strip_prefix(&format!("{ASSETS_DIR}/")) {
        normalized = stripped.to_owned();
    }
    if normalized.split('/').any(|part| part == "..") {
        return Err(anyhow!("asset source cannot contain '..'"));
    }
    if !normalized.ends_with(".rbxm") && !normalized.ends_with(".rbxmx") {
        normalized.push_str(".rbxm");
    }
    Ok(PathBuf::from(normalized))
}

pub fn infer_target(source: &str) -> String {
    source
        .replace('\\', "/")
        .trim_end_matches(".rbxm")
        .trim_end_matches(".rbxmx")
        .split('/')
        .filter(|part| !part.is_empty())
        .collect::<Vec<_>>()
        .join(".")
}

pub fn asset_name(source: &str) -> String {
    Path::new(source)
        .file_stem()
        .and_then(|stem| stem.to_str())
        .unwrap_or("Asset")
        .to_owned()
}

pub fn is_asset_file(path: &Path) -> bool {
    path.extension()
        .and_then(|extension| extension.to_str())
        .map(|extension| matches!(extension.to_ascii_lowercase().as_str(), "rbxm" | "rbxmx"))
        .unwrap_or(false)
}

pub fn sha256_hex(bytes: &[u8]) -> String {
    format!("{:x}", Sha256::digest(bytes))
}

pub fn slash(path: impl AsRef<Path>) -> String {
    path.as_ref()
        .to_string_lossy()
        .trim_start_matches(r"\\?\")
        .replace('\\', "/")
}

#[cfg(test)]
mod tests {
    use super::*;

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
}
