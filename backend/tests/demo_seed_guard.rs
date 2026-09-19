//! Guards against the demo credentials that migration 0002 seeds
//! (GAP-113).
//!
//! `sqlx::migrate!` runs at every startup, so when the seed block lived in
//! a migration the five accounts it creates — all sharing the Argon2 hash
//! of `password123`, which `backend/README.md` documented — existed in
//! *every* environment, production included, and `client@cerca.com` handed
//! out a valid 7-day session to anyone who read the repository.
//!
//! Three things have to hold, and this file checks all three:
//!   1. migration 0011 nulls those hashes, so password login stops working;
//!   2. the hash constant the guard compares against actually matches what
//!      migration 0002 inserted (otherwise the guard would silently never
//!      fire, and the drift would be invisible);
//!   3. `count_with_password_hash` reports leftovers, which is what `main`
//!      uses to refuse a production boot.

use std::sync::Arc;

use sqlx::PgPool;

use backend::features::auth::domain::{UserRepository, DEMO_SEED_PASSWORD_HASH};
use backend::features::auth::infrastructure::PostgresUserRepository;

fn repo(pool: &PgPool) -> Arc<PostgresUserRepository> {
    Arc::new(PostgresUserRepository::new(pool.clone()))
}

/// The migration is what makes an already-deployed database safe, so this
/// is the assertion that matters for production.
#[sqlx::test(migrations = "./migrations")]
async fn the_demo_password_hash_is_gone_after_migrating(pool: PgPool) {
    let leftover: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM users WHERE password_hash = $1")
        .bind(DEMO_SEED_PASSWORD_HASH)
        .fetch_one(&pool)
        .await
        .unwrap();

    assert_eq!(
        leftover.0, 0,
        "migration 0011 must neutralise every account still carrying the \
         publicly-known demo password"
    );
}

/// The seeded rows themselves are kept — `job_requests` and friends
/// reference them, so deleting the users would cascade real jobs away.
/// What must not survive is the credential.
#[sqlx::test(migrations = "./migrations")]
async fn the_demo_accounts_survive_without_a_password(pool: PgPool) {
    let rows: Vec<(String, Option<String>)> =
        sqlx::query_as("SELECT email, password_hash FROM users WHERE email LIKE '%@cerca.com' ORDER BY email")
            .fetch_all(&pool)
            .await
            .unwrap();

    assert_eq!(rows.len(), 5, "the demo accounts are still there to reference");
    for (email, hash) in rows {
        assert!(
            hash.is_none(),
            "{email} still has a usable password hash after migrating"
        );
    }
}

/// If migration 0002's literal and `DEMO_SEED_PASSWORD_HASH` ever drift
/// apart, the deployment guard in `main` would compare against a hash no
/// row carries and pass unconditionally — a silent hole. Re-deriving the
/// inserted value from the migration file catches that.
#[test]
fn the_guard_hash_matches_what_migration_0002_inserts() {
    let migration = include_str!("../migrations/0002_cerca_features.sql");

    assert!(
        migration.contains(DEMO_SEED_PASSWORD_HASH),
        "DEMO_SEED_PASSWORD_HASH no longer appears in migration 0002: either it was \
         mistyped, or 0002 changed. The production guard compares users.password_hash \
         against this constant, so a mismatch makes it a no-op."
    );
}

/// What `main` calls before it starts serving traffic.
#[sqlx::test(migrations = "./migrations")]
async fn leftover_demo_credentials_are_reported_to_the_deployment_guard(pool: PgPool) {
    // Freshly migrated: nothing left to report.
    assert_eq!(
        repo(&pool).count_with_password_hash(DEMO_SEED_PASSWORD_HASH).await.unwrap(),
        0
    );

    // Simulate a database that never ran 0011 — the state a production
    // instance must refuse to boot in.
    sqlx::query("UPDATE users SET password_hash = $1 WHERE email = 'client@cerca.com'")
        .bind(DEMO_SEED_PASSWORD_HASH)
        .execute(&pool)
        .await
        .unwrap();

    assert_eq!(
        repo(&pool).count_with_password_hash(DEMO_SEED_PASSWORD_HASH).await.unwrap(),
        1,
        "the guard must see the reintroduced credential"
    );
}

/// The guard matches on the hash, not on the email, so an account whose
/// password was rotated legitimately is out of its scope — and, just as
/// importantly, an unrelated account whose password merely *looks* like a
/// credential is not pulled in either.
#[sqlx::test(migrations = "./migrations")]
async fn the_guard_only_counts_the_exact_demo_hash(pool: PgPool) {
    // Two accounts in the state a never-migrated database would be in.
    sqlx::query("UPDATE users SET password_hash = $1 WHERE email = 'client@cerca.com'")
        .bind(DEMO_SEED_PASSWORD_HASH)
        .execute(&pool)
        .await
        .unwrap();
    sqlx::query("UPDATE users SET password_hash = 'some-other-real-hash' WHERE email = 'ana@cerca.com'")
        .execute(&pool)
        .await
        .unwrap();

    assert_eq!(
        repo(&pool).count_with_password_hash(DEMO_SEED_PASSWORD_HASH).await.unwrap(),
        1,
        "only the account actually carrying the demo hash may be counted"
    );

    // Rotating the offending password is the other way out of the guard,
    // without needing migration 0011 to have run.
    sqlx::query("UPDATE users SET password_hash = 'a-fresh-hash' WHERE email = 'client@cerca.com'")
        .execute(&pool)
        .await
        .unwrap();

    assert_eq!(
        repo(&pool).count_with_password_hash(DEMO_SEED_PASSWORD_HASH).await.unwrap(),
        0,
        "a rotated password must not keep the account flagged"
    );
}
