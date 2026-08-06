use thiserror::Error;

#[derive(Debug, Error, Clone)]
pub enum JobError {
    #[error("job request not found")]
    JobNotFound,

    #[error("job offer not found")]
    OfferNotFound,

    #[error("invalid job status or transition")]
    InvalidStatusTransition,

    #[error("unauthorized operation")]
    Unauthorized,

    #[error("ya enviaste una oferta para este trabajo")]
    OfferAlreadySubmitted,

    #[error("la oferta no es válida: revisa el precio y el tiempo estimado")]
    InvalidOffer,

    #[error("database error: {0}")]
    Repository(String),
}
