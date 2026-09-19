//! Chat and tracking through the real router (GAP-74, GAP-43).
//!
//! These two features had **no HTTP-level test at all**: `business_rules`
//! exercised their use cases directly, and `role_authorization` does not
//! touch either route (its lists cover four technician routes and five
//! client ones). So the authorization rules, the status codes and the
//! 404-vs-403 distinction were entirely unverified.

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

const TEST_JWT_SECRET: &str = "test-secret-for-chat-tracking";

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
    sqlx::query("INSERT INTO users (id, email, name, role, password_hash) VALUES ($1, $2, 'Test', $3, 'hash')")
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

/// A `direct` job: free, so it is born `active` with `fee_paid = true`,
/// which is the state chat and tracking are actually usable in.
async fn create_active_job(pool: &PgPool, client_id: Uuid, profile_id: i32) -> Uuid {
    backend::features::job::application::CreateJobUseCase::new(Arc::new(
        PostgresJobRepository::new(pool.clone()),
    ))
    .execute(backend::features::job::application::CreateJobInput {
        client_id,
        technician_profile_id: Some(profile_id),
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

// ---------------------------------------------------------------------
// GAP-43: a job that does not exist is a 404, not a 403
// ---------------------------------------------------------------------

#[sqlx::test(migrations = "./migrations")]
async fn an_unknown_job_is_a_404_on_the_chat_route(pool: PgPool) {
    let client_id = create_user(&pool, "client").await;
    let token = token_for(client_id, Role::Client);

    let (status, body) = call(
        &pool,
        "GET",
        &format!("/jobs/{}/messages", Uuid::new_v4()),
        Some(&token),
        None::<String>,
    )
    .await;

    assert_eq!(
        status,
        StatusCode::NOT_FOUND,
        "a stale link is not a permission problem: {body}"
    );
}

#[sqlx::test(migrations = "./migrations")]
async fn an_unknown_job_is_a_404_on_the_tracking_route(pool: PgPool) {
    let client_id = create_user(&pool, "client").await;
    let token = token_for(client_id, Role::Client);

    let (status, body) = call(
        &pool,
        "GET",
        &format!("/jobs/{}/location", Uuid::new_v4()),
        Some(&token),
        None::<String>,
    )
    .await;

    assert_eq!(status, StatusCode::NOT_FOUND, "{body}");
}

// ---------------------------------------------------------------------
// GAP-38: contact is not gated on fee_paid
// ---------------------------------------------------------------------

#[sqlx::test(migrations = "./migrations")]
async fn the_chosen_technician_can_message_before_the_fee_is_paid(pool: PgPool) {
    use std::sync::Arc;

    use backend::features::job::application::{
        ChooseOfferInput, ChooseOfferUseCase, CreateJobInput, CreateJobUseCase, SubmitOfferInput,
        SubmitOfferUseCase,
    };
    use backend::features::job::domain::JobRepository;

    let job_repo = Arc::new(PostgresJobRepository::new(pool.clone()));
    let tech_repo = Arc::new(PostgresTechnicianRepository::new(pool.clone()));

    let client_id = create_user(&pool, "client").await;
    let (tech_id, _) = create_technician(&pool).await;

    let job = CreateJobUseCase::new(job_repo.clone())
        .execute(CreateJobInput {
            client_id,
            technician_profile_id: None,
            tech_team_id: None,
            job_kind: "bidding".to_string(),
            title: Some("Fuga".to_string()),
            address: None,
            mobility_included: None,
        })
        .await
        .unwrap();

    SubmitOfferUseCase::new(job_repo.clone(), tech_repo.clone())
        .execute(SubmitOfferInput {
            job_request_id: job.id,
            technician_user_id: tech_id,
            price: 150,
            eta: "Hoy".to_string(),
        })
        .await
        .unwrap();

    let offers = job_repo.find_offers_by_job_id(job.id).await.unwrap();
    ChooseOfferUseCase::new(job_repo.clone())
        .execute(ChooseOfferInput {
            job_request_id: job.id,
            client_id,
            offer_id: offers[0].id,
        })
        .await
        .unwrap();

    let unpaid = job_repo.find_job_request_by_id(job.id).await.unwrap().unwrap();
    assert!(!unpaid.fee_paid, "precondition: fee not paid yet");

    let (status, body) = call(
        &pool,
        "POST",
        &format!("/jobs/{}/messages", job.id),
        Some(&token_for(tech_id, Role::Technician)),
        Some(r#"{"text":"Llego en 20 minutos"}"#.to_string()),
    )
    .await;

    assert_eq!(
        status,
        StatusCode::CREATED,
        "assigned technician must chat before paying the platform fee: {body}"
    );
}

// ---------------------------------------------------------------------
// Chat authorization
// ---------------------------------------------------------------------

#[sqlx::test(migrations = "./migrations")]
async fn the_client_and_assigned_technician_can_chat(pool: PgPool) {
    let client_id = create_user(&pool, "client").await;
    let (tech_id, profile_id) = create_technician(&pool).await;
    let job_id = create_active_job(&pool, client_id, profile_id).await;

    // The client opens with a message.
    let (status, body) = call(
        &pool,
        "POST",
        &format!("/jobs/{job_id}/messages"),
        Some(&token_for(client_id, Role::Client)),
        Some(r#"{"text":"Hola, ¿cuál es tu número?"}"#.to_string()),
    )
    .await;
    assert_eq!(status, StatusCode::CREATED, "{body}");

    // The technician replies.
    let (status, body) = call(
        &pool,
        "POST",
        &format!("/jobs/{job_id}/messages"),
        Some(&token_for(tech_id, Role::Technician)),
        Some(r#"{"text":"Claro, 999 888 777"}"#.to_string()),
    )
    .await;
    assert_eq!(status, StatusCode::CREATED, "{body}");

    // Both read the same thread.
    for (who, token) in [
        ("client", token_for(client_id, Role::Client)),
        ("technician", token_for(tech_id, Role::Technician)),
    ] {
        let (status, body) = call(
            &pool,
            "GET",
            &format!("/jobs/{job_id}/messages"),
            Some(&token),
            None::<String>,
        )
        .await;
        assert_eq!(status, StatusCode::OK, "{who}: {body}");
        assert!(body.contains("999 888 777"), "{who} must see the thread: {body}");
    }
}

/// A third party must not be able to read a conversation they are not part
/// of — the rule existed in the use case but had never been exercised over
/// HTTP.
#[sqlx::test(migrations = "./migrations")]
async fn a_stranger_cannot_read_or_write_the_thread(pool: PgPool) {
    let client_id = create_user(&pool, "client").await;
    let stranger_id = create_user(&pool, "client").await;
    let (_, profile_id) = create_technician(&pool).await;
    let job_id = create_active_job(&pool, client_id, profile_id).await;

    let token = token_for(stranger_id, Role::Client);

    let (read, _) = call(
        &pool,
        "GET",
        &format!("/jobs/{job_id}/messages"),
        Some(&token),
        None::<String>,
    )
    .await;
    assert_eq!(read, StatusCode::FORBIDDEN);

    let (write, _) = call(
        &pool,
        "POST",
        &format!("/jobs/{job_id}/messages"),
        Some(&token),
        Some(r#"{"text":"hola"}"#.to_string()),
    )
    .await;
    assert_eq!(write, StatusCode::FORBIDDEN);
}

/// A technician who is not the assigned one has no business in the thread
/// either, even though they are a legitimate technician.
#[sqlx::test(migrations = "./migrations")]
async fn an_unassigned_technician_cannot_read_the_thread(pool: PgPool) {
    let client_id = create_user(&pool, "client").await;
    let (_, profile_id) = create_technician(&pool).await;
    let (other_tech_id, _) = create_technician(&pool).await;
    let job_id = create_active_job(&pool, client_id, profile_id).await;

    let (status, _) = call(
        &pool,
        "GET",
        &format!("/jobs/{job_id}/messages"),
        Some(&token_for(other_tech_id, Role::Technician)),
        None::<String>,
    )
    .await;

    assert_eq!(status, StatusCode::FORBIDDEN);
}

#[sqlx::test(migrations = "./migrations")]
async fn the_chat_routes_reject_anonymous_callers(pool: PgPool) {
    let job_id = Uuid::new_v4();

    for (method, path, body) in [
        ("GET", format!("/jobs/{job_id}/messages"), None),
        ("POST", format!("/jobs/{job_id}/messages"), Some(r#"{"text":"hola"}"#.to_string())),
        ("GET", format!("/jobs/{job_id}/location"), None),
    ] {
        let (status, _) = call(&pool, method, &path, None, body).await;
        assert_eq!(
            status,
            StatusCode::UNAUTHORIZED,
            "{method} {path} must answer 401 without a token"
        );
    }
}

// ---------------------------------------------------------------------
// Tracking
// ---------------------------------------------------------------------

/// A client cannot publish a location — only the technician moves.
#[sqlx::test(migrations = "./migrations")]
async fn a_client_cannot_publish_a_location(pool: PgPool) {
    let client_id = create_user(&pool, "client").await;
    let (_, profile_id) = create_technician(&pool).await;
    let job_id = create_active_job(&pool, client_id, profile_id).await;

    let (status, _) = call(
        &pool,
        "POST",
        &format!("/jobs/{job_id}/location"),
        Some(&token_for(client_id, Role::Client)),
        Some(r#"{"latitude":-12.05,"longitude":-77.04}"#.to_string()),
    )
    .await;

    assert_eq!(status, StatusCode::FORBIDDEN);
}

#[sqlx::test(migrations = "./migrations")]
async fn a_stranger_cannot_read_the_location(pool: PgPool) {
    let client_id = create_user(&pool, "client").await;
    let (tech_id, profile_id) = create_technician(&pool).await;
    let (stranger_id, _) = create_technician(&pool).await;
    let job_id = create_active_job(&pool, client_id, profile_id).await;

    // The technician shares a position first.
    let (pushed, _) = call(
        &pool,
        "POST",
        &format!("/jobs/{job_id}/location"),
        Some(&token_for(tech_id, Role::Technician)),
        Some(r#"{"latitude":-12.05,"longitude":-77.04}"#.to_string()),
    )
    .await;
    assert_eq!(pushed, StatusCode::OK);

    // The client may read it…
    let (owner, body) = call(
        &pool,
        "GET",
        &format!("/jobs/{job_id}/location"),
        Some(&token_for(client_id, Role::Client)),
        None::<String>,
    )
    .await;
    assert_eq!(owner, StatusCode::OK, "{body}");
    assert!(body.contains("-12.05"), "{body}");

    // …a third party may not.
    let (stranger, _) = call(
        &pool,
        "GET",
        &format!("/jobs/{job_id}/location"),
        Some(&token_for(stranger_id, Role::Technician)),
        None::<String>,
    )
    .await;
    assert_eq!(stranger, StatusCode::FORBIDDEN);
}

/// No position has been shared yet: that is a 404, not a 403.
#[sqlx::test(migrations = "./migrations")]
async fn reading_a_location_that_was_never_shared_is_a_404(pool: PgPool) {
    let client_id = create_user(&pool, "client").await;
    let (_, profile_id) = create_technician(&pool).await;
    let job_id = create_active_job(&pool, client_id, profile_id).await;

    let (status, body) = call(
        &pool,
        "GET",
        &format!("/jobs/{job_id}/location"),
        Some(&token_for(client_id, Role::Client)),
        None::<String>,
    )
    .await;

    assert_eq!(status, StatusCode::NOT_FOUND, "{body}");
}
