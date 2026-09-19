//! Development seeder: loads `seeds/demo.sql` into the database named by
//! `DATABASE_URL`.
//!
//! This exists so demo data never travels through `sqlx::migrate!`. The
//! old migration 0002 seeded five accounts sharing the hash of
//! `password123`, and because migrations run on every startup those
//! credentials existed in production too (GAP-113). Demo fixtures are not
//! schema, so they are moved here, where nothing runs them implicitly.
//!
//! `seeds/demo.sql` deliberately stores a `NULL` password hash for every
//! demo account: combined with the profiles and teams it makes the app
//! browsable, while `login_user` answers `PasswordLoginUnavailable`
//! instead of granting a session. To sign in as a demo user locally, set
//! a password for it explicitly — that is a deliberate second step so the
//! fixture cannot become a shared credential again:
//!
//! ```text
//! cargo run --bin seed           # load the fixture
//! # then, to give client@cerca.com a password you choose:
//! #   POST /auth/register is unsuitable (the row exists), so use the
//! #   forgot-password flow once it exists, or set the hash by hand with
//! #   the hash produced by `cargo run --bin seed -- --hash <password>`.
//! ```
//!
//! Usage:
//!   `cargo run --bin seed`                  load seeds/demo.sql
//!   `cargo run --bin seed -- --hash <pwd>`  print an Argon2 hash for a
//!                                           password, to paste into SQL

use backend::features::auth::application::PasswordHasher;
use backend::features::auth::infrastructure::Argon2PasswordHasher;

#[tokio::main]
async fn main() {
    let _ = dotenvy::dotenv();

    let args: Vec<String> = std::env::args().collect();

    // `--hash` is a tiny utility so a developer never has to invent or
    // copy a credential hash from anywhere.
    if let Some(position) = args.iter().position(|a| a == "--hash") {
        let Some(password) = args.get(position + 1) else {
            eprintln!("usage: cargo run --bin seed -- --hash <password>");
            std::process::exit(2);
        };
        match Argon2PasswordHasher.hash(password) {
            Ok(hash) => println!("{hash}"),
            Err(()) => {
                eprintln!("could not hash the password");
                std::process::exit(1);
            }
        }
        return;
    }

    let database_url = std::env::var("DATABASE_URL")
        .expect("DATABASE_URL must be set (see backend/.env.example)");

    let sql = match tokio::fs::read_to_string("seeds/demo.sql").await {
        Ok(sql) => sql,
        Err(error) => {
            eprintln!(
                "could not read seeds/demo.sql ({error}) — run this from the `backend/` directory"
            );
            std::process::exit(1);
        }
    };

    let pool = match backend::db::create_pool(&database_url).await {
        Ok(pool) => pool,
        Err(error) => {
            eprintln!("could not connect to Postgres: {error}");
            std::process::exit(1);
        }
    };

    // `AssertSqlSafe`: the SQL comes from a file in this repository, not
    // from a request, and it carries no interpolation at all. sqlx's lint
    // exists to make exactly this judgement explicit.
    let statement = sqlx::raw_sql(sqlx::AssertSqlSafe(sql));

    match statement.execute(&pool).await {
        Ok(_) => {
            tracing::info!("demo fixture loaded");
            println!("demo fixture loaded into the database");
        }
        Err(error) => {
            eprintln!("failed to load the demo fixture: {error}");
            std::process::exit(1);
        }
    }
}
