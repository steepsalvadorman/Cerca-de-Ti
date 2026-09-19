//! Property-based authorization: the wrong actor must get 403 (GAP-09).
//!
//! `role_authorization.rs` checks role gates; this file checks *ownership*:
//! a legitimate client who is not the job owner, or a technician who is not
//! assigned, must not mutate or read someone else's job.

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

const TEST_JWT_SECRET: &str = "test-secret-for-ownership-authorization";

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

async fn status_of(
    pool: &PgPool,
    method: &str,
    path: &str,
    token: Option<&str>,
    body: Option<String>,
) -> StatusCode {
    let mut request = Request::builder().method(method).uri(path);
    if let Some(token) = token {
        request = request.header("Authorization", format!("Bearer {token}"));
    }
    if body.is_some() {
        request = request.header("Content-Type", "application/json");
    }

    app_router(test_state(pool.clone()), &[])
        .oneshot(request.body(body.map_or_else(Body::empty, Body::from)).unwrap())
        .await
        .unwrap()
        .status()
}

struct JobFixture {
    job_id: Uuid,
    offer_id: i32,
}

async fn bidding_job_with_chosen_technician(pool: &PgPool) -> JobFixture {
    let job_repo = Arc::new(PostgresJobRepository::new(pool.clone()));
    let tech_repo = Arc::new(PostgresTechnicianRepository::new(pool.clone()));

    let owner_id = create_user(pool, "client").await;
    let (assigned_tech_id, _) = create_technician(pool).await;

    let job = CreateJobUseCase::new(job_repo.clone())
        .execute(CreateJobInput {
            client_id: owner_id,
            technician_profile_id: None,
            tech_team_id: None,
            job_kind: "bidding".to_string(),
            title: Some("Fuga".to_string()),
            address: Some("Calle 1".to_string()),
            mobility_included: None,
        })
        .await
        .unwrap();

    SubmitOfferUseCase::new(job_repo.clone(), tech_repo.clone())
        .execute(SubmitOfferInput {
            job_request_id: job.id,
            technician_user_id: assigned_tech_id,
            price: 120,
            eta: "Hoy".to_string(),
        })
        .await
        .unwrap();

    let offers = job_repo.find_offers_by_job_id(job.id).await.unwrap();
    ChooseOfferUseCase::new(job_repo)
        .execute(ChooseOfferInput {
            job_request_id: job.id,
            client_id: owner_id,
            offer_id: offers[0].id,
        })
        .await
        .unwrap();

    JobFixture {
        job_id: job.id,
        offer_id: offers[0].id,
    }
}

#[sqlx::test(migrations = "./migrations")]
async fn an_unrelated_client_cannot_pay_rate_or_choose_on_someone_elses_job(pool: PgPool) {
    let fixture = bidding_job_with_chosen_technician(&pool).await;
    let stranger_id = create_user(&pool, "client").await;
    let token = token_for(stranger_id, Role::Client);

    assert_eq!(
        status_of(
            &pool,
            "POST",
            &format!("/jobs/{}/pay", fixture.job_id),
            Some(&token),
            Some(r#"{"payment_method":"card"}"#.to_string()),
        )
        .await,
        StatusCode::FORBIDDEN
    );

    assert_eq!(
        status_of(
            &pool,
            "POST",
            &format!("/jobs/{}/rate", fixture.job_id),
            Some(&token),
            Some(r#"{"rating":5,"comment":"genial"}"#.to_string()),
        )
        .await,
        StatusCode::FORBIDDEN
    );

    assert_eq!(
        status_of(
            &pool,
            "POST",
            &format!("/jobs/{}/offers/choose", fixture.job_id),
            Some(&token),
            Some(format!(r#"{{"offer_id":{}}}"#, fixture.offer_id)),
        )
        .await,
        StatusCode::FORBIDDEN
    );

    assert_eq!(
        status_of(
            &pool,
            "POST",
            &format!("/jobs/{}/cancel", fixture.job_id),
            Some(&token),
            Some(r#"{"reason":"ya no"}"#.to_string()),
        )
        .await,
        StatusCode::FORBIDDEN
    );
}

#[sqlx::test(migrations = "./migrations")]
async fn an_unassigned_technician_cannot_advance_pay_or_bid_on_a_closed_assignment(pool: PgPool) {
    let fixture = bidding_job_with_chosen_technician(&pool).await;
    let (other_tech_id, _) = create_technician(&pool).await;
    let token = token_for(other_tech_id, Role::Technician);

    assert_eq!(
        status_of(
            &pool,
            "POST",
            &format!("/jobs/{}/advance", fixture.job_id),
            Some(&token),
            None,
        )
        .await,
        StatusCode::FORBIDDEN
    );

    assert_eq!(
        status_of(
            &pool,
            "POST",
            &format!("/jobs/{}/offers", fixture.job_id),
            Some(&token),
            Some(r#"{"price":100,"eta":"Mañana"}"#.to_string()),
        )
        .await,
        StatusCode::FORBIDDEN
    );

    assert_eq!(
        status_of(
            &pool,
            "GET",
            &format!("/jobs/{}/messages", fixture.job_id),
            Some(&token),
            None,
        )
        .await,
        StatusCode::FORBIDDEN
    );

    assert_eq!(
        status_of(
            &pool,
            "GET",
            &format!("/jobs/{}/location", fixture.job_id),
            Some(&token),
            None,
        )
        .await,
        StatusCode::FORBIDDEN
    );
}

#[sqlx::test(migrations = "./migrations")]
async fn a_stranger_cannot_read_someone_elses_job(pool: PgPool) {
    let fixture = bidding_job_with_chosen_technician(&pool).await;
    let stranger_id = create_user(&pool, "client").await;
    let token = token_for(stranger_id, Role::Client);

    assert_eq!(
        status_of(
            &pool,
            "GET",
            &format!("/jobs/{}", fixture.job_id),
            Some(&token),
            None,
        )
        .await,
        StatusCode::FORBIDDEN
    );
}
