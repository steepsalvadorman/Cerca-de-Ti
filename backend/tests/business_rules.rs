//! Negative tests for the job lifecycle rules.
//!
//! `job_lifecycle.rs` covers the happy path; this file covers everything
//! the backend must *refuse*. These rules were added after an audit found
//! the lifecycle was write-forward: it accepted almost any transition in
//! almost any order, and required bidding payments were never checked.

use std::sync::Arc;

use sqlx::PgPool;
use uuid::Uuid;

use backend::features::chat::application::{GetMessagesUseCase, SendMessageInput, SendMessageUseCase};
use backend::features::chat::infrastructure::PostgresChatRepository;
use backend::features::job::application::{
    ChooseOfferInput, ChooseOfferUseCase, CreateJobInput, CreateJobUseCase, PayFeeInput, PayFeeUseCase,
    SubmitOfferInput, SubmitOfferUseCase,
};
use backend::features::job::domain::{JobError, JobRepository, JobRequest};
use backend::features::job::infrastructure::{FakePaymentGateway, PostgresJobRepository};
use backend::features::job::application::PaymentGateway;
use backend::features::technician::domain::TechnicianRepository;
use backend::features::technician::infrastructure::PostgresTechnicianRepository;
use backend::features::tracking::application::{GetLocationUseCase, UpdateLocationInput, UpdateLocationUseCase};
use backend::features::tracking::infrastructure::PostgresTrackingRepository;

struct Ctx {
    jobs: Arc<dyn JobRepository>,
    techs: Arc<dyn TechnicianRepository>,
    payments: Arc<dyn PaymentGateway>,
    pool: PgPool,
}

impl Ctx {
    fn new(pool: PgPool) -> Self {
        Self {
            jobs: Arc::new(PostgresJobRepository::new(pool.clone())),
            techs: Arc::new(PostgresTechnicianRepository::new(pool.clone())),
            payments: Arc::new(FakePaymentGateway),
            pool,
        }
    }

    async fn user(&self, role: &str) -> Uuid {
        let id = Uuid::new_v4();
        sqlx::query("INSERT INTO users (id, email, name, role, password_hash) VALUES ($1, $2, 'Test', $3, 'hash')")
            .bind(id)
            .bind(format!("{id}@test.local"))
            .bind(role)
            .execute(&self.pool)
            .await
            .unwrap();
        id
    }

    async fn technician(&self) -> (Uuid, i32) {
        let user_id = self.user("technician").await;
        // `is_verified` is TRUE because bidding is gated on it (GAP-05):
        // these tests are about the auction rules, not about verification,
        // and an unverified bidder is rejected before any of them apply.
        // The unverified case has its own test.
        let row: (i32,) = sqlx::query_as(
            "INSERT INTO technician_profiles (user_id, oficio, pin_top, pin_left, is_verified) VALUES ($1, 'Gasfitero', 0.5, 0.5, TRUE) RETURNING id",
        )
        .bind(user_id)
        .fetch_one(&self.pool)
        .await
        .unwrap();
        (user_id, row.0)
    }

    async fn job(&self, client_id: Uuid, kind: &str, technician_profile_id: Option<i32>) -> JobRequest {
        CreateJobUseCase::new(self.jobs.clone())
            .execute(CreateJobInput {
                client_id,
                technician_profile_id,
                tech_team_id: None,
                job_kind: kind.to_string(),
                title: None,
                address: None,
                mobility_included: None,
            })
            .await
            .unwrap()
    }

    async fn pay(&self, job_id: Uuid, client_id: Uuid) -> Result<backend::features::job::application::PayFeeResult, JobError> {
        PayFeeUseCase::new(self.jobs.clone(), self.payments.clone())
            .execute(PayFeeInput { job_request_id: job_id, client_id, payment_method: "card".to_string() })
            .await
    }

    fn send_message(&self) -> SendMessageUseCase {
        SendMessageUseCase::new(
            Arc::new(PostgresChatRepository::new(self.pool.clone())),
            self.jobs.clone(),
            self.techs.clone(),
        )
    }

    fn read_messages(&self) -> GetMessagesUseCase {
        GetMessagesUseCase::new(
            Arc::new(PostgresChatRepository::new(self.pool.clone())),
            self.jobs.clone(),
            self.techs.clone(),
        )
    }

    fn push_location(&self) -> UpdateLocationUseCase {
        UpdateLocationUseCase::new(
            Arc::new(PostgresTrackingRepository::new(self.pool.clone())),
            self.jobs.clone(),
            self.techs.clone(),
        )
    }

    fn read_location(&self) -> GetLocationUseCase {
        GetLocationUseCase::new(
            Arc::new(PostgresTrackingRepository::new(self.pool.clone())),
            self.jobs.clone(),
            self.techs.clone(),
        )
    }
}

