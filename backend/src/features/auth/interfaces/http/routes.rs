use axum::routing::{get, post};
use axum::Router;

use crate::state::AppState;

use super::handlers::{google_sign_in, login, me, register};

pub fn auth_routes() -> Router<AppState> {
    Router::new()
        .route("/auth/register", post(register))
        .route("/auth/login", post(login))
        .route("/auth/google", post(google_sign_in))
        .route("/me", get(me))
}
