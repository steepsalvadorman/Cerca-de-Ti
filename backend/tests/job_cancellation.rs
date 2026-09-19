//! Cancellation, through the real router (GAP-19).
//!
//! `cancelled` has been in `JobStatus` and in the `job_requests.status`
//! CHECK since the schema was written, but **no use case ever wrote it** —
//! grepping for `cancel` in `backend/src` returned only the enum
//! definition. A client whose auction drew no bids had no way to close it,
//! and an abandoned job stayed `active` forever. These tests pin the rule
//! now that it exists.

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

const TEST_JWT_SECRET: &str = "test-secret-for-cancellation";

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
    token: &str,
    body: Option<String>,
) -> (StatusCode, String) {
    let mut request = Request::builder()
        .method(method)
        .uri(path)
        .header("Authorization", format!("Bearer {token}"));
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

/// A `bidding` job, which is born `pending` and therefore cancellable
/// without any payment having happened.
async fn create_bidding_job(pool: &PgPool, client_id: Uuid) -> Uuid {
    let job_repo: Arc<dyn backend::features::job::domain::JobRepository> =
        Arc::new(PostgresJobRepository::new(pool.clone()));

    backend::features::job::application::CreateJobUseCase::new(job_repo)
        .execute(backend::features::job::application::CreateJobInput {
            client_id,
            technician_profile_id: None,
            tech_team_id: None,
            job_kind: "bidding".to_string(),
            title: Some("Fuga de agua".to_string()),
            address: Some("Av. Siempre Viva 123".to_string()),
            mobility_included: None,
        })
        .await
        .unwrap()
        .id
}

/// A free `direct` job, which is born `active`.
async fn create_direct_job(pool: &PgPool, client_id: Uuid, technician_profile_id: i32) -> Uuid {
    let job_repo: Arc<dyn backend::features::job::domain::JobRepository> =
        Arc::new(PostgresJobRepository::new(pool.clone()));

    backend::features::job::application::CreateJobUseCase::new(job_repo)
        .execute(backend::features::job::application::CreateJobInput {
            client_id,
            technician_profile_id: Some(technician_profile_id),
            tech_team_id: None,
            job_kind: "direct".to_string(),
            title: Some("Fuga de agua".to_string()),
            address: Some("Av. Siempre Viva 123".to_string()),
            mobility_included: None,
        })
        .await
        .unwrap()
        .id
}

async fn job_row(pool: &PgPool, job_id: Uuid) -> (String, Option<String>, Option<String>) {
    sqlx::query_as(
        "SELECT status, cancellation_reason, cancelled_at::text FROM job_requests WHERE id = $1",
    )
    .bind(job_id)
    .fetch_one(pool)
    .await
    .unwrap()
}

/// The core of GAP-19: before this, there was no way to end a job.
#[sqlx::test(migrations = "./migrations")]
async fn a_client_can_cancel_their_open_auction(pool: PgPool) {
    let client_id = create_user(&pool, "client").await;
    let job_id = create_bidding_job(&pool, client_id).await;

    let (status, body) = call(
        &pool,
        "POST",
        &format!("/jobs/{job_id}/cancel"),
        &token_for(client_id, Role::Client),
        Some(r#"{"reason":"Ya no lo necesito"}"#.to_string()),
    )
    .await;

    assert_eq!(status, StatusCode::OK, "cancelling an open job must work: {body}");

    let (state, reason, cancelled_at) = job_row(&pool, job_id).await;
    assert_eq!(state, "cancelled");
    assert_eq!(reason.as_deref(), Some("Ya no lo necesito"));
    assert!(cancelled_at.is_some(), "the timestamp must be recorded");
}

/// The rule has to hold for a job already under way, which is the case a
/// client is most likely to want out of.
#[sqlx::test(migrations = "./migrations")]
async fn a_client_can_cancel_an_active_job(pool: PgPool) {
    let client_id = create_user(&pool, "client").await;
    let (_, profile_id) = create_technician(&pool).await;
    let job_id = create_direct_job(&pool, client_id, profile_id).await;

    let (status, body) = call(
        &pool,
        "POST",
        &format!("/jobs/{job_id}/cancel"),
        &token_for(client_id, Role::Client),
        Some("{}".to_string()),
    )
    .await;

    assert_eq!(status, StatusCode::OK, "an active job must be cancellable: {body}");
    assert_eq!(job_row(&pool, job_id).await.0, "cancelled");
}

/// No reason is a legitimate request, not a malformed one.
#[sqlx::test(migrations = "./migrations")]
async fn cancelling_without_a_reason_is_allowed(pool: PgPool) {
    let client_id = create_user(&pool, "client").await;
    let job_id = create_bidding_job(&pool, client_id).await;

    let (status, _) = call(
        &pool,
        "POST",
        &format!("/jobs/{job_id}/cancel"),
        &token_for(client_id, Role::Client),
        Some("{}".to_string()),
    )
    .await;

    assert_eq!(status, StatusCode::OK);
    let (_, reason, _) = job_row(&pool, job_id).await;
    assert!(reason.is_none());
}

/// A blank reason is stored as no reason rather than as an empty string.
#[sqlx::test(migrations = "./migrations")]
async fn a_blank_reason_is_normalised_to_none(pool: PgPool) {
    let client_id = create_user(&pool, "client").await;
    let job_id = create_bidding_job(&pool, client_id).await;

    let (status, _) = call(
        &pool,
        "POST",
        &format!("/jobs/{job_id}/cancel"),
        &token_for(client_id, Role::Client),
        Some(r#"{"reason":"   "}"#.to_string()),
    )
    .await;

    assert_eq!(status, StatusCode::OK);
    let (_, reason, _) = job_row(&pool, job_id).await;
    assert!(reason.is_none(), "whitespace is not a reason, got {reason:?}");
}

/// A finished job is not cancellable: there is nothing left to end.
#[sqlx::test(migrations = "./migrations")]
async fn a_completed_job_cannot_be_cancelled(pool: PgPool) {
    let client_id = create_user(&pool, "client").await;
    let (tech_id, profile_id) = create_technician(&pool).await;
    let job_id = create_direct_job(&pool, client_id, profile_id).await;

    // Walk it to completion as the assigned technician.
    let tech_token = token_for(tech_id, Role::Technician);
    for _ in 0..3 {
        let (status, body) = call(
            &pool,
            "POST",
            &format!("/jobs/{job_id}/advance"),
            &tech_token,
            None::<String>,
        )
        .await;
        assert_eq!(status, StatusCode::OK, "{body}");
    }
    assert_eq!(job_row(&pool, job_id).await.0, "completed");

    let (status, _) = call(
        &pool,
        "POST",
        &format!("/jobs/{job_id}/cancel"),
        &token_for(client_id, Role::Client),
        Some("{}".to_string()),
    )
    .await;

    assert_eq!(
        status,
        StatusCode::BAD_REQUEST,
        "a completed job must not be cancellable"
    );
    assert_eq!(job_row(&pool, job_id).await.0, "completed", "and it must not have moved");
}

/// Cancelling twice is not a second event, and accepting it silently would
/// overwrite the original reason and timestamp.
#[sqlx::test(migrations = "./migrations")]
async fn cancelling_twice_is_refused(pool: PgPool) {
    let client_id = create_user(&pool, "client").await;
    let job_id = create_bidding_job(&pool, client_id).await;
    let token = token_for(client_id, Role::Client);

    let (first, _) = call(
        &pool,
        "POST",
        &format!("/jobs/{job_id}/cancel"),
        &token,
        Some(r#"{"reason":"primera"}"#.to_string()),
    )
    .await;
    assert_eq!(first, StatusCode::OK);

    let (second, _) = call(
        &pool,
        "POST",
        &format!("/jobs/{job_id}/cancel"),
        &token,
        Some(r#"{"reason":"segunda"}"#.to_string()),
    )
    .await;
    assert_eq!(second, StatusCode::BAD_REQUEST);

    let (_, reason, _) = job_row(&pool, job_id).await;
    assert_eq!(reason.as_deref(), Some("primera"), "the first reason must survive");
}

/// Someone else's job is not yours to end.
#[sqlx::test(migrations = "./migrations")]
async fn another_client_cannot_cancel_someone_elses_job(pool: PgPool) {
    let owner_id = create_user(&pool, "client").await;
    let stranger_id = create_user(&pool, "client").await;
    let job_id = create_bidding_job(&pool, owner_id).await;

    let (status, _) = call(
        &pool,
        "POST",
        &format!("/jobs/{job_id}/cancel"),
        &token_for(stranger_id, Role::Client),
        Some("{}".to_string()),
    )
    .await;

    assert_eq!(status, StatusCode::FORBIDDEN);
    assert_eq!(job_row(&pool, job_id).await.0, "pending", "the job must be untouched");
}

/// A technician cannot cancel: walking away from agreed work is an
/// abandonment, which needs its own rule and its own consequences.
#[sqlx::test(migrations = "./migrations")]
async fn a_technician_cannot_cancel_a_job(pool: PgPool) {
    let client_id = create_user(&pool, "client").await;
    let (tech_id, profile_id) = create_technician(&pool).await;
    let job_id = create_direct_job(&pool, client_id, profile_id).await;

    let (status, _) = call(
        &pool,
        "POST",
        &format!("/jobs/{job_id}/cancel"),
        &token_for(tech_id, Role::Technician),
        Some("{}".to_string()),
    )
    .await;

    // 403 from the client-only extractor, before the use case runs.
    assert_eq!(status, StatusCode::FORBIDDEN);
    assert_eq!(job_row(&pool, job_id).await.0, "active");
}

/// A cancelled auction must leave the open-bid feed: the feed is what
/// technicians browse, and a withdrawn job there is a wasted bid.
#[sqlx::test(migrations = "./migrations")]
async fn a_cancelled_auction_disappears_from_the_open_bid_feed(pool: PgPool) {
    let client_id = create_user(&pool, "client").await;
    let (tech_id, _) = create_technician(&pool).await;
    let job_id = create_bidding_job(&pool, client_id).await;
    let tech_token = token_for(tech_id, Role::Technician);

    let (before, body) = call(&pool, "GET", "/technician/jobs", &tech_token, None::<String>).await;
    assert_eq!(before, StatusCode::OK);
    assert!(body.contains(&job_id.to_string()), "the auction starts listed: {body}");

    let (cancel, _) = call(
        &pool,
        "POST",
        &format!("/jobs/{job_id}/cancel"),
        &token_for(client_id, Role::Client),
        Some("{}".to_string()),
    )
    .await;
    assert_eq!(cancel, StatusCode::OK);

    let (after, body) = call(&pool, "GET", "/technician/jobs", &tech_token, None::<String>).await;
    assert_eq!(after, StatusCode::OK);
    assert!(
        !body.contains(&job_id.to_string()),
        "a withdrawn auction must not keep soliciting bids: {body}"
    );
}

/// A cancelled job must not accept a bid, or the client would be paying
/// attention to an auction they already closed.
#[sqlx::test(migrations = "./migrations")]
async fn a_cancelled_job_accepts_no_more_bids(pool: PgPool) {
    let client_id = create_user(&pool, "client").await;
    let (tech_id, _) = create_technician(&pool).await;
    let job_id = create_bidding_job(&pool, client_id).await;

    let (cancel, _) = call(
        &pool,
        "POST",
        &format!("/jobs/{job_id}/cancel"),
        &token_for(client_id, Role::Client),
        Some("{}".to_string()),
    )
    .await;
    assert_eq!(cancel, StatusCode::OK);

    let (status, _) = call(
        &pool,
        "POST",
        &format!("/jobs/{job_id}/offers"),
        &token_for(tech_id, Role::Technician),
        Some(r#"{"price":130,"eta":"Hoy"}"#.to_string()),
    )
    .await;

    assert_eq!(status, StatusCode::BAD_REQUEST);
}

/// GAP-12, which cancellation made reachable.
///
/// A free job (`direct`/`project`) is born `fee_paid = true`, and the
/// idempotency early-return in `pay_fee` used to run *before* any status
/// validation — so `POST /pay` on a cancelled or completed free job
/// answered `Ok`. The client would report a successful payment on a job
/// nobody could be charged for.
#[sqlx::test(migrations = "./migrations")]
async fn a_cancelled_free_job_cannot_be_paid(pool: PgPool) {
    let client_id = create_user(&pool, "client").await;
    let (_, profile_id) = create_technician(&pool).await;
    let job_id = create_direct_job(&pool, client_id, profile_id).await;
    let token = token_for(client_id, Role::Client);

    let (cancel, _) = call(
        &pool,
        "POST",
        &format!("/jobs/{job_id}/cancel"),
        &token,
        Some("{}".to_string()),
    )
    .await;
    assert_eq!(cancel, StatusCode::OK);

    let (status, body) = call(
        &pool,
        "POST",
        &format!("/jobs/{job_id}/pay"),
        &token,
        Some(r#"{"payment_method":"card"}"#.to_string()),
    )
    .await;

    assert_eq!(
        status,
        StatusCode::BAD_REQUEST,
        "paying a cancelled job must fail rather than report success: {body}"
    );
    assert_eq!(job_row(&pool, job_id).await.0, "cancelled", "and it must stay cancelled");
}

/// The other half of the same ordering bug: a completed free job.
#[sqlx::test(migrations = "./migrations")]
async fn a_completed_free_job_cannot_be_paid(pool: PgPool) {
    let client_id = create_user(&pool, "client").await;
    let (tech_id, profile_id) = create_technician(&pool).await;
    let job_id = create_direct_job(&pool, client_id, profile_id).await;

    let tech_token = token_for(tech_id, Role::Technician);
    for _ in 0..3 {
        let (status, body) = call(
            &pool,
            "POST",
            &format!("/jobs/{job_id}/advance"),
            &tech_token,
            None::<String>,
        )
        .await;
        assert_eq!(status, StatusCode::OK, "{body}");
    }

    let (status, _) = call(
        &pool,
        "POST",
        &format!("/jobs/{job_id}/pay"),
        &token_for(client_id, Role::Client),
        Some(r#"{"payment_method":"card"}"#.to_string()),
    )
    .await;

    assert_eq!(status, StatusCode::BAD_REQUEST);
}

/// A retry on a job that is still live must stay harmless — the idempotency
/// this ordering fix must not have broken.
#[sqlx::test(migrations = "./migrations")]
async fn paying_a_live_free_job_twice_stays_harmless(pool: PgPool) {
    let client_id = create_user(&pool, "client").await;
    let (_, profile_id) = create_technician(&pool).await;
    let job_id = create_direct_job(&pool, client_id, profile_id).await;
    let token = token_for(client_id, Role::Client);

    for _ in 0..2 {
        let (status, body) = call(
            &pool,
            "POST",
            &format!("/jobs/{job_id}/pay"),
            &token,
            Some(r#"{"payment_method":"card"}"#.to_string()),
        )
        .await;
        assert_eq!(status, StatusCode::OK, "a retried payment is not an error: {body}");
    }

    assert_eq!(job_row(&pool, job_id).await.0, "active");
}

/// GAP-02, on the only free-text field cancellation adds.
#[sqlx::test(migrations = "./migrations")]
async fn an_overlong_cancellation_reason_is_truncated_not_rejected(pool: PgPool) {
    let client_id = create_user(&pool, "client").await;
    let job_id = create_bidding_job(&pool, client_id).await;

    let reason = "x".repeat(400);
    let (status, body) = call(
        &pool,
        "POST",
        &format!("/jobs/{job_id}/cancel"),
        &token_for(client_id, Role::Client),
        Some(format!(r#"{{"reason":"{reason}"}}"#)),
    )
    .await;

    // The intent ("cancel it") is unambiguous, so the note is trimmed
    // rather than the request refused.
    assert_eq!(status, StatusCode::OK, "{body}");
    let (_, stored, _) = job_row(&pool, job_id).await;
    let stored = stored.expect("a reason was given");
    assert_eq!(stored.chars().count(), 300, "the note must be capped");
}