// ---------------------------------------------------------------------
// Direct contact is free at launch. Chat and location must be available
// immediately without a fake payment step.
// ---------------------------------------------------------------------

#[sqlx::test(migrations = "./migrations")]
async fn direct_chat_is_available_without_a_platform_payment(pool: PgPool) {
    let ctx = Ctx::new(pool);
    let client_id = ctx.user("client").await;
    let (_, profile_id) = ctx.technician().await;
    let job = ctx.job(client_id, "direct", Some(profile_id)).await;

    ctx.send_message()
        .execute(SendMessageInput {
            job_request_id: job.id,
            sender_id: client_id,
            sender_role: "client".to_string(),
            text: "Hola, ¿cuál es tu número?".to_string(),
        })
        .await
        .expect("direct contact must be free");
    assert_eq!(ctx.read_messages().execute(job.id, client_id).await.unwrap().len(), 1);
}

#[sqlx::test(migrations = "./migrations")]
async fn direct_tracking_is_available_without_a_platform_payment(pool: PgPool) {
    let ctx = Ctx::new(pool);
    let client_id = ctx.user("client").await;
    let (tech_user_id, profile_id) = ctx.technician().await;
    let job = ctx.job(client_id, "direct", Some(profile_id)).await;

    ctx.push_location()
        .execute(UpdateLocationInput {
            job_request_id: job.id,
            technician_user_id: tech_user_id,
            latitude: -12.05,
            longitude: -77.04,
        })
        .await
        .expect("tracking for a direct job must be free");
    let location = ctx.read_location().execute(job.id, client_id).await.unwrap();
    assert_eq!(location.latitude, -12.05);
    assert_eq!(location.longitude, -77.04);
}

// ---------------------------------------------------------------------
// Paying
// ---------------------------------------------------------------------

#[sqlx::test(migrations = "./migrations")]
async fn paying_twice_is_harmless_and_never_resurrects_a_finished_job(pool: PgPool) {
    let ctx = Ctx::new(pool);
    let client_id = ctx.user("client").await;
    let (tech_user_id, profile_id) = ctx.technician().await;
    let job = ctx.job(client_id, "direct", Some(profile_id)).await;

    ctx.pay(job.id, client_id).await.unwrap();

    // Drive it to completion.
    let advance = backend::features::job::application::AdvanceProgressUseCase::new(ctx.jobs.clone(), ctx.techs.clone());
    for _ in 0..3 {
        advance.execute(job.id, tech_user_id).await.unwrap();
    }
    let completed = ctx.jobs.find_job_request_by_id(job.id).await.unwrap().unwrap();
    assert_eq!(completed.status.as_str(), "completed");

    // A retried payment must not reset the job back to step 0 — and it must
    // not report success either. A `direct` job is born `fee_paid`, so the
    // idempotency early-return used to answer `Ok` here and the client had
    // no way to tell that it had just "paid" a finished job (GAP-12). The
    // terminal check now runs first, so this is refused outright. What the
    // name promises is unchanged: nothing resurrects the job.
    let retry = ctx.pay(job.id, client_id).await;
    assert!(
        matches!(retry, Err(JobError::InvalidStatusTransition)),
        "paying a finished job must be refused, got {retry:?}"
    );

    let after = ctx.jobs.find_job_request_by_id(job.id).await.unwrap().unwrap();
    assert_eq!(after.status.as_str(), "completed");
    assert_eq!(after.timeline_step, 3);
}

// ---------------------------------------------------------------------
// Bidding
// ---------------------------------------------------------------------

#[sqlx::test(migrations = "./migrations")]
async fn a_technician_cannot_bid_twice_on_the_same_job(pool: PgPool) {
    let ctx = Ctx::new(pool);
    let client_id = ctx.user("client").await;
    let (tech_user_id, _) = ctx.technician().await;
    let job = ctx.job(client_id, "bidding", None).await;

    let submit = SubmitOfferUseCase::new(ctx.jobs.clone(), ctx.techs.clone());
    let bid = |price: i32| SubmitOfferInput {
        job_request_id: job.id,
        technician_user_id: tech_user_id,
        price,
        eta: "Hoy, 16:00".to_string(),
    };

    submit.execute(bid(80)).await.unwrap();
    let second = submit.execute(bid(70)).await;

    assert!(
        matches!(second, Err(JobError::OfferAlreadySubmitted)),
        "otherwise one technician can flood the client's bidding screen"
    );
    assert_eq!(ctx.jobs.find_offers_by_job_id(job.id).await.unwrap().len(), 1);
}

