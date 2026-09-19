//! Input validation at the HTTP boundary (GAP-02).
//!
//! Nothing validated the *shape* of a request. `TEXT` columns have no
//! length bound in Postgres, so a `title`, an address or a chat message
//! could be megabytes long, be stored happily, and then be re-sent to
//! every client that reads the row — and the chat thread is polled, so the
//! cost recurs. There was also no limit on the request body at all.
//!
//! These drive the real router, because that is where the validation now
//! lives: the use cases keep their own business rules, and the interface
//! answers `422` naming the field for anything malformed.

use std::sync::Arc;

use axum::body::Body;
use axum::http::{Request, StatusCode};
use sqlx::PgPool;
use tower::ServiceExt;
use uuid::Uuid;

use backend::features::auth::application::TokenService;
use backend::features::auth::domain::Role;
use backend::features::auth::infrastructure::{
    Argon2PasswordHasher, JwtTokenService, PostgresUserRepository, UnconfiguredIdentityVerifier,
};
use backend::features::chat::infrastructure::PostgresChatRepository;
use backend::features::client::infrastructure::PostgresClientRepository;
use backend::features::job::infrastructure::{FakePaymentGateway, PostgresJobRepository};
use backend::features::technician::infrastructure::{
    PostgresTechnicianRepository, UnconfiguredObjectStorage,
};
use backend::features::tracking::infrastructure::PostgresTrackingRepository;
use backend::routes::app_router;
use backend::state::AppState;

const TEST_JWT_SECRET: &str = "test-secret-for-validation";

