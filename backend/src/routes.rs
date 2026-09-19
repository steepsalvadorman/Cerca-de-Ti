use std::sync::Arc;

use axum::http::{header, HeaderValue, Method};
use axum::routing::get;
use axum::Router;
use tower_http::cors::{AllowOrigin, CorsLayer};
use tower_http::trace::TraceLayer;

use crate::features::auth::interfaces::http::auth_routes;
use crate::features::auth::interfaces::http::routes::GENERAL_REQUESTS_PER_MINUTE;
use crate::features::technician::interfaces::http::technician_routes;
use crate::features::client::interfaces::http::client_routes;
use crate::features::job::interfaces::http::job_routes;
use crate::features::chat::interfaces::http::chat_routes;
use crate::features::tracking::interfaces::http::tracking_routes;
use crate::shared::rate_limit::{self, RateLimiter};
use crate::state::AppState;

async fn health() -> &'static str {
    "ok"
}

/// Largest request body the API will read, in bytes.
///
/// The largest legitimate payload is a technician profile: a trade, a
/// price label, a radius and two short arrays — well under a kilobyte. The
/// rest are ids and short text. 64 KiB is therefore generous for every
/// real request while making a 100 MB `title` impossible to even read, let
/// alone store (GAP-02).
///
/// Document *bytes* never pass through this server: uploads go straight to
/// the bucket from the device, so this limit does not constrain them.
const MAX_REQUEST_BODY_BYTES: usize = 64 * 1024;

/// Builds the CORS layer from a list of allowed origins. An empty list
/// (the default — see `AppConfig::cors_allowed_origins`) rejects every
/// browser-based cross-origin request, which is the safe default for a
/// mobile-only API. Invalid origin strings are dropped rather than
/// panicking, since this runs at startup from env-provided config.
fn cors_layer(allowed_origins: &[String]) -> CorsLayer {
    let origins: Vec<HeaderValue> = allowed_origins
        .iter()
        .filter_map(|origin| HeaderValue::from_str(origin).ok())
        .collect();

    CorsLayer::new()
        .allow_origin(AllowOrigin::list(origins))
        .allow_methods([Method::GET, Method::POST, Method::PATCH, Method::DELETE])
        .allow_headers([header::AUTHORIZATION, header::CONTENT_TYPE])
}

pub fn app_router(state: AppState, cors_allowed_origins: &[String]) -> Router {
    // A second, much looser limiter over everything: it exists to shed an
    // accidental retry loop or a runaway poll, not to police behaviour.
    // Kept separate from the credential limiter so a busy chat screen
    // cannot use up anyone's login attempts.
    let general_limiter = Arc::new(RateLimiter::new(GENERAL_REQUESTS_PER_MINUTE));

    Router::new()
        .route("/health", get(health))
        .merge(auth_routes())
        .merge(technician_routes())
        .merge(client_routes())
        .merge(job_routes())
        .merge(chat_routes())
        .merge(tracking_routes())
        .layer(TraceLayer::new_for_http())
        .layer(cors_layer(cors_allowed_origins))
        // Reject an oversized body before any handler reads it. Layer
        // order matters: this has to sit outside the handlers, and inside
        // the limiter, so a flood of huge bodies costs a header check
        // rather than a buffer.
        .layer(tower_http::limit::RequestBodyLimitLayer::new(MAX_REQUEST_BODY_BYTES))
        // Outermost, so a refused request costs neither a handler nor a
        // database round-trip.
        .layer(axum::middleware::from_fn_with_state(general_limiter, rate_limit::enforce))
        .with_state(state)
}
