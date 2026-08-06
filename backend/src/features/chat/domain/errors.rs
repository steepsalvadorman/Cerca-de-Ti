use thiserror::Error;

#[derive(Debug, Error, Clone)]
pub enum ChatError {
    #[error("unauthorized chat access")]
    Unauthorized,

    #[error("la tarifa de contacto de Cerca aún no está pagada")]
    FeeNotPaid,

    #[error("database error: {0}")]
    Repository(String),
}
