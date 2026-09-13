use async_trait::async_trait;
use uuid::Uuid;

use crate::features::auth::domain::{AuthError, Role};

/// Technical capability the use cases need — hashing is a delivery
/// detail (argon2 today), not a domain concept, so it lives as an
/// application-level port rather than on the `User` aggregate.
pub trait PasswordHasher: Send + Sync {
    fn hash(&self, plain: &str) -> Result<String, ()>;
    fn verify(&self, plain: &str, hash: &str) -> Result<bool, ()>;
}

pub struct TokenClaims {
    pub user_id: Uuid,
    pub role: Role,
}

/// Port for issuing/validating session tokens (JWT today).
pub trait TokenService: Send + Sync {
    fn issue(&self, user_id: Uuid, role: Role) -> Result<String, ()>;
    fn verify(&self, token: &str) -> Result<TokenClaims, ()>;
}

/// What an identity provider tells us about the person signing in, once
/// their token has been checked against the provider's public keys.
pub struct VerifiedIdentity {
    /// The provider's own immutable id for the account (`sub`).
    pub subject: String,
    pub email: String,
    pub email_verified: bool,
    pub name: Option<String>,
}

/// Port for checking a provider's ID token. Implemented against Google
/// in infrastructure; the use case never sees a JWKS or an HTTP call.
#[async_trait]
pub trait IdentityVerifier: Send + Sync {
    async fn verify_google_id_token(&self, id_token: &str) -> Result<VerifiedIdentity, AuthError>;
}
