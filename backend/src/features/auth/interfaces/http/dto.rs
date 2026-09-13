use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use crate::features::auth::application::AuthenticatedUser;
use crate::features::auth::domain::User;

#[derive(Deserialize)]
pub struct RegisterRequest {
    pub email: String,
    pub password: String,
    pub name: String,
    pub role: String,
}

#[derive(Deserialize)]
pub struct LoginRequest {
    pub email: String,
    pub password: String,
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
