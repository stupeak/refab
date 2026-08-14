use crate::{
    assets::{AssetState, AssetSummary},
    paths::{
        asset_name, find_project_root, infer_target, is_asset_file, normalize_asset_source,
        sha256_hex, slash, CanonicalizeOrIntended, ASSETS_DIR,
    },
};
use anyhow::{anyhow, Result};
use std::{fs, path::PathBuf};
use walkdir::WalkDir;

#[derive(Debug, Clone)]
pub struct App {
    pub project_root: PathBuf,
    pub assets_root: PathBuf,
}

impl App {
    pub fn discover(start: PathBuf) -> Result<Self> {
        let project_root = find_project_root(&start);
        Ok(Self {
            assets_root: project_root.join(ASSETS_DIR),
            project_root,
        })
    }

    pub fn ensure_project_folders(&self) -> Result<()> {
        fs::create_dir_all(&self.assets_root)?;
        Ok(())
    }

    pub fn scan_assets(&self) -> Result<Vec<AssetSummary>> {
        self.ensure_project_folders()?;
        let mut assets = Vec::new();

        for entry in WalkDir::new(&self.assets_root)
            .into_iter()
            .filter_map(Result::ok)
        {
            if !entry.file_type().is_file() {
                continue;
            }

            let absolute = entry.path();
            if !is_asset_file(absolute) {
                continue;
            }

            let bytes = fs::read(absolute)?;
            let relative = slash(absolute.strip_prefix(&self.assets_root)?);
            let source = format!("{ASSETS_DIR}/{relative}");

            assets.push(AssetSummary {
                id: source.clone(),
                name: asset_name(&relative),
                source: source.clone(),
                target: infer_target(&relative),
                class_name: "rbxm".to_owned(),
                hash: sha256_hex(&bytes),
                size: bytes.len() as u64,
                status: AssetState::Clean,
            });
        }

        assets.sort_by(|a, b| a.source.cmp(&b.source));
        Ok(assets)
    }

    pub fn asset_absolute_path(&self, source: &str) -> Result<PathBuf> {
        let relative = normalize_asset_source(source)?;
        let absolute = self.assets_root.join(relative).canonicalize_or_intended();
        let relative_from_assets = absolute
            .strip_prefix(self.assets_root.canonicalize_or_intended())
            .map_err(|_| anyhow!("asset source escapes assets directory"))?;
        if relative_from_assets
            .components()
            .any(|part| part.as_os_str() == "..")
        {
            return Err(anyhow!("asset source escapes assets directory"));
        }
        Ok(absolute)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::{
        fs,
        time::{SystemTime, UNIX_EPOCH},
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

        let app = App::discover(root.clone()).unwrap();
        let assets = app.scan_assets().unwrap();

        assert_eq!(assets.len(), 2);
        assert_eq!(assets[0].source, "assets/StarterGui/CurrencyUI.rbxm");
        assert_eq!(assets[0].target, "StarterGui.CurrencyUI");
        assert_eq!(assets[0].name, "CurrencyUI");
        assert_eq!(assets[0].size, 3);
        assert!(matches!(assets[0].status, AssetState::Clean));
        assert_eq!(assets[1].source, "assets/Workspace/Rewards.rbxm");
        assert_eq!(assets[1].target, "Workspace.Rewards");

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
}
