use anyhow::{anyhow, Result};
use std::env;
use std::io::{Read, Write};
use std::net::TcpStream;

mod app;
mod assets;
mod paths;
mod server;
mod version;

use app::App;
use server::{helper_port, run_helper, status_payload};
use version::CLI_VERSION;

fn main() {
    if let Err(error) = run() {
        eprintln!("error: {error:#}");
        std::process::exit(1);
    }
}

fn run() -> Result<()> {
    let Some(command) = env::args().nth(1) else {
        print_usage();
        return Ok(());
    };

    match command.as_str() {
        "--version" | "-V" | "version" => {
            println!("refab {CLI_VERSION}");
            return Ok(());
        }
        "--help" | "-h" | "help" => {
            print_usage();
            return Ok(());
        }
        "stop" => {
            stop_helper()?;
            return Ok(());
        }
        _ => {}
    }

    let app = App::discover(env::current_dir()?)?;
    app.ensure_project_folders()?;

    match command.as_str() {
        "run" | "serve" => run_helper(app),
        "status" => print_json(&status_payload(&app)?),
        "scan" => print_json(&serde_json::json!({
            "ok": true,
            "assets": app.scan_assets()?,
        })),
        _ => Err(anyhow!(
            "unknown command: {command}\nusage: refab run|status|scan|version|stop"
        )),
    }
}

fn print_usage() {
    println!("Refab {CLI_VERSION}");
    println!("Asset workflow helper for Roblox projects");
    println!();
    println!("Usage: refab [OPTIONS] [COMMAND]");
    println!();
    println!("Commands:");
    println!("  run      Starts the local helper server");
    println!("  stop     Stops the local helper server");
    println!("  status   Prints helper project status as JSON");
    println!("  scan     Lists local assets as JSON");
    println!("  version  Prints the Refab CLI version");
    println!("  help     Prints this message");
    println!();
    println!("Options:");
    println!("  -h, --help     Print help");
    println!("  -V, --version  Print version");
}

fn stop_helper() -> Result<()> {
    let port = helper_port();
    let mut stream = TcpStream::connect(("127.0.0.1", port))
        .map_err(|_| anyhow!("Refab helper is not running on 127.0.0.1:{port}"))?;
    stream.write_all(
        b"POST /shutdown HTTP/1.1\r\nHost: 127.0.0.1\r\nContent-Length: 0\r\nConnection: close\r\n\r\n",
    )?;

    let mut response = String::new();
    stream.read_to_string(&mut response)?;
    if response.starts_with("HTTP/1.1 200") || response.starts_with("HTTP/1.0 200") {
        println!("Refab helper stopped");
        Ok(())
    } else {
        Err(anyhow!("Refab helper refused to stop"))
    }
}

fn print_json(payload: &serde_json::Value) -> Result<()> {
    println!("{}", serde_json::to_string_pretty(payload)?);
    Ok(())
}
