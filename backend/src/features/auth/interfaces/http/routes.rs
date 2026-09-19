use std::sync::Arc;

use axum::routing::{get, post};
use axum::Router;

use crate::shared::rate_limit::{self, RateLimiter};
use crate::state::AppState;

use super::handlers::{google_sign_in, login, me, register};

/// Attempts allowed per minute per caller against the credential
/// endpoints.
///
/// Every one of them runs a full Argon2id evaluation, so this is the
/// difference between "expensive" and "free to attack". Five is generous
/// for a human mistyping a password and hostile to a script; a legitimate
/// user who trips it waits out the window instead of being locked out.
pub const AUTH_ATTEMPTS_PER_MINUTE: u32 = 5;

/// A permissive budget for the rest of the API: enough that no real client
/// notices, low enough to shed an accidental retry loop or a runaway poll.
pub const GENERAL_REQUESTS_PER_MINUTE: u32 = 240;

pub fn auth_routes() -> Router<AppState> {
    // One limiter shared by all three credential endpoints, so switching
    // between `/auth/login` and `/auth/register` does not hand a caller a
    // second budget.
    let limiter = Arc::new(RateLimiter::new(AUTH_ATTEMPTS_PER_MINUTE));

    Router::new()
        .route("/auth/register", post(register))
        .route("/auth/login", post(login))
        .route("/auth/google", post(google_sign_in))
        .route("/me", get(me))
        .layer(axum::middleware::from_fn_with_state(limiter, rate_limit::enforce))
}