#[sqlx::test(migrations = "./migrations")]
async fn offers_are_rejected_on_the_wrong_kind_of_job_and_at_impossible_prices(pool: PgPool) {
    let ctx = Ctx::new(pool);
    let client_id = ctx.user("client").await;
    let (tech_user_id, profile_id) = ctx.technician().await;

    let direct = ctx.job(client_id, "direct", Some(profile_id)).await;
    let submit = SubmitOfferUseCase::new(ctx.jobs.clone(), ctx.techs.clone());

    let on_direct = submit
        .execute(SubmitOfferInput {
            job_request_id: direct.id,
            technician_user_id: tech_user_id,
            price: 80,
            eta: "Hoy".to_string(),
        })
        .await;
    assert!(matches!(on_direct, Err(JobError::InvalidStatusTransition)), "a direct hire is not an auction");

    let auction = ctx.job(client_id, "bidding", None).await;
    for bad_price in [0, -50] {
        let result = submit
            .execute(SubmitOfferInput {
                job_request_id: auction.id,
                technician_user_id: tech_user_id,
                price: bad_price,
                eta: "Hoy".to_string(),
            })
            .await;
        assert!(matches!(result, Err(JobError::InvalidOffer)), "price {bad_price} must be rejected");
    }

    let blank_eta = submit
        .execute(SubmitOfferInput {
            job_request_id: auction.id,
            technician_user_id: tech_user_id,
            price: 80,
            eta: "   ".to_string(),
        })
        .await;
    assert!(matches!(blank_eta, Err(JobError::InvalidOffer)));
}

#[sqlx::test(migrations = "./migrations")]
async fn an_offer_cannot_be_chosen_twice_or_after_the_job_started(pool: PgPool) {
    let ctx = Ctx::new(pool);
    let client_id = ctx.user("client").await;
    let (first_user, _) = ctx.technician().await;
    let (second_user, _) = ctx.technician().await;
    let job = ctx.job(client_id, "bidding", None).await;

    let submit = SubmitOfferUseCase::new(ctx.jobs.clone(), ctx.techs.clone());
    for user_id in [first_user, second_user] {
        submit
            .execute(SubmitOfferInput {
                job_request_id: job.id,
                technician_user_id: user_id,
                price: 90,
                eta: "Hoy".to_string(),
            })
            .await
            .unwrap();
    }

    let offers = ctx.jobs.find_offers_by_job_id(job.id).await.unwrap();
    assert_eq!(offers.len(), 2);

    let choose = ChooseOfferUseCase::new(ctx.jobs.clone());
    choose
        .execute(ChooseOfferInput { job_request_id: job.id, client_id, offer_id: offers[0].id })
        .await
        .unwrap();

    // Swapping to the runner-up after committing would strand the first
    // technician, who already sees the job as theirs.
    let swap = choose
        .execute(ChooseOfferInput { job_request_id: job.id, client_id, offer_id: offers[1].id })
        .await;
    assert!(matches!(swap, Err(JobError::InvalidStatusTransition)));

    // And once the job is paid for and running, nothing may reassign it.
    ctx.pay(job.id, client_id).await.unwrap();
    let after_start = choose
        .execute(ChooseOfferInput { job_request_id: job.id, client_id, offer_id: offers[1].id })
        .await;
    assert!(matches!(after_start, Err(JobError::InvalidStatusTransition)));
}

#[sqlx::test(migrations = "./migrations")]
async fn bidding_closes_once_the_job_has_its_technician(pool: PgPool) {
    let ctx = Ctx::new(pool);
    let client_id = ctx.user("client").await;
    let (winner_user, _) = ctx.technician().await;
    let (latecomer_user, _) = ctx.technician().await;
    let job = ctx.job(client_id, "bidding", None).await;

    let submit = SubmitOfferUseCase::new(ctx.jobs.clone(), ctx.techs.clone());
    submit
        .execute(SubmitOfferInput {
            job_request_id: job.id,
            technician_user_id: winner_user,
            price: 90,
            eta: "Hoy".to_string(),
        })
        .await
        .unwrap();

    let offers = ctx.jobs.find_offers_by_job_id(job.id).await.unwrap();
    ChooseOfferUseCase::new(ctx.jobs.clone())
        .execute(ChooseOfferInput { job_request_id: job.id, client_id, offer_id: offers[0].id })
        .await
        .unwrap();

    let late = submit
        .execute(SubmitOfferInput {
            job_request_id: job.id,
            technician_user_id: latecomer_user,
            price: 50,
            eta: "Mañana".to_string(),
        })
        .await;
    // Once it has its technician the job belongs to someone else: the
    // latecomer gets the same answer as any unassigned technician (403),
    // which `ownership_authorization.rs` pins at the HTTP level.
    assert!(matches!(late, Err(JobError::Unauthorized)));
}
