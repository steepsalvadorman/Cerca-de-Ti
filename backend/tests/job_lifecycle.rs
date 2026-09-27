//! Integration tests for the job feature's core use cases, run against a
//! real (ephemeral, per-test) Postgres database via `#[sqlx::test]`. These
//! exercise the exact application-layer code the HTTP handlers call, just
//! without the HTTP/auth transport — the cheapest place to catch a broken
//! authorization check or a wrong SQL column list.

use std::sync::Arc;

use sqlx::PgPool;
use uuid::Uuid;

use backend::features::job::application::{
    AdvanceProgressUseCase, ChooseOfferInput, ChooseOfferUseCase, CreateJobInput, CreateJobUseCase,
    PayFeeInput, PayFeeUseCase, RateJobInput, RateJobUseCase, SubmitOfferInput, SubmitOfferUseCase,
};
use backend::features::job::domain::JobRepository;
use backend::features::job::infrastructure::{FakePaymentGateway, PostgresJobRepository};
use backend::features::technician::domain::TechnicianRepository;
use backend::features::technician::infrastructure::PostgresTechnicianRepository;

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

async fn create_technician_profile(pool: &PgPool, user_id: Uuid) -> i32 {
    // Verified: bidding requires it (GAP-05), and these tests are about
    // the lifecycle rather than about verification.
    let row: (i32,) = sqlx::query_as(
        "INSERT INTO technician_profiles (user_id, oficio, pin_top, pin_left, is_verified) VALUES ($1, 'Gasfitero', 0.5, 0.5, TRUE) RETURNING id",
    )
    .bind(user_id)
    .fetch_one(pool)
    .await
    .unwrap();
    row.0
}

#[sqlx::test(migrations = "./migrations")]
async fn creating_a_job_computes_the_fee_server_side(pool: PgPool) {
    let job_repo: Arc<dyn JobRepository> = Arc::new(PostgresJobRepository::new(pool.clone()));
    let client_id = create_user(&pool, "client").await;

    let job = CreateJobUseCase::new(job_repo)
        .execute(CreateJobInput {
            client_id,
            technician_profile_id: None,
            tech_team_id: None,
            job_kind: "bidding".to_string(),
            title: None,
            address: None,
            mobility_included: None,
        })
        .await
        .unwrap();

    // S/ 4 is the only launch fee and is owned by the backend.
    assert_eq!(job.fee_amount, 4);
    assert!(job.mobility_included); // defaults to true when not specified
    assert_eq!(job.status.as_str(), "pending");
}

#[sqlx::test(migrations = "./migrations")]
async fn creating_a_job_rejects_incompatible_provider_assignments(pool: PgPool) {
    let repo: Arc<dyn JobRepository> = Arc::new(PostgresJobRepository::new(pool.clone()));
    let client_id = create_user(&pool, "client").await;

    for (kind, technician_profile_id, tech_team_id) in [
        ("direct", None, None),
        ("bidding", Some(1), None),
        ("bidding", None, Some(1)),
        ("project", Some(1), None),
    ] {
        let result = CreateJobUseCase::new(repo.clone())
            .execute(CreateJobInput {
                client_id,
                technician_profile_id,
                tech_team_id,
                job_kind: kind.to_string(),
                title: None,
                address: None,
                mobility_included: None,
            })
            .await;
        assert!(result.is_err(), "{kind} accepted an incompatible provider assignment");
    }
}

