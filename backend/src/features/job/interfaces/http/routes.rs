use axum::routing::{get, post};
use axum::Router;

use crate::state::AppState;

use super::handlers::{
    advance_progress, cancel_job, choose_offer, create_job, get_client_history, get_job, get_offers,
    get_technician_jobs, pay_fee, rate_job, submit_offer,
};

pub fn job_routes() -> Router<AppState> {
    Router::new()
        .route("/jobs", post(create_job))
        .route("/jobs/{id}", get(get_job))
        .route("/jobs/{id}/pay", post(pay_fee))
        .route("/jobs/{id}/advance", post(advance_progress))
        .route("/jobs/{id}/rate", post(rate_job))
        .route("/jobs/{id}/cancel", post(cancel_job))
        .route("/jobs/{id}/offers", get(get_offers).post(submit_offer))
        .route("/jobs/{id}/offers/choose", post(choose_offer))
        .route("/client/history", get(get_client_history))
        .route("/technician/jobs", get(get_technician_jobs))
}
