use axum::http::{header, HeaderValue, Method};
use axum::routing::get;
use axum::Router;
use tower_http::cors::{AllowOrigin, CorsLayer};
use tower_http::trace::TraceLayer;

use crate::features::auth::interfaces::http::auth_routes;
use crate::features::technician::interfaces::http::technician_routes;
use crate::features::client::interfaces::http::client_routes;
use crate::features::job::interfaces::http::job_routes;
use crate::features::chat::interfaces::http::chat_routes;
use crate::features::tracking::interfaces::http::tracking_routes;
use crate::state::AppState;

async fn health() -> &'static str {
    "ok"
}

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
        .with_state(state)
}
