use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use crate::features::auth::application::AuthenticatedUser;
use crate::features::auth::domain::User;
use crate::shared::{validation, AppError};

/// Upper bounds for credentials (GAP-02, GAP-123).
///
/// The lower bound on a password is a domain rule (`WeakPassword`); these
/// are the ceilings, which nothing enforced: `name` was stored verbatim on
/// the password path while the Google path already trimmed and rejected
/// blanks, and a password had no maximum at all — so the cost of hashing
/// an arbitrarily large string was the server's to pay.
pub const MAX_EMAIL_CHARS: usize = 254;
pub const MAX_NAME_CHARS: usize = 120;
pub const MAX_PASSWORD_CHARS: usize = 128;

#[derive(Deserialize)]
pub struct RegisterRequest {
    pub email: String,
    pub password: String,
    pub name: String,
    pub role: String,
}

impl RegisterRequest {
    pub fn validate(&self) -> Result<(), AppError> {
        validation::required_text("email", &self.email, MAX_EMAIL_CHARS)?;
        validation::required_text("name", &self.name, MAX_NAME_CHARS)?;
        validation::one_of("role", &self.role, &["client", "technician"])?;

        // Not trimmed: leading or trailing whitespace can be part of a
        // password on purpose. Only its length is bounded.
        if self.password.chars().count() > MAX_PASSWORD_CHARS {
            return Err(AppError::Validation(format!(
                "la contraseña no puede superar los {MAX_PASSWORD_CHARS} caracteres"
            )));
        }

        Ok(())
    }
}

#[derive(Deserialize)]
pub struct LoginRequest {
    pub email: String,
    pub password: String,
}

impl LoginRequest {
    /// Deliberately minimal: `/auth/login` must not tell a caller whether
    /// an address is well-formed, only whether the credentials match. A
    /// length cap is safe because it cannot distinguish a real account
    /// from a fake one.
    pub fn validate(&self) -> Result<(), AppError> {
        if self.email.chars().count() > MAX_EMAIL_CHARS
            || self.password.chars().count() > MAX_PASSWORD_CHARS
        {
            return Err(AppError::Validation("credenciales no válidas".to_string()));
        }
        Ok(())
    }
}

#[derive(Deserialize)]
pub struct GoogleSignInRequest {
    /// The ID token from the Google Sign-In SDK on the device.
    pub id_token: String,
    /// Sent only when the app already knows which side of the app the
    /// person belongs to. A first-time account without it comes back as
    /// 422 so the app can ask and retry.
    #[serde(default)]
    pub role: Option<String>,
}

#[derive(Serialize)]
pub struct UserResponse {
    pub id: Uuid,
    pub email: String,
    pub name: String,
    pub role: String,
    pub created_at: DateTime<Utc>,
}

impl From<&User> for UserResponse {
    fn from(user: &User) -> Self {
        Self {
            id: user.id,
            email: user.email.as_str().to_string(),
            name: user.name.clone(),
            role: user.role.as_str().to_string(),
            created_at: user.created_at,
        }
    }
}

#[derive(Serialize)]
pub struct AuthResponse {
    pub token: String,
    pub user: UserResponse,
}

impl From<AuthenticatedUser> for AuthResponse {
    fn from(authenticated: AuthenticatedUser) -> Self {
        Self {
            user: UserResponse::from(&authenticated.user),
            token: authenticated.token,
        }
    }
}
