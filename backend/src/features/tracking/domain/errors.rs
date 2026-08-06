use thiserror::Error;

#[derive(Debug, Error, Clone)]
pub enum TrackingError {
    #[error("location not found")]
    LocationNotFound,

    #[error("unauthorized tracking access")]
    Unauthorized,

    #[error("la tarifa de contacto de Cerca aún no está pagada")]
    FeeNotPaid,

    #[error("database error: {0}")]
    Repository(String),
}
