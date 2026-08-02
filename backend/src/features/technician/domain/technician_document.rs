use serde::{Deserialize, Serialize};
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum DocStatus {
    Uploaded,
    Pending,
}

impl DocStatus {
    pub fn as_str(&self) -> &'static str {
        match self {
            DocStatus::Uploaded => "uploaded",
            DocStatus::Pending => "pending",
        }
    }

    pub fn parse(raw: &str) -> Result<Self, String> {
        match raw {
            "uploaded" => Ok(DocStatus::Uploaded),
            "pending" => Ok(DocStatus::Pending),
            _ => Err(format!("invalid document status: {raw}")),
        }
    }
}

/// The set of documents a technician can be asked for. Kept here rather
/// than accepting any string, so a caller cannot invent document keys and
/// fill the table (and the bucket) with arbitrary entries.
///
/// `seguro` is optional — see `MANDATORY_DOCUMENT_KEYS`, which drives
/// automatic verification once the required ones are in.
pub const DOCUMENT_KEYS: [&str; 4] = ["cedula", "antecedentes", "especialidad", "seguro"];

pub const MANDATORY_DOCUMENT_KEYS: [&str; 3] = ["cedula", "antecedentes", "especialidad"];

pub fn is_valid_document_key(key: &str) -> bool {
    DOCUMENT_KEYS.contains(&key)
}

// id/technician_profile_id are populated from the DB row but not read yet —
// the handlers serialize the checklist, not the storage bookkeeping.
#[allow(dead_code)]
#[derive(Debug, Clone)]
pub struct TechnicianDocument {
    pub id: Uuid,
    pub technician_profile_id: i32,
    pub document_key: String,
    pub status: DocStatus,
    /// Object key in the bucket. `None` for rows that predate real file
    /// uploads, or whose upload slot was never requested.
    pub storage_key: Option<String>,
    pub content_type: Option<String>,
    pub original_filename: Option<String>,
    pub uploaded_at: Option<chrono::DateTime<chrono::Utc>>,
}
