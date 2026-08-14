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
