use thiserror::Error;

#[derive(Debug, Error, Clone)]
pub enum TrackingError {
    /// The job does not exist — distinct from "not yours" (403) for the
    /// same reason as in chat (GAP-43).
    #[error("job request not found")]
    JobNotFound,

    #[error("location not found")]
    LocationNotFound,

    #[error("unauthorized tracking access")]
    Unauthorized,

    #[error("este trabajo ya no acepta ubicación")]
    JobClosed,

    #[error("la ubicación en vivo solo está disponible con el trabajo en curso")]
    NotActive,

    #[error("database error: {0}")]
    Repository(String),
}
