//! End-to-end tests for the bidding flow through the real router.
//!
//! These exist because of GAP-80: the bidding feature was inoperable from
//! the app and no test noticed. `GetTechnicianJobsUseCase` listed open
//! auctions, the technician tapped one, the detail screen fetched
//! `GET /jobs/{id}` ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â and `authorize_job_access` answered 403, because it
//! only recognised the owning client and the *already assigned*
//! technician. On an open auction `technician_profile_id` is NULL, so no
//! technician could ever open the job, the offer form never rendered, and
//! nothing else in the app posts an offer.
//!
//! The unit/integration tests that existed all drove use cases directly
//! with the *owner* as the caller, which is exactly why the hole survived:
//! the missing case was a legitimate third party, not a forbidden one.
//!
//! The second half of the file is the other side of the same fix ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â being
//! allowed to *read* an auction must not mean seeing who posted it or
//! where they live (GAP-18).

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

const TEST_JWT_SECRET: &str = "test-secret-for-bidding-flow";

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

/// A technician with the profile row that `submit_offer` requires.
///
/// Verified by default: bidding is gated on `is_verified` (GAP-05), and
/// most of these tests are about authorization. The unverified case has
/// its own helper and its own test.
async fn create_technician(pool: &PgPool) -> Uuid {
    create_technician_with_verification(pool, true).await
}

/// A technician whose verification is deliberately incomplete.
async fn create_unverified_technician(pool: &PgPool) -> Uuid {
    create_technician_with_verification(pool, false).await
}

async fn create_technician_with_verification(pool: &PgPool, is_verified: bool) -> Uuid {
    let user_id = create_user(pool, "technician").await;
    sqlx::query(
        "INSERT INTO technician_profiles (user_id, oficio, pin_top, pin_left, is_verified) \
         VALUES ($1, 'Gasfitero', 0.5, 0.5, $2)",
    )
    .bind(user_id)
    .bind(is_verified)
    .execute(pool)
    .await
    .unwrap();
    user_id
}

fn token_for(user_id: Uuid, role: Role) -> String {
    JwtTokenService::new(TEST_JWT_SECRET).issue(user_id, role).unwrap()
}

/// Returns the status and the raw body, since the restricted view is
/// defined by *which fields are absent* ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â a status code alone cannot
/// assert that.
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

/// Creates a `bidding` job owned by `client_id` and returns its id.
async fn create_bidding_job(pool: &PgPool, client_id: Uuid, title: &str, address: &str) -> Uuid {
    let job_repo: Arc<dyn backend::features::job::domain::JobRepository> =
        Arc::new(PostgresJobRepository::new(pool.clone()));

    let job = backend::features::job::application::CreateJobUseCase::new(job_repo)
        .execute(backend::features::job::application::CreateJobInput {
            client_id,
            technician_profile_id: None,
            tech_team_id: None,
            job_kind: "bidding".to_string(),
            title: Some(title.to_string()),
            address: Some(address.to_string()),
            mobility_included: None,
        })
        .await
        .unwrap();

    job.id
}

/// Creates a `direct` job owned by `client_id`, assigned to `technician_profile_id`.
/// `direct` jobs are free, so they are born `active` with a timeline to walk.
async fn create_direct_job(pool: &PgPool, client_id: Uuid, technician_profile_id: i32) -> Uuid {
    let job_repo: Arc<dyn backend::features::job::domain::JobRepository> =
        Arc::new(PostgresJobRepository::new(pool.clone()));

    let job = backend::features::job::application::CreateJobUseCase::new(job_repo)
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
        .unwrap();

    job.id
}

async fn technician_profile_id(pool: &PgPool, user_id: Uuid) -> i32 {
    let row: (i32,) = sqlx::query_as("SELECT id FROM technician_profiles WHERE user_id = $1")
        .bind(user_id)
        .fetch_one(pool)
        .await
        .unwrap();
    row.0
}

