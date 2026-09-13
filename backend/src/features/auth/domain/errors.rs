use thiserror::Error;

/// Domain-level failures for the auth feature. Interfaces map these to
/// HTTP status codes; nothing in here knows about HTTP.
#[derive(Debug, Error)]
pub enum AuthError {
    #[error("that email is already registered")]
    EmailAlreadyExists,
    #[error("invalid email or password")]
    InvalidCredentials,
    #[error("invalid email address")]
    InvalidEmail,
    #[error("role must be 'client' or 'technician'")]
    InvalidRole,
    #[error("password must be at least 8 characters")]
    WeakPassword,
    #[error("this account signs in with Google")]
    PasswordLoginUnavailable,
    #[error("could not verify that Google account")]
    InvalidProviderToken,
    #[error("that Google account has no verified email address")]
    ProviderEmailUnverified,
    #[error("choose whether you are a client or a technician to finish signing up")]
    RoleRequired,
    #[error("sign-in with Google is not available right now")]
    ProviderUnavailable,
    #[error("could not process the password")]
    Hashing,
    #[error("could not issue a session token")]
    Token,
    #[error("unexpected repository failure: {0}")]
    Repository(String),
}
