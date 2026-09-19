use thiserror::Error;

#[derive(Debug, Error, Clone)]
pub enum ChatError {
    /// The job does not exist.
    ///
    /// Separate from `Unauthorized` because the two answer different
    /// questions: "there is no such job" (404) and "this job is not yours"
    /// (403). Sharing one variant meant a valid UUID that simply did not
    /// exist came back as 403, which tells a client to check its
    /// permissions when the real problem is a stale link (GAP-43).
    #[error("job request not found")]
    JobNotFound,

    #[error("unauthorized chat access")]
    Unauthorized,

    #[error("este trabajo ya no acepta mensajes")]
    JobClosed,

    #[error("el trabajo terminó — el chat es de solo lectura")]
    ReadOnly,

    #[error("database error: {0}")]
    Repository(String),
}
