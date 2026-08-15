use crate::{
    app::App,
    assets::{AssetState, AssetSummary, CompareAssetRequest, WriteAssetRequest},
    paths::{asset_name, infer_target, sha256_hex, slash, CanonicalizeOrIntended, ASSETS_DIR},
    version::{CLI_VERSION, PROTOCOL_VERSION},
};
use anyhow::{anyhow, Context, Result};
use base64::{engine::general_purpose, Engine as _};
use std::{env, fs};
use tiny_http::{Header, Method, Request, Response, Server, StatusCode};
use url::Url;

pub const DEFAULT_PORT: u16 = 34874;

pub fn helper_port() -> u16 {
    env::var("REFAB_PORT")
        .ok()
        .and_then(|value| value.parse::<u16>().ok())
        .unwrap_or(DEFAULT_PORT)
}

pub fn run_helper(app: App) -> Result<()> {
    let port = helper_port();
    let address = format!("127.0.0.1:{port}");
    let server = Server::http(&address).map_err(|error| anyhow!("{error}"))?;

    println!("Refab listening on http://{address}");
    println!("Project root: {}", app.project_root.display());
    println!("Assets root:  {}", app.assets_root.display());

    for request in server.incoming_requests() {
        match handle_request(&app, request) {
            Ok(should_stop) if should_stop => break,
            Ok(_) => {}
            Err(error) => eprintln!("request error: {error:#}"),
        }
    }

    Ok(())
}

pub fn status_payload(app: &App) -> Result<serde_json::Value> {
    Ok(serde_json::json!({
        "ok": true,
        "cliVersion": CLI_VERSION,
        "protocolVersion": PROTOCOL_VERSION,
        "projectRoot": slash(&app.project_root),
        "assetsRoot": slash(&app.assets_root),
        "assetCount": app.scan_assets()?.len(),
    }))
}

fn handle_request(app: &App, mut request: Request) -> Result<bool> {
    let method = request.method().clone();
    let url = Url::parse(&format!("http://localhost{}", request.url()))?;
    let path = url.path().to_owned();
    let mut should_stop = false;

    let result = match (method, path.as_str()) {
        (Method::Get, "/status") => status_payload(app),
        (Method::Get, "/assets") => Ok(serde_json::json!({
            "ok": true,
            "assets": app.scan_assets()?,
        })),
        (Method::Get, "/assets/read") => handle_read_asset(app, &url),
        (Method::Post, "/assets/compare") => handle_compare_asset(app, &mut request),
        (Method::Post, "/assets/write") => handle_write_asset(app, &mut request),
        (Method::Post, "/rescan") => Ok(serde_json::json!({
            "ok": true,
            "assets": app.scan_assets()?,
        })),
        (Method::Post, "/shutdown") => {
            should_stop = true;
            Ok(serde_json::json!({
                "ok": true,
                "message": "Refab stopped",
            }))
        }
        _ => Ok(serde_json::json!({
            "ok": false,
            "message": format!("Unknown route: {} {}", request.method(), url.path()),
        })),
    };

    match result {
        Ok(payload) => respond_json(request, 200, payload)?,
        Err(error) => respond_json(
            request,
            500,
            serde_json::json!({
                "ok": false,
                "message": error.to_string(),
            }),
        )?,
    };

    Ok(should_stop)
}

fn handle_read_asset(app: &App, url: &Url) -> Result<serde_json::Value> {
    let source = url
        .query_pairs()
        .find_map(|(key, value)| (key == "path").then(|| value.into_owned()))
        .ok_or_else(|| anyhow!("path query parameter is required"))?;
    let absolute = app.asset_absolute_path(&source)?;
    if !absolute.exists() {
        return Ok(serde_json::json!({
            "ok": false,
            "message": format!("Asset not found: {source}"),
        }));
    }

    let bytes = fs::read(&absolute)?;
    let normalized_source = format!(
        "{ASSETS_DIR}/{}",
        slash(absolute.strip_prefix(app.assets_root.canonicalize_or_intended())?)
    );
    let asset = app
        .scan_assets()?
        .into_iter()
        .find(|asset| asset.source == normalized_source);

    Ok(serde_json::json!({
        "ok": true,
        "asset": asset,
        "dataBase64": general_purpose::STANDARD.encode(bytes),
    }))
}

fn handle_compare_asset(app: &App, request: &mut Request) -> Result<serde_json::Value> {
    let mut body = String::new();
    request.as_reader().read_to_string(&mut body)?;
    let payload: CompareAssetRequest = serde_json::from_str(&body).context("invalid JSON")?;
    let absolute = app.asset_absolute_path(&payload.source)?;
    let incoming = general_purpose::STANDARD
        .decode(payload.data_base64)
        .context("invalid dataBase64")?;
    let incoming_hash = sha256_hex(&incoming);

    let status = if !absolute.exists() {
        AssetState::New
    } else {
        let local_hash = sha256_hex(&fs::read(&absolute)?);
        if local_hash == incoming_hash {
            AssetState::Clean
        } else {
            AssetState::Changed
        }
    };

    Ok(serde_json::json!({
        "ok": true,
        "source": payload.source,
        "hash": incoming_hash,
        "status": status,
    }))
}

fn handle_write_asset(app: &App, request: &mut Request) -> Result<serde_json::Value> {
    let mut body = String::new();
    request.as_reader().read_to_string(&mut body)?;
    let payload: WriteAssetRequest = serde_json::from_str(&body).context("invalid JSON")?;
    let absolute = app.asset_absolute_path(&payload.source)?;
    let bytes = general_purpose::STANDARD
        .decode(payload.data_base64)
        .context("invalid dataBase64")?;

    if let Some(parent) = absolute.parent() {
        fs::create_dir_all(parent)?;
    }
    fs::write(&absolute, &bytes)?;

    let relative = slash(absolute.strip_prefix(app.assets_root.canonicalize_or_intended())?);
    let source = format!("{ASSETS_DIR}/{relative}");
    let entry = AssetSummary {
        id: source.clone(),
        name: payload.name.unwrap_or_else(|| asset_name(&relative)),
        source: source.clone(),
        target: payload.target.unwrap_or_else(|| infer_target(&relative)),
        class_name: payload.class_name.unwrap_or_else(|| "rbxm".to_owned()),
        hash: sha256_hex(&bytes),
        size: bytes.len() as u64,
        status: AssetState::Clean,
    };

    Ok(serde_json::json!({
        "ok": true,
        "message": format!("Wrote {source}"),
        "asset": entry,
    }))
}

fn respond_json(request: Request, status: u16, payload: serde_json::Value) -> Result<()> {
    let body = serde_json::to_string(&payload)?;
    let response = Response::from_string(body)
        .with_status_code(StatusCode(status))
        .with_header(Header::from_bytes("Content-Type", "application/json").unwrap());
    request
        .respond(response)
        .map_err(|error| anyhow!("{error}"))
}