/// GAP-15: the client used to be able to walk the timeline to `completed`
/// on their own job — the "Actualizar estado" button on the tracking
/// screen — and then rate a job they had just closed themselves, without
/// the technician ever leaving the house.
#[sqlx::test(migrations = "./migrations")]
async fn a_client_cannot_advance_their_own_job(pool: PgPool) {
    let client_id = create_user(&pool, "client").await;
    let tech_id = create_technician(&pool).await;
    let profile_id = technician_profile_id(&pool, tech_id).await;
    let job_id = create_direct_job(&pool, client_id, profile_id).await;

    let (status, _) = call(
        &pool,
        "POST",
        &format!("/jobs/{job_id}/advance"),
        &token_for(client_id, Role::Client),
        None::<String>,
    )
    .await;

    assert_eq!(
        status,
        StatusCode::FORBIDDEN,
        "only the assigned technician can confirm the work happened"
    );

    // And the job really did not move.
    let (step, status): (i32, String) =
        sqlx::query_as("SELECT timeline_step, status FROM job_requests WHERE id = $1")
            .bind(job_id)
            .fetch_one(&pool)
            .await
            .unwrap();
    assert_eq!(step, 0);
    assert_eq!(status, "active");
}

/// The technician it belongs to still can — the fix must not have broken
/// the normal path.
#[sqlx::test(migrations = "./migrations")]
async fn the_assigned_technician_can_still_advance_the_job(pool: PgPool) {
    let client_id = create_user(&pool, "client").await;
    let tech_id = create_technician(&pool).await;
    let profile_id = technician_profile_id(&pool, tech_id).await;
    let job_id = create_direct_job(&pool, client_id, profile_id).await;

    let token = token_for(tech_id, Role::Technician);
    for expected_step in 1..=3 {
        let (status, body) = call(
            &pool,
            "POST",
            &format!("/jobs/{job_id}/advance"),
            &token,
            None::<String>,
        )
        .await;
        assert_eq!(status, StatusCode::OK, "advance to step {expected_step} failed: {body}");

        let (step,): (i32,) = sqlx::query_as("SELECT timeline_step FROM job_requests WHERE id = $1")
            .bind(job_id)
            .fetch_one(&pool)
            .await
            .unwrap();
        assert_eq!(step, expected_step);
    }

    let (status,): (String,) = sqlx::query_as("SELECT status FROM job_requests WHERE id = $1")
        .bind(job_id)
        .fetch_one(&pool)
        .await
        .unwrap();
    assert_eq!(status, "completed");
}

/// A technician who was not assigned still cannot move someone else's job.
#[sqlx::test(migrations = "./migrations")]
async fn an_unassigned_technician_cannot_advance_the_job(pool: PgPool) {
    let client_id = create_user(&pool, "client").await;
    let assigned_id = create_technician(&pool).await;
    let stranger_id = create_technician(&pool).await;
    let profile_id = technician_profile_id(&pool, assigned_id).await;
    let job_id = create_direct_job(&pool, client_id, profile_id).await;

    let (status, _) = call(
        &pool,
        "POST",
        &format!("/jobs/{job_id}/advance"),
        &token_for(stranger_id, Role::Technician),
        None::<String>,
    )
    .await;

    assert_eq!(status, StatusCode::FORBIDDEN);
}

