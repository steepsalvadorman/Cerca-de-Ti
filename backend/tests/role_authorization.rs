//! Integration tests for role-gated routes, driven through the real
//! router so the auth extractors, JWT verification and status codes are
//! all exercised. `job_lifecycle.rs` covers the use cases directly and
//! deliberately skips the HTTP/auth transport — this file is the other
//! half: it barely cares what a handler does, only who is allowed to
//! reach it.

use std::sync::Arc;

use axum::body::Body;
use axum::http::{Request, StatusCode};
use sqlx::PgPool;
use tower::ServiceExt; // for `oneshot`
use uuid::Uuid;

use backend::features::auth::application::TokenService;
use backend::features::auth::domain::Role;
use backend::features::auth::infrastructure::{Argon2PasswordHasher, JwtTokenService, PostgresUserRepository};
use backend::features::chat::infrastructure::PostgresChatRepository;
use backend::features::client::infrastructure::PostgresClientRepository;
use backend::features::job::infrastructure::PostgresJobRepository;
use backend::features::technician::infrastructure::PostgresTechnicianRepository;
use backend::features::tracking::infrastructure::PostgresTrackingRepository;
use backend::routes::app_router;
use backend::state::AppState;

const TEST_JWT_SECRET: &str = "test-secret-for-role-authorization";

fn test_state(pool: PgPool) -> AppState {
    AppState {
        user_repository: Arc::new(PostgresUserRepository::new(pool.clone())),
        password_hasher: Arc::new(Argon2PasswordHasher),
        token_service: Arc::new(JwtTokenService::new(TEST_JWT_SECRET)),
        technician_repository: Arc::new(PostgresTechnicianRepository::new(pool.clone())),
        client_repository: Arc::new(PostgresClientRepository::new(pool.clone())),
        job_repository: Arc::new(PostgresJobRepository::new(pool.clone())),
        chat_repository: Arc::new(PostgresChatRepository::new(pool.clone())),
        tracking_repository: Arc::new(PostgresTrackingRepository::new(pool)),
    }
}

async fn create_user(pool: &PgPool, role: &str) -> Uuid {
    let id = Uuid::new_v4();
    sqlx::query("INSERT INTO users (id, email, name, role, password_hash) VALUES ($1, $2, 'Test User', $3, 'hash')")
        .bind(id)
        .bind(format!("{id}@test.local"))
        .bind(role)
        .execute(pool)
        .await
        .unwrap();
    id
}

async fn create_technician_profile(pool: &PgPool, user_id: Uuid) {
    sqlx::query(
        "INSERT INTO technician_profiles (user_id, oficio, pin_top, pin_left) VALUES ($1, 'Gasfitero', 0.5, 0.5)",
    )
    .bind(user_id)
    .execute(pool)
    .await
    .unwrap();
}

fn token_for(user_id: Uuid, role: Role) -> String {
    JwtTokenService::new(TEST_JWT_SECRET).issue(user_id, role).unwrap()
}

/// Sends one request through the whole router and returns its status.
/// `token` is `None` for anonymous callers.
async fn status_of(
    pool: &PgPool,
    method: &str,
    path: &str,
    token: Option<&str>,
    body: Option<&'static str>,
) -> StatusCode {
    let mut request = Request::builder().method(method).uri(path);
    if let Some(token) = token {
        request = request.header("Authorization", format!("Bearer {token}"));
    }
    if body.is_some() {
        request = request.header("Content-Type", "application/json");
    }

    let request = request
        .body(body.map_or_else(Body::empty, Body::from))
        .unwrap();

    app_router(test_state(pool.clone()), &[])
        .oneshot(request)
        .await
        .unwrap()
        .status()
}

#[sqlx::test(migrations = "./migrations")]
async fn a_client_cannot_reach_technician_only_routes(pool: PgPool) {
    let client_id = create_user(&pool, "client").await;
    let token = token_for(client_id, Role::Client);

    for (method, path, body) in [
        ("GET", "/technician/profile", None),
        ("POST", "/technician/profile", Some(r#"{"oficio":"Gasfitero","coverage_km":5,"available_days":[],"categories":[]}"#)),
        ("GET", "/technician/documents", None),
        ("GET", "/technician/jobs", None),
    ] {
        assert_eq!(
            status_of(&pool, method, path, Some(&token), body).await,
            StatusCode::FORBIDDEN,
            "{method} {path} must reject a client with 403"
        );
    }
}

#[sqlx::test(migrations = "./migrations")]
async fn a_technician_cannot_reach_client_only_routes(pool: PgPool) {
    let tech_id = create_user(&pool, "technician").await;
    let token = token_for(tech_id, Role::Technician);

    for (method, path, body) in [
        ("GET", "/client/addresses", None),
        ("POST", "/client/addresses", Some(r#"{"label":"Casa","detail":"Av. Siempre Viva 123"}"#)),
        ("GET", "/client/payment-methods", None),
        ("GET", "/client/history", None),
        ("POST", "/jobs", Some(r#"{"job_kind":"bidding"}"#)),
    ] {
        assert_eq!(
            status_of(&pool, method, path, Some(&token), body).await,
            StatusCode::FORBIDDEN,
            "{method} {path} must reject a technician with 403"
        );
    }
}

#[sqlx::test(migrations = "./migrations")]
async fn the_right_role_is_not_rejected(pool: PgPool) {
    let client_id = create_user(&pool, "client").await;
    let tech_id = create_user(&pool, "technician").await;
    // `/technician/jobs` also 403s for a technician with no profile row
    // (`GetTechnicianJobsUseCase` treats "no inbox" as unauthorized), so
    // without this the check below would pass for the wrong reason.
    create_technician_profile(&pool, tech_id).await;

    // Sanity check on the two tests above: these same routes must NOT
    // 403 for the role they belong to, otherwise the assertions there
    // would pass even if every route rejected everyone.
    let client_status = status_of(&pool, "GET", "/client/addresses", Some(&token_for(client_id, Role::Client)), None).await;
    assert_eq!(client_status, StatusCode::OK);

    let tech_status = status_of(&pool, "GET", "/technician/jobs", Some(&token_for(tech_id, Role::Technician)), None).await;
    assert_eq!(tech_status, StatusCode::OK);
}

#[sqlx::test(migrations = "./migrations")]
async fn protected_routes_still_reject_anonymous_callers(pool: PgPool) {
    // Role gating must not accidentally turn a missing token into a 403:
    // "who are you?" (401) and "not allowed" (403) drive different
    // client behaviour — the app force-logs-out only on 401.
    for (method, path) in [("GET", "/technician/profile"), ("GET", "/client/addresses"), ("GET", "/me")] {
        assert_eq!(
            status_of(&pool, method, path, None, None).await,
            StatusCode::UNAUTHORIZED,
            "{method} {path} must answer 401 when no token is sent"
        );
    }
}

#[sqlx::test(migrations = "./migrations")]
async fn the_providers_listing_stays_public(pool: PgPool) {
    // `/providers` feeds the home screen before a technician has picked
    // anything — it is intentionally the one unauthenticated data route.
    assert_eq!(status_of(&pool, "GET", "/providers", None, None).await, StatusCode::OK);
}
