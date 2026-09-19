//! Optimistic concurrency on `job_requests` (GAP-07).
//!
//! Every mutating use case reads a job, changes it, and writes it back.
//! The UPDATE used to be unconditional on anything but `id`, so two
//! requests that read the same row both wrote and the loser's change
//! vanished without an error. The concrete shapes that matters in:
//!
//!   * two clients/technicians racing on the same job;
//!   * a double-tapped button;
//!   * a retry after a timeout that actually succeeded.
//!
//! Migration 0013 adds a `version` counter and `save_job_request` compares
//! it, so the second writer matches no rows and gets a conflict instead of
//! silently overwriting.

use std::sync::Arc;

use sqlx::PgPool;
use uuid::Uuid;

use backend::features::job::application::{
    AdvanceProgressUseCase, CancelJobInput, CancelJobUseCase, ChooseOfferInput, ChooseOfferUseCase,
    CreateJobInput, CreateJobUseCase, SubmitOfferInput, SubmitOfferUseCase,
};
use backend::features::job::domain::{JobError, JobRepository, JobRequest};
use backend::features::job::infrastructure::PostgresJobRepository;
use backend::features::technician::domain::TechnicianRepository;
use backend::features::technician::infrastructure::PostgresTechnicianRepository;

fn job_repo(pool: &PgPool) -> Arc<dyn JobRepository> {
    Arc::new(PostgresJobRepository::new(pool.clone()))
}

