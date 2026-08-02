use axum::routing::{get, post};
use axum::Router;

use crate::state::AppState;

use super::handlers::{
    confirm_document_upload, create_document_upload_url, get_documents, get_my_profile,
    get_providers, save_profile,
};

pub fn technician_routes() -> Router<AppState> {
    Router::new()
        .route("/providers", get(get_providers))
        .route("/technician/profile", get(get_my_profile).post(save_profile))
        .route("/technician/documents", get(get_documents))
        // Two steps because the file never passes through this server:
        // the device asks for a signed URL, uploads straight to the
        // bucket, then reports back.
        .route("/technician/documents/{document_key}/upload-url", post(create_document_upload_url))
        .route("/technician/documents/{document_key}/confirm", post(confirm_document_upload))
}
