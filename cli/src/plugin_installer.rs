use crate::version::CLI_VERSION;
use anyhow::{anyhow, Context, Result};
use std::{
    env, fs,
    path::{Path, PathBuf},
};

const RELEASE_OWNER: &str = "stupeak";
const RELEASE_REPO: &str = "refab";
const PLUGIN_FILE_NAME: &str = "Refab.rbxm";

pub fn install_plugin() -> Result<PathBuf> {
    let url = plugin_download_url();
    let target = roblox_plugins_dir()?.join(PLUGIN_FILE_NAME);

    println!("Installing Refab Studio plugin v{CLI_VERSION}...");
    println!("Target: {}", target.display());

    let response = reqwest::blocking::get(&url).with_context(|| {
        format!(
            "Could not download {PLUGIN_FILE_NAME}. Check your internet connection and try again."
        )
    })?;

    let status = response.status();
    if !status.is_success() {
        if status.as_u16() == 404 {
            return Err(anyhow!(
                "{PLUGIN_FILE_NAME} was not found for release v{CLI_VERSION}. Make sure the GitHub release exists and includes {PLUGIN_FILE_NAME}."
            ));
        }

        return Err(anyhow!(
            "GitHub returned HTTP {status} while downloading {PLUGIN_FILE_NAME}."
        ));
    }

    let bytes = response
        .bytes()
        .with_context(|| format!("Could not read the downloaded {PLUGIN_FILE_NAME} file."))?;

    if bytes.is_empty() {
        return Err(anyhow!("Downloaded {PLUGIN_FILE_NAME} was empty."));
    }

    let target_dir = target
        .parent()
        .ok_or_else(|| anyhow!("Roblox Plugins folder path was invalid"))?;
    fs::create_dir_all(target_dir).with_context(|| {
        format!(
            "Could not create the Roblox Plugins folder at {}",
            target_dir.display()
        )
    })?;
    fs::write(&target, bytes).with_context(|| {
        format!(
            "Could not write {PLUGIN_FILE_NAME} to {}. Close Roblox Studio and try again.",
            target.display()
        )
    })?;

    Ok(target)
}

fn plugin_download_url() -> String {
    format!(
        "https://github.com/{RELEASE_OWNER}/{RELEASE_REPO}/releases/download/v{CLI_VERSION}/{PLUGIN_FILE_NAME}"
    )
}

fn roblox_plugins_dir() -> Result<PathBuf> {
    if cfg!(target_os = "windows") {
        let local_app_data =
            env::var_os("LOCALAPPDATA").ok_or_else(|| anyhow!("LOCALAPPDATA was not set"))?;
        return Ok(Path::new(&local_app_data).join("Roblox").join("Plugins"));
    }

    if cfg!(target_os = "macos") {
        let home = env::var_os("HOME").ok_or_else(|| anyhow!("HOME was not set"))?;
        return Ok(Path::new(&home)
            .join("Library")
            .join("Application Support")
            .join("Roblox")
            .join("Plugins"));
    }

    let home = env::var_os("HOME").ok_or_else(|| anyhow!("HOME was not set"))?;
    Ok(Path::new(&home)
        .join(".local")
        .join("share")
        .join("Roblox")
        .join("Plugins"))
}