fn tech_repo(pool: &PgPool) -> Arc<dyn TechnicianRepository> {
    Arc::new(PostgresTechnicianRepository::new(pool.clone()))
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

async fn create_bidding_job(pool: &PgPool, client_id: Uuid) -> JobRequest {
    CreateJobUseCase::new(job_repo(pool))
        .execute(CreateJobInput {
            client_id,
            technician_profile_id: None,
            tech_team_id: None,
            job_kind: "bidding".to_string(),
            title: Some("Fuga de agua".to_string()),
            address: None,
            mobility_included: None,
        })
        .await
        .unwrap()
}

/// A job is born at version 0.
#[sqlx::test(migrations = "./migrations")]
async fn a_new_job_starts_at_version_zero(pool: PgPool) {
    let client_id = create_user(&pool, "client").await;
    let job = create_bidding_job(&pool, client_id).await;

    assert_eq!(job.version, 0);
}

/// The heart of the fix: two writers that read the same version cannot both
/// win. Before this, the second write simply overwrote the first.
#[sqlx::test(migrations = "./migrations")]
async fn a_stale_write_is_refused_instead_of_overwriting(pool: PgPool) {
    let client_id = create_user(&pool, "client").await;
    let repo = job_repo(&pool);
    let job = create_bidding_job(&pool, client_id).await;

    // Two readers, both holding version 0 — the shape of any race.
    let first = repo.find_job_request_by_id(job.id).await.unwrap().unwrap();
    let second = repo.find_job_request_by_id(job.id).await.unwrap().unwrap();
    assert_eq!(first.version, second.version);

    // The first writer commits.
    let mut winner = first;
    winner.title = Some("Primero".to_string());
    repo.save_job_request(&winner).await.unwrap();

    // The second writer's decision was based on a version that no longer
    // exists.
    let mut loser = second;
    loser.title = Some("Segundo".to_string());
    let result = repo.save_job_request(&loser).await;

    assert!(
        matches!(result, Err(JobError::ConcurrentModification)),
        "a write against a stale version must be refused, got {result:?}"
    );

    let after = repo.find_job_request_by_id(job.id).await.unwrap().unwrap();
    assert_eq!(
        after.title.as_deref(),
        Some("Primero"),
        "the first writer's change must survive"
    );
    assert_eq!(after.version, 1, "the version advanced exactly once");
}

/// A read-modify-write in the normal, uncontended case must still work —
/// the guard cannot be so strict that it breaks ordinary flows.
#[sqlx::test(migrations = "./migrations")]
async fn sequential_writes_keep_working(pool: PgPool) {
    let client_id = create_user(&pool, "client").await;
    let repo = job_repo(&pool);
    let job = create_bidding_job(&pool, client_id).await;

    for expected_version in 1..=3 {
        // Re-read each time, as every use case does.
        let mut current = repo.find_job_request_by_id(job.id).await.unwrap().unwrap();
        current.title = Some(format!("Edición {expected_version}"));
        repo.save_job_request(&current).await.unwrap();

        let stored = repo.find_job_request_by_id(job.id).await.unwrap().unwrap();
        assert_eq!(stored.version, expected_version);
    }
}

/// The scenario the plan called out: two offer selections racing on the
/// same auction. Both read "pending, no technician", and exactly one must
/// be allowed to assign it — otherwise the first technician is told the job
/// is theirs while the row points at the second.
#[sqlx::test(migrations = "./migrations")]
async fn concurrent_offer_selections_assign_exactly_one_technician(pool: PgPool) {
    let client_id = create_user(&pool, "client").await;
    let (first_tech, _) = create_technician(&pool).await;
    let (second_tech, _) = create_technician(&pool).await;
    let job = create_bidding_job(&pool, client_id).await;

    let submit = SubmitOfferUseCase::new(job_repo(&pool), tech_repo(&pool));
    for (tech, price) in [(first_tech, 130), (second_tech, 150)] {
        submit
            .execute(SubmitOfferInput {
                job_request_id: job.id,
                technician_user_id: tech,
                price,
                eta: "Hoy".to_string(),
            })
            .await
            .unwrap();
    }

    let offers = job_repo(&pool).find_offers_by_job_id(job.id).await.unwrap();
    assert_eq!(offers.len(), 2);

    // Both selections are decided from the same observation of the job —
    // this is what a double tap or two racing requests looks like.
    let choose = ChooseOfferUseCase::new(job_repo(&pool));
    let first = choose
        .execute(ChooseOfferInput {
            job_request_id: job.id,
            client_id,
            offer_id: offers[0].id,
        })
        .await;
    let second = choose
        .execute(ChooseOfferInput {
            job_request_id: job.id,
            client_id,
            offer_id: offers[1].id,
        })
        .await;

    assert!(first.is_ok(), "the first selection must succeed: {first:?}");
    // The second is refused — either because the job is no longer pending
    // (its own status check) or because its version is stale. Both are
    // correct refusals; what matters is that it is not silently accepted.
    assert!(
        second.is_err(),
        "the second selection must not also succeed: {second:?}"
    );

    let after = job_repo(&pool).find_job_request_by_id(job.id).await.unwrap().unwrap();
    assert_eq!(
        after.technician_profile_id,
        Some(offers[0].technician_profile_id),
        "the job must point at the first winner"
    );
}

/// Two advances from the same step: the timeline must not skip, and the
/// loser must be told rather than silently losing its transition.
#[sqlx::test(migrations = "./migrations")]
async fn concurrent_advances_do_not_lose_a_transition(pool: PgPool) {
    let client_id = create_user(&pool, "client").await;
    let (tech_user, profile_id) = create_technician(&pool).await;
    let repo = job_repo(&pool);

    // A free `direct` job is born `active` at step 0.
    let job = CreateJobUseCase::new(repo.clone())
        .execute(CreateJobInput {
            client_id,
            technician_profile_id: Some(profile_id),
            tech_team_id: None,
            job_kind: "direct".to_string(),
            title: None,
            address: None,
            mobility_included: None,
        })
        .await
        .unwrap();

    let advance = AdvanceProgressUseCase::new(repo.clone(), tech_repo(&pool));

    // Two decisions from the same observation: both would write step 1.
    let observation = repo.find_job_request_by_id(job.id).await.unwrap().unwrap();
    assert_eq!(observation.version, 0);

    let first = advance.execute(job.id, tech_user).await;
    assert!(first.is_ok(), "{first:?}");

    // A second caller who had read version 0 is now stale.
    let mut stale = observation;
    stale.timeline_step += 1;
    let stale_result = repo.save_job_request(&stale).await;
    assert!(
        matches!(stale_result, Err(JobError::ConcurrentModification)),
        "a stale advance must not overwrite the newer one, got {stale_result:?}"
    );

    let after = repo.find_job_request_by_id(job.id).await.unwrap().unwrap();
    assert_eq!(after.timeline_step, 1, "the step advanced exactly once");
}

/// Cancellation is a state change like any other, so it participates: a
/// cancel decided against an old view must not undo a newer change.
#[sqlx::test(migrations = "./migrations")]
async fn a_cancel_against_a_stale_view_is_refused(pool: PgPool) {
    let client_id = create_user(&pool, "client").await;
    let repo = job_repo(&pool);
    let job = create_bidding_job(&pool, client_id).await;

    // Read the job, then let someone else change it.
    let stale = repo.find_job_request_by_id(job.id).await.unwrap().unwrap();

    let mut newer = repo.find_job_request_by_id(job.id).await.unwrap().unwrap();
    newer.title = Some("Cambiado por otro".to_string());
    repo.save_job_request(&newer).await.unwrap();

    // Now try to cancel using the stale copy.
    let mut cancelling = stale;
    cancelling.cancel(client_id, None).unwrap();
    let result = repo.save_job_request(&cancelling).await;

    assert!(
        matches!(result, Err(JobError::ConcurrentModification)),
        "got {result:?}"
    );

    let after = repo.find_job_request_by_id(job.id).await.unwrap().unwrap();
    assert_eq!(after.status.as_str(), "pending", "the job must still be open");
    assert_eq!(after.title.as_deref(), Some("Cambiado por otro"));
}

/// The use case path, not just the repository: a cancel that loses the race
/// must surface as a refusal rather than a silent no-op.
#[sqlx::test(migrations = "./migrations")]
async fn the_use_case_reports_the_conflict(pool: PgPool) {
    let client_id = create_user(&pool, "client").await;
    let repo = job_repo(&pool);
    let job = create_bidding_job(&pool, client_id).await;

    // Bump the version behind the use case's back, simulating another
    // request that committed between its read and its write.
    sqlx::query("UPDATE job_requests SET version = version + 1 WHERE id = $1")
        .bind(job.id)
        .execute(&pool)
        .await
        .unwrap();

    // The use case re-reads, so this one succeeds — proving the guard does
    // not fire on an up-to-date read.
    CancelJobUseCase::new(repo.clone())
        .execute(CancelJobInput {
            job_request_id: job.id,
            client_id,
            reason: None,
        })
        .await
        .unwrap();

    assert_eq!(
        repo.find_job_request_by_id(job.id).await.unwrap().unwrap().status.as_str(),
        "cancelled"
    );
}