fn test_state(pool: PgPool) -> AppState {
    AppState {
        user_repository: Arc::new(PostgresUserRepository::new(pool.clone())),
        password_hasher: Arc::new(Argon2PasswordHasher),
        token_service: Arc::new(JwtTokenService::new(TEST_JWT_SECRET)),
        identity_verifier: Arc::new(UnconfiguredIdentityVerifier),
        technician_repository: Arc::new(PostgresTechnicianRepository::new(pool.clone())),
        client_repository: Arc::new(PostgresClientRepository::new(pool.clone())),
        job_repository: Arc::new(PostgresJobRepository::new(pool.clone())),
        payment_gateway: Arc::new(FakePaymentGateway),
        chat_repository: Arc::new(PostgresChatRepository::new(pool.clone())),
        tracking_repository: Arc::new(PostgresTrackingRepository::new(pool)),
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

async fn create_technician(pool: &PgPool) -> (Uuid, i32) {
    let user_id = create_user(pool, "technician").await;
    let row: (i32,) = sqlx::query_as(
        "INSERT INTO technician_profiles (user_id, oficio, pin_top, pin_left, is_verified) \
         VALUES ($1, 'Gasfitero', 0.5, 0.5, TRUE) RETURNING id",
    )
    .bind(user_id)
    .fetch_one(pool)
    .await
    .unwrap();
    (user_id, row.0)
}

fn token_for(user_id: Uuid, role: Role) -> String {
    JwtTokenService::new(TEST_JWT_SECRET).issue(user_id, role).unwrap()
}

async fn call(
    pool: &PgPool,
    method: &str,
    path: &str,
    token: Option<&str>,
    body: Option<String>,
) -> (StatusCode, String) {
    let mut request = Request::builder().method(method).uri(path);
    if let Some(token) = token {
        request = request.header("Authorization", format!("Bearer {token}"));
    }
    if body.is_some() {
        request = request.header("Content-Type", "application/json");
    }

    let response = app_router(test_state(pool.clone()), &[])
        .oneshot(request.body(body.map_or_else(Body::empty, Body::from)).unwrap())
        .await
        .unwrap();

    let status = response.status();
    let bytes = axum::body::to_bytes(response.into_body(), usize::MAX).await.unwrap();
    (status, String::from_utf8_lossy(&bytes).into_owned())
}

// ---------------------------------------------------------------------
// Registration
// ---------------------------------------------------------------------

/// GAP-123: the Google path already trimmed and rejected blank names; the
/// password path stored whatever arrived.
#[sqlx::test(migrations = "./migrations")]
async fn a_blank_name_is_refused_at_registration(pool: PgPool) {
    for name in ["", "   "] {
        let (status, body) = call(
            &pool,
            "POST",
            "/auth/register",
            None,
            Some(format!(
                r#"{{"email":"someone@example.com","password":"long-enough-1","name":"{name}","role":"client"}}"#
            )),
        )
        .await;

        assert_eq!(status, StatusCode::UNPROCESSABLE_ENTITY, "name {name:?}: {body}");
        assert!(body.contains("name") || body.contains("nombre"), "the field must be named: {body}");
    }
}

#[sqlx::test(migrations = "./migrations")]
async fn an_overlong_name_is_refused(pool: PgPool) {
    let name = "a".repeat(121);
    let (status, body) = call(
        &pool,
        "POST",
        "/auth/register",
        None,
        Some(format!(
            r#"{{"email":"someone@example.com","password":"long-enough-1","name":"{name}","role":"client"}}"#
        )),
    )
    .await;

    assert_eq!(status, StatusCode::UNPROCESSABLE_ENTITY, "{body}");
}

/// An unknown role is a malformed field, not a business-state problem.
#[sqlx::test(migrations = "./migrations")]
async fn an_unknown_role_is_refused(pool: PgPool) {
    let (status, body) = call(
        &pool,
        "POST",
        "/auth/register",
        None,
        Some(
            r#"{"email":"someone@example.com","password":"long-enough-1","name":"Ana","role":"admin"}"#
                .to_string(),
        ),
    )
    .await;

    assert_eq!(status, StatusCode::UNPROCESSABLE_ENTITY, "{body}");
    assert!(body.contains("role") || body.contains("rol"), "{body}");
}

/// A password has no upper bound today, so hashing an arbitrarily large
/// string was the server's cost to pay.
#[sqlx::test(migrations = "./migrations")]
async fn an_overlong_password_is_refused(pool: PgPool) {
    let password = "a".repeat(129);
    let (status, body) = call(
        &pool,
        "POST",
        "/auth/register",
        None,
        Some(format!(
            r#"{{"email":"someone@example.com","password":"{password}","name":"Ana","role":"client"}}"#
        )),
    )
    .await;

    assert_eq!(status, StatusCode::UNPROCESSABLE_ENTITY, "{body}");
}

/// The validation must not have made a legitimate multi-byte name illegal.
#[sqlx::test(migrations = "./migrations")]
async fn an_accented_name_of_legal_length_is_accepted(pool: PgPool) {
    let name = "José Ángel Ñuñez de la Cruz".to_string();
    let email = format!("{}@example.com", Uuid::new_v4());

    let (status, body) = call(
        &pool,
        "POST",
        "/auth/register",
        None,
        Some(format!(
            r#"{{"email":"{email}","password":"long-enough-1","name":"{name}","role":"client"}}"#
        )),
    )
    .await;

    assert_eq!(status, StatusCode::CREATED, "{body}");
}

// ---------------------------------------------------------------------
// Jobs
// ---------------------------------------------------------------------

/// GAP-02 on the fields a job is created with: `title` and `address` are
/// shown to the technician and stored as `TEXT`, with nothing bounding
/// them.
#[sqlx::test(migrations = "./migrations")]
async fn an_oversized_job_title_or_address_is_refused(pool: PgPool) {
    let client_id = create_user(&pool, "client").await;
    let token = token_for(client_id, Role::Client);

    let long_title = "t".repeat(121);
    let (status, body) = call(
        &pool,
        "POST",
        "/jobs",
        Some(&token),
        Some(format!(r#"{{"job_kind":"bidding","title":"{long_title}"}}"#)),
    )
    .await;
    assert_eq!(status, StatusCode::UNPROCESSABLE_ENTITY, "title: {body}");

    let long_address = "a".repeat(301);
    let (status, body) = call(
        &pool,
        "POST",
        "/jobs",
        Some(&token),
        Some(format!(r#"{{"job_kind":"bidding","address":"{long_address}"}}"#)),
    )
    .await;
    assert_eq!(status, StatusCode::UNPROCESSABLE_ENTITY, "address: {body}");
}

/// An unknown `job_kind` is a malformed field. It previously surfaced as a
/// status-transition error, which names nothing.
#[sqlx::test(migrations = "./migrations")]
async fn an_unknown_job_kind_is_named_in_the_error(pool: PgPool) {
    let client_id = create_user(&pool, "client").await;
    let token = token_for(client_id, Role::Client);

    let (status, body) = call(
        &pool,
        "POST",
        "/jobs",
        Some(&token),
        Some(r#"{"job_kind":"freebie"}"#.to_string()),
    )
    .await;

    assert_eq!(status, StatusCode::UNPROCESSABLE_ENTITY, "{body}");
    assert!(body.contains("job_kind"), "the field must be named: {body}");
}

/// GAP-17: a rating of 9 was reported as a status-transition error.
#[sqlx::test(migrations = "./migrations")]
async fn an_out_of_range_rating_names_the_field(pool: PgPool) {
    let client_id = create_user(&pool, "client").await;
    let token = token_for(client_id, Role::Client);

    let (status, body) = call(
        &pool,
        "POST",
        &format!("/jobs/{}/rate", Uuid::new_v4()),
        Some(&token),
        Some(r#"{"rating":9}"#.to_string()),
    )
    .await;

    assert_eq!(status, StatusCode::UNPROCESSABLE_ENTITY, "{body}");
    assert!(body.contains("rating"), "{body}");
}

// ---------------------------------------------------------------------
// Chat
// ---------------------------------------------------------------------

/// GAP-40: `{"text":""}` was accepted and stored.
#[sqlx::test(migrations = "./migrations")]
async fn a_blank_chat_message_is_refused(pool: PgPool) {
    let client_id = create_user(&pool, "client").await;
    let token = token_for(client_id, Role::Client);

    for text in ["", "   "] {
        let (status, body) = call(
            &pool,
            "POST",
            &format!("/jobs/{}/messages", Uuid::new_v4()),
            Some(&token),
            Some(format!(r#"{{"text":"{text}"}}"#)),
        )
        .await;

        assert_eq!(status, StatusCode::UNPROCESSABLE_ENTITY, "text {text:?}: {body}");
    }
}

/// The thread is polled by both participants, so one huge message is a
/// recurring cost rather than a one-off.
#[sqlx::test(migrations = "./migrations")]
async fn an_oversized_chat_message_is_refused(pool: PgPool) {
    let client_id = create_user(&pool, "client").await;
    let token = token_for(client_id, Role::Client);
    let text = "x".repeat(2001);

    let (status, body) = call(
        &pool,
        "POST",
        &format!("/jobs/{}/messages", Uuid::new_v4()),
        Some(&token),
        Some(format!(r#"{{"text":"{text}"}}"#)),
    )
    .await;

    assert_eq!(status, StatusCode::UNPROCESSABLE_ENTITY, "{body}");
}

// ---------------------------------------------------------------------
// Client account
// ---------------------------------------------------------------------

#[sqlx::test(migrations = "./migrations")]
async fn blank_or_oversized_address_fields_are_refused(pool: PgPool) {
    let client_id = create_user(&pool, "client").await;
    let token = token_for(client_id, Role::Client);

    for body in [
        r#"{"label":"   ","detail":"Av. Siempre Viva 123"}"#.to_string(),
        r#"{"label":"Casa","detail":""}"#.to_string(),
        format!(r#"{{"label":"Casa","detail":"{}"}}"#, "d".repeat(301)),
    ] {
        let (status, response) = call(&pool, "POST", "/client/addresses", Some(&token), Some(body.clone())).await;
        assert_eq!(
            status,
            StatusCode::UNPROCESSABLE_ENTITY,
            "body {body} must be refused: {response}"
        );
    }
}

#[sqlx::test(migrations = "./migrations")]
async fn a_valid_address_is_still_accepted(pool: PgPool) {
    let client_id = create_user(&pool, "client").await;
    let token = token_for(client_id, Role::Client);

    let (status, body) = call(
        &pool,
        "POST",
        "/client/addresses",
        Some(&token),
        Some(r#"{"label":"  Casa  ","detail":"Av. Siempre Viva 123"}"#.to_string()),
    )
    .await;

    assert_eq!(status, StatusCode::CREATED, "{body}");
    // Trimmed on the way in, so "Casa" and " Casa " are one label.
    assert!(body.contains("\"label\":\"Casa\""), "the label must be trimmed: {body}");
}

// ---------------------------------------------------------------------
// Technician profile
// ---------------------------------------------------------------------

/// GAP-32: `coverage_km` accepted negatives and `i32::MAX`, and
/// `categories` accepted anything at all — so a technician appeared in
/// `/providers` for a trade they do not work in.
#[sqlx::test(migrations = "./migrations")]
async fn an_invalid_technician_profile_is_refused(pool: PgPool) {
    let (tech_id, _) = create_technician(&pool).await;
    let token = token_for(tech_id, Role::Technician);

    let cases = [
        ("coverage_km negativo", r#"{"oficio":"Gasfitero","price_label":"Desde S/ 60","coverage_km":-1,"available_days":["lun"],"categories":["gasfiteria"]}"#.to_string()),
        ("coverage_km absurdo", r#"{"oficio":"Gasfitero","price_label":"Desde S/ 60","coverage_km":2147483647,"available_days":["lun"],"categories":["gasfiteria"]}"#.to_string()),
        ("oficio vacio", r#"{"oficio":"","price_label":"Desde S/ 60","coverage_km":5,"available_days":["lun"],"categories":["gasfiteria"]}"#.to_string()),
        ("categoria inventada", r#"{"oficio":"Gasfitero","price_label":"Desde S/ 60","coverage_km":5,"available_days":["lun"],"categories":["xyz"]}"#.to_string()),
        ("dia invalido", r#"{"oficio":"Gasfitero","price_label":"Desde S/ 60","coverage_km":5,"available_days":["lunes"],"categories":["gasfiteria"]}"#.to_string()),
        ("sin categorias", r#"{"oficio":"Gasfitero","price_label":"Desde S/ 60","coverage_km":5,"available_days":["lun"],"categories":[]}"#.to_string()),
        ("sin dias", r#"{"oficio":"Gasfitero","price_label":"Desde S/ 60","coverage_km":5,"available_days":[],"categories":["gasfiteria"]}"#.to_string()),
    ];

    for (what, body) in cases {
        let (status, response) = call(&pool, "POST", "/technician/profile", Some(&token), Some(body)).await;
        assert_eq!(
            status,
            StatusCode::UNPROCESSABLE_ENTITY,
            "{what} must be refused, got {status}: {response}"
        );
    }
}

#[sqlx::test(migrations = "./migrations")]
async fn a_valid_technician_profile_is_still_accepted(pool: PgPool) {
    let (tech_id, _) = create_technician(&pool).await;
    let token = token_for(tech_id, Role::Technician);

    let (status, body) = call(
        &pool,
        "POST",
        "/technician/profile",
        Some(&token),
        Some(
            r#"{"oficio":"Gasfitero","price_label":"Desde S/ 60","coverage_km":10,"available_days":["lun","mar"],"categories":["gasfiteria"]}"#
                .to_string(),
        ),
    )
    .await;

    assert_eq!(status, StatusCode::OK, "{body}");
}

// ---------------------------------------------------------------------
// Request body limit
// ---------------------------------------------------------------------

/// The outermost bound: a body far beyond anything legitimate is refused
/// before a handler reads it, so an oversized payload cannot be buffered
/// at all.
#[sqlx::test(migrations = "./migrations")]
async fn a_gigantic_request_body_is_refused(pool: PgPool) {
    let client_id = create_user(&pool, "client").await;
    let token = token_for(client_id, Role::Client);

    // Comfortably past the 64 KiB cap, and well past what any field in
    // this API could legitimately hold.
    let huge = "x".repeat(200 * 1024);
    let body = format!(r#"{{"job_kind":"bidding","title":"{huge}"}}"#);

    let (status, _) = call(&pool, "POST", "/jobs", Some(&token), Some(body)).await;

    assert!(
        status == StatusCode::PAYLOAD_TOO_LARGE || status == StatusCode::UNPROCESSABLE_ENTITY,
        "an oversized body must be refused, got {status}"
    );
}
