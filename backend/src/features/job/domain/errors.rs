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

    /// Cerca's whole promise is "verified technicians", and `is_verified`
    /// was only ever a badge in the UI: an unverified account could bid,
    /// win, and be hired. Verification has to gate the action the badge
    /// vouches for, or it means nothing (GAP-05/GAP-20).
    #[error("necesitas completar tu verificación antes de ofertar")]
    TechnicianNotVerified,

    /// Another request changed this job between our read and our write.
    ///
    /// Distinct from `InvalidStatusTransition` on purpose: the transition
    /// may have been perfectly legal when it was decided, and the caller's
    /// information is simply stale. That is retryable (re-read, re-decide),
    /// whereas an illegal transition is not.
    #[error("el trabajo cambió mientras lo actualizabas — vuelve a intentarlo")]
    ConcurrentModification,

    #[error("el pago no pudo completarse")]
    PaymentFailed,

    #[error("el proveedor de pagos no está disponible")]
    PaymentUnavailable,

    #[error("database error: {0}")]
    Repository(String),
}
