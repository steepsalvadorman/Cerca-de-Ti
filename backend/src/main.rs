use std::sync::Arc;

use backend::config::AppConfig;
use backend::features::auth::application::IdentityVerifier;
use backend::features::auth::infrastructure::{
    Argon2PasswordHasher, GoogleIdentityVerifier, JwtTokenService, PostgresUserRepository,
    UnconfiguredIdentityVerifier,
};
use backend::features::technician::application::ObjectStorage;
use backend::features::technician::infrastructure::{
    PostgresTechnicianRepository, S3ObjectStorage, UnconfiguredObjectStorage,
};
use backend::features::client::infrastructure::PostgresClientRepository;
use backend::features::job::infrastructure::PostgresJobRepository;
use backend::features::chat::infrastructure::PostgresChatRepository;
use backend::features::tracking::infrastructure::PostgresTrackingRepository;
use backend::state::AppState;
use backend::{db, routes};

#[tokio::main]
async fn main() {
    // Ignore the error: in Docker/production env vars are set directly
    // and there is no .env file to load.
    let _ = dotenvy::dotenv();

    tracing_subscriber::fmt()
        .with_env_filter(
            std::env::var("RUST_LOG").unwrap_or_else(|_| "backend=debug,tower_http=debug".into()),
        )
        .init();

    let config = AppConfig::from_env();

    let pool = db::create_pool(&config.database_url)
        .await
        .expect("failed to connect to Postgres — is it running? see backend/docker-compose.yml");

    sqlx::migrate!("./migrations")
        .run(&pool)
        .await
        .expect("failed to run database migrations");

    let object_storage: Arc<dyn ObjectStorage> = match config.storage {
        Some(storage) => Arc::new(S3ObjectStorage::new(storage)),
        None => {
            tracing::warn!("object storage is not configured — technician document uploads will answer 503");
            Arc::new(UnconfiguredObjectStorage)
        }
    };

    let identity_verifier: Arc<dyn IdentityVerifier> = if config.google_client_ids.is_empty() {
        tracing::warn!("GOOGLE_CLIENT_IDS is not set — sign-in with Google will answer 503");
        Arc::new(UnconfiguredIdentityVerifier)
    } else {
        Arc::new(GoogleIdentityVerifier::new(config.google_client_ids.clone()))
    };

    let state = AppState {
        user_repository: Arc::new(PostgresUserRepository::new(pool.clone())),
        password_hasher: Arc::new(Argon2PasswordHasher),
        token_service: Arc::new(JwtTokenService::new(&config.jwt_secret)),
        identity_verifier,
        technician_repository: Arc::new(PostgresTechnicianRepository::new(pool.clone())),
        client_repository: Arc::new(PostgresClientRepository::new(pool.clone())),
        job_repository: Arc::new(PostgresJobRepository::new(pool.clone())),
        chat_repository: Arc::new(PostgresChatRepository::new(pool.clone())),
        tracking_repository: Arc::new(PostgresTrackingRepository::new(pool)),
        object_storage,
    };

    let app = routes::app_router(state, &config.cors_allowed_origins);

    let listener = tokio::net::TcpListener::bind(("0.0.0.0", config.port))
        .await
        .expect("failed to bind to port");

    tracing::info!("listening on port {}", config.port);

    axum::serve(listener, app).await.expect("server error");
}
