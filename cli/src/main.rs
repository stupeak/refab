use anyhow::{anyhow, Context, Result};
use base64::{engine::general_purpose, Engine as _};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::{
    env, fs,
    path::{Path, PathBuf},
};
use tiny_http::{Header, Method, Request, Response, Server, StatusCode};
use url::Url;
use walkdir::WalkDir;

const DEFAULT_PORT: u16 = 34874;
const ASSETS_DIR: &str = "assets";

#[derive(Debug, Clone)]
struct App {
    project_root: PathBuf,
    assets_root: PathBuf,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
struct AssetSummary {
    id: String,
    name: String,
    source: String,
    target: String,
    class_name: String,
    hash: String,
    size: u64,
    status: AssetState,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
enum AssetState {
    Clean,
    New,
    Changed,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct WriteAssetRequest {
    name: Option<String>,
    source: String,
    target: Option<String>,
    class_name: Option<String>,
    data_base64: String,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct CompareAssetRequest {
    source: String,
    data_base64: String,
}

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

impl App {
    fn discover(start: PathBuf) -> Result<Self> {
        let project_root = find_project_root(&start);
        Ok(Self {
            assets_root: project_root.join(ASSETS_DIR),
            project_root,
        })
    }

    fn ensure_project_folders(&self) -> Result<()> {
        fs::create_dir_all(&self.assets_root)?;
        Ok(())
    }

    fn scan_assets(&self) -> Result<Vec<AssetSummary>> {
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
            let hash = sha256_hex(&bytes);

            assets.push(AssetSummary {
                id: source.clone(),
                name: asset_name(&relative),
                source: source.clone(),
                target: infer_target(&relative),
                class_name: "rbxm".to_owned(),
                hash,
                size: bytes.len() as u64,
                status: AssetState::Clean,
            });
        }

        assets.sort_by(|a, b| a.source.cmp(&b.source));
        Ok(assets)
    }

    fn asset_absolute_path(&self, source: &str) -> Result<PathBuf> {
        let relative = normalize_asset_source(source)?;
        let absolute = self.assets_root.join(relative).canonicalize_or_intended();
        let relative_from_assets = absolute
            .strip_prefix(&self.assets_root.canonicalize_or_intended())
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

trait CanonicalizeOrIntended {
    fn canonicalize_or_intended(&self) -> PathBuf;
}

impl CanonicalizeOrIntended for Path {
    fn canonicalize_or_intended(&self) -> PathBuf {
        self.canonicalize().unwrap_or_else(|_| self.to_path_buf())
    }
}

fn find_project_root(start: &Path) -> PathBuf {
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

fn serve(app: App) -> Result<()> {
    let port = env::var("REFAB_PORT")
        .ok()
        .and_then(|value| value.parse::<u16>().ok())
        .unwrap_or(DEFAULT_PORT);
    let address = format!("127.0.0.1:{port}");
    let server = Server::http(&address).map_err(|error| anyhow!("{error}"))?;

    println!("Refab helper listening on http://{address}");
    println!("Project root: {}", app.project_root.display());
    println!("Assets root:  {}", app.assets_root.display());

    for request in server.incoming_requests() {
        if let Err(error) = handle_request(&app, request) {
            eprintln!("request error: {error:#}");
        }
    }

    Ok(())
}

fn handle_request(app: &App, mut request: Request) -> Result<()> {
    let method = request.method().clone();
    let url = Url::parse(&format!("http://localhost{}", request.url()))?;
    let path = url.path().to_owned();

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
        _ => Ok(serde_json::json!({
            "ok": false,
            "message": format!("Unknown route: {} {}", request.method(), url.path()),
        })),
    };

    match result {
        Ok(payload) => respond_json(request, 200, payload),
        Err(error) => respond_json(
            request,
            500,
            serde_json::json!({
                "ok": false,
                "message": error.to_string(),
            }),
        ),
    }
}

fn status_payload(app: &App) -> Result<serde_json::Value> {
    Ok(serde_json::json!({
        "ok": true,
        "projectRoot": slash(&app.project_root),
        "assetsRoot": slash(&app.assets_root),
        "assetCount": app.scan_assets()?.len(),
    }))
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
        slash(absolute.strip_prefix(&app.assets_root.canonicalize_or_intended())?)
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

    let relative = slash(absolute.strip_prefix(&app.assets_root.canonicalize_or_intended())?);
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

fn print_json(payload: &serde_json::Value) -> Result<()> {
    println!("{}", serde_json::to_string_pretty(payload)?);
    Ok(())
}

fn normalize_asset_source(source: &str) -> Result<PathBuf> {
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

fn infer_target(source: &str) -> String {
    source
        .replace('\\', "/")
        .trim_end_matches(".rbxm")
        .trim_end_matches(".rbxmx")
        .split('/')
        .filter(|part| !part.is_empty())
        .collect::<Vec<_>>()
        .join(".")
}

fn asset_name(source: &str) -> String {
    Path::new(source)
        .file_stem()
        .and_then(|stem| stem.to_str())
        .unwrap_or("Asset")
        .to_owned()
}

fn is_asset_file(path: &Path) -> bool {
    path.extension()
        .and_then(|extension| extension.to_str())
        .map(|extension| matches!(extension.to_ascii_lowercase().as_str(), "rbxm" | "rbxmx"))
        .unwrap_or(false)
}

fn sha256_hex(bytes: &[u8]) -> String {
    format!("{:x}", Sha256::digest(bytes))
}

fn slash(path: impl AsRef<Path>) -> String {
    path.as_ref()
        .to_string_lossy()
        .trim_start_matches(r"\\?\")
        .replace('\\', "/")
}
