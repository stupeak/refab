use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct AssetSummary {
    pub id: String,
    pub name: String,
    pub source: String,
    pub target: String,
    pub class_name: String,
    pub hash: String,
    pub size: u64,
    pub status: AssetState,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub enum AssetState {
    Clean,
    New,
    Changed,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct WriteAssetRequest {
    pub name: Option<String>,
    pub source: String,
    pub target: Option<String>,
    pub class_name: Option<String>,
    pub data_base64: String,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CompareAssetRequest {
    pub source: String,
    pub data_base64: String,
}