#[sqlx::test(migrations = "./migrations")]
async fn choosing_an_offer_assigns_the_technician_and_records_the_price(pool: PgPool) {
    let job_repo: Arc<dyn JobRepository> = Arc::new(PostgresJobRepository::new(pool.clone()));
    let tech_repo: Arc<dyn TechnicianRepository> = Arc::new(PostgresTechnicianRepository::new(pool.clone()));

    let client_id = create_user(&pool, "client").await;
    let tech_user_id = create_user(&pool, "technician").await;
    let tech_profile_id = create_technician_profile(&pool, tech_user_id).await;

    let job = CreateJobUseCase::new(job_repo.clone())
        .execute(CreateJobInput {
            client_id,
            technician_profile_id: None,
            tech_team_id: None,
            job_kind: "bidding".to_string(),
            title: None,
            address: None,
            mobility_included: None,
        })
        .await
        .unwrap();

    SubmitOfferUseCase::new(job_repo.clone(), tech_repo.clone())
        .execute(SubmitOfferInput {
            job_request_id: job.id,
            technician_user_id: tech_user_id,
            price: 27000,
            eta: "Hoy, 16:00".to_string(),
        })
        .await
        .unwrap();

    let offers = job_repo.find_offers_by_job_id(job.id).await.unwrap();
    assert_eq!(offers.len(), 1);

    ChooseOfferUseCase::new(job_repo.clone())
        .execute(ChooseOfferInput { job_request_id: job.id, client_id, offer_id: offers[0].id })
        .await
        .unwrap();

    let updated = job_repo.find_job_request_by_id(job.id).await.unwrap().unwrap();
    assert_eq!(updated.technician_profile_id, Some(tech_profile_id));
    // This is the exact bug fixed in this change: previously nothing
    // recorded which offer/price was accepted once a job was assigned.
    assert_eq!(updated.agreed_price, Some(27000));
}

#[sqlx::test(migrations = "./migrations")]
async fn paying_the_fee_activates_the_job_and_advancing_completes_it(pool: PgPool) {
    let job_repo: Arc<dyn JobRepository> = Arc::new(PostgresJobRepository::new(pool.clone()));
    let tech_repo: Arc<dyn TechnicianRepository> = Arc::new(PostgresTechnicianRepository::new(pool.clone()));

    let client_id = create_user(&pool, "client").await;
    let tech_user_id = create_user(&pool, "technician").await;
    let tech_profile_id = create_technician_profile(&pool, tech_user_id).await;

    let job = CreateJobUseCase::new(job_repo.clone())
        .execute(CreateJobInput {
            client_id,
            technician_profile_id: Some(tech_profile_id),
            tech_team_id: None,
            job_kind: "direct".to_string(),
            title: Some("Fuga de agua".to_string()),
            address: Some("Av. Siempre Viva 123".to_string()),
            mobility_included: None,
        })
        .await
        .unwrap();

    PayFeeUseCase::new(job_repo.clone(), Arc::new(FakePaymentGateway))
        .execute(PayFeeInput { job_request_id: job.id, client_id, payment_method: "card".to_string() })
        .await
        .unwrap();

    let after_payment = job_repo.find_job_request_by_id(job.id).await.unwrap().unwrap();
    assert!(after_payment.fee_paid);
    // A direct job carries no app fee, so "paying" settles nothing new and
    // no transaction happens: `payment_done` stays false. The paid path is
    // covered by `paying_a_bidding_fee_records_the_transaction`.
    assert!(!after_payment.payment_done);
    assert_eq!(after_payment.status.as_str(), "active");
    assert_eq!(after_payment.timeline_step, 0);

    let advance = AdvanceProgressUseCase::new(job_repo.clone(), tech_repo.clone());
    for expected_step in 1..=3 {
        advance.execute(job.id, tech_user_id).await.unwrap();
        let current = job_repo.find_job_request_by_id(job.id).await.unwrap().unwrap();
        assert_eq!(current.timeline_step, expected_step);
    }

    let completed = job_repo.find_job_request_by_id(job.id).await.unwrap().unwrap();
    assert_eq!(completed.status.as_str(), "completed");
}

#[sqlx::test(migrations = "./migrations")]
async fn a_technician_not_assigned_to_a_job_cannot_advance_it(pool: PgPool) {
    let job_repo: Arc<dyn JobRepository> = Arc::new(PostgresJobRepository::new(pool.clone()));
    let tech_repo: Arc<dyn TechnicianRepository> = Arc::new(PostgresTechnicianRepository::new(pool.clone()));

    let client_id = create_user(&pool, "client").await;
    let assigned_tech_user_id = create_user(&pool, "technician").await;
    let assigned_tech_profile_id = create_technician_profile(&pool, assigned_tech_user_id).await;
    let stranger_tech_user_id = create_user(&pool, "technician").await;
    create_technician_profile(&pool, stranger_tech_user_id).await;

    let job = CreateJobUseCase::new(job_repo.clone())
        .execute(CreateJobInput {
            client_id,
            technician_profile_id: Some(assigned_tech_profile_id),
            tech_team_id: None,
            job_kind: "direct".to_string(),
            title: None,
            address: None,
            mobility_included: None,
        })
        .await
        .unwrap();

    PayFeeUseCase::new(job_repo.clone(), Arc::new(FakePaymentGateway))
        .execute(PayFeeInput { job_request_id: job.id, client_id, payment_method: "cash".to_string() })
        .await
        .unwrap();

    let result = AdvanceProgressUseCase::new(job_repo.clone(), tech_repo.clone())
        .execute(job.id, stranger_tech_user_id)
        .await;

    assert!(result.is_err(), "a technician not assigned to the job must not be able to advance it");
}