/// The regression test for GAP-05/GAP-20.
///
/// `is_verified` used to be a badge and nothing else: an account with no
/// documents at all could bid, win, and be hired. The claim "verified
/// technicians" is the product's promise, so the action the badge vouches
/// for has to be gated on it.
#[sqlx::test(migrations = "./migrations")]
async fn an_unverified_technician_cannot_bid(pool: PgPool) {
    let client_id = create_user(&pool, "client").await;
    let tech_id = create_unverified_technician(&pool).await;
    let job_id = create_bidding_job(&pool, client_id, "Fuga de agua", "Av. Siempre Viva 123").await;

    let (status, body) = call(
        &pool,
        "POST",
        &format!("/jobs/{job_id}/offers"),
        &token_for(tech_id, Role::Technician),
        Some(r#"{"price":130,"eta":"Hoy, 16:00"}"#.to_string()),
    )
    .await;

    assert_eq!(
        status,
        StatusCode::FORBIDDEN,
        "an unverified technician must not be able to bid: {body}"
    );

    let (offers,): (i64,) =
        sqlx::query_as("SELECT COUNT(*) FROM job_offers WHERE job_request_id = $1")
            .bind(job_id)
            .fetch_one(&pool)
            .await
            .unwrap();
    assert_eq!(offers, 0, "and the attempt must not have left an offer behind");
}

/// Reading the auction is still allowed while unverified — the client
/// decides what to do about an unverified bidder, and `/technician/jobs`
/// is what the app uses to know what it *could* bid on once verified.
/// The gate belongs on the action, not on the read.
#[sqlx::test(migrations = "./migrations")]
async fn an_unverified_technician_can_still_see_the_auction(pool: PgPool) {
    let client_id = create_user(&pool, "client").await;
    let tech_id = create_unverified_technician(&pool).await;
    let job_id = create_bidding_job(&pool, client_id, "Fuga de agua", "Av. Siempre Viva 123").await;

    let (status, _) = call(
        &pool,
        "GET",
        &format!("/jobs/{job_id}"),
        &token_for(tech_id, Role::Technician),
        None::<String>,
    )
    .await;

    assert_eq!(status, StatusCode::OK);
}

/// GAP-06: `price` is an `i32`, so without a ceiling a client could post
/// `2147483647` and poison the bidding screen.
#[sqlx::test(migrations = "./migrations")]
async fn an_absurd_offer_price_is_rejected(pool: PgPool) {
    let client_id = create_user(&pool, "client").await;
    let tech_id = create_technician(&pool).await;
    let job_id = create_bidding_job(&pool, client_id, "Fuga de agua", "Av. Siempre Viva 123").await;

    for price in [i32::MAX, 1_000_001] {
        let (status, body) = call(
            &pool,
            "POST",
            &format!("/jobs/{job_id}/offers"),
            &token_for(tech_id, Role::Technician),
            Some(format!(r#"{{"price":{price},"eta":"Hoy"}}"#)),
        )
        .await;

        assert_eq!(
            status,
            StatusCode::BAD_REQUEST,
            "price {price} must be refused: {body}"
        );
    }

    // A plausible quote still works.
    let (status, _) = call(
        &pool,
        "POST",
        &format!("/jobs/{job_id}/offers"),
        &token_for(tech_id, Role::Technician),
        Some(r#"{"price":130,"eta":"Hoy"}"#.to_string()),
    )
    .await;
    assert_eq!(status, StatusCode::CREATED);
}

/// GAP-02, on the one free-text field of a bid.
#[sqlx::test(migrations = "./migrations")]
async fn an_overlong_eta_is_rejected(pool: PgPool) {
    let client_id = create_user(&pool, "client").await;
    let tech_id = create_technician(&pool).await;
    let job_id = create_bidding_job(&pool, client_id, "Fuga de agua", "Av. Siempre Viva 123").await;

    let eta = "a".repeat(61);
    let (status, body) = call(
        &pool,
        "POST",
        &format!("/jobs/{job_id}/offers"),
        &token_for(tech_id, Role::Technician),
        Some(format!(r#"{{"price":130,"eta":"{eta}"}}"#)),
    )
    .await;

    assert_eq!(status, StatusCode::BAD_REQUEST, "61 characters must be refused: {body}");
}

/// The regression test for GAP-80.
#[sqlx::test(migrations = "./migrations")]
async fn an_eligible_technician_can_open_an_open_bidding_job(pool: PgPool) {
    let client_id = create_user(&pool, "client").await;
    let tech_id = create_technician(&pool).await;
    let job_id = create_bidding_job(&pool, client_id, "Fuga de agua", "Av. Siempre Viva 123").await;

    let (status, _) = call(
        &pool,
        "GET",
        &format!("/jobs/{job_id}"),
        &token_for(tech_id, Role::Technician),
        None::<String>,
    )
    .await;

    assert_eq!(
        status,
        StatusCode::OK,
        "a technician must be able to open an auction they are allowed to bid on ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â \
         this 403 is what made the bidding flow unusable from the app"
    );
}

/// And the endpoint the app actually needs after opening it.
#[sqlx::test(migrations = "./migrations")]
async fn an_eligible_technician_can_submit_an_offer_on_that_job(pool: PgPool) {
    let client_id = create_user(&pool, "client").await;
    let tech_id = create_technician(&pool).await;
    let job_id = create_bidding_job(&pool, client_id, "Fuga de agua", "Av. Siempre Viva 123").await;

    let (status, _) = call(
        &pool,
        "POST",
        &format!("/jobs/{job_id}/offers"),
        &token_for(tech_id, Role::Technician),
        Some(r#"{"price":130,"eta":"Hoy, 16:00"}"#.to_string()),
    )
    .await;

    assert_eq!(status, StatusCode::CREATED);
}

/// GAP-18: the client's identity and address are not part of what a
/// candidate needs to decide whether to bid.
#[sqlx::test(migrations = "./migrations")]
async fn the_restricted_view_withholds_the_clients_identity_and_address(pool: PgPool) {
    let client_id = create_user(&pool, "client").await;
    let tech_id = create_technician(&pool).await;
    let job_id = create_bidding_job(&pool, client_id, "Fuga de agua", "Av. Siempre Viva 123").await;

    let (status, body) = call(
        &pool,
        "GET",
        &format!("/jobs/{job_id}"),
        &token_for(tech_id, Role::Technician),
        None::<String>,
    )
    .await;
    assert_eq!(status, StatusCode::OK);

    // The job id and the details that inform a bid are thereÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦
    assert!(body.contains(&job_id.to_string()), "the technician needs the job id: {body}");
    assert!(body.contains("Fuga de agua"), "the title is what they bid on: {body}");
    assert!(body.contains("bidding"), "the kind tells them it is an auction: {body}");

    // ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦and the client's data is not.
    assert!(
        !body.contains(&client_id.to_string()),
        "the restricted view leaked the client's user id: {body}"
    );
    assert!(
        !body.contains("Av. Siempre Viva"),
        "the restricted view leaked the client's address: {body}"
    );
    assert!(
        !body.contains("fee_amount") && !body.contains("fee_paid"),
        "what the client is charged is not the bidder's business: {body}"
    );
}

/// The same restriction has to hold on the listing, which is the endpoint
/// every technician's app polls ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â leaking there would be worse.
#[sqlx::test(migrations = "./migrations")]
async fn the_open_bid_feed_never_leaks_the_clients_address(pool: PgPool) {
    let client_id = create_user(&pool, "client").await;
    let tech_id = create_technician(&pool).await;
    create_bidding_job(&pool, client_id, "Fuga de agua", "Av. Siempre Viva 123").await;

    let (status, body) = call(
        &pool,
        "GET",
        "/technician/jobs",
        &token_for(tech_id, Role::Technician),
        None::<String>,
    )
    .await;
    assert_eq!(status, StatusCode::OK);

    assert!(body.contains("Fuga de agua"), "the auction must still be listed: {body}");
    assert!(
        !body.contains(&client_id.to_string()),
        "the open-bid feed leaked the client's user id: {body}"
    );
    assert!(
        !body.contains("Av. Siempre Viva"),
        "the open-bid feed leaked the client's address: {body}"
    );
}

/// The client keeps the full view of their own job ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â the restriction must
/// not have been applied by simply hiding these fields from everybody.
#[sqlx::test(migrations = "./migrations")]
async fn the_owning_client_still_sees_their_own_job_in_full(pool: PgPool) {
    let client_id = create_user(&pool, "client").await;
    let job_id = create_bidding_job(&pool, client_id, "Fuga de agua", "Av. Siempre Viva 123").await;

    let (status, body) = call(
        &pool,
        "GET",
        &format!("/jobs/{job_id}"),
        &token_for(client_id, Role::Client),
        None::<String>,
    )
    .await;
    assert_eq!(status, StatusCode::OK);

    assert!(body.contains(&client_id.to_string()), "the owner sees their own id: {body}");
    assert!(body.contains("Av. Siempre Viva"), "the owner sees their own address: {body}");
    assert!(body.contains("fee_amount"), "the owner sees what they are charged: {body}");
}

/// Widening access to open auctions must not have widened it to jobs that
/// are already spoken for: a technician who lost the bid still must not be
/// able to read the job once someone else is assigned.
#[sqlx::test(migrations = "./migrations")]
async fn a_technician_who_lost_the_bid_cannot_read_the_assigned_job(pool: PgPool) {
    let client_id = create_user(&pool, "client").await;
    let winner_id = create_technician(&pool).await;
    let loser_id = create_technician(&pool).await;
    let job_id = create_bidding_job(&pool, client_id, "Fuga de agua", "Av. Siempre Viva 123").await;

    // Both bid, the client picks the winner.
    for (tech_id, price) in [(winner_id, 130), (loser_id, 150)] {
        let offer = format!(r#"{{"price":{price},"eta":"Hoy"}}"#);
        let (status, _) = call(
            &pool,
            "POST",
            &format!("/jobs/{job_id}/offers"),
            &token_for(tech_id, Role::Technician),
            Some(offer.clone()),
        )
        .await;
        assert_eq!(status, StatusCode::CREATED);
    }

    let offers: Vec<(i32, Uuid)> = sqlx::query_as(
        "SELECT jo.id, tp.user_id FROM job_offers jo \
         JOIN technician_profiles tp ON tp.id = jo.technician_profile_id \
         WHERE jo.job_request_id = $1",
    )
    .bind(job_id)
    .fetch_all(&pool)
    .await
    .unwrap();
    let winning_offer_id = offers.iter().find(|(_, user)| *user == winner_id).unwrap().0;

    let (status, _) = call(
        &pool,
        "POST",
        &format!("/jobs/{job_id}/offers/choose"),
        &token_for(client_id, Role::Client),
        Some(format!(r#"{{"offer_id":{winning_offer_id}}}"#)),
    )
    .await;
    assert_eq!(status, StatusCode::OK);

    // The winner keeps accessÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦
    let (winner_status, _) = call(
        &pool,
        "GET",
        &format!("/jobs/{job_id}"),
        &token_for(winner_id, Role::Technician),
        None::<String>,
    )
    .await;
    assert_eq!(winner_status, StatusCode::OK, "the assigned technician keeps access");

    // ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦the runner-up does not.
    let (loser_status, _) = call(
        &pool,
        "GET",
        &format!("/jobs/{job_id}"),
        &token_for(loser_id, Role::Technician),
        None::<String>,
    )
    .await;
    assert_eq!(
        loser_status,
        StatusCode::FORBIDDEN,
        "only an *open* auction is readable by candidates; once assigned it is private"
    );
}

/// A technician account with no profile row is not a bidder, and must not
/// get the candidate's pass into open auctions.
#[sqlx::test(migrations = "./migrations")]
async fn a_user_without_a_technician_profile_cannot_read_an_open_auction(pool: PgPool) {
    let client_id = create_user(&pool, "client").await;
    let bare_tech_id = create_user(&pool, "technician").await;
    let job_id = create_bidding_job(&pool, client_id, "Fuga de agua", "Av. Siempre Viva 123").await;

    let (status, _) = call(
        &pool,
        "GET",
        &format!("/jobs/{job_id}"),
        &token_for(bare_tech_id, Role::Technician),
        None::<String>,
    )
    .await;

    assert_eq!(
        status,
        StatusCode::FORBIDDEN,
        "without a technician profile there is nothing to bid with"
    );
}

/// A direct hire is not an auction: the wide-open rule applies to
/// `bidding` jobs only.
#[sqlx::test(migrations = "./migrations")]
async fn an_unrelated_technician_cannot_read_a_direct_job(pool: PgPool) {
    let client_id = create_user(&pool, "client").await;
    let assigned_id = create_technician(&pool).await;
    let stranger_id = create_technician(&pool).await;

    let job_repo: Arc<dyn backend::features::job::domain::JobRepository> =
        Arc::new(PostgresJobRepository::new(pool.clone()));
    let profile_id: (i32,) = sqlx::query_as("SELECT id FROM technician_profiles WHERE user_id = $1")
        .bind(assigned_id)
        .fetch_one(&pool)
        .await
        .unwrap();

    let job = backend::features::job::application::CreateJobUseCase::new(job_repo)
        .execute(backend::features::job::application::CreateJobInput {
            client_id,
            technician_profile_id: Some(profile_id.0),
            tech_team_id: None,
            job_kind: "direct".to_string(),
            title: Some("Fuga".to_string()),
            address: Some("Av. Siempre Viva 123".to_string()),
            mobility_included: None,
        })
        .await
        .unwrap();

    let (status, _) = call(
        &pool,
        "GET",
        &format!("/jobs/{}", job.id),
        &token_for(stranger_id, Role::Technician),
        None::<String>,
    )
    .await;

    assert_eq!(status, StatusCode::FORBIDDEN);
}
