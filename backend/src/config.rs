use std::env;

pub struct AppConfig {
    pub database_url: String,
    pub jwt_secret: String,
    pub port: u16,
    /// Origins allowed to call the API via CORS (e.g. a future admin web
    /// panel). Defaults to empty — the app is mobile-only today, and
    /// mobile clients aren't subject to CORS, so "no origins configured"
    /// is the safe default rather than an error to `.expect()` on.
    pub cors_allowed_origins: Vec<String>,
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
        }
    }
}
