use thiserror::Error;

// TeamNotFound/DocumentNotFound aren't constructed yet — reserved for
// find_team_by_id and document lookups that don't check existence yet.
#[allow(dead_code)]
#[derive(Debug, Error, Clone)]
pub enum TechnicianError {
    #[error("technician profile not found")]
    TechnicianNotFound,

    #[error("tech team not found")]
    TeamNotFound,

    #[error("document not found")]
    DocumentNotFound,

    #[error("invalid document status: {0}")]
    InvalidDocumentStatus(String),

    #[error("unknown document type: {0}")]
    InvalidDocumentKey(String),

    #[error("unsupported file type: {0}")]
    InvalidContentType(String),

    /// The client asked for a URL for one kind of file and something else
    /// (or nothing at all) ended up in the bucket. Verification used to be
    /// a client assertion; this is the error that makes it a server fact.
    #[error("the uploaded file is not what was declared: {0}")]
    DocumentContentMismatch(String),

    /// The stored object is larger than a verification document may be.
    #[error("the uploaded file is too large ({size_bytes} bytes, limit {limit_bytes})")]
    DocumentTooLarge { size_bytes: u64, limit_bytes: u64 },

    #[error("document storage is not configured on this server")]
    StorageUnavailable,

    #[error("database error: {0}")]
    Repository(String),
}
