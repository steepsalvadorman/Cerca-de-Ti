use std::env;

use crate::features::technician::infrastructure::R2Config;

pub struct AppConfig {
    pub database_url: String,
    pub jwt_secret: String,
    pub port: u16,
    /// Origins allowed to call the API via CORS (e.g. a future admin web
    /// panel). Defaults to empty — the app is mobile-only today, and
    /// mobile clients aren't subject to CORS, so "no origins configured"
    /// is the safe default rather than an error to `.expect()` on.
    pub cors_allowed_origins: Vec<String>,
    /// `None` until the document bucket is provisioned. Uploads then
    /// answer 503 instead of the server refusing to start — every other
    /// feature works without it.
    pub r2: Option<R2Config>,
}

impl AppConfig {
    pub fn from_env() -> Self {
        Self {
            database_url: env::var("DATABASE_URL")
                .expect("DATABASE_URL must be set (see backend/.env.example)"),
            jwt_secret: env::var("JWT_SECRET")
                .expect("JWT_SECRET must be set (see backend/.env.example)"),
            port: env::var("PORT")
                .ok()
                .and_then(|p| p.parse().ok())
                .unwrap_or(8080),
            cors_allowed_origins: env::var("CORS_ALLOWED_ORIGINS")
                .unwrap_or_default()
                .split(',')
                .map(|s| s.trim().to_string())
                .filter(|s| !s.is_empty())
                .collect(),
            r2: r2_from_env(),
        }
    }
}

/// All four R2 variables or none — a half-configured bucket would fail
/// at upload time with a signature error that says nothing useful.
fn r2_from_env() -> Option<R2Config> {
    Some(R2Config {
        account_id: non_empty("R2_ACCOUNT_ID")?,
        access_key_id: non_empty("R2_ACCESS_KEY_ID")?,
        secret_access_key: non_empty("R2_SECRET_ACCESS_KEY")?,
        bucket: non_empty("R2_BUCKET_NAME")?,
    })
}

fn non_empty(key: &str) -> Option<String> {
    env::var(key).ok().map(|v| v.trim().to_string()).filter(|v| !v.is_empty())
}
