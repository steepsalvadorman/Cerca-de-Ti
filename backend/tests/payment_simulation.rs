//! Simulated fee payments through the real router (GAP-14).

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
use backend::features::job::application::{
    ChooseOfferInput, ChooseOfferUseCase, CreateJobInput, CreateJobUseCase, SubmitOfferInput,
    SubmitOfferUseCase,
};
use backend::features::job::domain::JobRepository;
use backend::features::job::infrastructure::{FakePaymentGateway, PostgresJobRepository};
use backend::features::technician::infrastructure::{
    PostgresTechnicianRepository, UnconfiguredObjectStorage,
};
use backend::features::tracking::infrastructure::PostgresTrackingRepository;
use backend::routes::app_router;
use backend::state::AppState;

const TEST_JWT_SECRET: &str = "test-secret-for-payment-simulation";

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

async fn pay(
    pool: &PgPool,
    job_id: Uuid,
    client_id: Uuid,
    payment_method: &str,
) -> (StatusCode, String) {
    let token = JwtTokenService::new(TEST_JWT_SECRET)
        .issue(client_id, Role::Client)
        .unwrap();

    let response = app_router(test_state(pool.clone()), &[])
        .oneshot(
            Request::builder()
                .method("POST")
                .uri(format!("/jobs/{job_id}/pay"))
                .header("Authorization", format!("Bearer {token}"))
                .header("Content-Type", "application/json")
                .body(Body::from(format!(
                    r#"{{"payment_method":"{payment_method}"}}"#
                )))
                .unwrap(),
        )
        .await
        .unwrap();

    let status = response.status();
    let body = axum::body::to_bytes(response.into_body(), usize::MAX)
        .await
        .unwrap();
    (status, String::from_utf8_lossy(&body).into_owned())
}

async fn bidding_job_ready_to_pay(pool: &PgPool) -> (Uuid, Uuid) {
    let job_repo = Arc::new(PostgresJobRepository::new(pool.clone()));
    let tech_repo = Arc::new(PostgresTechnicianRepository::new(pool.clone()));

    let client_id = create_user(pool, "client").await;
    let (tech_user_id, _) = create_technician(pool).await;

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
            technician_user_id: tech_user_id,
            price: 150,
            eta: "Hoy".to_string(),
        })
        .await
        .unwrap();

    let offers = job_repo.find_offers_by_job_id(job.id).await.unwrap();
    ChooseOfferUseCase::new(job_repo)
        .execute(ChooseOfferInput {
            job_request_id: job.id,
            client_id,
            offer_id: offers[0].id,
        })
        .await
        .unwrap();

    (job.id, client_id)
}

#[sqlx::test(migrations = "./migrations")]
async fn the_fake_gateway_records_a_simulated_capture(pool: PgPool) {
    let (job_id, client_id) = bidding_job_ready_to_pay(&pool).await;

    let (status, body) = pay(&pool, job_id, client_id, "Tarjeta").await;

    assert_eq!(status, StatusCode::OK, "{body}");
    assert!(body.contains(r#""simulated":true"#), "{body}");
    assert!(body.contains("fake-"), "{body}");

    let job = PostgresJobRepository::new(pool.clone())
        .find_job_request_by_id(job_id)
        .await
        .unwrap()
        .unwrap();
    assert!(job.fee_paid);
    assert!(job.payment_done);
    assert_eq!(job.payment_method.as_deref(), Some("card"));
    assert_eq!(job.status.as_str(), "active");

    let count: (i64,) = sqlx::query_as(
        "SELECT COUNT(*) FROM job_payments WHERE job_request_id = $1 AND simulated = TRUE",
    )
    .bind(job_id)
    .fetch_one(&pool)
    .await
    .unwrap();
    assert_eq!(count.0, 1);
}

#[sqlx::test(migrations = "./migrations")]
async fn paying_twice_is_idempotent_and_keeps_one_payment_row(pool: PgPool) {
    let (job_id, client_id) = bidding_job_ready_to_pay(&pool).await;

    let (first, _) = pay(&pool, job_id, client_id, "Efectivo").await;
    let (second, body) = pay(&pool, job_id, client_id, "Efectivo").await;

    assert_eq!(first, StatusCode::OK);
    assert_eq!(second, StatusCode::OK, "{body}");

    let count: (i64,) = sqlx::query_as(
        "SELECT COUNT(*) FROM job_payments WHERE job_request_id = $1",
    )
    .bind(job_id)
    .fetch_one(&pool)
    .await
    .unwrap();
    assert_eq!(count.0, 1);
}

#[sqlx::test(migrations = "./migrations")]
async fn an_unknown_payment_method_is_rejected(pool: PgPool) {
    let (job_id, client_id) = bidding_job_ready_to_pay(&pool).await;

    let (status, body) = pay(&pool, job_id, client_id, "bitcoin").await;

    assert_eq!(status, StatusCode::UNPROCESSABLE_ENTITY, "{body}");
}
