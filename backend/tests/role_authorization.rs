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
use backend::features::auth::infrastructure::{
    Argon2PasswordHasher, JwtTokenService, PostgresUserRepository, UnconfiguredIdentityVerifier,
};
use backend::features::auth::interfaces::http::routes::AUTH_ATTEMPTS_PER_MINUTE;
use backend::features::chat::infrastructure::PostgresChatRepository;
use backend::features::client::infrastructure::PostgresClientRepository;
use backend::features::job::infrastructure::{FakePaymentGateway, PostgresJobRepository};
use backend::features::technician::infrastructure::{PostgresTechnicianRepository, UnconfiguredObjectStorage};
use backend::features::tracking::infrastructure::PostgresTrackingRepository;
use backend::routes::app_router;
use backend::state::AppState;

const TEST_JWT_SECRET: &str = "test-secret-for-role-authorization";

fn test_state(pool: PgPool) -> AppState {
    AppState {
        user_repository: Arc::new(PostgresUserRepository::new(pool.clone())),
        password_hasher: Arc::new(Argon2PasswordHasher),
        token_service: Arc::new(JwtTokenService::new(TEST_JWT_SECRET)),
        // Same reasoning as the storage stub below: these tests never
        // sign in with Google, and a real verifier would want to reach
        // Google's servers.
        identity_verifier: Arc::new(UnconfiguredIdentityVerifier),
        technician_repository: Arc::new(PostgresTechnicianRepository::new(pool.clone())),
        client_repository: Arc::new(PostgresClientRepository::new(pool.clone())),
        job_repository: Arc::new(PostgresJobRepository::new(pool.clone())),
        payment_gateway: Arc::new(FakePaymentGateway),
        chat_repository: Arc::new(PostgresChatRepository::new(pool.clone())),
        tracking_repository: Arc::new(PostgresTrackingRepository::new(pool)),
        // These tests only assert who may reach a route, never that an
        // upload succeeds, so no bucket is needed.
        object_storage: Arc::new(UnconfiguredObjectStorage),
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

/// The regression test for GAP-118.
///
/// `/auth/login` and `/auth/register` each run a full Argon2id evaluation,
/// so leaving them unmetered made a denial-of-service free: an
/// unauthenticated caller could keep the blocking pool saturated. The
/// limiter must trip well before an attacker can do meaningful work.
///
/// This drives a **single** `app_router` across every attempt. `status_of`
/// builds a fresh router per call, and `auth_routes()` builds its limiter
/// once per construction — so calling `status_of` in a loop would hand
/// every request a brand-new budget and never accumulate anything.
#[sqlx::test(migrations = "./migrations")]
async fn repeated_login_attempts_are_rate_limited(pool: PgPool) {
    let router = app_router(test_state(pool.clone()), &[]);
    let attempts = (AUTH_ATTEMPTS_PER_MINUTE + 3) as usize;
    let mut statuses = Vec::with_capacity(attempts);

    for _ in 0..attempts {
        let request = Request::builder()
            .method("POST")
            .uri("/auth/login")
            .header("Content-Type", "application/json")
            .body(Body::from(
                r#"{"email":"someone@example.com","password":"wrong-password"}"#,
            ))
            .unwrap();

        // `oneshot` consumes the service, so clone the router instead of
        // rebuilding it: the limiter lives inside and must survive.
        statuses.push(router.clone().oneshot(request).await.unwrap().status());
    }

    assert!(
        statuses.contains(&StatusCode::TOO_MANY_REQUESTS),
        "a burst of login attempts must eventually be refused, got {statuses:?}"
    );

    // The first attempts must still have been *processed* (401 for bad
    // credentials), not refused outright: the limiter has to leave room
    // for a real user who mistypes a password.
    assert_eq!(
        statuses[0],
        StatusCode::UNAUTHORIZED,
        "the first attempt must reach the handler, got {statuses:?}"
    );

    // And it stays tripped rather than letting later requests through.
    assert_eq!(statuses.last().copied().unwrap(), StatusCode::TOO_MANY_REQUESTS);
}

/// The credential limiter must not bleed into unrelated routes: a wall of
/// failed logins should not lock someone out of browsing providers.
#[sqlx::test(migrations = "./migrations")]
async fn rate_limiting_logins_does_not_block_other_routes(pool: PgPool) {
    let router = app_router(test_state(pool.clone()), &[]);

    for _ in 0..(AUTH_ATTEMPTS_PER_MINUTE + 3) {
        let request = Request::builder()
            .method("POST")
            .uri("/auth/login")
            .header("Content-Type", "application/json")
            .body(Body::from(
                r#"{"email":"someone@example.com","password":"wrong-password"}"#,
            ))
            .unwrap();
        let _ = router.clone().oneshot(request).await.unwrap();
    }

    let browse = Request::builder()
        .method("GET")
        .uri("/providers")
        .body(Body::empty())
        .unwrap();

    assert_eq!(
        router.oneshot(browse).await.unwrap().status(),
        StatusCode::OK,
        "an unrelated public route must keep working while auth is throttled"
    );
}
