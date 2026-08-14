use anyhow::{anyhow, Result};
use std::env;

mod app;
mod assets;
mod paths;
mod server;

use app::App;
use server::{serve, status_payload};

fn main() {
    if let Err(error) = run() {
        eprintln!("error: {error:#}");
        std::process::exit(1);
    }
}

fn run() -> Result<()> {
    let command = env::args().nth(1).unwrap_or_else(|| "serve".to_owned());
    let app = App::discover(env::current_dir()?)?;
    app.ensure_project_folders()?;

    match command.as_str() {
        "serve" => serve(app),
        "status" => print_json(&status_payload(&app)?),
        "scan" => print_json(&serde_json::json!({
            "ok": true,
            "assets": app.scan_assets()?,
        })),
        _ => Err(anyhow!(
            "unknown command: {command}\nusage: refab serve|status|scan"
        )),
    }
}

fn print_json(payload: &serde_json::Value) -> Result<()> {
    println!("{}", serde_json::to_string_pretty(payload)?);
    Ok(())
}