#[sqlx::test(migrations = "./migrations")]
async fn rating_a_job_updates_the_technicians_average(pool: PgPool) {
    let job_repo: Arc<dyn JobRepository> = Arc::new(PostgresJobRepository::new(pool.clone()));
    let tech_repo: Arc<dyn TechnicianRepository> = Arc::new(PostgresTechnicianRepository::new(pool.clone()));

    let client_id = create_user(&pool, "client").await;
    let tech_user_id = create_user(&pool, "technician").await;
    let tech_profile_id = create_technician_profile(&pool, tech_user_id).await;

    let job = CreateJobUseCase::new(job_repo.clone())
        .execute(CreateJobInput {
            client_id,
            technician_profile_id: Some(tech_profile_id),
            tech_team_id: None,
            job_kind: "direct".to_string(),
            title: None,
            address: None,
            mobility_included: None,
        })
        .await
        .unwrap();

    let advance = AdvanceProgressUseCase::new(job_repo.clone(), tech_repo.clone());
    for _ in 0..3 {
        advance.execute(job.id, tech_user_id).await.unwrap();
    }

    RateJobUseCase::new(job_repo, tech_repo.clone())
        .execute(RateJobInput {
            job_request_id: job.id,
            client_id,
            rating: 3,
            comment: Some("Regular".to_string()),
        })
        .await
        .unwrap();

    let profile = tech_repo
        .find_profile_by_user_id(tech_user_id)
        .await
        .unwrap()
        .expect("profile");

    assert_eq!(profile.reviews, 1);
    assert!((profile.rating - 3.0).abs() < f64::EPSILON);
}

#[sqlx::test(migrations = "./migrations")]
async fn paying_a_bidding_fee_records_the_transaction(pool: PgPool) {
    let job_repo: Arc<dyn JobRepository> = Arc::new(PostgresJobRepository::new(pool.clone()));
    let tech_repo: Arc<dyn TechnicianRepository> = Arc::new(PostgresTechnicianRepository::new(pool.clone()));

    let client_id = create_user(&pool, "client").await;
    let tech_user_id = create_user(&pool, "technician").await;
    create_technician_profile(&pool, tech_user_id).await;

    let job = CreateJobUseCase::new(job_repo.clone())
        .execute(CreateJobInput {
            client_id,
            technician_profile_id: None,
            tech_team_id: None,
            job_kind: "bidding".to_string(),
            title: None,
            address: None,
            mobility_included: None,
        })
        .await
        .unwrap();
    assert!(!job.fee_paid);
    assert!(!job.payment_done);
    assert_eq!(job.status.as_str(), "pending");

    SubmitOfferUseCase::new(job_repo.clone(), tech_repo.clone())
        .execute(SubmitOfferInput {
            job_request_id: job.id,
            technician_user_id: tech_user_id,
            price: 27000,
            eta: "Hoy, 16:00".to_string(),
        })
        .await
        .unwrap();
    let offers = job_repo.find_offers_by_job_id(job.id).await.unwrap();
    ChooseOfferUseCase::new(job_repo.clone())
        .execute(ChooseOfferInput { job_request_id: job.id, client_id, offer_id: offers[0].id })
        .await
        .unwrap();

    PayFeeUseCase::new(job_repo.clone(), Arc::new(FakePaymentGateway))
        .execute(PayFeeInput { job_request_id: job.id, client_id, payment_method: "card".to_string() })
        .await
        .unwrap();

    let after_payment = job_repo.find_job_request_by_id(job.id).await.unwrap().unwrap();
    assert!(after_payment.fee_paid);
    assert!(after_payment.payment_done);
    assert_eq!(after_payment.status.as_str(), "active");
    assert_eq!(after_payment.timeline_step, 0);
}
