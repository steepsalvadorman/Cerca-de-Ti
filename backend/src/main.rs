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
use backend::features::job::infrastructure::{
    FakePaymentGateway, PostgresJobRepository, UnconfiguredPaymentGateway,
};
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

    let user_repository = Arc::new(PostgresUserRepository::new(pool.clone()));

    // Deployment guard: migration 0002 seeded five accounts whose password
    // hash is public knowledge (it is in this repository), and
    // `sqlx::migrate!` runs at every startup — so a deployed database could
    // be carrying a working `client@cerca.com` / `password123` login that
    // hands out a 7-day session (GAP-113). Migration 0011 nulls those
    // hashes, which is why this runs *after* migrating: an up-to-date
    // database passes, and one that somehow reintroduced the hash refuses
    // to serve traffic instead of quietly accepting logins.
    if config.is_production() && config.payments_mode == "fake" {
        panic!(
            "refusing to start with APP_ENV=production and PAYMENTS_MODE=fake — \
             fee payments would be simulated with no money collected. \
             Wire a real payment adapter or leave PAYMENTS_MODE unset in production. \
             See GAP-14 in docs/qa/plan-de-solucion-vacios.md."
        );
    }

    if config.is_production() {
        // `UserRepository` has to be in scope for the trait method.
        use backend::features::auth::domain::UserRepository as _;

        let still_seeded = user_repository
            .count_with_password_hash(backend::features::auth::domain::DEMO_SEED_PASSWORD_HASH)
            .await
            .expect("could not check for leftover demo accounts");

        if still_seeded > 0 {
            panic!(
                "refusing to start with APP_ENV=production: {still_seeded} account(s) still use the \
                 publicly-known demo password seeded by migration 0002. Run the migrations (0011 \
                 nulls those hashes) or set a real password for every account in question. \
                 See GAP-113 in docs/qa/plan-de-solucion-vacios.md."
            );
        }
    }

    let object_storage: Arc<dyn ObjectStorage> = match config.storage {
        Some(storage) => Arc::new(S3ObjectStorage::new(storage)),
        None => {
            tracing::warn!("object storage is not configured — technician document uploads will answer 503");
            Arc::new(UnconfiguredObjectStorage)
        }
    };

    let payment_gateway: Arc<dyn backend::features::job::application::PaymentGateway> =
        if config.payments_mode == "fake" {
            Arc::new(FakePaymentGateway)
        } else {
            tracing::warn!(
                "PAYMENTS_MODE={} — fee payments will answer 503 until a real adapter is wired",
                config.payments_mode
            );
            Arc::new(UnconfiguredPaymentGateway)
        };

    let identity_verifier: Arc<dyn IdentityVerifier> = if config.google_client_ids.is_empty() {
        tracing::warn!("GOOGLE_CLIENT_IDS is not set — sign-in with Google will answer 503");
        Arc::new(UnconfiguredIdentityVerifier)
    } else {
        Arc::new(GoogleIdentityVerifier::new(config.google_client_ids.clone()))
    };

    let state = AppState {
        user_repository,
        password_hasher: Arc::new(Argon2PasswordHasher),
        token_service: Arc::new(JwtTokenService::new(&config.jwt_secret)),
        identity_verifier,
        technician_repository: Arc::new(PostgresTechnicianRepository::new(pool.clone())),
        client_repository: Arc::new(PostgresClientRepository::new(pool.clone())),
        job_repository: Arc::new(PostgresJobRepository::new(pool.clone())),
        payment_gateway,
        chat_repository: Arc::new(PostgresChatRepository::new(pool.clone())),
        tracking_repository: Arc::new(PostgresTrackingRepository::new(pool)),
        object_storage,
    };

    let app = routes::app_router(state, &config.cors_allowed_origins);

    let listener = tokio::net::TcpListener::bind(("0.0.0.0", config.port))
        .await
        .expect("failed to bind to port");

    tracing::info!("listening on port {}", config.port);

    // `into_make_service_with_connect_info` is what puts the peer address
    // into the request extensions, which is how the rate limiter tells
    // callers apart. Without it every request would share one bucket and
    // the first burst would lock out everybody — see
    // `shared::rate_limit::enforce`.
    axum::serve(
        listener,
        app.into_make_service_with_connect_info::<std::net::SocketAddr>(),
    )
    .await
    .expect("server error");
}
