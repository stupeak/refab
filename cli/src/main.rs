use anyhow::{anyhow, Result};
use std::env;
use std::io::{Read, Write};
use std::net::TcpStream;

use refab::{
    app::App,
    server::{helper_port, run_helper, status_payload},
    version::CLI_VERSION,
};

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
    println!("Refab asset workflow CLI for Roblox projects");
    println!();
    println!("Usage: refab [OPTIONS] [COMMAND]");
    println!();
    println!("Commands:");
    println!("  run      Starts local asset sync");
    println!("  stop     Stops local asset sync");
    println!("  status   Prints project status as JSON");
    println!("  scan     Lists local asset files as JSON");
    println!("  version  Prints the Refab CLI version");
    println!("  help     Print this message or the help of the given command(s)");
    println!();
    println!("Options:");
    println!("  -h, --help     Print help");
    println!("  -V, --version  Print version");
}

fn stop_helper() -> Result<()> {
    let port = helper_port();
    let mut stream = TcpStream::connect(("127.0.0.1", port))
        .map_err(|_| anyhow!("Refab is not running on 127.0.0.1:{port}"))?;
    stream.write_all(
        b"POST /shutdown HTTP/1.1\r\nHost: 127.0.0.1\r\nContent-Length: 0\r\nConnection: close\r\n\r\n",
    )?;

    let mut response = String::new();
    stream.read_to_string(&mut response)?;
    if response.starts_with("HTTP/1.1 200") || response.starts_with("HTTP/1.0 200") {
        println!("Refab stopped");
        Ok(())
    } else {
        Err(anyhow!("Refab refused to stop"))
    }
}

fn print_json(payload: &serde_json::Value) -> Result<()> {
    println!("{}", serde_json::to_string_pretty(payload)?);
    Ok(())
}
